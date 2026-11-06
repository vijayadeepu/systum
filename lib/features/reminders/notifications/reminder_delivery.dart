import 'package:logger/logger.dart';

import '../models/reminder.dart';
import '../repository/reminder_repository.dart';
import 'reminder_notification_ids.dart';
import 'reminder_notification_plan.dart';
import 'reminder_notification_scheduler.dart';

/// Mirrors persisted reminder intent into the platform scheduler.
///
/// Persistence and delivery are deliberately separate: failures here are
/// logged and never write to or delete reminder rows. SQLite remains
/// authoritative, and a later edit or task lifecycle change can retry.
class ReminderDelivery {
  ReminderDelivery({
    required this.repository,
    required this.scheduler,
    required this.planner,
    required this.logger,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ReminderRepository repository;
  final ReminderNotificationScheduler scheduler;
  final ReminderNotificationPlanner planner;
  final Logger logger;
  final DateTime Function() _clock;

  /// Mirrors persisted reminder intent into the platform scheduler.
  ///
  /// Persistence and delivery are deliberately separate: failures here are
  /// logged and never write to or delete reminder rows. SQLite remains
  /// authoritative, and a later edit or task lifecycle change can retry.
  Future<void> syncReminder(Reminder reminder) async {
    try {
      await ensureScheduled(reminder);
    } catch (error, stackTrace) {
      _logSchedulingFailure(reminder, error, stackTrace);
    }
  }

  /// Ensures the Android schedule for [reminder] matches its intent.
  ///
  /// Cancelled reminders only cancel. Past or unsupported occurrences cancel
  /// so Android cannot keep a stale notification for old intent. The caller
  /// may retry this method after permission changes or lifecycle edits.
  Future<void> ensureScheduled(Reminder reminder) async {
    final notificationId = reminderNotificationId(reminder.id);
    if (!reminder.isScheduled) {
      await cancel(notificationId);
      return;
    }

    final ReminderNotificationPlan? plan;
    try {
      plan = planner.plan(reminder, nowUtc: _clock().toUtc());
    } on ReminderScheduleException catch (error, stackTrace) {
      await cancel(notificationId);
      _logSchedulingFailure(reminder, error, stackTrace);
      return;
    }

    if (plan == null) {
      await cancel(notificationId);
      return;
    }

    // A stable ID makes this a replacement. Cancelling first also clears a
    // previously repeating schedule before the new intent is installed.
    await cancel(notificationId);

    final bool granted;
    try {
      granted = await scheduler.requestPermission();
    } catch (error, stackTrace) {
      _logSchedulingFailure(reminder, error, stackTrace);
      return;
    }
    if (!granted) {
      logger.i(
        'Notification permission is not granted; reminder ${reminder.id} '
        'remains persisted without an Android schedule.',
      );
      return;
    }

    try {
      await scheduler.schedule(plan);
    } catch (error, stackTrace) {
      _logSchedulingFailure(reminder, error, stackTrace);
    }
  }

  /// Re-reads persisted state for a task and reconciles every reminder.
  Future<void> syncTask(String taskId) async {
    final reminders = await repository.getForTask(taskId);
    for (final reminder in reminders) {
      await syncReminder(reminder);
    }
  }

  /// Reads the IDs that must be cancelled before a cascading task delete.
  Future<List<String>> reminderIdsForTask(String taskId) async {
    final reminders = await repository.getForTask(taskId);
    return [for (final reminder in reminders) reminder.id];
  }

  Future<void> cancelReminderIds(Iterable<String> reminderIds) async {
    for (final reminderId in reminderIds) {
      await cancel(reminderNotificationId(reminderId));
    }
  }

  Future<void> cancelReminder(String reminderId) {
    return cancel(reminderNotificationId(reminderId));
  }

  Future<void> cancel(int notificationId) async {
    try {
      await scheduler.cancel(notificationId);
    } catch (error, stackTrace) {
      logger.w(
        'Could not cancel reminder notification $notificationId.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _logSchedulingFailure(
    Reminder reminder,
    Object error,
    StackTrace stackTrace,
  ) {
    logger.w(
      'Could not schedule reminder notification for ${reminder.id}. '
      'The persisted reminder was left unchanged.',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void logReconciliationFailure(
    Reminder reminder,
    Object error,
    StackTrace stackTrace,
  ) {
    logger.w(
      'Reminder notification reconciliation failed for ${reminder.id}. '
      'The persisted reminder was left unchanged.',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
