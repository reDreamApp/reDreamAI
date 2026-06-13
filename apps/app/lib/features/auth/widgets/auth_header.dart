import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Brand logo + gradient slogan shown on top of the auth screens
/// (ported from legacy widgets/brand_logo.dart + the auth page headers).
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, this.logoHeight = 140});

  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        const SizedBox(height: 20),
        Image.asset(
          isDark
              ? 'assets/images/reDreamAI_logo_dark_transparent.png'
              : 'assets/images/reDreamAI_logo_light_transparent.png',
          height: logoHeight,
          errorBuilder: (_, __, ___) => Icon(
            Icons.nightlight_round,
            size: logoHeight / 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 10),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              Theme.of(context).colorScheme.onPrimaryContainer,
              Theme.of(context).colorScheme.inversePrimary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            l10n.authSlogan,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
