import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../home/widgets/brand_logo.dart';

/// First-run onboarding, ported from the legacy
/// screens/onboarding/onboarding_page.dart (introduction_screen flow).
///
/// Pushed fullscreen by HomeScreen when the [seenPrefsKey] preference is
/// unset; the flag is written here when the user finishes or skips.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  /// shared_preferences flag marking the onboarding as completed/skipped.
  static const String seenPrefsKey = 'onboarding_seen';

  Future<void> _finish(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(seenPrefsKey, true);
    if (context.mounted) Navigator.of(context).pop();
  }

  List<PageViewModel> _buildPages(
    AppLocalizations l10n,
    PageDecoration pageDecoration,
  ) {
    const bodyTextStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w400,
    );

    return [
      PageViewModel(
        title: l10n.onboardingCongratsTitle,
        bodyWidget: Column(
          children: [
            Image.asset(
              'assets/images/illustration-characters-is-celebrating-a-birthday-with-a-party.png',
              height: 240,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 48),
            Text(
              l10n.onboardingCongratsBody,
              textAlign: TextAlign.center,
              style: bodyTextStyle,
            ),
          ],
        ),
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: l10n.onboardingWelcomeTitle,
        bodyWidget: Column(
          children: [
            const BrandLogo(height: 240),
            const SizedBox(height: 48),
            Text(
              l10n.onboardingWelcomeBody,
              textAlign: TextAlign.center,
              style: bodyTextStyle,
            ),
          ],
        ),
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: l10n.onboardingScienceTitle,
        bodyWidget: Column(
          children: [
            Image.asset(
              'assets/images/data-analysis-concept-illustration-flat-vector-design-statistical-and-data-analysis-for-business-finance-investment-concept-taking-part-in-business-activities-free.png',
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 48),
            Text(
              l10n.onboardingScienceBody,
              textAlign: TextAlign.center,
              style: bodyTextStyle,
            ),
          ],
        ),
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: l10n.onboardingAiTitle,
        bodyWidget: Column(
          children: [
            Image.asset(
              'assets/images/artificial-intelligence-design-illustration-ai-technology-and-cyber-background-and-banner-futuristic-technology-service-and-communication-artificial-intelligence-concept-free.png',
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 48),
            Text(
              l10n.onboardingAiBody,
              textAlign: TextAlign.center,
              style: bodyTextStyle,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.onboardingAiSteps,
              textAlign: TextAlign.left,
              style: bodyTextStyle,
            ),
          ],
        ),
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: l10n.onboardingPrivacyTitle,
        bodyWidget: Column(
          children: [
            Image.asset(
              'assets/images/digital-data-protection-design-illustration-cyber-security-illustration-background-cloud-computing-network-safety-concept-free.png',
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 48),
            Text(
              l10n.onboardingPrivacyBody,
              textAlign: TextAlign.center,
              style: bodyTextStyle,
            ),
          ],
        ),
        decoration: pageDecoration,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700),
      bodyTextStyle: TextStyle(fontSize: 19.0),
      titlePadding: EdgeInsets.fromLTRB(16.0, 96.0, 16.0, 0.0),
      bodyPadding: EdgeInsets.fromLTRB(16.0, 48.0, 16.0, 16.0),
      pageColor: Colors.transparent,
      imagePadding: EdgeInsets.zero,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: BrandColors.backgroundGradient(isDark),
        ),
        child: SafeArea(
          child: IntroductionScreen(
            globalBackgroundColor: Colors.transparent,
            allowImplicitScrolling: false,
            infiniteAutoScroll: false,
            pages: _buildPages(l10n, pageDecoration),
            skipOrBackFlex: 0,
            nextFlex: 0,
            showSkipButton: true,
            showDoneButton: true,
            skip: Text(
              l10n.onboardingSkip,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onSkip: () => _finish(context),
            next: const Icon(Icons.arrow_forward, size: 28),
            done: Text(
              l10n.onboardingDone,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onDone: () => _finish(context),
            curve: Curves.fastLinearToSlowEaseIn,
            controlsMargin: const EdgeInsets.all(16),
            controlsPadding: const EdgeInsets.all(8.0),
            dotsDecorator: DotsDecorator(
              size: const Size(10.0, 10.0),
              activeColor: Theme.of(context).colorScheme.primary,
              activeSize: const Size(22.0, 10.0),
              activeShape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(25.0)),
              ),
            ),
            globalFooter: const SizedBox(height: 32),
          ),
        ),
      ),
    );
  }
}
