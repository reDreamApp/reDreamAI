import 'package:flutter/material.dart';

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
