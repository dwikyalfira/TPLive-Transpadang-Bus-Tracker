import 'package:flutter/material.dart';

/// Drag handle di tengah bilah atas bottom sheet berjenjang.
///
/// Berada di dalam [CustomScrollView] yang memakai scroll controller dari
/// [DraggableScrollableSheet], sehingga menarik dari bilah ini pun mengubah
/// tinggi sheet — bukan hanya daftar isinya.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
