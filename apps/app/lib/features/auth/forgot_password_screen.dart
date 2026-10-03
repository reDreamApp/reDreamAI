import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/app_services.dart';
import 'package:redream_app/core/utils/errors.dart';
import 'package:redream_app/core/widgets/app_button.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/auth/auth_fields.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await context
          .read<AppServices>()
          .account
          .requestPasswordReset(_email.text);
      final (message, error) = switch (result) {
        _ when result.accountExists && result.emailSent => (
          l10n.forgotPasswordSent,
          false,
        ),
        _ when !result.accountExists => (l10n.forgotPasswordNoAccount, true),
        _ => (l10n.forgotPasswordFailed, true),
      };
      if (mounted) {
        setState(() {
          _message = message;
          _isError = error;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _message = describeError(e, l10n);
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthTopBar(showBack: true),
                const AuthHeader(),
                const SizedBox(height: 24),
                Text(
                  l10n.forgotPasswordTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(l10n.forgotPasswordIntro, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                AuthEmailField(
                  controller: _email,
                  autofocus: true,
                  hint: l10n.forgotPasswordEmailHint,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                if (_message != null) ...[
                  InlineNotice(message: _message!, error: _isError),
                  const SizedBox(height: 16),
                ],
                AppButton(
                  label: l10n.forgotPasswordSend,
                  busy: _busy,
                  onPressed: _submit,
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(l10n.backToSignIn),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
