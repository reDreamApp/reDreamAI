import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../settings/privacy_policy_screen.dart';
import 'consent_state.dart';

/// Blocks the signed-in app until Art. 9 consent is granted for the current
/// consent-text version. Mounted by the auth gate in app.dart; assumes a
/// [ConsentState] provider in scope.
class ConsentGate extends StatefulWidget {
  const ConsentGate({required this.child, super.key});

  final Widget child;

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ConsentState>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final consent = context.watch<ConsentState>();
    switch (consent.consentRequired) {
      case false:
        return widget.child;
      case true:
        return const ConsentScreen();
      case null:
        // Status unknown: still loading, or the fetch failed.
        return _ConsentLoadingScaffold(
          failed: !consent.loading && consent.errorMessage != null,
          onRetry: consent.load,
        );
    }
  }
}

class _ConsentLoadingScaffold extends StatelessWidget {
  const _ConsentLoadingScaffold({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: failed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.consentLoadError),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: onRetry, child: Text(l10n.chatRetry)),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

/// The explicit-consent screen (GDPR Art. 9(2)(a)): names what is processed
/// and by whom, requires an active opt-in, and offers sign-out as the way
/// to decline. Copy is near-final pending the lawyer pass — keep changes to
/// the WORDING in the .arb files; a material change also requires bumping
/// the backend's consent version.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final consent = context.watch<ConsentState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 16),
                    Icon(
                      Icons.shield_outlined,
                      size: 48,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.consentTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.consentIntro),
                    const SizedBox(height: 16),
                    _ConsentPoint(
                      icon: Icons.nights_stay_outlined,
                      text: l10n.consentBulletData,
                    ),
                    _ConsentPoint(
                      icon: Icons.dns_outlined,
                      text: l10n.consentBulletProcessors,
                    ),
                    _ConsentPoint(
                      icon: Icons.tune_outlined,
                      text: l10n.consentBulletControl,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        ),
                        child: Text(l10n.settingsPrivacyPolicy),
                      ),
                    ),
                    if (consent.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          consent.errorMessage!,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                  ],
                ),
              ),
              CheckboxListTile(
                value: _agreed,
                onChanged: consent.saving
                    ? null
                    : (v) => setState(() => _agreed = v ?? false),
                title: Text(l10n.consentCheckbox),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _agreed && !consent.saving ? consent.grant : null,
                child: consent.saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.consentContinue),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.consentDeclineHint,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () => context.read<IAuthService>().signOut(),
                child: Text(l10n.consentSignOut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentPoint extends StatelessWidget {
  const _ConsentPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
