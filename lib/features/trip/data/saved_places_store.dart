import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/saved_place.dart';

/// Penyimpanan favorit & riwayat tujuan di [SharedPreferences].
///
/// Dipisah dari provider supaya mudah di-override saat pengujian (pola yang
/// sama dengan `SettingsStore`).
class SavedPlacesStore {
  static const _kFavorites = 'saved_places.favorites';
  static const _kRecents = 'saved_places.recents';

  /// Slot tunggal "lokasi rumah", terpisah dari daftar favorit.
  static const _kHome = 'saved.home';

  final SharedPreferences _prefs;

  const SavedPlacesStore(this._prefs);

  List<SavedPlace> loadFavorites() => _decode(_prefs.getString(_kFavorites));

  List<SavedPlace> loadRecents() => _decode(_prefs.getString(_kRecents));

  Future<void> saveFavorites(List<SavedPlace> places) =>
      _prefs.setString(_kFavorites, _encode(places));

  Future<void> saveRecents(List<SavedPlace> places) =>
      _prefs.setString(_kRecents, _encode(places));

  /// Lokasi rumah pengguna, atau null bila belum diatur.
  SavedPlace? loadHome() {
    final raw = _prefs.getString(_kHome);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return SavedPlace.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  Future<void> saveHome(SavedPlace place) =>
      _prefs.setString(_kHome, jsonEncode(place.toJson()));

  Future<void> clearHome() => _prefs.remove(_kHome);

  static String _encode(List<SavedPlace> places) =>
      jsonEncode([for (final place in places) place.toJson()]);

  static List<SavedPlace> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>) SavedPlace.fromJson(item),
      ];
    } on FormatException {
      return const [];
    }
  }
}
