import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_motion.dart';

/// Tampilan status kosong / memuat / galat yang seragam mengikuti gaya
/// Material 3: ikon di dalam lingkaran tonal, judul opsional, pesan, dan
/// aksi opsional. Menggantikan beberapa salinan yang sebelumnya tersebar
/// di tiap layar.

/// Animasi masuk halus (memudar + naik 10 dp) untuk seluruh tampilan status.
///
/// Hanya memengaruhi `Opacity`/`Transform`, jadi tata letak tidak berubah dan
/// teks tetap ada di pohon widget sejak frame pertama (aman untuk pembaca
/// layar maupun pengujian).
class _StateEntrance extends StatelessWidget {
  final Widget child;

  const _StateEntrance({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.resolve(context, AppMotion.medium2),
      curve: AppMotion.emphasizedDecelerate,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}

/// Wadah tata letak bersama untuk seluruh tampilan status.
class _StateLayout extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String? title;
  final String message;
  final Widget? action;

  const _StateLayout({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StateEntrance(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: iconColor),
            ),
            const SizedBox(height: 20),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Tampilan "kosong" (mis. tidak ada bus). Bila [scrollable] benar, isinya
/// dibungkus guliran agar tetap bisa dipakai dengan pull-to-refresh.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String message;
  final Widget? action;
  final bool scrollable;

  const EmptyStateView({
    super.key,
    required this.icon,
    this.title,
    required this.message,
    this.action,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final layout = _StateLayout(
      icon: icon,
      iconColor: scheme.onSurfaceVariant,
      iconBackground: scheme.surfaceVariant.withOpacity(0.5),
      title: title,
      message: message,
      action: action,
    );
    if (!scrollable) return Center(child: layout);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 96),
        layout,
      ],
    );
  }
}

/// Tampilan galat dengan tombol "Coba lagi" opsional.
class ErrorStateView extends StatelessWidget {
  final String message;
  final String? title;
  final VoidCallback? onRetry;

  /// Aksi khusus (mis. beberapa tombol). Bila diisi, [onRetry] diabaikan.
  final Widget? action;
  final IconData icon;

  const ErrorStateView({
    super.key,
    required this.message,
    this.title,
    this.onRetry,
    this.action,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: _StateLayout(
        icon: icon,
        iconColor: scheme.error,
        iconBackground: scheme.errorContainer.withOpacity(0.5),
        title: title,
        message: message,
        action: action ??
            (onRetry == null
                ? null
                : FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                  )),
      ),
    );
  }
}

/// Tampilan memuat dengan indikator melingkar dan pesan opsional.
class LoadingStateView extends StatelessWidget {
  final String? message;

  const LoadingStateView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _StateEntrance(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
