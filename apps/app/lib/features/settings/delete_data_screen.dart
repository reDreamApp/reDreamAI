import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/app_services.dart';
import 'package:redream_app/core/auth/auth_service.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/auth/auth_fields.dart';
import 'package:redream_app/features/chat/chat_state.dart';
import 'package:redream_app/features/home/progress_state.dart';
import 'package:redream_app/features/journal/journal_state.dart';
import 'package:redream_app/features/settings/_form_page.dart';
import 'package:redream_app/features/settings/profile_state.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class DeleteDataScreen extends StatefulWidget {
  const DeleteDataScreen({super.key});

  @override
  State<DeleteDataScreen> createState() => _DeleteDataScreenState();
}

class _DeleteDataScreenState extends State<DeleteDataScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(
    text: context.read<AuthService>().email ?? '',
  );
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
    setState(() {
      _busy = true;
      _error = null;
    });
    final services = context.read<AppServices>();
    final journal = context.read<JournalState>();
    final chat = context.read<ChatState>();
    final progress = context.read<ProgressState>();
    final profile = context.read<ProfileState>();
    try {
      await services.account.deleteData();
      if (auth.userId case final id?) await services.store.clearUser(id);
      await journal.resetForUser();
      chat.clear();
      progress.resetForUser();
      profile.resetForUser();
      if (!mounted) return;
      showAppSnackBar(
        context,
        l10n.deleteDataSuccess,
        duration: const Duration(seconds: 4),
      );
      Navigator.pop(context);
    } on Exception catch (_) {
      if (mounted) setState(() => _error = l10n.deleteDataFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return FormPage(
      title: l10n.deleteDataTitle,
      icon: Icons.delete_sweep_outlined,
      iconColor: scheme.error,
      heading: l10n.deleteDataTitle,
      body: l10n.deleteDataBody,
      children: [
        Form(
          key: _form,
          child: AuthEmailField(
            controller: _email,
            label: l10n.settingsEmail,
            isUsername: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 16),
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
              : Text(l10n.deleteDataButton),
        ),
      ],
    );
  }
}
