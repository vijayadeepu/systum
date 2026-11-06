import 'reminder_notification_plan.dart';

/// Platform boundary for Android notification scheduling.
///
/// The reminder domain only depends on this interface. Tests substitute a
/// small recording implementation instead of mocking plugin internals.
abstract interface class ReminderNotificationScheduler {
  /// Prepares the platform channel and routes notification taps to [onTap]
  /// with the persisted task ID stored in the notification payload.
  Future<void> initialize({required void Function(String taskId) onTap});

  /// Requests runtime notification permission when the platform requires it.
  Future<bool> requestPermission();

  /// Creates or replaces the notification identified by the plan.
  Future<void> schedule(ReminderNotificationPlan plan);

  /// Removes a pending notification. Missing IDs are a platform no-op.
  Future<void> cancel(int notificationId);
}
