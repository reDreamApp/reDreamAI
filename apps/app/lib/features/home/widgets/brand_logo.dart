import 'package:flutter/material.dart';

/// reDreamAI logo, picking the asset variant by theme brightness.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 120, this.fit = BoxFit.contain});

  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assetPath = isDark
        ? 'assets/images/reDreamAI_logo_dark_transparent.png'
        : 'assets/images/reDreamAI_logo_light_transparent.png';

    return Image.asset(assetPath, height: height, fit: fit);
  }
}
