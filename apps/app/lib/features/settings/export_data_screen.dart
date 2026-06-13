import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../l10n/generated/app_localizations.dart';
import 'account_data_service.dart';
import 'widgets/settings_widgets.dart';

/// GDPR data export (GET /api/v1/exports/data). Shows the JSON in a
/// selectable monospaced view with a copy button — file saving needs extra
/// dependencies and is intentionally not ported.
class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  late final IAccountDataService _service;

  bool _busy = false;
  String? _error;
  String? _json;

  @override
  void initState() {
    super.initState();
    _service = ApiAccountDataService(context.read<ApiClient>());
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
      _json = null;
    });
    try {
      final data = await _service.exportData();
      if (!mounted) return;
      setState(() => _json = const JsonEncoder.withIndent('  ').convert(data));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.settingsExportError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _json!));
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.settingsExportCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsExportTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.download_outlined, size: 48, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              l10n.settingsExportTitle,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _json == null ? l10n.settingsExportBody : l10n.settingsExportReady,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_error != null) SettingsErrorBanner(message: _error!),
            if (_busy)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(l10n.settingsExportLoading),
                  ],
                ),
              )
            else if (_json != null) ...[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _json!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy, size: 20),
                  label: Text(
                    l10n.settingsExportCopy,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _export,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.settingsExportButton,
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
    );
  }
}
