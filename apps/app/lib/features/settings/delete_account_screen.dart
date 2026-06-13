import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../l10n/generated/app_localizations.dart';
import 'account_data_service.dart';
import 'widgets/settings_widgets.dart';

/// Permanent account deletion (DELETE /api/v1/users/me, then sign-out).
///
/// Ported from legacy screens/profile_settings/delete_account_page.dart:
/// double confirmation via an "I understand" checkbox plus an explicit dialog.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  late final IAccountDataService _service;

  bool _acknowledged = false;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service = ApiAccountDataService(context.read<ApiClient>());
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_acknowledged) {
      setState(() => _error = l10n.settingsDeleteAccountConfirmRequired);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsDeleteAccountConfirmTitle),
        content: Text(l10n.settingsDeleteAccountConfirmBody),
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
            child: Text(l10n.settingsDeleteAccountButton),
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
      await _service.deleteAccount();
      if (!mounted) return;
      // Signing out tears down the whole signed-in UI, including this screen.
      await context.read<IAuthService>().signOut();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.settingsDeleteAccountError;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsDeleteAccountTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.delete_forever_outlined,
                      size: 48, color: scheme.error),
                  const SizedBox(height: 16),
                  Text(
                    l10n.settingsDeleteAccountTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.settingsDeleteAccountBody,
                    style:
                        TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: scheme.error, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              l10n.settingsDeleteAccountWarningTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.settingsDeleteAccountWarningIntro,
                          style: TextStyle(
                            fontSize: 14,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.settingsDeleteAccountWarningList,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _acknowledged,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() {
                              _acknowledged = v ?? false;
                              if (_acknowledged) _error = null;
                            }),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.settingsDeleteAccountCheckbox,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) SettingsErrorBanner(message: _error!),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: _busy || !_acknowledged ? null : _submit,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              l10n.settingsDeleteAccountButton,
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
    );
  }
}
