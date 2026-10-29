import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/fade_through_route.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/saved_place.dart';
import '../../domain/trip_endpoint.dart';
import '../location_picker_screen.dart';
import '../trip_providers.dart';
import '../trip_screen.dart';

/// Tombol bulat "Lokasi rumah" di samping kolom pencarian beranda.
///
/// Sengaja ringkas (satu tombol 48x48) supaya tidak memakan satu baris penuh:
/// * belum diatur → ketuk untuk memilih lokasi rumah lewat pemilih lokasi yang
///   sama dengan pemilih tujuan perjalanan;
/// * sudah diatur → ketuk untuk langsung membuka perencana perjalanan dengan
///   tujuan terisi lokasi rumah; tekan lama untuk mengubah atau menghapusnya.
///
/// Lokasi rumah disimpan di satu slot terpisah dari favorit/riwayat
/// ([SavedPlacesStore.saveHome]), jadi tidak bercampur dengan daftar tujuan.
class HomePlaceButton extends ConsumerWidget {
  const HomePlaceButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final home = ref.watch(savedPlacesProvider.select((s) => s.home));
    final isSet = home != null;

    return Semantics(
      button: true,
      label: isSet ? l10n.homeLocationRoute : l10n.homeLocationSet,
      hint: isSet ? l10n.homeLocationChange : null,
      child: Material(
        color: Color.alphaBlend(
          scheme.primary.withOpacity(isSet ? 0.16 : 0.07),
          scheme.surface,
        ),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => isSet
              ? _routeHome(context, ref, home)
              : _pickHome(context, ref),
          // Tekan lama = aksi sekunder (ubah/hapus) agar ketukan tetap satu
          // langkah menuju rute pulang.
          onLongPress: isSet ? () => _showMenu(context, ref, home) : null,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              isSet ? Icons.home : Icons.home_outlined,
              size: 22,
              color: scheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  /// Menu aksi sekunder: ubah atau hapus lokasi rumah.
  Future<void> _showMenu(
    BuildContext context,
    WidgetRef ref,
    SavedPlace home,
  ) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final l10n = AppLocalizations.of(context);
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      origin & box.size,
      Offset.zero & overlay.size,
    );

    final choice = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
          value: 'change',
          child: _MenuRow(
            icon: Icons.edit_outlined,
            label: l10n.homeLocationChange,
          ),
        ),
        PopupMenuItem<String>(
          value: 'remove',
          child: _MenuRow(
            icon: Icons.delete_outline,
            label: l10n.homeLocationRemove,
          ),
        ),
      ],
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'change') {
      await _pickHome(context, ref);
    } else if (choice == 'remove') {
      await _removeHome(context, ref, home);
    }
  }

  /// Membuka pemilih lokasi (halte/tempat) lalu menyimpan pilihannya sebagai
  /// lokasi rumah. Lokasi GPS sengaja tidak diterima: rumah harus punya
  /// koordinat tetap agar bisa dipakai kapan saja.
  Future<void> _pickHome(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final result = await Navigator.of(context).push<TripEndpoint>(
      fadeThroughRoute<TripEndpoint>(
        builder: (_) => LocationPickerScreen(title: l10n.homeLocationPickTitle),
      ),
    );
    if (result == null || result.isGps) return;
    final place = SavedPlace.fromEndpoint(result);
    if (place == null) return;
    await ref.read(savedPlacesProvider.notifier).setHome(place);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.homeLocationSaved)));
  }

  /// Menghapus lokasi rumah. Tidak ada dialog konfirmasi di aplikasi ini, jadi
  /// penghapusan dibuat bisa dibatalkan lewat SnackBar "Urungkan".
  Future<void> _removeHome(
    BuildContext context,
    WidgetRef ref,
    SavedPlace place,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(savedPlacesProvider.notifier).clearHome();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.homeLocationRemoved),
          action: SnackBarAction(
            label: l10n.homeLocationUndo,
            onPressed: () =>
                ref.read(savedPlacesProvider.notifier).setHome(place),
          ),
        ),
      );
  }

  /// Membuka perencana perjalanan dengan tujuan = lokasi rumah. Asal selalu
  /// dikembalikan ke GPS agar artinya "pulang dari sini".
  void _routeHome(BuildContext context, WidgetRef ref, SavedPlace? home) {
    if (home == null) return;
    ref.read(tripOriginEndpointProvider.notifier).state =
        const TripEndpoint.gps();
    ref.read(tripDestinationEndpointProvider.notifier).state = home.toEndpoint();
    Navigator.of(context).push(
      fadeThroughRoute<void>(builder: (_) => const TripScreen()),
    );
  }
}

/// Satu baris ikon + teks di dalam menu aksi.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        // `Flexible` supaya teks panjang tidak meluber keluar menu (lebar menu
        // dibatasi Material, bukan oleh isinya).
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
