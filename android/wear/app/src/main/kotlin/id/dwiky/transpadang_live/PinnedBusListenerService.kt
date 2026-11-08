package id.dwiky.transpadang_live

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService

/**
 * Dibangunkan sistem tiap HP mengirim/menghapus data bus yang di-pin — bahkan
 * saat app jam tidak terbuka. Memperbarui Ongoing Activity dan membuka app saat
 * sebuah bus baru di-pin.
 */
class PinnedBusListenerService : WearableListenerService() {

    private val main = Handler(Looper.getMainLooper())

    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) {
            if (event.dataItem.uri.path != PinnedBus.PATH) continue
            if (event.type == DataEvent.TYPE_DELETED) {
                main.post { PinnedBusStore.current = null }
                PinnedBusNotifier.onUnpinned(this)
                continue
            }
            val map = DataMapItem.fromDataItem(event.dataItem).dataMap
            val bus = PinnedBus.from(map)
            Log.d("TPLiveWear", "service: pinned=${bus != null}")
            // Perbarui juga state yang dibaca UI: listener milik Activity hanya
            // aktif saat app di layar, sedangkan layanan ini selalu menerima data.
            // Dengan begitu tampilan selalu mengikuti (bus baru / unpin / app HP
            // ditutup) walau app jam sedang di latar belakang.
            main.post {
                PinnedBusStore.current = bus
                PinnedBusStore.noBusLabel = map.getString("noBusLabel")
            }
            if (bus == null) PinnedBusNotifier.onUnpinned(this) else PinnedBusNotifier.onPinned(this, bus)
        }
    }
}
