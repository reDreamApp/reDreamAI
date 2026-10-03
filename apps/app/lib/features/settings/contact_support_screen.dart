import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:redream_app/core/widgets/app_button.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/settings/_form_page.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

const supportEmail = 'info@redreamai.com';

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  Future<void> _openEmail(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final ok = await launchUrl(Uri(scheme: 'mailto', path: supportEmail));
      if (!ok) throw StateError('mailto');
    } on Exception catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, l10n.contactOpenFailed, error: true);
      }
    }
  }

  Future<void> _copyEmail(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    if (context.mounted) showAppSnackBar(context, l10n.contactCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return FormPage(
      title: l10n.contactTitle,
      icon: Icons.support_agent_outlined,
      heading: l10n.contactTitle,
      body: l10n.contactBody,
      children: [
        Text(l10n.contactEmailLabel, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const SelectableText(supportEmail),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: l10n.contactOpenEmail,
          icon: Icons.mail_outline,
          onPressed: () => _openEmail(context),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: l10n.contactCopyEmail,
          icon: Icons.copy_outlined,
          style: AppButtonStyle.outlined,
          onPressed: () => _copyEmail(context),
        ),
      ],
    );
  }
}
