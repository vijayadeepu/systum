import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/reminders/models/reminder.dart';
import 'package:systum/features/reminders/repository/reminder_repository.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SystumDatabase database;
  late TaskRepository tasks;
  late ReminderRepository reminders;

  final createdAt = DateTime.utc(2026, 1, 1, 12);
  const unset = Object();

  setUp(() async {
    database = SystumDatabase.test(NativeDatabase.memory());
    tasks = TaskRepository(database);
    reminders = ReminderRepository(database);
    await tasks.insert(
      Task(
        id: 'task-1',
        title: 'Task',
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
  });

  tearDown(() => database.close());

  Reminder once({
    String id = 'reminder-1',
    String taskId = 'task-1',
    Object? scheduledAt = unset,
    ReminderStatus status = ReminderStatus.scheduled,
    ReminderCancellationReason? reason,
    DateTime? cancelledAt,
  }) {
    return Reminder(
      id: id,
      taskId: taskId,
      scheduleType: ReminderScheduleType.once,
      timezoneId: 'America/New_York',
      scheduledAtUtc: identical(scheduledAt, unset)
          ? DateTime.utc(2026, 1, 2, 9, 30)
          : scheduledAt as DateTime?,
      status: status,
      cancellationReason: reason,
      cancelledAtUtc: cancelledAt,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  Reminder recurring({String id = 'recurring-1'}) {
    return Reminder(
      id: id,
      taskId: 'task-1',
      scheduleType: ReminderScheduleType.weekly,
      timezoneId: 'America/New_York',
      localTimeSeconds: 8 * 3600 + 15 * 60,
      interval: 2,
      weekdays: 0x7f,
      startDate: DateTime.utc(2026, 2, 1),
      endDate: DateTime.utc(2026, 8, 1),
      maxOccurrences: 20,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  test('persists one-time reminders as UTC instants', () async {
    final reminder = once(scheduledAt: DateTime.utc(2026, 3, 8, 6, 59));
    await reminders.create(reminder);

    final stored = await reminders.getById(reminder.id);

    expect(stored, reminder);
    expect(stored!.scheduledAtUtc, DateTime.utc(2026, 3, 8, 6, 59));
    expect(stored.isScheduled, isTrue);
    final row = await database.select(database.reminders).getSingle();
    expect(
      row.scheduledAtUtcMs,
      DateTime.utc(2026, 3, 8, 6, 59).millisecondsSinceEpoch,
    );
  });

  test('persists recurring local-time and DST timezone metadata', () async {
    await reminders.create(recurring());

    final stored = await reminders.getById('recurring-1');

    expect(stored, isNotNull);
    expect(stored!.scheduleType, ReminderScheduleType.weekly);
    expect(stored.timezoneId, 'America/New_York');
    expect(stored.localTimeSeconds, 8 * 3600 + 15 * 60);
    expect(stored.interval, 2);
    expect(stored.weekdays, 0x7f);
    expect(stored.startDate, DateTime.utc(2026, 2, 1));
    expect(stored.endDate, DateTime.utc(2026, 8, 1));
    expect(stored.maxOccurrences, 20);
    expect(stored.validate(), isEmpty);
  });

  test('rejects reminders for missing tasks', () async {
    await expectLater(
      reminders.create(once(taskId: 'missing')),
      throwsA(isA<ReminderRelationshipException>()),
    );
    expect(await database.select(database.reminders).get(), isEmpty);
  });

  test('rejects new scheduled reminders for completed tasks', () async {
    await tasks.setCompleted('task-1', true);

    await expectLater(
      reminders.create(once()),
      throwsA(isA<ReminderRelationshipException>()),
    );
    expect(await database.select(database.reminders).get(), isEmpty);
  });

  test('validates schedule intent before writing', () async {
    await expectLater(
      reminders.create(once(scheduledAt: null)),
      throwsA(isA<ReminderValidationException>()),
    );
    expect(await database.select(database.reminders).get(), isEmpty);
  });

  test('updates an existing reminder without changing its stable ID', () async {
    await reminders.create(once());
    final updated = once(
      scheduledAt: DateTime.utc(2026, 1, 3, 10),
    ).copyWith(updatedAt: DateTime.utc(2026, 1, 1, 13));

    await reminders.update(updated);

    final stored = await reminders.getById('reminder-1');
    expect(stored!.id, 'reminder-1');
    expect(stored.scheduledAtUtc, DateTime.utc(2026, 1, 3, 10));
  });

  test('rejects updates for missing reminders and completed tasks', () async {
    await expectLater(
      reminders.update(once(id: 'missing')),
      throwsA(isA<ReminderRelationshipException>()),
    );

    await reminders.create(once());
    await tasks.setCompleted('task-1', true);

    await expectLater(
      reminders.update(
        once(
          scheduledAt: DateTime.utc(2026, 2, 1, 9),
        ).copyWith(updatedAt: DateTime.utc(2026, 1, 1, 13)),
      ),
      throwsA(isA<ReminderRelationshipException>()),
    );
  });

  test('cancels idempotently while retaining the row', () async {
    await reminders.create(once());
    final cancelledAt = DateTime.utc(2026, 1, 1, 13);

    await reminders.cancel('reminder-1', at: cancelledAt);
    await reminders.cancel('reminder-1', at: DateTime.utc(2026, 1, 1, 14));

    final stored = await reminders.getById('reminder-1');
    expect(stored!.status, ReminderStatus.cancelled);
    expect(stored.cancellationReason, ReminderCancellationReason.user);
    expect(stored.cancelledAtUtc, cancelledAt);
    expect(await database.select(database.reminders).get(), hasLength(1));
  });

  test('cancel rejects a missing reminder', () async {
    await expectLater(
      reminders.cancel('missing'),
      throwsA(isA<ReminderRelationshipException>()),
    );
  });

  test('delete removes the reminder and is idempotent', () async {
    await reminders.create(once());

    await reminders.delete('reminder-1');
    await reminders.delete('reminder-1');

    expect(await reminders.getById('reminder-1'), isNull);
  });

  test('returns reminders for one task in deterministic order', () async {
    await reminders.create(
      once(
        id: 'cancelled',
        status: ReminderStatus.cancelled,
        reason: ReminderCancellationReason.user,
        cancelledAt: createdAt,
      ),
    );
    await reminders.create(once(id: 'scheduled'));

    final result = await reminders.getForTask('task-1');

    expect(result.map((reminder) => reminder.id), ['scheduled', 'cancelled']);
    expect(await reminders.getForTask('missing'), isEmpty);
  });

  test(
    'task completion cancels scheduled reminders but preserves user cancel',
    () async {
      await reminders.create(once(id: 'scheduled'));
      await reminders.create(
        once(
          id: 'user-cancelled',
          status: ReminderStatus.cancelled,
          reason: ReminderCancellationReason.user,
          cancelledAt: createdAt,
        ),
      );

      await tasks.setCompleted('task-1', true);

      final scheduled = await reminders.getById('scheduled');
      expect(scheduled!.status, ReminderStatus.cancelled);
      expect(
        scheduled.cancellationReason,
        ReminderCancellationReason.taskCompleted,
      );
      expect(scheduled.cancelledAtUtc, isNotNull);

      final userCancelled = await reminders.getById('user-cancelled');
      expect(userCancelled!.status, ReminderStatus.cancelled);
      expect(userCancelled.cancellationReason, ReminderCancellationReason.user);
    },
  );

  test(
    'reopening a task reactivates only completion-cancelled reminders',
    () async {
      await reminders.create(once(id: 'scheduled'));
      await reminders.create(
        once(
          id: 'user-cancelled',
          status: ReminderStatus.cancelled,
          reason: ReminderCancellationReason.user,
          cancelledAt: createdAt,
        ),
      );
      await tasks.setCompleted('task-1', true);

      await tasks.setCompleted('task-1', false);

      final scheduled = await reminders.getById('scheduled');
      expect(scheduled!.status, ReminderStatus.scheduled);
      expect(scheduled.cancellationReason, isNull);
      expect(scheduled.cancelledAtUtc, isNull);

      final userCancelled = await reminders.getById('user-cancelled');
      expect(userCancelled!.status, ReminderStatus.cancelled);
      expect(userCancelled.cancellationReason, ReminderCancellationReason.user);
    },
  );

  test('task completion rolls back when the task does not exist', () async {
    await reminders.create(once());

    await expectLater(
      tasks.setCompleted('missing', true),
      throwsA(isA<Object>()),
    );

    final stored = await reminders.getById('reminder-1');
    expect(stored!.status, ReminderStatus.scheduled);
  });

  test('deleting a task cascades to its reminders', () async {
    await reminders.create(once());
    await reminders.create(recurring());

    await tasks.delete('task-1');

    expect(await database.select(database.reminders).get(), isEmpty);
  });
}
