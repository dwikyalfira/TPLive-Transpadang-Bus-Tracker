import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/settings.dart';
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

// --- Class SettingsScreen ---

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _SectionLabel(text: l10n.sectionAppearance),
          _SettingsCard(
            children: [
              _OptionBlock(
                title: l10n.themeModeTitle,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  style: _segmentStyle,
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: const Icon(Icons.brightness_auto_outlined),
                      label: Text(l10n.themeSystem),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode_outlined),
                      label: Text(l10n.themeLight),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_outlined),
                      label: Text(l10n.themeDark),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (selection) =>
                      notifier.setThemeMode(selection.first),
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
                child: SegmentedButton<_LanguageChoice>(
                  showSelectedIcon: false,
                  style: _segmentStyle,
                  segments: [
                    ButtonSegment(
                      value: _LanguageChoice.system,
                      icon: const Icon(Icons.settings_suggest_outlined),
                      label: Text(l10n.languageSystem),
                    ),
                    ButtonSegment(
                      value: _LanguageChoice.indonesian,
                      label: Text(l10n.languageIndonesian),
                    ),
                    ButtonSegment(
                      value: _LanguageChoice.english,
                      label: Text(l10n.languageEnglish),
                    ),
                  ],
                  selected: {_LanguageChoice.of(settings.locale)},
                  onSelectionChanged: (selection) =>
                      notifier.setLocale(selection.first.locale),
                ),
              ),
            ],
          ),
          _SectionLabel(text: l10n.sectionAbout),
          const _AboutCard(),
        ],
      ),
    );
  }

  ButtonStyle get _segmentStyle => SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      );
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
      ],
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
