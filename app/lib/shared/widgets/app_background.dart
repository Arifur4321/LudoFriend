import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_gradients.dart';
import 'app_assets.dart';

/// Brand gradient background with a faint original pattern overlay.
class AppBackground extends StatelessWidget {
  const AppBackground(
      {super.key, required this.child, this.showPattern = true});

  final Widget child;
  final bool showPattern;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.background),
      child: Stack(
        children: [
          if (showPattern)
            Positioned.fill(
              child: Opacity(
                opacity: 0.10,
                child: SvgPicture.asset(
                  AppAssets.bgPattern,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
