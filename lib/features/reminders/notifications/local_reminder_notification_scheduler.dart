import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'reminder_notification_plan.dart';
import 'reminder_notification_scheduler.dart';

/// Android implementation of the reminder notification boundary.
///
/// All plugin-specific types stay in this file. SQLite reminder rows remain
/// authoritative; this adapter only mirrors the current intent into Android.
class LocalReminderNotificationScheduler
    implements ReminderNotificationScheduler {
  LocalReminderNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'systum_reminders';
  static const channelName = 'Task reminders';
  static const channelDescription = 'Reminders for tasks in Systum';

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;
  bool? _permissionGranted;

  @override
  Future<void> initialize({required void Function(String taskId) onTap}) async {
    if (_initialized) {
      return;
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/systum_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        _openTask(response.payload, onTap);
      },
    );

    final android = _android;
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
      ),
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _openTask(launchDetails!.notificationResponse?.payload, onTap);
    }

    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    final cached = _permissionGranted;
    if (cached != null) {
      return cached;
    }
    final granted = await _android?.requestNotificationsPermission() ?? false;
    _permissionGranted = granted;
    return granted;
  }

  @override
  Future<void> schedule(ReminderNotificationPlan plan) {
    return _plugin.zonedSchedule(
      plan.notificationId,
      'Task reminder',
      'Open Systum to view this task.',
      plan.scheduledAt,
      _notificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // Inexact alarms avoid a second runtime permission while still allowing
      // delivery in Doze. Exact-alarm behaviour is a documented D3 limitation.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: plan.taskId,
      matchDateTimeComponents: switch (plan.repeatComponent) {
        null => null,
        ReminderRepeatComponent.time => DateTimeComponents.time,
        ReminderRepeatComponent.dayOfWeekAndTime =>
          DateTimeComponents.dayOfWeekAndTime,
      },
    );
  }

  @override
  Future<void> cancel(int notificationId) {
    return _plugin.cancel(notificationId);
  }

  AndroidFlutterLocalNotificationsPlugin? get _android {
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  void _openTask(String? payload, void Function(String taskId) onTap) {
    if (payload == null || payload.isEmpty) {
      return;
    }
    onTap(payload);
  }
}
