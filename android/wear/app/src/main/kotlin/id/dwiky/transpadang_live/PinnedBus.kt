package id.dwiky.transpadang_live

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.android.gms.wearable.DataMap

/** Ringkasan bus yang di-pin di HP (diterima lewat Wearable Data Layer). */
data class PinnedBus(
    val title: String,
    val color: Int,
    val nextStop: String?,
    val distanceText: String?,
    val etaText: String?,
    val onboard: Boolean,
    val onboardLabel: String?,
    val searchingLabel: String?,
    val stops: String?,
    val busLat: Double?,
    val busLng: Double?,
    val nextIndex: Int,
    /** Waktu kirim dari HP (ms epoch); dipakai untuk membuang data basi. */
    val sentAt: Long,
) {
    companion object {
        const val PATH = "/pinned_bus"

        /**
         * Data lebih tua dari ini dianggap basi (HP berhenti mengirim, mis. app HP
         * dimatikan paksa / HP mati / Bluetooth putus). HP biasanya mengirim tiap
         * 1-2 detik, dan mengirim sinyal "kosong" saat bus di-unpin atau app
         * ditutup, jadi batas ini hanya jaring pengaman.
         */
        const val STALE_MS = 90 * 1000L

        /** Mengembalikan null bila tidak ada bus yang di-pin (active=false). */
        fun from(map: DataMap): PinnedBus? {
            if (!map.getBoolean("active", false)) return null
            return PinnedBus(
                title = map.getString("title") ?: "",
                color = map.getInt("color", 0xFFF47F38.toInt()),
                nextStop = map.getString("nextStop"),
                distanceText = map.getString("distanceText"),
                etaText = map.getString("etaText"),
                onboard = map.getString("status") == "onboard",
                onboardLabel = map.getString("onboardLabel"),
                searchingLabel = map.getString("searchingLabel"),
                stops = map.getString("stops"),
                busLat = if (map.containsKey("busLat")) map.getDouble("busLat") else null,
                busLng = if (map.containsKey("busLng")) map.getDouble("busLng") else null,
                nextIndex = map.getInt("nextIndex", 0),
                sentAt = map.getLong("ts", System.currentTimeMillis()),
            )
        }
    }
}

/** Penyimpan state tunggal yang diamati UI Compose. */
object PinnedBusStore {
    var current by mutableStateOf<PinnedBus?>(null)
    var noBusLabel by mutableStateOf<String?>(null)
}
