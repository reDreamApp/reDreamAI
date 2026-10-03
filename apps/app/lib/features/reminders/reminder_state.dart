import 'package:flutter/material.dart';

import 'package:redream_app/core/storage/local_store.dart';
import 'package:redream_app/features/reminders/notification_service.dart';

/// Daily rehearsal reminder toggle, persisted locally.
class ReminderState extends ChangeNotifier {
  ReminderState(this._store, this._notifications);

  static const _enabledKey = 'daily_reminder_enabled';
  static const _hourKey = 'daily_reminder_hour';
  static const _minuteKey = 'daily_reminder_minute';

  final LocalStore _store;
  final NotificationService _notifications;

  bool _enabled = false;
  TimeOfDay? _time;
  bool _restored = false;

  bool get enabled => _enabled;
  TimeOfDay? get time => _time;

  /// Reads the saved state; turns off if the OS dropped the schedule.
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    final enabled = _store.getBool(_enabledKey) ?? false;
    final hour = _store.getInt(_hourKey);
    final minute = _store.getInt(_minuteKey);
    _time = hour == null || minute == null
        ? null
        : TimeOfDay(hour: hour, minute: minute);
    _enabled = enabled && await _notifications.isDailyScheduled();
    if (enabled && !_enabled) await _store.setBool(_enabledKey, value: false);
    notifyListeners();
  }

  Future<void> enable(
    TimeOfDay time, {
    required String title,
    required String body,
  }) async {
    await _notifications.requestPermissions();
    await _notifications.scheduleDaily(time: time, title: title, body: body);
    _enabled = true;
    _time = time;
    await _store.setBool(_enabledKey, value: true);
    await _store.setInt(_hourKey, time.hour);
    await _store.setInt(_minuteKey, time.minute);
    notifyListeners();
  }

  Future<void> disable() async {
    await _notifications.cancelDaily();
    _enabled = false;
    _time = null;
    await _store.setBool(_enabledKey, value: false);
    await _store.remove(_hourKey);
    await _store.remove(_minuteKey);
    notifyListeners();
  }
}
