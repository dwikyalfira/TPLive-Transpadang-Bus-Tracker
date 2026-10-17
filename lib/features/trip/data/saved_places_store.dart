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

  final SharedPreferences _prefs;

  const SavedPlacesStore(this._prefs);

  List<SavedPlace> loadFavorites() => _decode(_prefs.getString(_kFavorites));

  List<SavedPlace> loadRecents() => _decode(_prefs.getString(_kRecents));

  Future<void> saveFavorites(List<SavedPlace> places) =>
      _prefs.setString(_kFavorites, _encode(places));

  Future<void> saveRecents(List<SavedPlace> places) =>
      _prefs.setString(_kRecents, _encode(places));

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
