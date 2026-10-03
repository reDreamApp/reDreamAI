import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/auth/auth_service.dart';
import 'package:redream_app/core/settings/app_settings.dart';
import 'package:redream_app/core/utils/errors.dart';
import 'package:redream_app/core/widgets/app_card.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/core/widgets/theme_mode_toggle.dart';
import 'package:redream_app/features/consent/consent_state.dart';
import 'package:redream_app/features/reminders/reminder_tile.dart';
import 'package:redream_app/features/settings/change_email_screen.dart';
import 'package:redream_app/features/settings/change_password_screen.dart';
import 'package:redream_app/features/settings/contact_support_screen.dart';
import 'package:redream_app/features/settings/delete_account_screen.dart';
import 'package:redream_app/features/settings/delete_data_screen.dart';
import 'package:redream_app/features/settings/export_data_screen.dart';
import 'package:redream_app/features/settings/help_center_screen.dart';
import 'package:redream_app/features/settings/privacy_policy_screen.dart';
import 'package:redream_app/features/settings/profile.dart';
import 'package:redream_app/features/settings/profile_labels.dart';
import 'package:redream_app/features/settings/profile_state.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<ProfileState>().load());
    });
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _editFrequency() async {
    final l10n = AppLocalizations.of(context)!;
    final profile = context.read<ProfileState>();
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _FrequencySheet(
        title: l10n.settingsUpdateFrequency,
        initial: profile.profile.nightmareFrequency,
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await profile.updateNightmareFrequency(picked);
    } on Exception catch (e) {
      if (mounted) {
        showAppSnackBar(context, describeError(e, l10n), error: true);
      }
    }
  }

  Future<void> _signOut() async {
    final auth = context.read<AuthService>();
    Navigator.of(context).popUntil((r) => r.isFirst);
    await auth.signOut();
  }

  /// Withdrawal is as easy as granting (Art. 7(3)): the consent gate
  /// blocks dream features again, the user's data stays untouched.
  Future<void> _withdrawConsent() async {
    final l10n = AppLocalizations.of(context)!;
    final consent = context.read<ConsentState>();
    final ok = await confirmDialog(
      context,
      title: l10n.withdrawConsentTitle,
      body: l10n.withdrawConsentBody,
      confirmLabel: l10n.withdrawConsentConfirm,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!ok || !mounted) return;
    if (await consent.withdraw()) {
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } else if (mounted) {
      showAppSnackBar(
        context,
        consent.errorMessage ?? l10n.errorUnknown,
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = context.watch<AuthService>();
    final settings = context.watch<AppSettings>();
    final profile = context.watch<ProfileState>();

    final frequency = profile.profile.nightmareFrequency;
    final frequencyText = profile.loading && !profile.loaded
        ? l10n.loading
        : frequency == null
        ? l10n.settingsNotProvided
        : profileLabel(frequency, l10n);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.person_outline),
            const SizedBox(width: 8),
            Flexible(
              child: Text(l10n.settingsTitle, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: profile.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(l10n.settingsIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            _Section(
              icon: Icons.person_outline,
              title: l10n.settingsProfileSection,
              children: [
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text(l10n.settingsEmail),
                  subtitle: Text(auth.email ?? l10n.settingsEmailError),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _push(const ChangeEmailScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(l10n.settingsPassword),
                  subtitle: const Text('**********'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _push(const ChangePasswordScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.nightlight_outlined),
                  title: Text(l10n.settingsNightmareFrequency),
                  subtitle: Text(frequencyText),
                  trailing: TextButton(
                    onPressed: _editFrequency,
                    child: Text(l10n.edit),
                  ),
                ),
                if (profile.error case final err?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      describeError(err, l10n),
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              icon: Icons.settings_outlined,
              title: l10n.settingsAppSection,
              children: [
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(l10n.settingsLanguage),
                  trailing: DropdownButton<String>(
                    value: settings.language,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(l10n.languageEnglish),
                      ),
                      DropdownMenuItem(
                        value: 'de',
                        child: Text(l10n.languageGerman),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) unawaited(settings.setLanguage(v));
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: Text(l10n.settingsTheme),
                  subtitle: Text(l10n.settingsThemeSubtitle),
                  trailing: const ThemeModeToggle(),
                ),
                const ReminderTile(),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              icon: Icons.privacy_tip_outlined,
              title: l10n.settingsPrivacySection,
              color: scheme.error,
              children: [
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(l10n.settingsPrivacyTitle),
                  subtitle: Text(l10n.settingsPrivacyBody),
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: Text(l10n.settingsExport),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(const ExportDataScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: Text(l10n.settingsDeleteData),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(const DeleteDataScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.gpp_maybe_outlined),
                  title: Text(l10n.settingsWithdrawConsent),
                  subtitle: Text(l10n.settingsWithdrawConsentSubtitle),
                  onTap: _withdrawConsent,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error),
                    ),
                    onPressed: () => _push(const DeleteAccountScreen()),
                    icon: const Icon(Icons.no_accounts_outlined),
                    label: Text(l10n.settingsDeleteAccount),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              icon: Icons.help_center_outlined,
              title: l10n.settingsSupportSection,
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined),
                  title: Text(l10n.settingsSupportTitle),
                  subtitle: Text(l10n.settingsSupportBody),
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(l10n.settingsHelpCenter),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(const HelpCenterScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text(l10n.settingsContact),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(const ContactSupportScreen()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: OutlinedButton.icon(
                    onPressed: () => _push(const PrivacyPolicyScreen()),
                    icon: const Icon(Icons.policy_outlined),
                    label: Text(l10n.settingsPrivacyPolicy),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              l10n.appTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const _VersionLabel(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                l10n.settingsTagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.logout, color: scheme.error),
                title: Text(
                  l10n.settingsSignOut,
                  style: TextStyle(color: scheme.error),
                ),
                subtitle: Text(l10n.settingsSignOutSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: _signOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
    this.color,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Icon(icon, color: color ?? theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _FrequencySheet extends StatefulWidget {
  const _FrequencySheet({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_FrequencySheet> createState() => _FrequencySheetState();
}

class _FrequencySheetState extends State<_FrequencySheet> {
  String? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _value,
            onChanged: (v) => setState(() => _value = v),
            child: Column(
              children: [
                for (final f in Profile.nightmareFrequencies)
                  RadioListTile<String>(
                    value: f,
                    title: Text(profileLabel(f, l10n)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _value == null
                  ? null
                  : () => Navigator.pop(context, _value),
              child: Text(l10n.save),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionLabel extends StatelessWidget {
  const _VersionLabel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final info = snap.data;
        final version = info == null
            ? '…'
            : '${info.version}+${info.buildNumber}';
        return Text(
          l10n.settingsVersion(version),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        );
      },
    );
  }
}
