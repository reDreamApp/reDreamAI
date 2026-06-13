import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';
import '../../core/language/language_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import 'change_email_screen.dart';
import 'change_password_screen.dart';
import 'contact_support_screen.dart';
import 'delete_account_screen.dart';
import 'delete_data_screen.dart';
import 'export_data_screen.dart';
import 'help_center_screen.dart';
import 'privacy_policy_screen.dart';
import 'profile_screen.dart';
import 'widgets/settings_widgets.dart';

/// Settings end-drawer — sectioned cards ported from the legacy
/// screens/profile_settings/advanced_menu.dart SettingsPage.
class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final language = context.read<LanguageProvider>();
    final current =
        language.localeOverride == null ? null : language.selectedLanguage;

    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.settingsLanguageLabel),
        children: [
          for (final (code, label) in [
            (null, l10n.settingsLanguageSystem),
            ('en', l10n.settingsLanguageEnglish),
            ('de', l10n.settingsLanguageGerman),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(code ?? 'system'),
              child: Row(
                children: [
                  Icon(
                    current == code
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                    color: Theme.of(dialogContext).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(label, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
        ],
      ),
    );
    if (choice == null) return;
    await language.setLanguage(choice == 'system' ? null : choice);
  }

  String _languageSubtitle(BuildContext context, AppLocalizations l10n) {
    final language = context.watch<LanguageProvider>();
    if (language.localeOverride == null) return l10n.settingsLanguageSystem;
    return language.selectedLanguage == 'de'
        ? l10n.settingsLanguageGerman
        : l10n.settingsLanguageEnglish;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<IAuthService>();

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header (brand gradient, like the legacy drawer header).
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: BrandColors.brandGradient(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.settingsTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.settingsDescription,
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Profile information.
            SettingsSectionCard(
              title: l10n.settingsProfileSection,
              icon: Icons.person_outline,
              tint: scheme.primaryContainer,
              onTint: scheme.onPrimaryContainer,
              children: [
                ListTile(
                  leading: SettingsLeadingIcon(
                    icon: Icons.email_outlined,
                    tint: scheme.primaryContainer,
                    color: scheme.primary,
                  ),
                  title: Text(
                    l10n.settingsEmailLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    auth.userEmail ?? '—',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(Icons.edit, color: scheme.primary, size: 20),
                  onTap: () => _push(context, const ChangeEmailScreen()),
                ),
                ListTile(
                  leading: SettingsLeadingIcon(
                    icon: Icons.lock_outline,
                    tint: scheme.primaryContainer,
                    color: scheme.primary,
                  ),
                  title: Text(
                    l10n.settingsPasswordLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle:
                      const Text('••••••••', style: TextStyle(fontSize: 14)),
                  trailing: Icon(Icons.edit, color: scheme.primary, size: 20),
                  onTap: () => _push(context, const ChangePasswordScreen()),
                ),
                ListTile(
                  leading: SettingsLeadingIcon(
                    icon: Icons.badge_outlined,
                    tint: scheme.primaryContainer,
                    color: scheme.primary,
                  ),
                  title: Text(
                    l10n.profileTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    l10n.profileDrawerSubtitle,
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(context, const ProfileScreen()),
                ),
              ],
            ),

            // App settings.
            SettingsSectionCard(
              title: l10n.settingsAppSection,
              icon: Icons.tune,
              tint: scheme.secondaryContainer,
              onTint: scheme.onSecondaryContainer,
              children: [
                ListTile(
                  leading: SettingsLeadingIcon(
                    icon: Icons.language,
                    tint: scheme.secondaryContainer,
                    color: scheme.secondary,
                  ),
                  title: Text(
                    l10n.settingsLanguageLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _languageSubtitle(context, l10n),
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickLanguage(context),
                ),
                ListTile(
                  leading: SettingsLeadingIcon(
                    icon: context.watch<ThemeProvider>().isDarkMode(context)
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    tint: scheme.secondaryContainer,
                    color: scheme.secondary,
                  ),
                  title: Text(
                    l10n.settingsThemeLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    l10n.settingsThemeSubtitle,
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: Switch(
                    value: context.watch<ThemeProvider>().isDarkMode(context),
                    onChanged: (_) =>
                        context.read<ThemeProvider>().toggleTheme(context),
                  ),
                ),
                // Daily reminder requires local notifications, which aren't
                // available in this build — shown disabled ("coming soon").
                ListTile(
                  enabled: false,
                  leading: SettingsLeadingIcon(
                    icon: Icons.notifications_outlined,
                    tint: scheme.secondaryContainer,
                    color: scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    l10n.settingsReminderLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    l10n.settingsReminderComingSoon,
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: const Switch(value: false, onChanged: null),
                ),
              ],
            ),

            // Privacy & security.
            SettingsSectionCard(
              title: l10n.settingsPrivacySection,
              icon: Icons.shield_outlined,
              tint: scheme.tertiaryContainer,
              onTint: scheme.onTertiaryContainer,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsPrivacyIntroTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.settingsPrivacyIntroBody,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: SettingsLeadingIcon(
                    icon: Icons.download_outlined,
                    tint: scheme.tertiaryContainer,
                    color: scheme.tertiary,
                  ),
                  title: Text(
                    l10n.settingsExportData,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(context, const ExportDataScreen()),
                ),
                ListTile(
                  leading: SettingsLeadingIcon(
                    icon: Icons.delete_outline,
                    tint: scheme.errorContainer,
                    color: scheme.error,
                  ),
                  title: Text(
                    l10n.settingsDeleteData,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(context, const DeleteDataScreen()),
                ),
                ListTile(
                  leading: SettingsLeadingIcon(
                    icon: Icons.delete_forever_outlined,
                    tint: scheme.errorContainer,
                    color: scheme.error,
                  ),
                  title: Text(
                    l10n.settingsDeleteAccount,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.error,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(context, const DeleteAccountScreen()),
                ),
              ],
            ),

            // Support & help.
            SettingsSectionCard(
              title: l10n.settingsSupportSection,
              icon: Icons.support_agent,
              tint: scheme.secondaryContainer,
              onTint: scheme.onSecondaryContainer,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsSupportIntroTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.settingsSupportIntroBody,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: SettingsLeadingIcon(
                    icon: Icons.help_outline,
                    tint: scheme.secondaryContainer,
                    color: scheme.secondary,
                  ),
                  title: Text(
                    l10n.settingsHelpCenter,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(context, const HelpCenterScreen()),
                ),
                ListTile(
                  leading: SettingsLeadingIcon(
                    icon: Icons.mail_outline,
                    tint: scheme.secondaryContainer,
                    color: scheme.secondary,
                  ),
                  title: Text(
                    l10n.settingsContactSupport,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(context, const ContactSupportScreen()),
                ),
                ListTile(
                  leading: SettingsLeadingIcon(
                    icon: Icons.privacy_tip_outlined,
                    tint: scheme.secondaryContainer,
                    color: scheme.secondary,
                  ),
                  title: Text(
                    l10n.settingsPrivacyPolicy,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(context, const PrivacyPolicyScreen()),
                ),
              ],
            ),

            // Sign out.
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: SettingsLeadingIcon(
                  icon: Icons.logout,
                  tint: scheme.errorContainer,
                  color: scheme.error,
                ),
                title: Text(
                  l10n.settingsSignOut,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.error,
                  ),
                ),
                subtitle: Text(
                  l10n.settingsSignOutSubtitle,
                  style: const TextStyle(fontSize: 14),
                ),
                onTap: () => context.read<IAuthService>().signOut(),
              ),
            ),

            // Footer: version + tagline.
            const Center(child: AppVersionWidget()),
            const SizedBox(height: 8),
            Text(
              l10n.settingsTagline,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
