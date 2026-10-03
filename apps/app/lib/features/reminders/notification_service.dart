import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Daily local reminder (id 1001) via flutter_local_notifications.
class NotificationService {
  static const _dailyId = 1001;
  static const _channelId = 'daily_reminders';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } on Exception catch (e) {
        debugPrint('NotificationService: timezone fallback to UTC ($e)');
        tz.setLocalLocation(tz.UTC);
      }
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              'Daily Reminders',
              description: 'Daily reminder notifications',
              importance: Importance.high,
            ),
          );
      _initialized = true;
    } on Exception catch (e) {
      debugPrint('NotificationService: initialize failed ($e)');
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      return true;
    } on Exception catch (e) {
      debugPrint('NotificationService: permission request failed ($e)');
      return false;
    }
  }

  Future<void> scheduleDaily({
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      _dailyId,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Daily Reminders',
          channelDescription: 'Daily reminder notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: await _androidScheduleMode(),
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDaily() => _plugin.cancel(_dailyId);

  Future<bool> isDailyScheduled() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.any((r) => r.id == _dailyId);
    } on Exception catch (_) {
      return false;
    }
  }

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return AndroidScheduleMode.exactAllowWhileIdle;
    try {
      // The manifest deliberately doesn't request exact alarms; a daily
      // reminder can drift a few minutes, so inexact is the fallback.
      if (await android.canScheduleExactNotifications() ?? false) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } on Exception catch (_) {}
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }
}
