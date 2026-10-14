import 'package:flutter/material.dart';

/// Membatasi lebar isi layar pada [maxWidth] dan memusatkannya secara
/// horizontal, sehingga tata letak tetap nyaman dibaca di layar lebar
/// (tablet, foldable, atau mode lanskap) alih-alih melebar penuh.
class ConstrainedContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ConstrainedContent({
    super.key,
    required this.child,
    this.maxWidth = 600,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
