package id.dwiky.transpadang_live

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

/**
 * Mengirim ringkasan bus yang di-pin ("diikuti") ke app Wear OS lewat
 * Wearable Data Layer. Semua panggilan best-effort: bila tidak ada jam
 * terpasangan / Play Services tidak tersedia, kegagalan hanya dicatat.
 */
object WearBridge {

    private const val TAG = "WearBridge"
    const val PATH_PINNED_BUS = "/pinned_bus"

    data class Snapshot(
        val title: String,
        val color: Int,
        val nextStop: String?,
        val distanceText: String?,
        val etaText: String?,
        val status: String,
        val onboardLabel: String,
        val searchingLabel: String,
        /** Halte arah yang ditempuh, "lat,lng;lat,lng;..." untuk peta di jam. */
        val stops: String,
        val busLat: Double?,
        val busLng: Double?,
        val nextIndex: Int,
        val mapHint: String,
    )

    fun push(context: Context, s: Snapshot) {
        send(context) { map ->
            map.putBoolean("active", true)
            map.putString("title", s.title)
            map.putInt("color", s.color)
            s.nextStop?.let { map.putString("nextStop", it) }
            s.distanceText?.let { map.putString("distanceText", it) }
            s.etaText?.let { map.putString("etaText", it) }
            map.putString("status", s.status)
            map.putString("onboardLabel", s.onboardLabel)
            map.putString("searchingLabel", s.searchingLabel)
            map.putString("stops", s.stops)
            s.busLat?.let { map.putDouble("busLat", it) }
            s.busLng?.let { map.putDouble("busLng", it) }
            map.putInt("nextIndex", s.nextIndex)
            map.putString("mapHint", s.mapHint)
        }
    }

    /** Dipanggil saat follow berhenti: jam kembali ke "tidak ada bus di-pin". */
    fun clear(context: Context, noBusLabel: String) {
        send(context) { map ->
            map.putBoolean("active", false)
            map.putString("noBusLabel", noBusLabel)
        }
    }

    private fun send(
        context: Context,
        fill: (com.google.android.gms.wearable.DataMap) -> Unit,
    ) {
        try {
            val req = PutDataMapRequest.create(PATH_PINNED_BUS)
            fill(req.dataMap)
            // Stempel waktu memastikan setiap kiriman dianggap perubahan data.
            req.dataMap.putLong("ts", System.currentTimeMillis())
            Wearable.getDataClient(context.applicationContext)
                .putDataItem(req.asPutDataRequest().setUrgent())
                .addOnFailureListener { Log.d(TAG, "Kirim ke jam gagal: ${it.message}") }
        } catch (e: Exception) {
            Log.d(TAG, "Wearable tidak tersedia: ${e.message}")
        }
    }
}
