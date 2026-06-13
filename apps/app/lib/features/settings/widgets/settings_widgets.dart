import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Rounded card with a tinted header row, matching the legacy
/// advanced_menu.dart section cards.
class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.tint,
    required this.onTint,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color tint;
  final Color onTint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: tint.withValues(alpha: 0.3),
            child: Row(
              children: [
                Icon(icon, size: 24, color: onTint),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: onTint,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) divider,
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Square tinted icon used as a ListTile leading, like legacy.
class SettingsLeadingIcon extends StatelessWidget {
  const SettingsLeadingIcon({
    super.key,
    required this.icon,
    required this.tint,
    required this.color,
  });

  final IconData icon;
  final Color tint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 24, color: color),
    );
  }
}

/// Red error banner used across the account screens (ported from the legacy
/// inline error containers).
class SettingsErrorBanner extends StatelessWidget {
  const SettingsErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Version x.y.z+n" footer text (ported from legacy app_version_widget.dart).
class AppVersionWidget extends StatelessWidget {
  const AppVersionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        final info = snapshot.data;
        if (snapshot.hasError || info == null) {
          return Text(
            l10n.settingsVersionError,
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return Text(
          l10n.settingsVersion('${info.version}+${info.buildNumber}'),
          style: Theme.of(context).textTheme.bodySmall,
        );
      },
    );
  }
}
