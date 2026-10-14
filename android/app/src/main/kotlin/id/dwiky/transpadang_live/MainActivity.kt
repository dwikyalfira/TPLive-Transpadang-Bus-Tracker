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
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "id.dwiky.transpadang_live/follow"
        private const val REQ_POST_NOTIFICATIONS = 9001

        /// Kanal notifikasi penting untuk acara kedatangan bus (bersuara &
        /// bergetar via DEFAULT_ALL).
        private const val EVENT_CHANNEL_ID = "bus_events"
    }

    private var notifPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isFollowing" -> result.success(FollowService.isActive)
                    "getFollowed" -> {
                        if (FollowService.isActive) {
                            result.success(
                                mapOf(
                                    "corridor" to FollowService.followedCorridor,
                                    "busNumber" to FollowService.followedBusNumber,
                                ),
                            )
                        } else {
                            result.success(null)
                        }
                    }
                    "startFollow" -> startFollow(call, result)
                    "stopFollow" -> {
                        val intent = Intent(this, FollowService::class.java)
                            .setAction(FollowService.ACTION_STOP)
                        startService(intent)
                        result.success(true)
                    }
                    "requestNotificationPermission" -> requestNotifPermission(result)
                    "showEventNotification" -> showEventNotification(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun startFollow(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val corridor = args?.get("corridor") as? String ?: ""
        val busNumber = args?.get("busNumber") as? String ?: ""
        if (corridor.isEmpty() || busNumber.isEmpty()) {
            result.error("invalid_args", "corridor dan busNumber wajib diisi", null)
            return
        }

        val intent = Intent(this, FollowService::class.java)
            .setAction(FollowService.ACTION_START)
            .putExtra(FollowService.EXTRA_CORRIDOR, corridor)
            .putExtra(FollowService.EXTRA_BUS_NUMBER, busNumber)
            .putExtra(FollowService.EXTRA_ORIGIN, args?.get("origin") as? String ?: "")
            .putExtra(FollowService.EXTRA_DESTINATION, args?.get("destination") as? String ?: "")
            .putExtra(FollowService.EXTRA_ROUTE, args?.get("route") as? String ?: "")
            .putExtra(FollowService.EXTRA_DIRECTION, args?.get("direction") as? String ?: "")
            .putExtra(FollowService.EXTRA_HALTES, encodeHaltes(args?.get("haltes")))

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            @Suppress("DEPRECATION")
            startService(intent)
        }
        result.success(true)
    }

    private fun encodeHaltes(value: Any?): String {
        if (value is List<*>) {
            val sb = StringBuilder("[")
            var first = true
            for (h in value) {
                if (h is Map<*, *>) {
                    if (!first) sb.append(',')
                    first = false
                    sb.append("{\"nama\":\"")
                        .append(escapeJson((h["nama"] as? String) ?: ""))
                        .append("\",\"lat\":")
                        .append(h["lat"])
                        .append(",\"lng\":")
                        .append(h["lng"])
                        .append('}')
                }
            }
            return sb.append(']').toString()
        }
        return "[]"
    }

    private fun escapeJson(s: String): String {
        return s
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
    }

    /// Notifikasi sesaat dengan suara & getar untuk acara kedatangan bus.
    private fun showEventNotification(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val title = (args?.get("title") as? String) ?: "TPLive"
        val body = (args?.get("body") as? String) ?: ""
        val id = ((args?.get("id") as? Number)?.toInt()) ?: 9101
        notifyEvent(title, body, id)
        result.success(true)
    }

    private fun notifyEvent(title: String, body: String, id: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureEventChannel(manager)

        val intent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val contentIntent = PendingIntent.getActivity(
            this, id, intent, pendingFlags(),
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, EVENT_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setSmallIcon(R.drawable.ic_stat_bus)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .setDefaults(Notification.DEFAULT_ALL)
            .setPriority(Notification.PRIORITY_HIGH)

        manager.notify(id, builder.build())
    }

    private fun ensureEventChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (manager.getNotificationChannel(EVENT_CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            EVENT_CHANNEL_ID,
            "Kedatangan bus",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Pemberitahuan kedatangan bus yang diikuti"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 250, 150, 250)
        }
        manager.createNotificationChannel(channel)
    }

    private fun pendingFlags(): Int {
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            f = f or PendingIntent.FLAG_IMMUTABLE
        }
        return f
    }

    private fun requestNotifPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        notifPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQ_POST_NOTIFICATIONS,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_POST_NOTIFICATIONS) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            notifPermissionResult?.success(granted)
            notifPermissionResult = null
        }
    }
}