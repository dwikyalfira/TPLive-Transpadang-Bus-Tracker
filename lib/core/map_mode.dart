/// Gaya basemap peta live yang dipilih pengguna.
///
/// [theme] tidak memaksa apa pun: peta mengikuti mode tampilan aplikasi
/// (gelap saat tema gelap, terang saat tema terang). Tiga nilai lainnya
/// memaksa gaya tertentu tanpa terpengaruh tema.
enum MapMode {
  theme,
  light,
  dark,
  satellite;

  /// Gaya yang benar-benar dipakai setelah [theme] diterjemahkan memakai
  /// kecerahan tema aktif.
  MapMode resolve(bool isDarkTheme) => switch (this) {
        MapMode.theme => isDarkTheme ? MapMode.dark : MapMode.light,
        _ => this,
      };
}
