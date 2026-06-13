import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';
import '../../l10n/generated/app_localizations.dart';
import 'widgets/auth_email_field.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_password_field.dart';
import 'widgets/auth_validators.dart';

/// Email + password sign-up (ported from legacy
/// screens/authentication/signup_page.dart). After a successful sign-up,
/// shows a localized "check your inbox to confirm" state.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<IAuthService>().signUp(
        email: _email.text.trim(),
        password: _password.text,
      );
      // Lets iOS offer saving the new credentials to the keychain.
      TextInput.finishAutofillContext();
      if (!mounted) return;
      setState(() => _submitted = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.authSignUpError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authSignUpTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _submitted ? _buildSuccess(l10n) : _buildForm(l10n),
        ),
      ),
    );
  }

  Widget _buildSuccess(AppLocalizations l10n) {
    return Column(
      children: [
        const AuthHeader(),
        const SizedBox(height: 32),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.authSignUpSuccessTitle,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.authSignUpSuccessBody,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.authBackToSignIn),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeader(),
          const SizedBox(height: 32),
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthEmailField(
                  controller: _email,
                  labelText: l10n.signInEmail,
                  hintText: l10n.authEmailHint,
                  validator: (v) => validateEmail(context, v),
                ),
                const SizedBox(height: 16),
                AuthPasswordField(
                  controller: _password,
                  labelText: l10n.signInPassword,
                  hintText: l10n.authPasswordHint,
                  validator: (v) => validatePassword(context, v),
                  textInputAction: TextInputAction.next,
                  isNewPassword: true,
                ),
                const SizedBox(height: 16),
                AuthPasswordField(
                  controller: _confirmPassword,
                  labelText: l10n.authConfirmPasswordLabel,
                  hintText: l10n.authConfirmPasswordHint,
                  validator: (v) =>
                      validateConfirmPassword(context, v, _password),
                  onSubmitted: (_) => _submit(),
                  isNewPassword: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      l10n.authSignUpButton,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.authBackToSignIn),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
