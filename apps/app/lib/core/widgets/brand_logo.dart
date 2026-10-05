import 'package:flutter/material.dart';
import 'package:redream_app/core/theme/app_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark ? 'assets/images/logo_dark.png' : 'assets/images/logo_light.png',
      height: height,
      fit: BoxFit.contain,
    );
  }
}

/// The cloud without the wordmark, for places too small to read the name.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark
          ? 'assets/images/logo_mark_dark.png'
          : 'assets/images/logo_mark_light.png',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}

/// The app's name set like the logo's wordmark: "re" and "AI" in the logo's
/// turquoise, "Dream" in the text colour (black on light, white on dark).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = TextStyle(color: BrandColors.logo);
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 're', style: accent),
          TextSpan(text: 'Dream'),
          TextSpan(text: 'AI', style: accent),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
