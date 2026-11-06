import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/logger_provider.dart';
import '../providers/reminder_repository_provider.dart';
import 'local_reminder_notification_scheduler.dart';
import 'reminder_delivery.dart';
import 'reminder_notification_plan.dart';
import 'reminder_notification_scheduler.dart';

/// The Android scheduler used by the app.
///
/// Bootstrap overrides this with an initialized instance so notification taps
/// and launch-from-notification are wired to the router.
final reminderNotificationSchedulerProvider =
    Provider<ReminderNotificationScheduler>((ref) {
      return LocalReminderNotificationScheduler();
    });

final reminderNotificationPlannerProvider =
    Provider<ReminderNotificationPlanner>((ref) {
      return const ReminderNotificationPlanner();
    });

final reminderDeliveryProvider = Provider<ReminderDelivery>((ref) {
  return ReminderDelivery(
    repository: ref.watch(reminderRepositoryProvider),
    scheduler: ref.watch(reminderNotificationSchedulerProvider),
    planner: ref.watch(reminderNotificationPlannerProvider),
    logger: ref.watch(loggerProvider),
  );
});
