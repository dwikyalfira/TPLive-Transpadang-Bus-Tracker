package id.dwiky.transpadang_live

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.wear.ongoing.OngoingActivity
import androidx.wear.ongoing.Status

/**
 * Menampilkan bus yang di-pin sebagai Ongoing Activity Wear OS (chip "live" di
 * watch face / launcher / recents) dan membuka app jam otomatis saat sebuah
 * bus baru di-pin.
 */
object PinnedBusNotifier {

    private const val TAG = "PinnedBusNotifier"
    private const val CHANNEL_LIVE = "pinned_bus_live"
    private const val CHANNEL_OPEN = "pinned_bus_open"
    private const val ID_LIVE = 7001
    private const val ID_OPEN = 7002
    private const val PREFS = "pinned_bus_state"
    private const val KEY_ACTIVE = "was_active"
    private const val KEY_LAST_SEEN = "last_seen"

    private fun canNotify(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    private fun ensureChannels(ctx: Context) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_LIVE,
                ctx.getString(R.string.channel_live),
                NotificationManager.IMPORTANCE_LOW,
            ).apply { setShowBadge(false) },
        )
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_OPEN,
                ctx.getString(R.string.channel_open),
                NotificationManager.IMPORTANCE_HIGH,
            ),
        )
    }

    private fun appIntent(ctx: Context): PendingIntent {
        val intent = Intent(ctx, WearMainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            ctx, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Bus di-pin / diperbarui: perbarui Ongoing Activity; buka app bila baru di-pin. */
    fun onPinned(ctx: Context, bus: PinnedBus) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        // Sesi dianggap sudah berakhir bila data sempat berhenti (HP mati mendadak),
        // sehingga pin berikutnya dihitung sebagai bus baru (app dibuka lagi).
        val wasActive = prefs.getBoolean(KEY_ACTIVE, false) &&
            now - prefs.getLong(KEY_LAST_SEEN, 0L) < PinnedBus.STALE_MS
        prefs.edit().putBoolean(KEY_ACTIVE, true).putLong(KEY_LAST_SEEN, now).apply()

        postOngoing(ctx, bus)
        if (!wasActive) openApp(ctx)
    }

    /** Bus di-unpin: hapus Ongoing Activity dan reset status. */
    fun onUnpinned(ctx: Context) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY_ACTIVE, false).apply()
        NotificationManagerCompat.from(ctx).apply {
            cancel(ID_LIVE)
            cancel(ID_OPEN)
        }
    }

    private fun postOngoing(ctx: Context, bus: PinnedBus) {
        if (!canNotify(ctx)) {
            Log.d(TAG, "POST_NOTIFICATIONS belum diizinkan; Ongoing Activity dilewati")
            return
        }
        ensureChannels(ctx)

        val stopName = bus.nextStop ?: bus.searchingLabel.orEmpty()
        val detail = listOfNotNull(bus.etaText, bus.distanceText).joinToString(" · ")
        val pending = appIntent(ctx)

        val builder = NotificationCompat.Builder(ctx, CHANNEL_LIVE)
            .setSmallIcon(R.drawable.ic_stat_bus)
            .setContentTitle(bus.title.replace(" · ", " – "))
            .setContentText(listOf(stopName, detail).filter { it.isNotEmpty() }.joinToString("\n"))
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setColor(bus.color)
            .setContentIntent(pending)
            // Hilang sendiri bila HP berhenti mengirim; tiap update memasang ulang
            // notifikasi sehingga batas waktunya ikut diperpanjang.
            .setTimeoutAfter(PinnedBus.STALE_MS)

        // Status singkat di chip watch face: "<halte> · ±N mnt".
        val chipText = if (detail.isNotEmpty()) "$stopName · ${bus.etaText ?: bus.distanceText}" else stopName
        val status = Status.Builder()
            .addTemplate("#text#")
            .addPart("text", Status.TextPart(chipText))
            .build()

        try {
            OngoingActivity.Builder(ctx.applicationContext, ID_LIVE, builder)
                .setStaticIcon(R.drawable.ic_stat_bus)
                .setTouchIntent(pending)
                .setStatus(status)
                .build()
                .apply(ctx.applicationContext)
            NotificationManagerCompat.from(ctx).notify(ID_LIVE, builder.build())
        } catch (e: SecurityException) {
            Log.w(TAG, "Gagal memposting notifikasi: ${e.message}")
        }
    }

    /**
     * Membuka app jam otomatis. Android membatasi start activity dari latar,
     * jadi: (1) langsung bila izin "tampil di atas app lain" diberikan, atau
     * (2) notifikasi full-screen-intent sebagai cadangan (heads-up bila layar
     * menyala dan app lain di depan; membuka app bila layar mati).
     */
    private fun openApp(ctx: Context) {
        val intent = Intent(ctx, WearMainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (Settings.canDrawOverlays(ctx)) {
            try {
                ctx.startActivity(intent)
                return
            } catch (e: Exception) {
                Log.w(TAG, "startActivity gagal: ${e.message}")
            }
        }
        if (!canNotify(ctx)) return
        ensureChannels(ctx)
        val pending = appIntent(ctx)
        val n = NotificationCompat.Builder(ctx, CHANNEL_OPEN)
            .setSmallIcon(R.drawable.ic_stat_bus)
            .setContentTitle(ctx.getString(R.string.pinned_open_title))
            .setContentText(ctx.getString(R.string.pinned_open_text))
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setTimeoutAfter(15_000)
            .setContentIntent(pending)
            .setFullScreenIntent(pending, true)
            .build()
        try {
            NotificationManagerCompat.from(ctx).notify(ID_OPEN, n)
        } catch (e: SecurityException) {
            Log.w(TAG, "Gagal memposting notifikasi buka-app: ${e.message}")
        }
    }
}
