package id.dwiky.transpadang_live

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.annotation.RequiresApi
import kotlin.math.roundToInt
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * Layanan foreground yang "mengikuti" satu bus TransPadang: membuka koneksi
 * WebSocket sendiri (independen dari UI), berlangganan satu koridor, lalu
 * memperbarui notifikasi ongoing berisi halte berikutnya + ETA + progress.
 *
 * Di Android 16+ (API 36) notifikasi memakai Notification.ProgressStyle dan
 * meminta status promoted ongoing lewat extra "android.requestPromotedOngoing"
 * (aplikasi tak boleh men-set FLAG_PROMOTED_ONGOING langsung; sistem yang
 * men-set-nya) sehingga tampil sebagai "live update"; di versi lebih lama
 * dipakai progress bar biasa.
 */
class FollowService : Service() {

    companion object {
        private const val TAG = "FollowService"
        const val CHANNEL_ID = "bus_follow"
        const val NOTIFICATION_ID = 4201
        const val ACTION_START = "id.dwiky.transpadang_live.follow.START"
        const val ACTION_STOP = "id.dwiky.transpadang_live.follow.STOP"

        const val EXTRA_CORRIDOR = "corridor"
        const val EXTRA_BUS_NUMBER = "busNumber"
        const val EXTRA_ORIGIN = "origin"
        const val EXTRA_DESTINATION = "destination"
        const val EXTRA_ROUTE = "route"
        const val EXTRA_DIRECTION = "direction"
        const val EXTRA_HALTES = "haltes"

        /** Warna aksen notifikasi (ARGB) yang sudah dihitung di Dart. */
        const val EXTRA_COLOR = "color"

        /** Fallback bila Dart tidak mengirim warna (abu-abu badge default). */
        val DEFAULT_KEY_COLOR = 0xFF546E7A.toInt()

        const val WS_URL = "wss://wstrans.padang.go.id/ws"

        // Sama dengan NotificationCompat.EXTRA_REQUEST_PROMOTED_ONGOING (androidx.core).
        // Aplikasi TIDAK boleh men-set FLAG_PROMOTED_ONGOING langsung; cukup minta
        // promosi lewat extra ini, dan sistem yang akan men-set flag tersebut.
        private const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"

        private const val STALE_MILLIS = 5 * 60 * 1000L
        private const val STALE_CHECK_INTERVAL = 30_000L
        private const val RECONNECT_DELAY = 5_000L

        private val _active = AtomicBoolean(false)
        val isActive: Boolean get() = _active.get()

        private val _followedCorridor = AtomicReference("")
        private val _followedBusNumber = AtomicReference("")
        val followedCorridor: String get() = _followedCorridor.get()
        val followedBusNumber: String get() = _followedBusNumber.get()
    }

    private var corridor = ""
    private var busNumber = ""
    private var origin = ""
    private var destination = ""
    private var route = ""
    private var direction = ""
    private val stops = ArrayList<HalteMath.Point>()
    private val stopNames = ArrayList<String>()
    private var keyColor = 0

    private var client: OkHttpClient? = null
    private var generation = 0
    private var lastMatchMillis = 0L

    private var hasPosition = false
    private var nextName: String? = null
    private var distKm: Double? = null
    private var etaMin: Int? = null
    private var pct = 0

    private val handler = Handler(Looper.getMainLooper())

    private val staleCheck = object : Runnable {
        override fun run() {
            handler.removeCallbacks(this)
            if (!_active.get()) return
            if (System.currentTimeMillis() - lastMatchMillis > STALE_MILLIS) {
                Log.d(TAG, "Data bus basi lebih dari 5 menit; berhenti follow")
                stopFollow()
                return
            }
            handler.postDelayed(this, STALE_CHECK_INTERVAL)
        }
    }

    private val reconnectRunnable = Runnable { connectWS() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                Log.d(TAG, "ACTION_STOP diterima")
                stopFollow()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                Log.d(TAG, "ACTION_START diterima")
                readExtras(intent)
                lastMatchMillis = System.currentTimeMillis()
                ensureNotificationChannel()
                startForegroundCompat()
                handler.removeCallbacks(staleCheck)
                handler.postDelayed(staleCheck, STALE_CHECK_INTERVAL)
                disconnectWS()
                connectWS()
                return START_NOT_STICKY
            }
            else -> {
                stopSelf()
                return START_NOT_STICKY
            }
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopFollow()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        _active.set(false)
        _followedCorridor.set("")
        _followedBusNumber.set("")
        handler.removeCallbacks(staleCheck)
        handler.removeCallbacks(reconnectRunnable)
        disconnectWS()
        super.onDestroy()
    }

    private fun readExtras(intent: Intent) {
        corridor = intent.getStringExtra(EXTRA_CORRIDOR) ?: ""
        busNumber = intent.getStringExtra(EXTRA_BUS_NUMBER) ?: ""
        origin = intent.getStringExtra(EXTRA_ORIGIN) ?: ""
        destination = intent.getStringExtra(EXTRA_DESTINATION) ?: ""
        route = intent.getStringExtra(EXTRA_ROUTE) ?: ""
        direction = intent.getStringExtra(EXTRA_DIRECTION) ?: ""
        keyColor = intent.getIntExtra(EXTRA_COLOR, DEFAULT_KEY_COLOR)

        stops.clear()
        stopNames.clear()
        try {
            val arr = JSONArray(intent.getStringExtra(EXTRA_HALTES) ?: "[]")
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                stopNames.add(o.optString("nama").ifEmpty { "Halte ${i + 1}" })
                stops.add(HalteMath.Point(o.optDouble("lat", 0.0), o.optDouble("lng", 0.0)))
            }
        } catch (e: Exception) {
            Log.w(TAG, "Gagal membaca daftar halte: ${e.message}")
        }

        hasPosition = false
        nextName = null
        distKm = null
        etaMin = null
        pct = 0
        _active.set(true)
        _followedCorridor.set(corridor)
        _followedBusNumber.set(busNumber)
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val ch = NotificationChannel(
            CHANNEL_ID,
            "Follow bus",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Notifikasi posisi bus yang sedang diikuti"
            setShowBadge(false)
        }
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(ch)
    }

    private fun startForegroundCompat() {
        val n = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
    }

    private fun pendingFlags(): Int {
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            f = f or PendingIntent.FLAG_IMMUTABLE
        }
        return f
    }

    private fun contentIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(this, 1, intent, pendingFlags())
    }

    private fun stopIntent(): PendingIntent {
        val intent = Intent(this, FollowService::class.java).setAction(ACTION_STOP)
        return PendingIntent.getService(
            this,
            NOTIFICATION_ID,
            intent,
            pendingFlags(),
        )
    }

    private fun formatKm(km: Double): String {
        if (km < 1) return "${(km * 1000).roundToInt()} m"
        return String.format(Locale.US, "%.1f km", km)
    }

    private fun buildNotification(): Notification {
        val title = if (busNumber.isNotEmpty()) {
            "Bus $busNumber · Koridor $corridor"
        } else {
            "Follow bus $corridor"
        }

        var text: String
        var sub: String
        if (hasPosition && nextName != null) {
            text = "Menuju $nextName"
            sub = buildString {
                if (distKm != null) {
                    append("${formatKm(distKm!!)} ke halte berikutnya")
                    if (etaMin != null) append(" · ±$etaMin mnt")
                } else {
                    append("Mencari halte berikutnya…")
                }
            }
        } else {
            text = "Mencari sinyal bus…"
            sub = destination.ifBlank { "Ikuti bus hingga tiba di tujuan" }
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setSmallIcon(R.drawable.ic_stat_dot)
            .setContentTitle(title)
            .setContentText(text)
            .setSubText(sub)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setPriority(Notification.PRIORITY_LOW)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setColor(keyColor)
            .setContentIntent(contentIntent())
            .addAction(0, "Berhenti", stopIntent())

        if (hasPosition) {
            builder.setProgress(100, pct, false)
        } else {
            builder.setProgress(0, 0, true)
        }

        val n: Notification
        if (Build.VERSION.SDK_INT >= 36) {
            n = applyProgressStyle(builder, pct, !hasPosition).build()
        } else {
            n = builder.build()
        }
        return n
    }

    /**
     * Live update (Android 16): notifikasi berformat progress + minta promosi.
     *
     * PENTING: nilai progres bar harus di-set pada ProgressStyle itu sendiri
     * ([Notification.ProgressStyle.setProgress]); builder.setProgress() diabaikan
     * saat template ProgressStyle dipakai. Maksimumnya = jumlah panjang Segments,
     * atau 100 bila tak ada segment.
     */
    @RequiresApi(36)
    private fun applyProgressStyle(
        builder: Notification.Builder,
        progressPct: Int,
        indeterminate: Boolean,
    ): Notification.Builder {
        val icon = Icon.createWithResource(this, R.drawable.ic_stat_dot)
        builder.extras.putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true)
        val style = Notification.ProgressStyle()
            .setStyledByProgress(true)
            .setProgressTrackerIcon(icon)
        if (indeterminate) {
            style.setProgressIndeterminate(true)
        } else {
            style.setProgress(progressPct.coerceIn(0, 100))
        }
        return builder.setStyle(style)
    }

    private fun pushNotification() {
        if (!_active.get()) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, buildNotification())
    }

    // ---- WebSocket ----

    private fun connectWS() {
        if (!_active.get()) return
        val myGen = ++generation
        try {
            val c = OkHttpClient.Builder()
                .connectTimeout(15, TimeUnit.SECONDS)
                .readTimeout(0, TimeUnit.MILLISECONDS)
                .pingInterval(30, TimeUnit.SECONDS)
                .build()
            client = c
            val request = Request.Builder().url(WS_URL).build()
            c.newWebSocket(request, object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: Response) {
                    if (myGen != generation) return
                    Log.d(TAG, "WS terbuka, subscribe $corridor")
                    lastMatchMillis = System.currentTimeMillis()
                    val msg = JSONObject()
                        .put("type", "subscribeKoridor")
                        .put("koridor", corridor)
                        .toString()
                    webSocket.send(msg)
                }

                override fun onMessage(webSocket: WebSocket, text: String) {
                    if (myGen != generation) return
                    handleMessage(text)
                }

                override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                    if (myGen != generation) return
                    Log.d(TAG, "WS gagal: ${t.message}")
                    scheduleReconnect()
                }

                override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                    if (myGen != generation) return
                    Log.d(TAG, "WS ditutup: $reason")
                    scheduleReconnect()
                }
            })
        } catch (e: Exception) {
            Log.w(TAG, "Gagal membuka WS: ${e.message}")
            scheduleReconnect()
        }
    }

    private fun disconnectWS() {
        generation++
        client?.dispatcher?.cancelAll()
        client?.connectionPool?.evictAll()
        client = null
    }

    private fun scheduleReconnect() {
        if (!_active.get()) return
        handler.removeCallbacks(reconnectRunnable)
        handler.postDelayed(reconnectRunnable, RECONNECT_DELAY)
    }

    private fun handleMessage(text: String) {
        try {
            val obj = JSONObject(text)
            if (obj.optString("type") != "busLocationByKoridor") return
            val data = obj.optJSONArray("data") ?: return
            for (i in 0 until data.length()) {
                val d = data.optJSONObject(i) ?: continue
                if (d.optString("bus") != busNumber) continue

                // Server mengirim field latitude/longitude TERBALIK.
                val lat = d.optDouble("longitude", Double.NaN)
                val lng = d.optDouble("latitude", Double.NaN)
                if (lat.isNaN() || lng.isNaN()) return

                val rawSpeed = d.optDouble("speed", -1.0)
                val speedKmh = if (rawSpeed >= 0) rawSpeed else null

                val progress = HalteMath.computeProgress(
                    stops,
                    HalteMath.Point(lat, lng),
                )

                hasPosition = true
                lastMatchMillis = System.currentTimeMillis()
                if (progress != null) {
                    nextName = stopNames.getOrNull(progress.nextIndex)
                    distKm = progress.distanceToNextKm
                    etaMin = HalteMath.etaMinutes(progress.distanceToNextKm, speedKmh)
                    pct = (progress.fraction * 100).roundToInt().coerceIn(0, 100)
                    Log.d(TAG, "Bus $busNumber: halte ${progress.nextIndex + 1}/${stopNames.size} " +
                        "(${formatKm(progress.distanceToNextKm)})")
                } else {
                    nextName = stopNames.firstOrNull()
                    distKm = null
                    etaMin = null
                    pct = 0
                }
                pushNotification()
                return
            }
        } catch (e: Exception) {
            Log.w(TAG, "Data tidak dapat diparse: ${e.message}")
        }
    }

    private fun stopFollow() {
        if (!_active.getAndSet(false)) {
            stopSelf()
            return
        }
        _followedCorridor.set("")
        _followedBusNumber.set("")
        handler.removeCallbacks(staleCheck)
        handler.removeCallbacks(reconnectRunnable)
        disconnectWS()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(NOTIFICATION_ID)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }
}