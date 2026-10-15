import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Transisi "fade-through" Material 3: halaman baru memudar masuk sambil
/// meluncur naik tipis. Dipakai seragam untuk layar sekunder (Pengaturan,
/// pencarian perjalanan, pemilih lokasi) agar konsisten dan tidak
/// di-duplikasi di tiap layar.
Route<T> fadeThroughRoute<T>({
  required WidgetBuilder builder,
  Duration transitionDuration = AppMotion.medium2,
  Duration reverseTransitionDuration = AppMotion.short4,
}) {
  return PageRouteBuilder<T>(
    transitionDuration: transitionDuration,
    reverseTransitionDuration: reverseTransitionDuration,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.fadeThroughIn,
        reverseCurve: AppMotion.fadeThroughOut,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
