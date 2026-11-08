package id.dwiky.transpadang_live

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Place
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import kotlinx.coroutines.delay
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.foundation.lazy.TransformingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberTransformingLazyColumnState
import androidx.wear.compose.material3.AppScaffold
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.ColorScheme
import androidx.wear.compose.material3.EdgeButton
import androidx.wear.compose.material3.FilledTonalButton
import androidx.wear.compose.material3.EdgeButtonSize
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.IconToggleButton
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import androidx.wear.compose.material3.dynamicColorScheme
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController

private const val ROUTE_INFO = "info"
private const val ROUTE_MAP = "map"

/** Akar UI: tema Material 3 (warna dinamis bila tersedia) + navigasi info/peta. */
@Composable
fun TPLiveWearApp() {
    val context = LocalContext.current
    MaterialTheme(colorScheme = dynamicColorScheme(context) ?: ColorScheme()) {
        AppScaffold {
            val nav = rememberSwipeDismissableNavController()
            SwipeDismissableNavHost(navController = nav, startDestination = ROUTE_INFO) {
                composable(ROUTE_INFO) {
                    val bus = rememberPinnedBus()
                    if (bus == null) {
                        EmptyScreen()
                    } else {
                        InfoScreen(bus = bus, onOpenMap = { nav.navigate(ROUTE_MAP) })
                    }
                }
                composable(ROUTE_MAP) {
                    val bus = rememberPinnedBus()
                    if (bus == null) {
                        // Bus di-unpin saat peta terbuka: kembali ke layar kosong.
                        nav.popBackStack()
                    } else {
                        MapScreen(bus = bus, onClose = { nav.popBackStack() })
                    }
                }
            }
        }
    }
}

/**
 * Bus yang di-pin saat ini, atau null bila tidak ada / datanya basi (HP berhenti
 * mengirim >90 dtk, mis. app HP dimatikan paksa). Dibaca di dalam tiap layar agar
 * perubahan state langsung memicu komposisi ulang.
 */
@Composable
private fun rememberPinnedBus(): PinnedBus? {
    val now by produceState(System.currentTimeMillis()) {
        while (true) {
            delay(15_000)
            value = System.currentTimeMillis()
        }
    }
    val current = PinnedBusStore.current ?: return null
    val age = now - current.sentAt
    // `now` diperbarui tiap 15 dtk, jadi bisa sedikit lebih lama dari sentAt;
    // toleransi 30 dtk ke depan untuk selisih jam HP-jam.
    return if (age < PinnedBus.STALE_MS && age > -30_000L) current else null
}

/** Tidak ada bus yang di-pin. */
@Composable
private fun EmptyScreen() {
    ScreenScaffold {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Icon(
                imageVector = Icons.Filled.Place,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(32.dp),
            )
            Text(
                text = PinnedBusStore.noBusLabel ?: stringResource(R.string.no_pinned_bus),
                style = MaterialTheme.typography.titleMedium,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 8.dp),
            )
            Text(
                text = stringResource(R.string.no_pinned_bus_hint),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 4.dp),
            )
            // Izin "tampil di atas app lain" agar app bisa terbuka sendiri.
            val ctx = LocalContext.current
            if (!Settings.canDrawOverlays(ctx)) {
                FilledTonalButton(
                    onClick = {
                        try {
                            ctx.startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:" + ctx.packageName),
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                            )
                        } catch (_: Exception) {
                        }
                    },
                    modifier = Modifier.padding(top = 8.dp),
                ) {
                    Text(
                        text = stringResource(R.string.auto_open),
                        style = MaterialTheme.typography.labelMedium,
                    )
                }
            }
        }
    }
}

/** Kartu info bus: lencana koridor, halte berikutnya, ETA/jarak, progres rute, status. */
@Composable
private fun InfoScreen(bus: PinnedBus, onOpenMap: () -> Unit) {
    val listState = rememberTransformingLazyColumnState()
    val accent = Color(bus.color)
    // Warna teks lencana dipilih otomatis agar kontras dengan warna koridor.
    val onAccent = if (accent.luminance() > 0.5f) Color.Black else Color.White

    ScreenScaffold(
        scrollState = listState,
        edgeButton = {
            EdgeButton(onClick = onOpenMap, buttonSize = EdgeButtonSize.Small) {
                Icon(
                    imageVector = Icons.Filled.LocationOn,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp),
                )
                Text(
                    text = stringResource(R.string.map),
                    modifier = Modifier.padding(start = 6.dp),
                )
            }
        },
    ) { contentPadding ->
        TransformingLazyColumn(
            state = listState,
            contentPadding = contentPadding,
            modifier = Modifier.fillMaxSize(),
        ) {
            item {
                // Lencana koridor: dibuat 2 baris ("Bus 61" / "Corridor K3") dan diberi
                // margin samping agar tidak terpotong di lengkung layar bulat.
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 28.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = bus.title.replace(" \u00B7 ", "\n"),
                        style = MaterialTheme.typography.labelMedium,
                        color = onAccent,
                        textAlign = TextAlign.Center,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier
                            .clip(RoundedCornerShape(20.dp))
                            .background(accent)
                            .padding(horizontal = 16.dp, vertical = 5.dp),
                    )
                }
            }
            item {
                Text(
                    text = bus.nextStop ?: bus.searchingLabel.orEmpty(),
                    style = MaterialTheme.typography.titleMedium,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 6.dp, start = 12.dp, end = 12.dp),
                )
            }
            if (bus.etaText != null || bus.distanceText != null) {
                item {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 2.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        bus.etaText?.let {
                            // ETA = informasi terpenting, ditonjolkan.
                            Text(
                                text = it,
                                style = MaterialTheme.typography.titleLarge,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                        if (bus.etaText != null && bus.distanceText != null) {
                            Text(
                                text = "  ·  ",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        bus.distanceText?.let {
                            Text(
                                text = it,
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
            if (bus.onboard) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = bus.onboardLabel ?: stringResource(R.string.on_board),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onTertiaryContainer,
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(MaterialTheme.colorScheme.tertiaryContainer)
                                .padding(horizontal = 12.dp, vertical = 4.dp),
                        )
                    }
                }
            }
        }
    }
}

/** Peta bus yang di-pin: geser, cubit, ketuk dua kali, crown; tombol ikuti & tutup. */
@Composable
private fun MapScreen(bus: PinnedBus, onClose: () -> Unit) {
    var follow by remember { mutableStateOf(true) }
    // Jam disembunyikan agar tidak menimpa atribusi peta di bagian atas.
    ScreenScaffold(
        scrollState = rememberTransformingLazyColumnState(),
        scrollIndicator = null,
        timeText = {},
    ) {
    Box(modifier = Modifier.fillMaxSize()) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { ctx -> WearMapView(ctx) },
            update = { view ->
                view.onFollowChanged = { follow = it }
                view.update(
                    bus.stops,
                    bus.busLat,
                    bus.busLng,
                    bus.nextIndex,
                    bus.color,
                )
                view.setFollow(follow)
            },
        )
        // Tombol ikuti bus di tepi kanan (toggle Material 3).
        IconToggleButton(
            checked = follow,
            onCheckedChange = { follow = it },
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .padding(end = 10.dp)
                .size(40.dp),
        ) {
            Icon(
                imageVector = Icons.Filled.LocationOn,
                contentDescription = stringResource(R.string.follow_bus),
                modifier = Modifier.size(22.dp),
            )
        }
        // EdgeButton Material 3 di bawah layar untuk menutup peta.
        EdgeButton(
            onClick = onClose,
            buttonSize = EdgeButtonSize.Small,
            colors = ButtonDefaults.filledTonalButtonColors(),
            modifier = Modifier.align(Alignment.BottomCenter),
        ) {
            Icon(
                imageVector = Icons.Filled.Close,
                contentDescription = stringResource(R.string.close_map),
                modifier = Modifier.size(20.dp),
            )
        }
    }
    }
}
