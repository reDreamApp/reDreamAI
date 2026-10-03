import 'package:flutter/material.dart';

import 'package:redream_app/core/widgets/app_card.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sections = [
      (l10n.privacyS1Title, l10n.privacyS1Body),
      (l10n.privacyS2Title, l10n.privacyS2Body),
      (l10n.privacyS3Title, l10n.privacyS3Body),
      (l10n.privacyS4Title, l10n.privacyS4Body),
      (l10n.privacyS5Title, l10n.privacyS5Body),
      (l10n.privacyS6Title, l10n.privacyS6Body),
      (l10n.privacyS7Title, l10n.privacyS7Body),
      (l10n.privacyS8Title, l10n.privacyS8Body),
      (l10n.privacyS9Title, l10n.privacyS9Body),
      (l10n.privacyS10Title, l10n.privacyS10Body),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.privacyTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            l10n.privacySubtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (final (title, body) in sections)
            AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(body, style: const TextStyle(height: 1.5)),
                ],
              ),
            ),
          Center(child: Chip(label: Text(l10n.privacyUpdated))),
        ],
      ),
    );
  }
}
