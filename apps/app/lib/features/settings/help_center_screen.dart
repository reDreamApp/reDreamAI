import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../l10n/generated/app_localizations.dart';
import 'help_center_service.dart';
import 'widgets/settings_widgets.dart';

/// Help-center concern categories. The backend only stores a message, so the
/// chosen category is prepended to it as a canonical English tag.
enum HelpCategory { general, technical, feedback, privacy, other }

extension on HelpCategory {
  String get tag {
    switch (this) {
      case HelpCategory.general:
        return 'General question';
      case HelpCategory.technical:
        return 'Technical problem';
      case HelpCategory.feedback:
        return 'Feedback';
      case HelpCategory.privacy:
        return 'Privacy';
      case HelpCategory.other:
        return 'Other';
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case HelpCategory.general:
        return l10n.helpCategoryGeneral;
      case HelpCategory.technical:
        return l10n.helpCategoryTechnical;
      case HelpCategory.feedback:
        return l10n.helpCategoryFeedback;
      case HelpCategory.privacy:
        return l10n.helpCategoryPrivacy;
      case HelpCategory.other:
        return l10n.helpCategoryOther;
    }
  }
}

/// Support form posting to POST /api/v1/help-center/concerns (ported from
/// legacy screens/profile_settings/help_center_page.dart).
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  late final IHelpCenterService _service;

  HelpCategory _category = HelpCategory.general;
  String? _error;
  bool _busy = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _service = ApiHelpCenterService(context.read<ApiClient>());
  }

  @override
  void dispose() {
    _message.dispose();
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
      await _service
          .submitConcern('[${_category.tag}] ${_message.text.trim()}');
      if (!mounted) return;
      setState(() => _submitted = true);
      _message.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.helpSendError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.menu_book, size: 48, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    l10n.helpTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.helpIntro,
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.helpFormTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<HelpCategory>(
                        initialValue: _category,
                        decoration: InputDecoration(
                          labelText: l10n.helpCategoryLabel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: [
                          for (final c in HelpCategory.values)
                            DropdownMenuItem(
                              value: c,
                              child: Text(c.label(l10n)),
                            ),
                        ],
                        onChanged: (c) =>
                            setState(() => _category = c ?? _category),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _message,
                        maxLines: 6,
                        minLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: l10n.helpMessageHint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return l10n.helpMessageRequired;
                          if (text.length < 10) return l10n.helpMessageTooShort;
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_error != null) SettingsErrorBanner(message: _error!),
                      if (_submitted)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.helpSendSuccess,
                            style:
                                TextStyle(color: scheme.onPrimaryContainer),
                          ),
                        ),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(l10n.helpSend),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
