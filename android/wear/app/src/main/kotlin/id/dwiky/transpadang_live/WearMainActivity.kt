package id.dwiky.transpadang_live

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable

/**
 * Layar jam (Wear OS, Material 3): menampilkan bus yang di-pin di HP. Data
 * datang dari HP lewat Wearable Data Layer pada path [PinnedBus.PATH].
 */
class WearMainActivity : ComponentActivity(), DataClient.OnDataChangedListener {

    private val dataClient by lazy { Wearable.getDataClient(this) }

    private val notificationPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Ongoing Activity butuh izin notifikasi (Android 13+).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
        setContent { TPLiveWearApp() }
    }

    override fun onResume() {
        super.onResume()
        dataClient.addListener(this)
        // Ambil data terakhir yang sudah tersimpan.
        dataClient.dataItems.addOnSuccessListener { items ->
            for (item in items) {
                if (item.uri.path == PinnedBus.PATH) apply(DataMapItem.fromDataItem(item))
            }
            items.release()
        }
    }

    override fun onPause() {
        dataClient.removeListener(this)
        super.onPause()
    }

    override fun onDataChanged(events: DataEventBuffer) {
        Log.d("TPLiveWear", "onDataChanged: ${events.count} event")
        for (event in events) {
            if (event.dataItem.uri.path != PinnedBus.PATH) continue
            if (event.type == DataEvent.TYPE_DELETED) {
                runOnUiThread { PinnedBusStore.current = null }
            } else {
                apply(DataMapItem.fromDataItem(event.dataItem))
            }
        }
    }

    private fun apply(item: DataMapItem) {
        val map = item.dataMap
        runOnUiThread {
            PinnedBusStore.current = PinnedBus.from(map)
            PinnedBusStore.noBusLabel = map.getString("noBusLabel")
        }
    }
}
