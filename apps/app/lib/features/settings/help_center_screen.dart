import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/app_services.dart';
import 'package:redream_app/core/auth/auth_service.dart';
import 'package:redream_app/core/widgets/app_button.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/settings/_form_page.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _message = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _message.text.trim();
    if (text.isEmpty) {
      setState(() => _error = l10n.helpEmpty);
      return;
    }
    if (text.length < 10) {
      setState(() => _error = l10n.helpTooShort);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _sent = false;
    });
    try {
      await context.read<AppServices>().account.submitConcern(
        text,
        email: context.read<AuthService>().email,
      );
      if (!mounted) return;
      _message.clear();
      setState(() => _sent = true);
    } on Exception catch (_) {
      if (mounted) setState(() => _error = l10n.helpFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FormPage(
      title: l10n.helpTitle,
      icon: Icons.menu_book_outlined,
      heading: l10n.helpCardTitle,
      body: l10n.helpIntro,
      children: [
        TextField(
          controller: _message,
          minLines: 4,
          maxLines: 6,
          decoration: InputDecoration(hintText: l10n.helpHint),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          InlineNotice(message: _error!),
          const SizedBox(height: 16),
        ],
        if (_sent) ...[
          InlineNotice(message: l10n.helpSuccess, error: false),
          const SizedBox(height: 16),
        ],
        AppButton(
          label: l10n.helpSend,
          icon: Icons.send_outlined,
          busy: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}
