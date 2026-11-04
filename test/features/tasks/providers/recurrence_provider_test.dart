import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/models/task_recurrence.dart';
import 'package:systum/features/tasks/providers/recurrence_provider.dart';
import 'package:systum/features/tasks/providers/task_provider.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  late SystumDatabase database;

  setUp(() {
    database = SystumDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Task buildTask({String id = 'task-1', DateTime? dueDate}) {
    final now = DateTime.utc(2026, 1, 1);
    return Task(
      id: id,
      title: 'Repeat $id',
      createdAt: now,
      updatedAt: now,
      dueDate: dueDate ?? DateTime.utc(2026, 1, 1),
    );
  }

  test(
    'task provider creates a task with its first occurrences and refreshes state',
    () async {
      final container = createContainer();
      final task = buildTask(id: 'task-1');
      await container.read(taskProvider.future);

      await container
          .read(taskProvider.notifier)
          .createTaskWithRecurrence(
            task,
            RecurrenceDraft(
              recurrenceType: RecurrenceType.daily,
              startDate: DateTime.utc(2026, 1, 1),
              endDate: DateTime.utc(2026, 1, 4),
            ),
          );

      final tasks = container.read(taskProvider).requireValue;
      expect(tasks.map((task) => task.id), contains('task-1'));

      final rule = await container
          .read(taskProvider.notifier)
          .getRecurrenceForTask(task.id);
      expect(rule, isNotNull);
      expect(rule!.recurrenceType, RecurrenceType.daily);

      final occurrences = await TaskRepository(
        database,
      ).getOccurrencesForRule(rule.id);
      expect(occurrences, hasLength(4));
    },
  );

  test(
    'task provider creates goal-assigned recurring tasks without a standalone task',
    () async {
      final container = createContainer();
      final now = DateTime.utc(2026, 1, 1);
      await database
          .into(database.goals)
          .insert(
            GoalsCompanion.insert(
              id: 'goal-1',
              title: 'Goal',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await container
          .read(taskProvider.notifier)
          .createTaskInGoalWithRecurrence(
            buildTask(id: 'goal-task'),
            'goal-1',
            RecurrenceDraft(
              recurrenceType: RecurrenceType.weekly,
              startDate: DateTime.utc(2026, 1, 1),
            ),
          );

      final stored = await TaskRepository(database).getById('goal-task');
      expect(stored, isNotNull);
      expect(stored!.goalId, 'goal-1');
      final rules = await TaskRepository(database).getAllRecurrenceRules();
      expect(rules, hasLength(1));
      expect(rules.single.parentTaskId, 'goal-task');
    },
  );

  test('task provider stop recurrence keeps stored occurrences', () async {
    final repository = TaskRepository(database);
    final task = buildTask(id: 'task-1');
    final draft = RecurrenceDraft(
      recurrenceType: RecurrenceType.daily,
      startDate: DateTime.utc(2026, 1, 1),
      endDate: DateTime.utc(2026, 1, 4),
    );
    await repository.createTaskWithRecurrence(task, draft);
    final rule = (await repository.getAllRecurrenceRules()).single;

    final container = createContainer();
    await container.read(taskProvider.notifier).stopRecurrence(rule.id);

    expect(
      (await container
              .read(taskProvider.notifier)
              .getRecurrenceForTask(task.id))
          ?.isActive,
      isFalse,
    );
    expect(await repository.generateOccurrences(rule.id), 0);
    expect((await repository.getOccurrencesForRule(rule.id)).length, 4);
  });

  test('recurrence actions complete and delete one occurrence only', () async {
    final repository = TaskRepository(database);
    final task = buildTask(id: 'task-1');
    final draft = RecurrenceDraft(
      recurrenceType: RecurrenceType.daily,
      startDate: DateTime.utc(2026, 1, 1),
      endDate: DateTime.utc(2026, 1, 2),
    );
    await repository.createTaskWithRecurrence(task, draft);
    final rule = (await repository.getAllRecurrenceRules()).single;
    final occurrences = await repository.getOccurrencesForRule(rule.id);

    final container = createContainer();
    final actions = container.read(recurrenceActionsProvider);

    await actions.setOccurrenceCompleted(rule.id, occurrences.first.id, true);
    await actions.deleteOccurrence(rule.id, occurrences.last.id);

    final updated = await repository.getOccurrencesForRule(rule.id);
    expect(updated, hasLength(1));
    expect(updated.first.completed, isTrue);
    expect(updated.first.isDeleted, isFalse);
    expect(
      await repository.getOccurrencesForRule(rule.id, includeDeleted: true),
      hasLength(2),
    );
  });
}
