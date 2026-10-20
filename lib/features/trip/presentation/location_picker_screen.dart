import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/constrained_content.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../tracking/domain/geo_utils.dart' as geo;
import '../../tracking/presentation/providers.dart';
import '../../tracking/presentation/widgets/corridor_badge.dart';
import '../../tracking/presentation/widgets/format.dart';
import '../data/geocoding_service.dart';
import '../domain/saved_place.dart';
import '../domain/trip_endpoint.dart';
import 'trip_providers.dart';

/// Layar pemilih lokasi: halte (utama) atau cari tempat (Nominatim).
class LocationPickerScreen extends ConsumerStatefulWidget {
  /// Judul, mis. "Pilih asal" / "Pilih tujuan".
  final String title;

  /// Bila true, sediakan opsi "Lokasi saya" (GPS) + daftar halte terdekat.
  /// Dipakai untuk titik asal.
  final bool includeGps;

  const LocationPickerScreen({
    super.key,
    required this.title,
    this.includeGps = false,
  });

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  late final TabController _tabs;
  String _query = '';
  int _tabIndex = 0;

  /// Menunda pencarian tempat saat mengetik agar tidak memanggil API tiap
  /// ketukan tombol.
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.index == _tabIndex) return;
      setState(() => _tabIndex = _tabs.index);
      if (_tabIndex == 1) _submitPlaceSearch();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(destinationQueryProvider.notifier).state = '';
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _tabs.dispose();
    super.dispose();
  }

  bool get _isPlace => _tabIndex == 1;

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    if (!_isPlace) return;
    // Pencarian "live" di tab Tempat: perlahan saat mengetik, tanpa perlu
    // menekan tombol cari.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(destinationQueryProvider.notifier).state = value.trim();
    });
  }

  void _submitPlaceSearch() {
    if (!_isPlace) return;
    FocusScope.of(context).unfocus();
    _debounce?.cancel();
    ref.read(destinationQueryProvider.notifier).state = _query.trim();
  }

  void _chooseGps() => Navigator.of(context).pop(const TripEndpoint.gps());

  void _chooseHalte(HalteEntry entry) =>
      Navigator.of(context).pop(TripEndpoint.halte(entry));

  void _chooseSavedPlace(SavedPlace place) =>
      Navigator.of(context).pop(place.toEndpoint());

  void _choosePlace(GeocodingResult result) => Navigator.of(context).pop(
        TripEndpoint.place(label: result.name, position: result.pos),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.tabHalte),
            Tab(text: l10n.tabPlace),
          ],
        ),
      ),
      body: ConstrainedContent(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: _SearchField(
                controller: _controller,
                isPlace: _isPlace,
                onChanged: _onQueryChanged,
                onSearch: _submitPlaceSearch,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _HalteTab(
                    query: _query,
                    includeGps: widget.includeGps,
                    onGps: _chooseGps,
                    onSelect: _chooseHalte,
                    onSelectSaved: _chooseSavedPlace,
                  ),
                  _PlaceTab(onSelect: _choosePlace),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kolom pencarian ringkas yang seragam untuk kedua tab.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool isPlace;
  final ValueChanged<String> onChanged;
  final VoidCallback onSearch;

  const _SearchField({
    required this.controller,
    required this.isPlace,
    required this.onChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(14);

    return TextField(
      controller: controller,
      autocorrect: false,
      textInputAction: isPlace ? TextInputAction.search : TextInputAction.none,
      onChanged: onChanged,
      onSubmitted: (_) => onSearch(),
      decoration: InputDecoration(
        hintText: isPlace ? l10n.searchPlaceHint : l10n.searchHalteHint,
        prefixIcon: const Icon(Icons.search, size: 22),
        suffixIcon: isPlace
            ? IconButton(
                tooltip: l10n.tooltipSearch,
                icon: const Icon(Icons.arrow_forward),
                onPressed: onSearch,
              )
            : null,
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

// --- Tab Halte ---

sealed class _HalteRow {
  const _HalteRow();
}

class _GpsTileRow extends _HalteRow {
  const _GpsTileRow();
}

class _SectionHeaderRow extends _HalteRow {
  final String title;
  const _SectionHeaderRow(this.title);
}

class _HalteEntryRow extends _HalteRow {
  final HalteEntry entry;
  final double? distanceKm;
  const _HalteEntryRow(this.entry, this.distanceKm);
}

class _SavedPlaceRow extends _HalteRow {
  final SavedPlace place;
  const _SavedPlaceRow(this.place);
}

/// Mengubah [HalteEntry] menjadi bentuk yang bisa disimpan sebagai favorit.
SavedPlace _savedForEntry(HalteEntry entry) => SavedPlace(
      kind: SavedPlaceKind.halte,
      label: entry.name,
      lat: entry.halte.pos.latitude,
      lng: entry.halte.pos.longitude,
      corridors: (entry.corridors.toList()..sort()).join(', '),
    );

class _HalteTab extends ConsumerWidget {
  final String query;
  final bool includeGps;
  final VoidCallback onGps;
  final ValueChanged<HalteEntry> onSelect;
  final ValueChanged<SavedPlace> onSelectSaved;

  const _HalteTab({
    required this.query,
    required this.includeGps,
    required this.onGps,
    required this.onSelect,
    required this.onSelectSaved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(halteEntriesProvider);
    if (entries.isEmpty) {
      return EmptyStateView(
        icon: Icons.hourglass_empty,
        message: l10n.loadingHalteData,
      );
    }

    final saved = ref.watch(savedPlacesProvider);
    bool isFavorite(SavedPlace place) =>
        saved.favorites.any((f) => f.id == place.id);
    void toggleFavorite(SavedPlace place) =>
        ref.read(savedPlacesProvider.notifier).toggleFavorite(place);

    _HalteListView list(List<_HalteRow> rows) => _HalteListView(
          rows: rows,
          onGps: onGps,
          onSelect: onSelect,
          onSelectSaved: onSelectSaved,
          isFavorite: isFavorite,
          onToggleFavorite: toggleFavorite,
        );

    final q = query.trim().toLowerCase();

    // Mode pencarian: tampilkan hanya hasil yang cocok (tanpa favorit/riwayat).
    if (q.isNotEmpty) {
      final filtered =
          entries.where((e) => e.name.toLowerCase().contains(q)).toList();
      if (filtered.isEmpty) {
        return EmptyStateView(
          icon: Icons.search_off,
          message: l10n.halteNotFound,
        );
      }
      return list([
        for (final entry in filtered) _HalteEntryRow(entry, null),
      ]);
    }

    final userLoc = ref.watch(userLocationProvider).valueOrNull;
    final corridorDist = ref.watch(corridorProximityProvider);
    final rows = <_HalteRow>[];

    // Favorit selalu di atas; riwayat tujuan hanya saat memilih tujuan.
    if (saved.favorites.isNotEmpty) {
      rows.add(_SectionHeaderRow(l10n.favoritesTitle));
      for (final place in saved.favorites) {
        rows.add(_SavedPlaceRow(place));
      }
    }
    if (!includeGps && saved.recents.isNotEmpty) {
      rows.add(_SectionHeaderRow(l10n.recentsTitle));
      for (final place in saved.recents) {
        rows.add(_SavedPlaceRow(place));
      }
    }

    if (includeGps) {
      rows.add(const _GpsTileRow());
      if (userLoc != null) {
        final sorted = entries
            .map((e) => (e, geo.distanceKm(userLoc, e.halte.pos)))
            .toList()
          ..sort((a, b) => a.$2.compareTo(b.$2));
        rows.add(_SectionHeaderRow(l10n.nearestHaltesFromYou));
        for (final (entry, km) in sorted.take(5)) {
          rows.add(_HalteEntryRow(entry, km));
        }
        rows.add(_SectionHeaderRow(l10n.allHaltes));
      } else {
        rows.add(_SectionHeaderRow(l10n.allHaltes));
      }
      for (final entry in entries) {
        rows.add(_HalteEntryRow(entry, null));
      }
      return list(rows);
    }

    // Pilih tujuan: urut & kelompokkan menurut koridor yang paling dekat
    // dengan lokasi pengguna; di dalam kelompok, halte terdekat lebih dulu.
    if (userLoc != null) {
      final grouped = entries.map((e) {
        String? corridor;
        double? corridorDistOf;
        for (final c in e.corridors) {
          final d = corridorDist[c];
          if (d == null) continue;
          if (corridorDistOf == null || d < corridorDistOf) {
            corridor = c;
            corridorDistOf = d;
          }
        }
        return (
          entry: e,
          corridor: corridor,
          corridorDist: corridorDistOf,
          dist: geo.distanceKm(userLoc, e.halte.pos),
        );
      }).toList()
        ..sort((a, b) {
          final byCorridor = (a.corridorDist ?? double.infinity)
              .compareTo(b.corridorDist ?? double.infinity);
          if (byCorridor != 0) return byCorridor;
          return a.dist.compareTo(b.dist);
        });

      String? lastCorridor;
      for (final item in grouped) {
        if (item.corridor != null && item.corridor != lastCorridor) {
          rows.add(_SectionHeaderRow(item.corridor ?? '—'));
          lastCorridor = item.corridor;
        }
        rows.add(_HalteEntryRow(item.entry, item.dist));
      }
      return list(rows);
    }

    // Tanpa lokasi GPS: urutkan alfabetis seperti sebelumnya.
    for (final entry in entries) {
      rows.add(_HalteEntryRow(entry, null));
    }

    return list(rows);
  }
}

class _HalteListView extends StatelessWidget {
  final List<_HalteRow> rows;
  final VoidCallback onGps;
  final ValueChanged<HalteEntry> onSelect;
  final ValueChanged<SavedPlace> onSelectSaved;
  final bool Function(SavedPlace place) isFavorite;
  final ValueChanged<SavedPlace> onToggleFavorite;

  const _HalteListView({
    required this.rows,
    required this.onGps,
    required this.onSelect,
    required this.onSelectSaved,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return switch (row) {
          _GpsTileRow() => _GpsTile(onTap: onGps),
          _SectionHeaderRow(:final title) => _SectionHeader(title: title),
          _SavedPlaceRow(:final place) => _SavedPlaceTile(
              place: place,
              isFavorite: isFavorite(place),
              onTap: () => onSelectSaved(place),
              onToggleFavorite: () => onToggleFavorite(place),
            ),
          _HalteEntryRow(:final entry, :final distanceKm) => _HalteTile(
              entry: entry,
              distanceKm: distanceKm,
              isFavorite: isFavorite(_savedForEntry(entry)),
              onToggleFavorite: () => onToggleFavorite(_savedForEntry(entry)),
              onTap: () => onSelect(entry),
            ),
        };
      },
    );
  }
}

class _GpsTile extends StatelessWidget {
  final VoidCallback onTap;

  const _GpsTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Material(
        color: theme.colorScheme.primaryContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: Icon(Icons.my_location, color: theme.colorScheme.primary),
          title: Text(
            l10n.myLocation,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(l10n.myLocationSubtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _HalteTile extends StatelessWidget {
  final HalteEntry entry;
  final double? distanceKm;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  const _HalteTile({
    required this.entry,
    required this.distanceKm,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final corridors = entry.corridors.toList()..sort();
    final accent = corridors.isEmpty
        ? theme.colorScheme.primary
        : corridorColor(corridors.first);
    final accentIconColor = ensureContrast(
      accent,
      Color.alphaBlend(accent.withOpacity(0.15), theme.colorScheme.surface),
    );

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: accent.withOpacity(0.15),
        child: Icon(Icons.directions_bus_outlined,
            color: accentIconColor, size: 20),
      ),
      title: Text(
        entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final corridor in corridors) ...[
            CorridorBadge(corridor: corridor, size: 24, fontSize: 10),
            if (corridor != corridors.last) const SizedBox(width: 4),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (distanceKm != null)
            Text(
              formatDistance(distanceKm!),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          _FavoriteStar(isFavorite: isFavorite, onPressed: onToggleFavorite),
        ],
      ),
    );
  }
}

/// Satu tempat tersimpan (favorit/riwayat): bisa berupa halte atau tempat (POI).
class _SavedPlaceTile extends StatelessWidget {
  final SavedPlace place;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const _SavedPlaceTile({
    required this.place,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHalte = place.kind == SavedPlaceKind.halte;
    final corridors = (place.corridors ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final accent = isHalte && corridors.isNotEmpty
        ? corridorColor(corridors.first)
        : theme.colorScheme.primary;
    final accentIconColor = ensureContrast(
      accent,
      Color.alphaBlend(accent.withOpacity(0.15), theme.colorScheme.surface),
    );

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: accent.withOpacity(0.15),
        child: Icon(
          isHalte ? Icons.directions_bus_outlined : Icons.place_outlined,
          color: accentIconColor,
          size: 20,
        ),
      ),
      title: Text(
        place.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: corridors.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final corridor in corridors) ...[
                  CorridorBadge(corridor: corridor, size: 24, fontSize: 10),
                  if (corridor != corridors.last) const SizedBox(width: 4),
                ],
              ],
            ),
      trailing:
          _FavoriteStar(isFavorite: isFavorite, onPressed: onToggleFavorite),
    );
  }
}

/// Tombol bintang untuk menambah/menghapus tempat dari favorit.
class _FavoriteStar extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onPressed;

  const _FavoriteStar({required this.isFavorite, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: isFavorite ? l10n.removeFavorite : l10n.addFavorite,
      onPressed: onPressed,
      icon: Icon(isFavorite ? Icons.star : Icons.star_border),
      color: isFavorite
          ? const Color(0xFFEAA221)
          : Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

// --- Tab Tempat ---

/// Pesan galat pencarian tempat sesuai jenis kegagalan dan bahasa aplikasi.
String _geocodingMessage(AppLocalizations l10n, Object error) {
  if (error is! GeocodingException) return l10n.placeSearchError;
  return switch (error.kind) {
    GeocodingErrorKind.timeout => l10n.placeSearchTimeout,
    GeocodingErrorKind.noConnection => l10n.placeSearchNoConnection,
    GeocodingErrorKind.invalidResponse => l10n.placeSearchInvalidResponse,
    GeocodingErrorKind.httpError => l10n.placeSearchHttp(error.statusCode ?? 0),
  };
}

class _PlaceTab extends ConsumerWidget {
  final ValueChanged<GeocodingResult> onSelect;

  const _PlaceTab({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(destinationQueryProvider);
    if (query.trim().length < 3) {
      return EmptyStateView(
        icon: Icons.travel_explore,
        message: l10n.placeMinChars,
      );
    }

    final results = ref.watch(destinationResultsProvider);
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorStateView(
        message: _geocodingMessage(l10n, error),
        onRetry: () => ref.invalidate(destinationResultsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return EmptyStateView(
            icon: Icons.search_off,
            message: l10n.placeNotFound,
          );
        }
        final favoriteIds =
            ref.watch(savedPlacesProvider).favorites.map((p) => p.id).toSet();
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final saved = SavedPlace(
              kind: SavedPlaceKind.place,
              label: item.name,
              lat: item.pos.latitude,
              lng: item.pos.longitude,
            );
            return ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(item.name),
              subtitle: Text(
                item.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: _FavoriteStar(
                isFavorite: favoriteIds.contains(saved.id),
                onPressed: () => ref
                    .read(savedPlacesProvider.notifier)
                    .toggleFavorite(saved),
              ),
              onTap: () => onSelect(item),
            );
          },
        );
      },
    );
  }
}
