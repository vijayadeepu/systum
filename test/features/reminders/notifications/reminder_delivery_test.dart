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
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/providers/task_provider.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';
import 'package:systum/features/reminders/providers/reminder_provider.dart';
import 'package:systum/features/reminders/providers/reminder_repository_provider.dart';
import 'package:systum/features/reminders/repository/reminder_repository.dart';
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
    scheduler = FakeReminderNotificationScheduler();
    await taskRepository.insert(
      Task(
        id: 'task-1',
        title: 'Task',
        createdAt: DateTime.utc(2026, 6, 1, 12),
        updatedAt: DateTime.utc(2026, 6, 1, 12),
      ),
    );
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

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        reminderNotificationSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

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

  test(
    'schedules a future one-time reminder after cancelling the old intent',
    () async {
      final result = delivery();

      await result.syncReminder(onceReminder());

      expect(scheduler.permissionGranted, isTrue);
      expect(scheduler.scheduledPlans, hasLength(1));
      expect(scheduler.scheduledPlans.single.taskId, 'task-1');
      expect(scheduler.scheduledPlans.single.repeatComponent, isNull);
      expect(scheduler.cancelledNotificationIds, hasLength(1));
    },
  );

  test(
    'does not schedule when permission is denied but keeps the row',
    () async {
      final result = delivery();
      scheduler.permissionGranted = false;

      await result.syncReminder(onceReminder());

      expect(scheduler.scheduledPlans, isEmpty);
      expect(scheduler.cancelledNotificationIds, hasLength(1));
    },
  );

  test('does not schedule for a cancelled reminder', () async {
    final result = delivery();
    final reminder = onceReminder().copyWith(
      status: ReminderStatus.cancelled,
      cancellationReason: ReminderCancellationReason.user,
      cancelledAtUtc: DateTime.utc(2026, 6, 2, 9),
    );

    await result.syncReminder(reminder);

    expect(scheduler.scheduledPlans, isEmpty);
    expect(scheduler.cancelledNotificationIds, hasLength(1));
  });

  test('leaves persisted state alone when scheduling fails', () async {
    final result = delivery();
    await result.repository.create(onceReminder());
    scheduler.failingSchedule = true;

    await result.syncReminder(onceReminder());

    expect(scheduler.scheduledPlans, isEmpty);
    expect(scheduler.cancelledNotificationIds, hasLength(1));
    final persisted = await result.repository.getById('reminder-1');
    expect(persisted?.status, ReminderStatus.scheduled);
  });

  test(
    'cancels a persisted reminder by deterministic notification id',
    () async {
      final result = delivery();

      await result.syncReminder(onceReminder());
      await result.cancelReminder('reminder-1');

      expect(scheduler.cancelledNotificationIds, hasLength(2));
      expect(
        scheduler.cancelledNotificationIds.last,
        reminderNotificationId('reminder-1'),
      );
    },
  );

  group('task lifecycle integration', () {
    test(
      'task completion cancels the scheduled reminder and reopening reschedules',
      () async {
        final container = createContainer();
        await container.read(taskProvider.future);
        await container.read(reminderActionsProvider).create(onceReminder());
        expect(scheduler.scheduledPlans, hasLength(1));
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
        scheduler.cancelledNotificationIds.clear();

        await container
            .read(taskProvider.notifier)
            .setCompleted('task-1', false);
        final reminders = await container
            .read(reminderRepositoryProvider)
            .getAll();
        expect(reminders.single.status, ReminderStatus.scheduled);
        expect(scheduler.scheduledPlans, hasLength(1));
      },
    );

    test('task deletion cancels the task reminder notification', () async {
      final container = createContainer();
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
