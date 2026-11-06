import 'package:flutter/services.dart';
import 'package:systum/features/reminders/notifications/reminder_notification_plan.dart';
import 'package:systum/features/reminders/notifications/reminder_notification_scheduler.dart';

class FakeReminderNotificationScheduler
    implements ReminderNotificationScheduler {
  FakeReminderNotificationScheduler();

  final List<ReminderNotificationPlan> scheduledPlans = [];
  final List<int> cancelledNotificationIds = [];
  bool permissionGranted = true;
  bool initializeCalled = false;
  bool failingSchedule = false;
  int initializeCalls = 0;

  @override
  Future<void> initialize({required void Function(String taskId) onTap}) async {
    initializeCalls++;
    initializeCalled = true;
  }

  @override
  Future<bool> requestPermission() async {
    return permissionGranted;
  }

  @override
  Future<void> schedule(ReminderNotificationPlan plan) async {
    if (failingSchedule) {
      throw PlatformException(code: 'unknown');
    }
    scheduledPlans.add(plan);
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelledNotificationIds.add(notificationId);
  }
}
