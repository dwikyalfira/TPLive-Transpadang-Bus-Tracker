import 'dart:async';

import 'package:flutter/material.dart';

import '../../tracking/presentation/home_screen.dart';

/// Layar pembuka yang menahan logo beberapa saat lalu fade ke beranda.
///
/// Native splash Android cuma bertahan selama proses engine memuat frame
/// pertama (sangat singkat), jadi pelambatan durasi dilakukan di sini.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.minimumDuration = const Duration(milliseconds: 1500),
  });

  /// Lama logo tampil sebelum berpindah ke [HomeScreen].
  final Duration minimumDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _fadeDuration = Duration(milliseconds: 300);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.minimumDuration, _goHome);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: _fadeDuration,
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Latar putih mengikuti native splash (nilai `color` pada
    // flutter_native_splash) supaya peralihan terasa mulus tanpa kedipan.
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/logo/tpl_logo_original.png',
          width: 140,
          height: 140,
          fit: BoxFit.contain,
          semanticLabel: 'Logo TPLive',
        ),
      ),
    );
  }
}