import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../onboarding/onboarding_screen.dart';
import '../progress/progress_section.dart';
import '../progress/progress_service.dart';
import '../progress/progress_state.dart';
import '../shell/tab_navigator.dart';
import 'irt_guide_page.dart';
import 'widgets/brand_logo.dart';
import 'widgets/gradient_card.dart';

/// Home tab, ported from the legacy screens/home/home_page.dart: branding,
/// progress + daily mood, quick actions, practice + IRT guide cards.
///
/// Also hosts the first-run onboarding gate (the shell cannot be modified):
/// on first build after sign-in, if the 'onboarding_seen' preference is unset,
/// the onboarding flow is pushed fullscreen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ProgressState _progress;
  bool _onboardingChecked = false;

  @override
  void initState() {
    super.initState();
    _progress = ProgressState(ProgressService(context.read<ApiClient>()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeShowOnboarding();
      _progress.preload();
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _maybeShowOnboarding() async {
    if (_onboardingChecked) return;
    _onboardingChecked = true;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(OnboardingScreen.seenPrefsKey) ?? false) return;
    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ChangeNotifierProvider<ProgressState>.value(
      value: _progress,
      child: Container(
        decoration: BoxDecoration(
          gradient: BrandColors.backgroundGradient(isDark),
        ),
        child: RefreshIndicator(
          onRefresh: _progress.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              // Branding: logo + slogan + mission statement.
              const Center(child: BrandLogo(height: 100)),
              Padding(
                padding: const EdgeInsets.all(6),
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      theme.colorScheme.onPrimaryContainer,
                      theme.colorScheme.inversePrimary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    l10n.homeSlogan,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  l10n.homeMission,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ),

              // Progress + daily mood check-in.
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ProgressSection(),
              ),

              // Quick actions: chat session, record dream, view collection.
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: GradientCard(
                  child: Column(
                    children: [
                      Text(
                        l10n.homeQuickActionsTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _QuickAction(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: l10n.homeQuickActionChat,
                            onTap: () => context
                                .read<TabNavigator>()
                                .goTo(AppTabs.chat),
                          ),
                          const SizedBox(width: 8),
                          _QuickAction(
                            icon: Icons.edit_note_rounded,
                            label: l10n.homeQuickActionRecord,
                            onTap: () => context
                                .read<TabNavigator>()
                                .goTo(AppTabs.record),
                          ),
                          const SizedBox(width: 8),
                          _QuickAction(
                            icon: Icons.menu_book_rounded,
                            label: l10n.homeQuickActionCollection,
                            onTap: () => context
                                .read<TabNavigator>()
                                .goTo(AppTabs.collection),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Practice card → collection tab (current dream rehearsal).
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: GradientCard(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/woman-practice.png',
                        height: 240,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.homePracticeBody,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 12),
                      _CardButton(
                        label: l10n.homePracticeButton,
                        onPressed: () => context
                            .read<TabNavigator>()
                            .goTo(AppTabs.collection),
                      ),
                    ],
                  ),
                ),
              ),

              // IRT guide card.
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: GradientCard(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/guide-2.png',
                        height: 240,
                        fit: BoxFit.contain,
                      ),
                      Text(
                        l10n.homeGuideBody,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 12),
                      _CardButton(
                        label: l10n.homeGuideButton,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const IrtGuidePage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outlined full-width card button (legacy "Practice"/"IRT Guide" style).
class _CardButton extends StatelessWidget {
  const _CardButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            side: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outline, width: 1.25),
            ),
            child: Column(
              children: [
                Icon(icon, size: 28, color: colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
