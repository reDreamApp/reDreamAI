import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/widgets/auth_email_field.dart';
import '../collection/collection_state.dart';
import 'account_data_service.dart';
import 'widgets/settings_widgets.dart';

/// GDPR data purge (DELETE /api/v1/users/me/data) — the account stays active.
///
/// Ported from legacy screens/profile_settings/delete_data_page.dart:
/// double confirmation via type-your-email field plus an explicit dialog.
class DeleteDataScreen extends StatefulWidget {
  const DeleteDataScreen({super.key});

  @override
  State<DeleteDataScreen> createState() => _DeleteDataScreenState();
}

class _DeleteDataScreenState extends State<DeleteDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  late final IAccountDataService _service;

  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service = ApiAccountDataService(context.read<ApiClient>());
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String? _validateEmailMatches(String? value) {
    final l10n = AppLocalizations.of(context)!;
    final accountEmail = context.read<IAuthService>().userEmail ?? '';
    if (value == null || value.trim().isEmpty) {
      return l10n.authEmailRequired;
    }
    if (value.trim().toLowerCase() != accountEmail.toLowerCase()) {
      return l10n.settingsDeleteDataEmailMismatch;
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsDeleteDataConfirmTitle),
        content: Text(l10n.settingsDeleteDataConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settingsDeleteDataButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.deleteData();
      if (!mounted) return;
      // Drop locally cached data so the UI doesn't show stale dreams.
      context.read<DreamCollectionState>().resetForUserChange();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsDeleteDataSuccess),
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.settingsDeleteDataError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsDeleteDataTitle)),
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
                    Icon(Icons.delete_outline, size: 48, color: scheme.error),
                    const SizedBox(height: 16),
                    Text(
                      l10n.settingsDeleteDataTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.settingsDeleteDataBody,
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    AuthEmailField(
                      controller: _email,
                      labelText: l10n.settingsEmailLabel,
                      hintText: l10n.settingsDeleteDataEmailHint,
                      validator: _validateEmailMatches,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) SettingsErrorBanner(message: _error!),
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
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
                                l10n.settingsDeleteDataButton,
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
