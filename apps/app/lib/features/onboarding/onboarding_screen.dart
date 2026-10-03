import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/settings/app_settings.dart';
import 'package:redream_app/core/utils/errors.dart';
import 'package:redream_app/core/widgets/app_button.dart';
import 'package:redream_app/core/widgets/brand_logo.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/settings/profile.dart';
import 'package:redream_app/features/settings/profile_labels.dart';
import 'package:redream_app/features/settings/profile_state.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 6;

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) => _controller.animateToPage(
    page,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<AppSettings>();
    final isLast = _page == _pageCount - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: settings.completeOnboarding,
                child: Text(l10n.skip),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _InfoPage(
                    title: l10n.onboardingCelebrateTitle,
                    body: l10n.onboardingCelebrateBody,
                    image: 'assets/images/onboarding_celebrate.png',
                  ),
                  _InfoPage(
                    title: l10n.onboardingWelcomeTitle,
                    body: l10n.onboardingWelcomeBody,
                    child: const BrandLogo(height: 200),
                  ),
                  _InfoPage(
                    title: l10n.onboardingScienceTitle,
                    body: l10n.onboardingScienceBody,
                    image: 'assets/images/onboarding_science.png',
                  ),
                  _InfoPage(
                    title: l10n.onboardingAiTitle,
                    body: l10n.onboardingAiBody,
                    image: 'assets/images/onboarding_ai.png',
                  ),
                  _InfoPage(
                    title: l10n.onboardingPrivacyTitle,
                    body: l10n.onboardingPrivacyBody,
                    image: 'assets/images/onboarding_privacy.png',
                  ),
                  const _ProfilePage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _page == 0 ? null : () => _go(_page - 1),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Spacer(),
                  _Dots(count: _pageCount, current: _page),
                  const Spacer(),
                  IconButton(
                    onPressed: isLast ? null : () => _go(_page + 1),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.title,
    required this.body,
    this.image,
    this.child,
  });

  final String title;
  final String body;
  final String? image;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          child ?? Image.asset(image!, height: 220, fit: BoxFit.contain),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage();

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  final _form = GlobalKey<FormState>();
  String? _gender;
  String? _ageRange;
  String? _frequency;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    final profile = context.read<ProfileState>();
    final settings = context.read<AppSettings>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await profile.save(
        Profile(
          gender: _gender,
          ageRange: _ageRange,
          nightmareFrequency: _frequency,
        ),
      );
      await settings.completeOnboarding();
    } on Exception catch (e) {
      if (mounted) setState(() => _error = describeError(e, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  DropdownButtonFormField<String> _dropdown({
    required String label,
    required List<String> values,
    required String? value,
    required ValueChanged<String?> onChanged,
    required AppLocalizations l10n,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final v in values)
        DropdownMenuItem(value: v, child: Text(profileLabel(v, l10n))),
    ],
    validator: (v) => v == null ? l10n.profileSelectPrompt : null,
    onChanged: onChanged,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              l10n.onboardingProfileTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 32),
            _dropdown(
              label: l10n.profileGender,
              values: Profile.genders,
              value: _gender,
              onChanged: (v) => setState(() => _gender = v),
              l10n: l10n,
            ),
            const SizedBox(height: 16),
            _dropdown(
              label: l10n.profileAgeRange,
              values: Profile.ageRanges,
              value: _ageRange,
              onChanged: (v) => setState(() => _ageRange = v),
              l10n: l10n,
            ),
            const SizedBox(height: 16),
            _dropdown(
              label: l10n.profileNightmareFrequency,
              values: Profile.nightmareFrequencies,
              value: _frequency,
              onChanged: (v) => setState(() => _frequency = v),
              l10n: l10n,
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              InlineNotice(message: _error!),
              const SizedBox(height: 16),
            ],
            AppButton(
              label: l10n.onboardingSubmit,
              style: AppButtonStyle.gradient,
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? scheme.primary : scheme.outline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
