import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/widgets/auth_password_field.dart';
import '../auth/widgets/auth_validators.dart';
import 'widgets/settings_widgets.dart';

/// Change the account password via Supabase (ported from legacy
/// screens/profile_settings/change_password_page.dart). The current password
/// is verified by re-signing-in before updating, like legacy.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<IAuthService>();

    if (_current.text == _next.text) {
      setState(() => _error = l10n.settingsPasswordSame);
      return;
    }
    final email = auth.userEmail;
    if (email == null) {
      setState(() => _error = l10n.settingsChangePasswordError);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Verify the current password first (mirrors legacy behavior).
      try {
        await auth.signIn(email: email, password: _current.text);
      } catch (_) {
        if (!mounted) return;
        setState(() => _error = l10n.settingsPasswordIncorrect);
        return;
      }
      await auth.updatePassword(_next.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsChangePasswordSuccess)),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.settingsChangePasswordError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsChangePasswordTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.lock_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.settingsChangePasswordHeading,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.settingsChangePasswordBody,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    AuthPasswordField(
                      controller: _current,
                      labelText: l10n.settingsCurrentPasswordLabel,
                      validator: (v) => validatePassword(context, v),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    AuthPasswordField(
                      controller: _next,
                      labelText: l10n.settingsNewPasswordLabel,
                      validator: (v) => validatePassword(context, v),
                      textInputAction: TextInputAction.next,
                      isNewPassword: true,
                    ),
                    const SizedBox(height: 20),
                    AuthPasswordField(
                      controller: _confirm,
                      labelText: l10n.settingsConfirmNewPasswordLabel,
                      validator: (v) =>
                          validateConfirmPassword(context, v, _next),
                      onSubmitted: (_) => _submit(),
                      isNewPassword: true,
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) SettingsErrorBanner(message: _error!),
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                l10n.settingsChangePasswordButton,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
