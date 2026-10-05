import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/core/widgets/app_button.dart';
import 'package:redream_app/features/shell/shell_tabs.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

/// The three steps on one page, ending in the button that starts a session.
class IrtGuideScreen extends StatelessWidget {
  const IrtGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final brand = BrandTheme.of(context);
    final steps = [
      (Icons.nights_stay_outlined, l10n.guideStep1Title, l10n.guideStep1Body),
      (Icons.edit_outlined, l10n.guideStep2Title, l10n.guideStep2Body),
      (Icons.track_changes, l10n.guideStep3Title, l10n.guideStep3Body),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeGuideTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: brand.heroGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_stories_outlined,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      l10n.guideWelcomeBody,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          for (final (i, (icon, title, body)) in steps.indexed)
            _Step(
              icon: icon,
              title: '${i + 1}. $title',
              body: body,
              last: i == steps.length - 1,
            ),
          const SizedBox(height: 28),
          AppButton(
            label: l10n.homeBeginSession,
            style: AppButtonStyle.gradient,
            onPressed: () {
              final tabs = context.read<ShellTabs>();
              Navigator.of(context).pop();
              tabs.select(ShellTab.session);
            },
          ),
        ],
      ),
    );
  }
}

/// One step of the timeline: icon badge, connector to the next step, text.
class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.title,
    required this.body,
    required this.last,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = BrandTheme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: brand.accentGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: Colors.white),
              ),
              if (!last)
                Expanded(child: Container(width: 2, color: brand.cardBorder)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2, bottom: last ? 0 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: brand.muted,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
