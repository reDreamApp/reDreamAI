import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// In-app GDPR privacy policy (ported from legacy
/// screens/profile_settings/privacy_policy_page.dart, fully localized).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final sections = <(String, String)>[
      (l10n.settingsPrivacyS1Title, l10n.settingsPrivacyS1Body),
      (l10n.settingsPrivacyS2Title, l10n.settingsPrivacyS2Body),
      (l10n.settingsPrivacyS3Title, l10n.settingsPrivacyS3Body),
      (l10n.settingsPrivacyS4Title, l10n.settingsPrivacyS4Body),
      (l10n.settingsPrivacyS5Title, l10n.settingsPrivacyS5Body),
      (l10n.settingsPrivacyS6Title, l10n.settingsPrivacyS6Body),
      (l10n.settingsPrivacyS7Title, l10n.settingsPrivacyS7Body),
      (l10n.settingsPrivacyS8Title, l10n.settingsPrivacyS8Body),
      (l10n.settingsPrivacyS9Title, l10n.settingsPrivacyS9Body),
      (l10n.settingsPrivacyS10Title, l10n.settingsPrivacyS10Body),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPrivacyPolicy)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.privacy_tip, size: 48, color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  l10n.settingsPrivacyPolicy,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.settingsPrivacyHeader,
                  style: TextStyle(
                    fontSize: 16,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          for (final (title, body) in sections)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      body,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(top: 8, bottom: 24),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              l10n.settingsPrivacyUpdated,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
