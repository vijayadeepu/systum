import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/goals/models/goal_date.dart';
import 'package:systum/features/goals/repository/goal_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('GoalRepository', () {
    late SystumDatabase database;
    late GoalRepository repository;

    setUp(() {
      database = SystumDatabase.test(NativeDatabase.memory());
      repository = GoalRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('getAll returns an empty list when there are no goals', () async {
      expect(await repository.getAll(), isEmpty);
    });

    test('create persists every goal field', () async {
      final goal = _buildGoal();

      await repository.create(goal);

      expect(await repository.getById(goal.id), equals(goal));
    });

    test('create preserves nullable goal fields', () async {
      final goal = GoalRow(
        id: 'nullable-goal',
        title: 'Goal without optional details',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      );

      await repository.create(goal);

      expect(await repository.getById(goal.id), equals(goal));
    });

    test('getAll returns all stored goals', () async {
      final firstGoal = _buildGoal(id: 'goal-1', title: 'First goal');
      final secondGoal = _buildGoal(id: 'goal-2', title: 'Second goal');
      await repository.create(firstGoal);
      await repository.create(secondGoal);

      final goals = await repository.getAll();

      expect(goals, containsAll([firstGoal, secondGoal]));
      expect(goals, hasLength(2));
    });

    test(
      'getAll returns newest goals first with a deterministic tiebreak',
      () async {
        final older = _buildGoal(
          id: 'older',
          title: 'Older',
          createdAt: DateTime(2026, 8, 1, 8),
          updatedAt: DateTime(2026, 8, 1, 8),
        );
        final newerB = _buildGoal(
          id: 'b-newer',
          title: 'Newer B',
          createdAt: DateTime(2026, 8, 2, 8),
          updatedAt: DateTime(2026, 8, 2, 8),
        );
        final newerA = _buildGoal(
          id: 'a-newer',
          title: 'Newer A',
          createdAt: DateTime(2026, 8, 2, 8),
          updatedAt: DateTime(2026, 8, 2, 8),
        );
        await repository.create(older);
        await repository.create(newerB);
        await repository.create(newerA);

        final goals = await repository.getAll();

        expect(goals.map((goal) => goal.id).toList(), [
          'a-newer',
          'b-newer',
          'older',
        ]);
      },
    );

    test('getById returns null when the goal does not exist', () async {
      expect(await repository.getById('missing-goal'), isNull);
    });

    test('update persists changed fields without changing identity', () async {
      final goal = _buildGoal();
      await repository.create(goal);
      final updatedGoal = goal.copyWith(
        title: 'Updated goal',
        description: const Value('Updated description'),
        targetDate: Value(GoalDate.fromDateTime(DateTime(2026, 9, 1))),
        updatedAt: DateTime(2026, 8, 2),
      );

      await repository.update(updatedGoal);

      expect(await repository.getById(goal.id), equals(updatedGoal));
    });

    test('update can clear nullable fields', () async {
      final goal = _buildGoal(
        description: 'Remove me',
        targetDate: DateTime(2026, 9, 1),
      );
      await repository.create(goal);

      await repository.update(
        goal.copyWith(
          description: const Value(null),
          targetDate: const Value(null),
          updatedAt: DateTime(2026, 8, 5),
        ),
      );

      final stored = await repository.getById(goal.id);
      expect(stored, isNotNull);
      expect(stored?.description, isNull);
      expect(stored?.targetDate, isNull);
      expect(stored?.title, goal.title);
      expect(stored?.createdAt, goal.createdAt);
      expect(stored?.updatedAt, DateTime(2026, 8, 5));
    });

    test(
      'update rejects a missing goal instead of silently succeeding',
      () async {
        await expectLater(
          repository.update(_buildGoal(id: 'missing-goal')),
          throwsA(
            isA<GoalNotFoundException>().having(
              (error) => error.id,
              'id',
              'missing-goal',
            ),
          ),
        );

        expect(await repository.getAll(), isEmpty);
      },
    );

    test('delete removes the goal', () async {
      final goal = _buildGoal();
      await repository.create(goal);

      await repository.delete(goal.id);

      expect(await repository.getById(goal.id), isNull);
    });

    test('deleting a goal unassigns tasks and preserves their data', () async {
      final goal = _buildGoal();
      await repository.create(goal);
      final taskCreatedAt = DateTime(2026, 8, 3, 10);
      final taskUpdatedAt = DateTime(2026, 8, 3, 11);
      await database
          .into(database.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'linked-task',
              title: 'Task linked to goal',
              description: const Value('Keep this task'),
              completed: const Value(true),
              createdAt: taskCreatedAt,
              updatedAt: taskUpdatedAt,
              dueDate: Value(DateTime(2026, 8, 10)),
              priority: const Value(4),
              category: const Value('Work'),
              goalId: Value(goal.id),
            ),
          );

      await repository.delete(goal.id);

      expect(await repository.getById(goal.id), isNull);
      final task = await (database.select(
        database.tasks,
      )..where((tasks) => tasks.id.equals('linked-task'))).getSingle();
      expect(task.id, 'linked-task');
      expect(task.title, 'Task linked to goal');
      expect(task.description, 'Keep this task');
      expect(task.completed, isTrue);
      expect(task.createdAt, taskCreatedAt);
      expect(task.updatedAt, taskUpdatedAt);
      expect(task.dueDate, DateTime(2026, 8, 10));
      expect(task.priority, 4);
      expect(task.category, 'Work');
      expect(task.goalId, isNull);
    });

    test('deleting a missing goal is a no-op', () async {
      await expectLater(repository.delete('missing-goal'), completes);

      expect(await repository.getAll(), isEmpty);
    });

    test(
      'deleting a goal preserves a parent, its subtask and their hierarchy',
      () async {
        final goal = _buildGoal();
        await repository.create(goal);
        final now = DateTime(2026, 8, 3, 10);
        await database
            .into(database.tasks)
            .insert(
              TasksCompanion.insert(
                id: 'parent',
                title: 'Parent task',
                createdAt: now,
                updatedAt: now,
                goalId: Value(goal.id),
              ),
            );
        await database
            .into(database.tasks)
            .insert(
              TasksCompanion.insert(
                id: 'child',
                title: 'Child task',
                createdAt: now,
                updatedAt: now,
                goalId: Value(goal.id),
                parentTaskId: const Value('parent'),
              ),
            );

        await repository.delete(goal.id);

        final parent = await (database.select(
          database.tasks,
        )..where((tasks) => tasks.id.equals('parent'))).getSingle();
        final child = await (database.select(
          database.tasks,
        )..where((tasks) => tasks.id.equals('child'))).getSingle();
        expect(parent.goalId, isNull);
        expect(child.goalId, isNull);
        expect(parent.parentTaskId, isNull);
        expect(child.parentTaskId, 'parent');
        expect(parent.title, 'Parent task');
        expect(child.title, 'Child task');
      },
    );

    test('create propagates duplicate ID failures', () async {
      final goal = _buildGoal();
      await repository.create(goal);

      await expectLater(
        repository.create(goal),
        throwsA(isA<SqliteException>()),
      );

      expect(await repository.getAll(), [goal]);
    });
  });

  test('goal fields persist after reopening a file-backed database', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'systum_goal_repository_test_',
    );
    SystumDatabase? fileDatabase;

    try {
      final databaseFile = File('${temporaryDirectory.path}/goals.sqlite');
      fileDatabase = SystumDatabase.test(NativeDatabase(databaseFile));
      final goal = _buildGoal(
        id: 'persistent-goal',
        title: 'Persist across connections',
        description: 'Verify file-backed persistence',
        targetDate: DateTime(2026, 9, 15, 12, 30),
        createdAt: DateTime(2026, 8, 1, 8, 15),
        updatedAt: DateTime(2026, 8, 2, 9, 45),
      );
      await GoalRepository(fileDatabase).create(goal);

      await fileDatabase.close();
      fileDatabase = null;

      fileDatabase = SystumDatabase.test(NativeDatabase(databaseFile));
      final storedGoal = await GoalRepository(fileDatabase).getById(goal.id);

      expect(storedGoal, equals(goal));
      final rawTargetDate = await fileDatabase
          .customSelect(
            "SELECT target_date FROM goals WHERE id = 'persistent-goal'",
          )
          .getSingle();
      expect(rawTargetDate.read<int>('target_date'), goal.targetDate!.epochDay);
    } finally {
      try {
        await fileDatabase?.close();
      } finally {
        await temporaryDirectory.delete(recursive: true);
      }
    }
  });
}

GoalRow _buildGoal({
  String id = 'goal-1',
  String title = 'Learn Flutter',
  String? description = 'Build a small app',
  DateTime? targetDate,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return GoalRow(
    id: id,
    title: title,
    description: description,
    targetDate: GoalDate.fromDateTime(targetDate ?? DateTime(2026, 9, 1)),
    createdAt: createdAt ?? DateTime(2026, 8, 1, 8),
    updatedAt: updatedAt ?? DateTime(2026, 8, 1, 8),
  );
}
