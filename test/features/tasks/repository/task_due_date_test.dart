import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/models/task_sort.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('TaskRepository.getTasksWithDueTimes', () {
    late SystumDatabase database;
    late TaskRepository repository;

    setUp(() {
      database = SystumDatabase.test(NativeDatabase.memory());
      repository = TaskRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> insertTasks() async {
      // Task with due date and due time (should be returned)
      await repository.insert(
        Task(
          id: 'task-with-time',
          title: 'Task with time',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
          dueDate: DateTime(2026, 8, 15),
          dueTime: 3600, // 1:00 AM
          dueTimezone: 'America/New_York',
          priority: 2,
        ),
      );
      // Task with due date only (no due time - should NOT be returned)
      await repository.insert(
        Task(
          id: 'task-date-only',
          title: 'Date only task',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
          dueDate: DateTime(2026, 8, 15),
          priority: 2,
        ),
      );
      // Task with due time only (no due date - should NOT be returned)
      await repository.insert(
        Task(
          id: 'task-time-only',
          title: 'Time only task',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
          dueTime: 3600,
          priority: 2,
        ),
      );
      // Completed task with due date and time (should NOT be returned)
      await repository.insert(
        Task(
          id: 'task-completed',
          title: 'Completed task',
          completed: true,
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
          dueDate: DateTime(2026, 8, 15),
          dueTime: 3600,
          priority: 2,
        ),
      );
      // Task without due date or time (should NOT be returned)
      await repository.insert(
        Task(
          id: 'task-no-date',
          title: 'No date task',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
          priority: 2,
        ),
      );
    }

    test(
      'returns tasks with both due date and due time that are not completed',
      () async {
        await insertTasks();

        final results = await repository.getTasksWithDueTimes();

        expect(results, hasLength(1));
        expect(results.first.id, 'task-with-time');
      },
    );

    test('excludes date-only tasks', () async {
      await insertTasks();

      final results = await repository.getTasksWithDueTimes();

      expect(results.map((t) => t.id), isNot(contains('task-date-only')));
    });

    test('excludes completed tasks', () async {
      await insertTasks();

      final results = await repository.getTasksWithDueTimes();

      expect(results.map((t) => t.id), isNot(contains('task-completed')));
    });

    test('excludes tasks without due date or time', () async {
      await insertTasks();

      final results = await repository.getTasksWithDueTimes();

      expect(results.map((t) => t.id), isNot(contains('task-no-date')));
    });

    test('excludes tasks with only due time', () async {
      await insertTasks();

      final results = await repository.getTasksWithDueTimes();

      expect(results.map((t) => t.id), isNot(contains('task-time-only')));
    });
  });

  group('TaskRepository migration v4 to v5', () {
    late SystumDatabase database;
    late TaskRepository repository;

    setUp(() {
      database = SystumDatabase.test(NativeDatabase.memory());
      repository = TaskRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('schema version is 10', () async {
      expect(database.schemaVersion, 10);
    });

    test('existing tasks preserve due date after migration', () async {
      // Create a task at schema v4 (simulated by inserting directly)
      await repository.insert(
        Task(
          id: 'existing-task',
          title: 'Existing task',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
          dueDate: DateTime(2026, 8, 15),
          priority: 2,
        ),
      );

      final stored = await repository.getById('existing-task');
      expect(stored, isNotNull);
      expect(stored?.dueDate, DateTime(2026, 8, 15));
      expect(stored?.dueTime, isNull);
      expect(stored?.dueTimezone, isNull);
    });

    test('new tasks can store due time and timezone', () async {
      await repository.insert(
        Task(
          id: 'new-task',
          title: 'New task',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
          dueDate: DateTime(2026, 8, 15),
          dueTime: 5400, // 1:30 AM
          dueTimezone: 'America/New_York',
          priority: 3,
        ),
      );

      final stored = await repository.getById('new-task');
      expect(stored, isNotNull);
      expect(stored?.dueTime, 5400);
      expect(stored?.dueTimezone, 'America/New_York');
    });

    test('task sorting by due date still works with due time', () async {
      await repository.insert(
        Task(
          id: 'task-later',
          title: 'Later task',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
          dueDate: DateTime(2026, 8, 20),
          dueTime: 7200, // 2:00 AM
          priority: 2,
        ),
      );
      await repository.insert(
        Task(
          id: 'task-earlier',
          title: 'Earlier task',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
          dueDate: DateTime(2026, 8, 12),
          dueTime: 3600, // 1:00 AM
          priority: 2,
        ),
      );

      final sorted = await repository.getAll(
        sort: const TaskSort(
          mode: TaskSortMode.dueDate,
          order: TaskSortOrder.ascending,
        ),
      );

      expect(
        sorted.map((t) => t.id).toList(),
        equals(['task-earlier', 'task-later']),
      );
    });
  });
}
