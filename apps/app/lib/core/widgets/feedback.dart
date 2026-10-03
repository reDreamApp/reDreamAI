import 'package:flutter/material.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool error = false,
  Duration duration = const Duration(seconds: 3),
  SnackBarAction? action,
}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: action,
        backgroundColor: error ? scheme.error : null,
      ),
    );
}

/// Yes/no dialog; resolves to true when [confirmLabel] was tapped.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Inline notice used for form errors and success messages.
class InlineNotice extends StatelessWidget {
  const InlineNotice({required this.message, super.key, this.error = true});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            error ? Icons.error_outline : Icons.check_circle_outline,
            color: error ? scheme.onErrorContainer : scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: error
                    ? scheme.onErrorContainer
                    : scheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
