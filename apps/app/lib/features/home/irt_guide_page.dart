import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// "How Imagery Rehearsal Therapy works" walkthrough, ported from the legacy
/// screens/home/irt_guide.dart (content localized instead of hardcoded EN).
class IrtGuidePage extends StatelessWidget {
  const IrtGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const bodyStyle = TextStyle(fontSize: 19.0);

    final gradient = BrandColors.brandGradient();
    final gradientColors = gradient.colors
        .map((color) => color.withValues(alpha: 0.5))
        .toList();

    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700),
      bodyTextStyle: bodyStyle,
      titlePadding: EdgeInsets.fromLTRB(16.0, 128.0, 16.0, 0.0),
      bodyPadding: EdgeInsets.fromLTRB(16.0, 64.0, 16.0, 16.0),
      pageColor: Colors.transparent,
      imagePadding: EdgeInsets.zero,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: gradient.begin,
            end: gradient.end,
          ),
        ),
        child: IntroductionScreen(
          globalBackgroundColor: Colors.transparent,
          allowImplicitScrolling: false,
          infiniteAutoScroll: false,
          pages: [
            PageViewModel(
              title: l10n.homeIrtGuideWelcomeTitle,
              body: l10n.homeIrtGuideWelcomeBody,
              decoration: pageDecoration,
            ),
            PageViewModel(
              title: l10n.homeIrtGuideStep1Title,
              body: l10n.homeIrtGuideStep1Body,
              decoration: pageDecoration,
            ),
            PageViewModel(
              title: l10n.homeIrtGuideStep2Title,
              body: l10n.homeIrtGuideStep2Body,
              decoration: pageDecoration,
            ),
            PageViewModel(
              title: l10n.homeIrtGuideStep3Title,
              body: l10n.homeIrtGuideStep3Body,
              decoration: pageDecoration,
            ),
          ],
          showBackButton: true,
          showDoneButton: true,
          back: const Icon(Icons.arrow_back, size: 28),
          next: const Icon(Icons.arrow_forward, size: 28),
          done: Text(
            l10n.homeIrtGuideDone,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          onDone: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
