import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/follow_service.dart';
import '../../../core/settings.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/ui/constrained_content.dart';
import '../../../l10n/app_localizations.dart';

/// Panduan singkat 3 layar yang tampil sekali saat aplikasi pertama dibuka.
///
/// Selalu bisa dilewati. Dengan [replay] (dibuka dari Pengaturan) layar ini
/// hanya di-pop saat selesai, tanpa mengubah preferensi.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.replay = false});

  final bool replay;

  static const Key skipKey = ValueKey('onboardingSkip');
  static const Key nextKey = ValueKey('onboardingNext');
  static const Key enableKey = ValueKey('onboardingEnable');
  static const Key pagesKey = ValueKey('onboardingPages');

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 3;
  final _controller = PageController();
  int _page = 0;
  bool _requesting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _pageCount - 1;

  Future<void> _finish() async {
    if (widget.replay) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    // Layar ini adalah `home`; menyimpan flag membuat MaterialApp beralih ke
    // beranda tanpa perlu navigasi manual.
    await ref.read(appSettingsProvider.notifier).completeOnboarding();
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: AppMotion.medium2,
      curve: AppMotion.standard,
    );
  }

  /// Meminta izin lokasi lalu notifikasi. Kegagalan (ditolak / tak tersedia)
  /// tidak menghalangi pengguna melanjutkan.
  Future<void> _enable() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
    try {
      await FollowService.requestNotificationPermission();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _requesting = false);
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = [
      _PageData(
        icon: Icons.directions_bus_rounded,
        title: l10n.onboardingLiveTitle,
        body: l10n.onboardingLiveBody,
      ),
      _PageData(
        icon: Icons.notifications_active_rounded,
        title: l10n.onboardingFollowTitle,
        body: l10n.onboardingFollowBody,
      ),
      _PageData(
        icon: Icons.my_location_rounded,
        title: l10n.onboardingPermTitle,
        body: l10n.onboardingPermBody,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: ConstrainedContent(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: AnimatedOpacity(
                    duration: AppMotion.short4,
                    opacity: _isLast ? 0 : 1,
                    child: TextButton(
                      key: OnboardingScreen.skipKey,
                      onPressed: _isLast ? null : _finish,
                      child: Text(l10n.onboardingSkip),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  key: OnboardingScreen.pagesKey,
                  controller: _controller,
                  itemCount: _pageCount,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _OnboardingPage(
                    data: pages[i],
                    index: i,
                    active: i == _page,
                    controller: _controller,
                  ),
                ),
              ),
              _Dots(count: _pageCount, index: _page),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: _isLast
                    ? Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: OnboardingScreen.enableKey,
                              onPressed: _requesting ? null : _enable,
                              child: Text(l10n.onboardingEnable),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              key: OnboardingScreen.nextKey,
                              onPressed: _requesting ? null : _next,
                              child: Text(l10n.onboardingStart),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: OnboardingScreen.nextKey,
                          onPressed: _next,
                          child: Text(l10n.onboardingNext),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageData {
  const _PageData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

/// Satu halaman panduan dengan dua lapis gerak:
///  - paralaks saat digeser: ikon dan teks bergerak/memudar dengan kecepatan
///    berbeda dari geseran halaman;
///  - animasi masuk tiap halaman menjadi aktif: ikon "muncul" membesar, lalu
///    judul dan isi naik berurutan.
/// Gerak dimatikan bila pengguna mengaktifkan "kurangi animasi".
class _OnboardingPage extends StatefulWidget {
  const _OnboardingPage({
    required this.data,
    required this.index,
    required this.active,
    required this.controller,
  });

  final _PageData data;
  final int index;
  final bool active;
  final PageController controller;

  @override
  State<_OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<_OnboardingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: AppMotion.long2 + AppMotion.medium2,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _enter.forward();
  }

  @override
  void didUpdateWidget(covariant _OnboardingPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _enter.forward(from: 0);
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end, Curve curve) =>
      CurvedAnimation(parent: _enter, curve: Interval(begin, end, curve: curve));

  /// Posisi halaman relatif terhadap halaman ini (0 = tepat di tengah).
  double _delta() {
    final c = widget.controller;
    final page = (c.hasClients && c.position.haveDimensions)
        ? (c.page ?? widget.index.toDouble())
        : widget.index.toDouble();
    return page - widget.index;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce && !_enter.isCompleted) _enter.value = 1;

    final hero = _interval(0.0, 0.6, AppMotion.emphasizedDecelerate);
    final title = _interval(0.25, 0.8, AppMotion.emphasizedDecelerate);
    final body = _interval(0.4, 1.0, AppMotion.emphasizedDecelerate);

    Widget rise(Animation<double> a, Widget child) => AnimatedBuilder(
          animation: a,
          builder: (_, c) => Opacity(
            opacity: a.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - a.value) * 24),
              child: c,
            ),
          ),
          child: child,
        );

    return LayoutBuilder(
      builder: (context, box) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final d = reduce ? 0.0 : _delta();
          final fade = (1 - d.abs() * 1.4).clamp(0.0, 1.0);
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ikon: bergeser lebih lambat + mengecil saat keluar.
                  Opacity(
                    opacity: fade,
                    child: Transform.translate(
                      offset: Offset(-d * 80, 0),
                      child: Transform.scale(
                        scale: 1 - d.abs() * 0.25,
                        child: AnimatedBuilder(
                          animation: hero,
                          builder: (_, c) => Transform.scale(
                            scale: 0.6 + 0.4 * hero.value,
                            child: Opacity(
                              opacity: hero.value.clamp(0.0, 1.0),
                              child: c,
                            ),
                          ),
                          child: _Hero(icon: widget.data.icon),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Teks: bergeser lebih cepat dari halaman (kesan berlapis).
                  Opacity(
                    opacity: fade,
                    child: Transform.translate(
                      offset: Offset(-d * 60, 0),
                      child: Column(
                        children: [
                          rise(
                            title,
                            Text(
                              widget.data.title,
                              textAlign: TextAlign.center,
                              style: text.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 12),
                          rise(
                            body,
                            Text(
                              widget.data.body,
                              textAlign: TextAlign.center,
                              style: text.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Kartu hero bergradasi (biru → krem → oranye/koral) senada ikon aplikasi.
class _Hero extends StatelessWidget {
  const _Hero({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(56),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3A62C8),
              Color(0xFFFFF0D2),
              Color(0xFFF0506E),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Icon(icon, size: 96, color: const Color(0xFF1F3A6B)),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppMotion.short4,
            curve: AppMotion.standard,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i == index ? scheme.primary : scheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}
