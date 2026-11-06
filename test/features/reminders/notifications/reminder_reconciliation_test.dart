import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/reminders/models/reminder.dart';
import 'package:systum/features/reminders/notifications/reminder_delivery.dart';
import 'package:systum/features/reminders/notifications/reminder_delivery_provider.dart';
import 'package:systum/features/reminders/notifications/reminder_notification_ids.dart';
import 'package:systum/features/reminders/notifications/reminder_notification_plan.dart';
import 'package:systum/features/reminders/notifications/reminder_reconciliation.dart';
import 'package:systum/features/reminders/notifications/reminder_reconciliation_provider.dart';
import 'package:systum/features/reminders/providers/reminder_repository_provider.dart';
import 'package:systum/features/reminders/providers/reminder_provider.dart';
import 'package:systum/features/reminders/repository/reminder_repository.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/providers/task_provider.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';
import 'package:systum/shared/providers/database_provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'fake_reminder_notification_scheduler.dart';

void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
  });

  late SystumDatabase database;
  late FakeReminderNotificationScheduler scheduler;
  late TaskRepository taskRepository;

  setUp(() async {
    database = SystumDatabase.test(NativeDatabase.memory());
    taskRepository = TaskRepository(database);
    await taskRepository.insert(
      Task(
        id: 'task-1',
        title: 'Task',
        createdAt: DateTime.utc(2026, 6, 1, 12),
        updatedAt: DateTime.utc(2026, 6, 1, 12),
      ),
    );
    scheduler = FakeReminderNotificationScheduler();
  });

  tearDown(() async {
    await database.close();
  });

  ReminderDelivery delivery() {
    return ReminderDelivery(
      repository: ReminderRepository(database),
      scheduler: scheduler,
      planner: const ReminderNotificationPlanner(),
      logger: Logger(
        printer: PrettyPrinter(methodCount: 0, errorMethodCount: 0),
      ),
    );
  }

  ReminderReconciliation reconciliation(ReminderDelivery delivery) =>
      ReminderReconciliation(
        repository: delivery.repository,
        delivery: delivery,
      );

  Reminder onceReminder() {
    return Reminder(
      id: 'reminder-1',
      taskId: 'task-1',
      scheduleType: ReminderScheduleType.once,
      scheduledAtUtc: DateTime.utc(2030, 6, 20, 9),
      createdAt: DateTime.utc(2026, 6, 1, 12),
      updatedAt: DateTime.utc(2026, 6, 1, 12),
    );
  }

  test('reconcileAll schedules an active future one-time reminder', () async {
    final result = delivery();
    await result.repository.create(onceReminder());

    await reconciliation(result).reconcileAll();

    expect(scheduler.scheduledPlans, hasLength(1));
    expect(scheduler.scheduledPlans.single.taskId, 'task-1');
  });

  test('reconcileAll cancels a cancelled reminder', () async {
    final result = delivery();
    final reminder = onceReminder().copyWith(
      status: ReminderStatus.cancelled,
      cancellationReason: ReminderCancellationReason.user,
      cancelledAtUtc: DateTime.utc(2026, 6, 2, 9),
    );
    await result.repository.create(reminder);

    await reconciliation(result).reconcileAll();

    expect(scheduler.scheduledPlans, isEmpty);
    expect(scheduler.cancelledNotificationIds, hasLength(1));
  });

  test('reconcileAll is idempotent for the same persisted intent', () async {
    final result = delivery();
    await result.repository.create(onceReminder());
    scheduler.scheduledPlans.clear();

    await reconciliation(result).reconcileAll();
    await reconciliation(result).reconcileAll();

    expect(scheduler.scheduledPlans, hasLength(2));
    expect(
      scheduler.scheduledPlans.map((plan) => plan.notificationId),
      everyElement(reminderNotificationId('reminder-1')),
    );
  });

  test('reconcileAll skips scheduling when permission is denied', () async {
    final result = delivery();
    scheduler.permissionGranted = false;
    await result.repository.create(onceReminder());

    await reconciliation(result).reconcileAll();

    expect(scheduler.scheduledPlans, isEmpty);
    final persisted = await result.repository.getById('reminder-1');
    expect(persisted?.status, ReminderStatus.scheduled);
  });

  test('reconcileAll schedules again when permission is restored', () async {
    final result = delivery();
    scheduler.permissionGranted = false;
    await result.repository.create(onceReminder());
    await reconciliation(result).reconcileAll();
    expect(scheduler.scheduledPlans, isEmpty);

    scheduler.permissionGranted = true;
    await reconciliation(result).reconcileAll();
    expect(scheduler.scheduledPlans, hasLength(1));
  });

  test('reconcileAll isolates failures across multiple reminders', () async {
    final result = delivery();
    await result.repository.create(onceReminder());
    await result.repository.create(
      onceReminder().copyWith(
        id: 'reminder-2',
        taskId: 'task-1',
        scheduledAtUtc: DateTime.utc(2030, 6, 21, 9),
      ),
    );
    scheduler.failingSchedule = true;

    await reconciliation(result).reconcileAll();

    expect(scheduler.scheduledPlans, isEmpty);
  });

  test(
    'reconcileAll re-arms a recurring reminder from persisted intent',
    () async {
      final result = delivery();
      await result.repository.create(
        Reminder(
          id: 'reminder-1',
          taskId: 'task-1',
          scheduleType: ReminderScheduleType.daily,
          localTimeSeconds: 3600,
          interval: 1,
          startDate: DateTime.utc(2026, 1, 1),
          createdAt: DateTime.utc(2026, 6, 1, 12),
          updatedAt: DateTime.utc(2026, 6, 1, 12),
        ),
      );

      await reconciliation(result).reconcileAll();

      expect(scheduler.scheduledPlans, hasLength(1));
      expect(scheduler.scheduledPlans.single.repeatComponent, isNotNull);
    },
  );

  test(
    'reconcileAll re-arms a missing schedule from persisted intent',
    () async {
      final result = delivery();
      await result.repository.create(onceReminder());
      await reconciliation(result).reconcileAll();
      expect(scheduler.scheduledPlans, hasLength(1));

      await result.cancel(reminderNotificationId('reminder-1'));
      scheduler.scheduledPlans.clear();

      await reconciliation(result).reconcileAll();
      expect(scheduler.scheduledPlans, hasLength(1));
    },
  );

  group('startup and task lifecycle reconciliation', () {
    test('startup provider reconciles persisted reminders', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          reminderNotificationSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      addTearDown(container.dispose);

      await container.read(reminderActionsProvider).create(onceReminder());
      scheduler.scheduledPlans.clear();

      await container.read(reminderStartupReconciliationProvider.future);
      expect(scheduler.scheduledPlans, hasLength(1));
    });

    test(
      'task completion through task provider cancels the reconciled reminder',
      () async {
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            reminderNotificationSchedulerProvider.overrideWithValue(scheduler),
          ],
        );
        addTearDown(container.dispose);
        await container.read(taskProvider.future);
        await container.read(reminderActionsProvider).create(onceReminder());
        scheduler.scheduledPlans.clear();
        scheduler.cancelledNotificationIds.clear();

        await container
            .read(taskProvider.notifier)
            .setCompleted('task-1', true);
        final cancelledReminders = await container
            .read(reminderRepositoryProvider)
            .getAll();
        expect(cancelledReminders.single.status, ReminderStatus.cancelled);
        expect(scheduler.cancelledNotificationIds, hasLength(1));

        await container
            .read(reminderReconciliationProvider)
            .reconcileTask('task-1');
        expect(scheduler.cancelledNotificationIds, hasLength(2));
      },
    );

    test('task reopening reschedules the reconciled reminder', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          reminderNotificationSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      addTearDown(container.dispose);
      await container.read(taskProvider.future);
      await container.read(reminderActionsProvider).create(onceReminder());
      scheduler.scheduledPlans.clear();
      scheduler.cancelledNotificationIds.clear();

      await container.read(taskProvider.notifier).setCompleted('task-1', true);
      await container.read(taskProvider.notifier).setCompleted('task-1', false);

      final reminders = await container
          .read(reminderRepositoryProvider)
          .getAll();
      expect(reminders.single.status, ReminderStatus.scheduled);
      expect(scheduler.scheduledPlans, hasLength(1));
    });

    test('task deletion removes the reconciled reminder state', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          reminderNotificationSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      addTearDown(container.dispose);
      await container.read(taskProvider.future);
      await container.read(reminderActionsProvider).create(onceReminder());
      scheduler.scheduledPlans.clear();
      scheduler.cancelledNotificationIds.clear();

      await container.read(taskProvider.notifier).deleteTask('task-1');
      final reminders = await container
          .read(reminderRepositoryProvider)
          .getAll();
      expect(reminders, isEmpty);
      expect(scheduler.cancelledNotificationIds, isNotEmpty);
    });
  });
}
