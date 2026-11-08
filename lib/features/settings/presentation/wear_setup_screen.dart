import 'package:flutter/material.dart';

import '../../../core/theme/status_colors.dart';
import '../../../core/ui/constrained_content.dart';
import '../../../core/wear_installer.dart';
import '../../../l10n/app_localizations.dart';

/// Panduan memasang app TPLive ke jam Wear OS lewat wireless debugging.
///
/// Pengguna mengaktifkan Wireless debugging di jam, lalu memasukkan alamat &
/// kode pairing yang tampil di jam. HP melakukan pairing + memasang app.
class WearSetupScreen extends StatefulWidget {
  const WearSetupScreen({super.key});

  static const Key pairAddressKey = ValueKey('wearPairAddress');
  static const Key pairCodeKey = ValueKey('wearPairCode');
  static const Key connectAddressKey = ValueKey('wearConnectAddress');
  static const Key installButtonKey = ValueKey('wearInstallButton');
  static const Key stageKey = ValueKey('wearStage');
  static const Key resultKey = ValueKey('wearResult');

  @override
  State<WearSetupScreen> createState() => _WearSetupScreenState();
}

class _WearSetupScreenState extends State<WearSetupScreen> {
  final _pairAddress = TextEditingController();
  final _pairCode = TextEditingController();
  final _connectAddress = TextEditingController();

  bool _busy = false;
  String? _error;
  bool _done = false;
  String? _stage;

  @override
  void dispose() {
    _pairAddress.dispose();
    _pairCode.dispose();
    _connectAddress.dispose();
    super.dispose();
  }

  Future<void> _install() async {
    final l10n = AppLocalizations.of(context);
    final code = _pairCode.text.trim();
    final manual = _pairAddress.text.trim().isNotEmpty ||
        _connectAddress.text.trim().isNotEmpty;
    final pair = HostPort.parse(_pairAddress.text);
    final connect = HostPort.parse(_connectAddress.text);
    // Kosong = otomatis (mDNS); bila salah satu diisi, keduanya harus valid.
    if (code.length != 6 || (manual && (pair == null || connect == null))) {
      setState(() => _error = l10n.wearInvalidInput);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _done = false;
      _stage = 'discover_pair';
    });
    final result = await WearInstaller.pairAndInstall(
      pair: manual ? pair : null,
      code: code,
      connect: manual ? connect : null,
      onStage: (stage) {
        if (mounted) setState(() => _stage = stage);
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _stage = null;
      _done = result.ok;
      _error = result.ok ? null : _describe(l10n, result.message);
    });
  }

  String _stageLabel(AppLocalizations l10n, String stage) {
    switch (stage) {
      case 'pairing':
        return l10n.wearStagePairing;
      case 'discover_connect':
      case 'connecting':
        return l10n.wearStageConnecting;
      case 'installing':
        return l10n.wearStageInstalling;
      default:
        return l10n.wearStageDiscover;
    }
  }

  String _describe(AppLocalizations l10n, String code) {
    switch (code) {
      case 'apk_missing':
        return l10n.wearApkMissing;
      case 'install_timeout':
        return l10n.wearInstallTimeout;
      case 'discover_pair_failed':
        return l10n.wearDiscoverPairFailed;
      case 'discover_connect_failed':
        return l10n.wearDiscoverConnectFailed;
      case 'pair_failed':
        return l10n.wearPairFailed;
      case 'connect_failed':
        return l10n.wearConnectFailed;
      default:
        return l10n.wearFailed(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.wearTitle)),
      body: ConstrainedContent(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(l10n.wearIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            _Step(number: 1, text: l10n.wearStep1),
            _Step(number: 2, text: l10n.wearStep2),
            _Step(number: 3, text: l10n.wearStep3),
            const SizedBox(height: 16),
            TextField(
              key: WearSetupScreen.pairCodeKey,
              controller: _pairCode,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: l10n.wearPairCode,
                hintText: '123456',
                border: const OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 4),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l10n.wearManualTitle),
              subtitle: Text(l10n.wearManualSubtitle),
              children: [
                const SizedBox(height: 8),
                TextField(
                  key: WearSetupScreen.pairAddressKey,
                  controller: _pairAddress,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.wearPairAddress,
                    hintText: '192.168.1.20:37099',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: WearSetupScreen.connectAddressKey,
                  controller: _connectAddress,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.wearConnectAddress,
                    hintText: '192.168.1.20:41233',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: WearSetupScreen.installButtonKey,
              onPressed: _busy ? null : _install,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.watch_outlined),
              label: Text(_busy ? l10n.wearInstalling : l10n.wearInstall),
            ),
            if (_busy && _stage != null) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                _stageLabel(l10n, _stage!),
                key: WearSetupScreen.stageKey,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (_error != null)
              _ResultCard(
                key: WearSetupScreen.resultKey,
                success: false,
                text: _error!,
              ),
            if (_done)
              _ResultCard(
                key: WearSetupScreen.resultKey,
                success: true,
                text: l10n.wearSuccess,
              ),
            const SizedBox(height: 16),
            Text(
              l10n.wearDisableNote,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu hasil akhir: centang hijau bila berhasil, ikon error bila gagal.
class _ResultCard extends StatelessWidget {
  final bool success;
  final String text;

  const _ResultCard({super.key, required this.success, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = success ? scheme.primaryContainer : scheme.errorContainer;
    final fg = success ? scheme.onPrimaryContainer : scheme.onErrorContainer;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error_outline,
            color: success
                ? StatusColors.successFor(theme.brightness)
                : scheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              '$number',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
