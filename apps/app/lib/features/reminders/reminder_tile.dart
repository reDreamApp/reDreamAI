import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/utils/errors.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/reminders/reminder_state.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class ReminderTile extends StatefulWidget {
  const ReminderTile({super.key});

  @override
  State<ReminderTile> createState() => _ReminderTileState();
}

class _ReminderTileState extends State<ReminderTile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<ReminderState>().restore());
    });
  }

  Future<void> _toggle(bool on) async {
    final l10n = AppLocalizations.of(context)!;
    final state = context.read<ReminderState>();
    try {
      if (!on) {
        await state.disable();
        if (mounted) showAppSnackBar(context, l10n.reminderCancelled);
        return;
      }
      final picked = await showTimePicker(
        context: context,
        initialTime: state.time ?? TimeOfDay.now(),
      );
      if (picked == null || !mounted) return;
      await state.enable(
        picked,
        title: l10n.reminderNotificationTitle,
        body: l10n.reminderNotificationBody,
      );
      if (mounted) {
        showAppSnackBar(context, l10n.reminderSet(picked.format(context)));
      }
    } on Exception catch (e) {
      if (mounted) {
        showAppSnackBar(context, describeError(e, l10n), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<ReminderState>();
    final scheme = Theme.of(context).colorScheme;
    final time = state.time;
    return ListTile(
      leading: Icon(
        state.enabled
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        color: state.enabled ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(l10n.reminderTitle),
      subtitle: Text(
        state.enabled && time != null
            ? l10n.reminderActiveAt(time.format(context))
            : l10n.reminderOff,
      ),
      trailing: Switch(value: state.enabled, onChanged: _toggle),
    );
  }
}
