import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/app_services.dart';
import 'package:redream_app/core/auth/auth_service.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/auth/auth_fields.dart';
import 'package:redream_app/features/settings/_form_page.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(
    text: context.read<AuthService>().email ?? '',
  );
  bool _confirmed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthService>();
    if (_email.text.trim().toLowerCase() != (auth.email ?? '').toLowerCase()) {
      setState(() => _error = l10n.emailMismatch);
      return;
    }
    if (!_confirmed) {
      setState(() => _error = l10n.deleteAccountConfirmRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final account = context.read<AppServices>().account;
    try {
      await account.deleteAccount();
      if (!mounted) return;
      showAppSnackBar(context, l10n.deleteAccountSuccess);
      Navigator.of(context).popUntil((r) => r.isFirst);
      await auth.signOut();
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _error = l10n.deleteAccountFailed;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final warnings = [
      l10n.deleteAccountWarn1,
      l10n.deleteAccountWarn2,
      l10n.deleteAccountWarn3,
      l10n.deleteAccountWarn4,
    ];
    return FormPage(
      title: l10n.deleteAccountTitle,
      icon: Icons.no_accounts_outlined,
      iconColor: scheme.error,
      heading: l10n.deleteAccountTitle,
      body: l10n.deleteAccountBody,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.deleteAccountWarnTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 4),
              for (final w in warnings)
                Text('• $w', style: TextStyle(color: scheme.onErrorContainer)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Form(
          key: _form,
          child: AuthEmailField(
            controller: _email,
            label: l10n.settingsEmail,
            isUsername: false,
            textInputAction: TextInputAction.done,
          ),
        ),
        CheckboxListTile(
          value: _confirmed,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l10n.deleteAccountConfirm),
          onChanged: (v) => setState(() {
            _confirmed = v ?? false;
            _error = null;
          }),
        ),
        const SizedBox(height: 8),
        if (_error != null) ...[
          InlineNotice(message: _error!),
          const SizedBox(height: 16),
        ],
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.deleteAccountButton),
        ),
      ],
    );
  }
}
