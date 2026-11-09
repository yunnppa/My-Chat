import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Subtle gradient backdrop for Liquid Glass chrome.
///
/// Content lists stay on opaque surfaces; this only sets atmosphere behind
/// navigation chrome.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors.backgroundGradient;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
  }
}
