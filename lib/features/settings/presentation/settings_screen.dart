import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/settings.dart';
import '../../../core/ui/constrained_content.dart';
import '../../../l10n/app_localizations.dart';

// --- Enum & Widget helper (di luar class SettingsScreen) ---

/// Pilihan bahasa yang dipetakan ke [Locale] aplikasi.
enum _LanguageChoice {
  system,
  indonesian,
  english;

  Locale? get locale => switch (this) {
        _LanguageChoice.system => null,
        _LanguageChoice.indonesian => const Locale('id'),
        _LanguageChoice.english => const Locale('en'),
      };

  static _LanguageChoice of(Locale? locale) {
    if (locale == null) return _LanguageChoice.system;
    return locale.languageCode == 'en'
        ? _LanguageChoice.english
        : _LanguageChoice.indonesian;
  }
}

/// Judul kecil di atas setiap kelompok pengaturan (label M3, warna primer).
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Wadah berkelompok bergaya M3 (permukaan tonal, sudut membulat).
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: Color.alphaBlend(
        scheme.primary.withOpacity(0.04),
        scheme.surface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Blok opsi: judul + kontrol pilihan (mis. [SegmentedButton]) dengan padding
/// seragam mengikuti grid M3.
class _OptionBlock extends StatelessWidget {
  final String title;
  final Widget child;

  const _OptionBlock({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }
}

/// Satu pilihan pada [_ChoiceField].
class _Choice<T> {
  const _Choice({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Kontrol pilihan yang menyesuaikan lebar layar.
///
/// - Bila semua pilihan muat, dipakai [SegmentedButton] **selebar penuh** dengan
///   segmen sama besar (sehingga tidak menyusut di layar sempit).
/// - Ikon dilepas otomatis bila lebar tidak cukup untuk ikon + label.
/// - Bila teks pun tidak muat berdampingan, kontrol berubah menjadi daftar
///   bertumpuk (vertikal) yang tetap ukuran penuh.
class _ChoiceField<T> extends StatelessWidget {
  const _ChoiceField({
    required this.choices,
    required this.selected,
    required this.onSelected,
  });

  final List<_Choice<T>> choices;
  final T selected;
  final ValueChanged<T> onSelected;

  static const double _minSegmentHeight = 44;
  static const double _hPadding = 10;
  static const double _iconWidth = 18;
  static const double _iconGap = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle =
        theme.textTheme.labelLarge ?? const TextStyle(fontSize: 14);
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final perSegment = available / choices.length;

        final withIconsFit =
            _fits(perSegment, labelStyle, scaler, includeIcons: true);
        final labelsOnlyFit =
            _fits(perSegment, labelStyle, scaler, includeIcons: false);

        // Layar terlalu sempit untuk tombol berjajar → tumpuk vertikal.
        if (!labelsOnlyFit) {
          return _vertical(context);
        }

        return SizedBox(
          width: double.infinity,
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: _hPadding),
              minimumSize: const Size(0, _minSegmentHeight),
            ),
            segments: [
              for (final choice in choices)
                ButtonSegment<T>(
                  value: choice.value,
                  icon: (withIconsFit && choice.icon != null)
                      ? Icon(choice.icon, size: _iconWidth)
                      : null,
                  label: Text(
                    choice.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            selected: {selected},
            onSelectionChanged: (selection) => onSelected(selection.first),
          ),
        );
      },
    );
  }

  /// Apakah semua label (beserta ikon, bila [includeIcons]) muat di dalam
  /// lebar satu segmen.
  bool _fits(
    double perSegment,
    TextStyle style,
    TextScaler scaler, {
    required bool includeIcons,
  }) {
    const buffer = 4.0;
    return choices.every((choice) {
      var need = _textWidth(choice.label, style, scaler) + _hPadding * 2;
      if (includeIcons && choice.icon != null) {
        need += _iconWidth + _iconGap;
      }
      return need + buffer <= perSegment;
    });
  }

  static double _textWidth(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  Widget _vertical(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < choices.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _ChoiceButton<T>(
            choice: choices[i],
            selected: choices[i].value == selected,
            onTap: () => onSelected(choices[i].value),
          ),
        ],
      ],
    );
  }
}

/// Satu baris pilihan bergaya M3 untuk tumpukan vertikal [ _ChoiceField ].
class _ChoiceButton<T> extends StatelessWidget {
  const _ChoiceButton({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final _Choice<T> choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground =
        selected ? scheme.onSecondaryContainer : scheme.onSurface;

    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? Colors.transparent : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              if (choice.icon != null) ...[
                Icon(choice.icon, size: 18, color: foreground),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  choice.label,
                  style: theme.textTheme.labelLarge?.copyWith(color: foreground),
                ),
              ),
              if (selected) Icon(Icons.check, size: 18, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Class SettingsScreen ---

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Kunci tanda tangan pembuat di kaki halaman (dipakai test).
  static const Key signatureKey = ValueKey('settingsSignature');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ConstrainedContent(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
          _SectionLabel(text: l10n.sectionAppearance),
          _SettingsCard(
            children: [
              _OptionBlock(
                title: l10n.themeModeTitle,
                child: _ChoiceField<ThemeMode>(
                  choices: [
                    _Choice(
                      value: ThemeMode.system,
                      label: l10n.themeSystem,
                      icon: Icons.brightness_auto_outlined,
                    ),
                    _Choice(
                      value: ThemeMode.light,
                      label: l10n.themeLight,
                      icon: Icons.light_mode_outlined,
                    ),
                    _Choice(
                      value: ThemeMode.dark,
                      label: l10n.themeDark,
                      icon: Icons.dark_mode_outlined,
                    ),
                  ],
                  selected: settings.themeMode,
                  onSelected: notifier.setThemeMode,
                ),
              ),
              const _CardDivider(),
              SwitchListTile(
                secondary: const Icon(Icons.palette_outlined),
                title: Text(l10n.dynamicColorTitle),
                subtitle: Text(l10n.dynamicColorSubtitle),
                value: settings.useDynamicColor,
                onChanged: notifier.setUseDynamicColor,
              ),
            ],
          ),
          _SectionLabel(text: l10n.sectionLanguage),
          _SettingsCard(
            children: [
              _OptionBlock(
                title: l10n.languageTitle,
                child: _ChoiceField<_LanguageChoice>(
                  choices: [
                    _Choice(
                      value: _LanguageChoice.system,
                      label: l10n.languageSystem,
                      icon: Icons.settings_suggest_outlined,
                    ),
                    _Choice(
                      value: _LanguageChoice.indonesian,
                      label: l10n.languageIndonesian,
                    ),
                    _Choice(
                      value: _LanguageChoice.english,
                      label: l10n.languageEnglish,
                    ),
                  ],
                  selected: _LanguageChoice.of(settings.locale),
                  onSelected: (choice) => notifier.setLocale(choice.locale),
                ),
              ),
            ],
          ),
          _SectionLabel(text: l10n.sectionAbout),
          const _AboutCard(),
          const _Signature(key: SettingsScreen.signatureKey),
          ],
        ),
      ),
    );
  }
}

/// Kartu "Tentang": logo aplikasi, nama, versi, dan deskripsi singkat.
class _AboutCard extends StatelessWidget {
  const _AboutCard();

  static const _logoAsset = 'assets/logo/tpl_logo_original.png';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return _SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  _logoAsset,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TPLive',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    const _AppVersionText(),
                    const SizedBox(height: 10),
                    Text(
                      l10n.aboutAppDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _AboutDisclaimer(text: l10n.aboutDisclaimer),
        ),
      ],
    );
  }
}

/// Tanda tangan pembuat aplikasi di kaki halaman Pengaturan.
///
/// Hanya teks handle `@dwikyalfira`, rata kiri (sejajar tepi kartu di atasnya)
/// dan 60% opasitas: ini tanda pengenal, bukan pengaturan — jadi tidak boleh
/// bersaing dengan kartu "Tentang" di atasnya.
class _Signature extends StatelessWidget {
  const _Signature({super.key});

  /// Handle pembuat yang ditampilkan (tidak diterjemahkan).
  static const String _handle = '@dwikyalfira';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Text(
        _handle,
        textAlign: TextAlign.start,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Kotak penafian di kartu "Tentang": menegaskan aplikasi ini bukan produk
/// resmi TransPadang/Pemkot Padang dan dibuat untuk memudahkan pengguna.
class _AboutDisclaimer extends StatelessWidget {
  final String text;

  const _AboutDisclaimer({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Menampilkan versi aplikasi (mis. "Versi 1.0.0 (1)") dari paket.
class _AppVersionText extends StatelessWidget {
  const _AppVersionText();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) {
          return Text('', style: style);
        }
        return Text(
          l10n.aboutVersion('${info.version} (${info.buildNumber})'),
          style: style,
        );
      },
    );
  }
}
