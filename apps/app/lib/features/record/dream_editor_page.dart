import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/dream_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../collection/collection_state.dart';
import '../shell/tab_navigator.dart';
import 'draft_models.dart';
import 'draft_repository.dart';

/// Full-screen editor for a single local [DreamDraft].
///
/// Autosaves field changes to the [IDraftRepository] (debounced) so there are
/// no unsaved-changes dialogs. "Save to collection" promotes the draft to a
/// real backend dream via [IDreamService] and deletes the local draft on
/// success.
class DreamEditorPage extends StatefulWidget {
  const DreamEditorPage({
    required this.repository,
    this.draft,
    super.key,
  });

  final IDraftRepository repository;

  /// Existing draft to edit, or null to start a fresh one.
  final DreamDraft? draft;

  @override
  State<DreamEditorPage> createState() => _DreamEditorPageState();
}

class _DreamEditorPageState extends State<DreamEditorPage> {
  static const Duration _autosaveDelay = Duration(milliseconds: 600);

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _rewrittenController;

  late String _draftId;
  late DateTime _createdAt;
  bool _isNightmare = false;
  int _intensity = 5;

  Timer? _autosaveTimer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _draftId =
        draft?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    _createdAt = draft?.updatedAt ?? DateTime.now();
    _isNightmare = draft?.isNightmare ?? false;
    _intensity = draft?.intensity ?? 5;
    _titleController = TextEditingController(text: draft?.title ?? '');
    _descriptionController =
        TextEditingController(text: draft?.originalDream ?? '');
    _rewrittenController =
        TextEditingController(text: draft?.rewrittenDream ?? '');

    _titleController.addListener(_scheduleAutosave);
    _descriptionController.addListener(_scheduleAutosave);
    _rewrittenController.addListener(_scheduleAutosave);
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    // Flush any pending edits so nothing is lost on a fast back-navigation.
    if (_hasContent()) {
      unawaited(widget.repository.save(_currentDraft()));
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _rewrittenController.dispose();
    super.dispose();
  }

  bool _hasContent() {
    return _titleController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _rewrittenController.text.trim().isNotEmpty;
  }

  DreamDraft _currentDraft() {
    final rewritten = _rewrittenController.text.trim();
    return DreamDraft(
      id: _draftId,
      title: _titleController.text.trim(),
      originalDream: _descriptionController.text.trim(),
      rewrittenDream:
          _isNightmare && rewritten.isNotEmpty ? rewritten : null,
      intensity: _isNightmare ? _intensity : null,
      isNightmare: _isNightmare,
      updatedAt: _createdAt,
    );
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, _autosave);
  }

  Future<void> _autosave() async {
    if (!_hasContent()) return;
    await widget.repository.save(_currentDraft());
  }

  void _onNightmareChanged({required bool value}) {
    setState(() => _isNightmare = value);
    _scheduleAutosave();
  }

  void _onIntensityChanged(double value) {
    setState(() => _intensity = value.round());
    _scheduleAutosave();
  }

  Future<void> _saveToCollection() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      _showSnack(messenger, l10n.draftValidationTitle, isError: true);
      return;
    }
    if (description.isEmpty) {
      _showSnack(messenger, l10n.draftValidationDescription, isError: true);
      return;
    }

    _autosaveTimer?.cancel();
    setState(() => _saving = true);

    final dreamService = context.read<IDreamService>();
    final collection = context.read<DreamCollectionState>();
    final tabs = context.read<TabNavigator>();
    final rewritten = _rewrittenController.text.trim();

    try {
      await dreamService.create(
        title: title,
        originalDream: description,
        rewrittenDream:
            _isNightmare && rewritten.isNotEmpty ? rewritten : null,
        intensity: _isNightmare ? _intensity : null,
        isNightmare: _isNightmare,
      );

      await widget.repository.delete(_draftId);
      unawaited(collection.refresh());

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.draftSaveSuccess),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: l10n.draftSaveSuccessView,
            onPressed: () => tabs.goTo(AppTabs.collection),
          ),
        ),
      );
      navigator.pop();
    } on ApiException {
      // Keep the local draft so nothing is lost.
      await _autosave();
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack(messenger, l10n.draftSaveError, isError: true);
    }
  }

  void _showSnack(
    ScaffoldMessengerState messenger,
    String message, {
    bool isError = false,
  }) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.watch<ThemeProvider>().isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.draft == null
              ? l10n.draftEditorNewTitle
              : l10n.draftEditorEditTitle,
        ),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: BrandColors.backgroundGradient(isDark),
        ),
        child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _FieldBlock(
                  helper: l10n.draftTitleHelper,
                  child: TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.draftTitleLabel,
                      hintText: l10n.draftTitleHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _FieldBlock(
                  helper: l10n.draftDescriptionHelper,
                  child: TextField(
                    controller: _descriptionController,
                    minLines: 4,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      labelText: l10n.draftDescriptionLabel,
                      hintText: l10n.draftDescriptionHint,
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: SwitchListTile(
                    value: _isNightmare,
                    onChanged: (v) => _onNightmareChanged(value: v),
                    title: Text(l10n.draftNightmareToggle),
                    subtitle: Text(l10n.draftNightmareHelper),
                  ),
                ),
                if (_isNightmare) ...[
                  const SizedBox(height: 20),
                  _FieldBlock(
                    helper: l10n.draftIntensityHelper,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.draftIntensityLabel(_intensity),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Slider(
                          value: _intensity.toDouble(),
                          max: 10,
                          divisions: 10,
                          label: '$_intensity',
                          onChanged: _onIntensityChanged,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _FieldBlock(
                    helper: l10n.draftRewrittenHelper,
                    child: TextField(
                      controller: _rewrittenController,
                      minLines: 3,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        labelText: l10n.draftRewrittenLabel,
                        hintText: l10n.draftRewrittenHint,
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  l10n.draftAutosaveHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveToCollection,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _saving ? l10n.draftSaving : l10n.draftSaveToCollection,
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  const _FieldBlock({required this.helper, required this.child});

  final String helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            helper,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.8),
                ),
          ),
        ),
        child,
      ],
    );
  }
}
