import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/reminders/models/reminder.dart';
import 'package:systum/features/reminders/notifications/reminder_delivery_provider.dart';
import 'package:systum/features/reminders/providers/reminder_provider.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/providers/task_provider.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';
import '../notifications/fake_reminder_notification_scheduler.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  late SystumDatabase database;

  setUp(() async {
    database = SystumDatabase.test(NativeDatabase.memory());
    final now = DateTime.utc(2026, 1, 1, 12);
    await TaskRepository(
      database,
    ).insert(Task(id: 'task-1', title: 'Task', createdAt: now, updatedAt: now));
  });

  tearDown(() => database.close());

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        reminderNotificationSchedulerProvider.overrideWithValue(
          FakeReminderNotificationScheduler(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Reminder once({String id = 'reminder-1'}) {
    final now = DateTime.utc(2026, 1, 1, 12);
    return Reminder(
      id: id,
      taskId: 'task-1',
      scheduleType: ReminderScheduleType.once,
      scheduledAtUtc: DateTime.utc(2026, 1, 2, 9),
      createdAt: now,
      updatedAt: now,
    );
  }

  test('loads task reminders through the repository provider', () async {
    final container = createContainer();

    expect(
      await container.read(taskRemindersProvider('task-1').future),
      isEmpty,
    );

    await container.read(reminderActionsProvider).create(once());

    final result = await container.read(taskRemindersProvider('task-1').future);
    expect(result.map((reminder) => reminder.id), ['reminder-1']);
    expect((await container.read(remindersProvider.future)), hasLength(1));
  });

  test('actions update, cancel and delete persisted reminders', () async {
    final container = createContainer();
    final actions = container.read(reminderActionsProvider);
    await actions.create(once());

    await actions.update(
      once().copyWith(
        scheduledAtUtc: DateTime.utc(2026, 1, 3, 9),
        updatedAt: DateTime.utc(2026, 1, 1, 13),
      ),
    );
    var reminders = await container.read(
      taskRemindersProvider('task-1').future,
    );
    expect(reminders.single.scheduledAtUtc, DateTime.utc(2026, 1, 3, 9));

    await actions.cancel('reminder-1', at: DateTime.utc(2026, 1, 1, 14));
    reminders = await container.read(taskRemindersProvider('task-1').future);
    expect(reminders.single.status, ReminderStatus.cancelled);

    await actions.delete('reminder-1');
    reminders = await container.read(taskRemindersProvider('task-1').future);
    expect(reminders, isEmpty);
  });

  test('task completion refreshes reminder state', () async {
    final container = createContainer();
    await container.read(reminderActionsProvider).create(once());
    await container.read(taskProvider.future);
    expect(
      (await container.read(
        taskRemindersProvider('task-1').future,
      )).single.status,
      ReminderStatus.scheduled,
    );

    await container.read(taskProvider.notifier).setCompleted('task-1', true);

    final reminders = await container.read(
      taskRemindersProvider('task-1').future,
    );
    expect(reminders.single.status, ReminderStatus.cancelled);
    expect(
      reminders.single.cancellationReason,
      ReminderCancellationReason.taskCompleted,
    );
    expect(
      (await container.read(remindersProvider.future)).single.status,
      ReminderStatus.cancelled,
    );
  });
}
