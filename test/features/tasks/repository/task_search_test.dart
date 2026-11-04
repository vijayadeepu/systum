import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('TaskRepository.searchTasks', () {
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
      await repository.insert(
        Task(
          id: 'task-1',
          title: 'Buy groceries',
          description: 'Milk, eggs, bread',
          createdAt: DateTime(2026, 8, 1, 8),
          updatedAt: DateTime(2026, 8, 1, 8),
        ),
      );
      await repository.insert(
        Task(
          id: 'task-2',
          title: 'Write report',
          description: 'Quarterly summary for the team meeting',
          createdAt: DateTime(2026, 8, 1, 9),
          updatedAt: DateTime(2026, 8, 1, 9),
        ),
      );
      await repository.insert(
        Task(
          id: 'task-3',
          title: 'Call dentist',
          description: null,
          createdAt: DateTime(2026, 8, 1, 10),
          updatedAt: DateTime(2026, 8, 1, 10),
        ),
      );
      await repository.insert(
        Task(
          id: 'task-4',
          title: 'Review report draft',
          description: 'Check the quarterly report',
          createdAt: DateTime(2026, 8, 1, 11),
          updatedAt: DateTime(2026, 8, 1, 11),
        ),
      );
    }

    test('returns all tasks when query is empty', () async {
      await insertTasks();

      final results = await repository.searchTasks('');

      expect(results, hasLength(4));
    });

    test('returns all tasks when query is whitespace only', () async {
      await insertTasks();

      final results = await repository.searchTasks('   ');

      expect(results, hasLength(4));
    });

    test('matches task title case-insensitively', () async {
      await insertTasks();

      final results = await repository.searchTasks('GROCERIES');

      expect(results.map((t) => t.id), contains('task-1'));
      expect(results, hasLength(1));
    });

    test('matches task title with partial substring', () async {
      await insertTasks();

      final results = await repository.searchTasks('gro');

      expect(results.map((t) => t.id), contains('task-1'));
      expect(results, hasLength(1));
    });

    test('matches task description case-insensitively', () async {
      await insertTasks();

      final results = await repository.searchTasks('EGGS');

      expect(results.map((t) => t.id), contains('task-1'));
      expect(results, hasLength(1));
    });

    test('matches task description with partial substring', () async {
      await insertTasks();

      final results = await repository.searchTasks('summary');

      expect(results.map((t) => t.id), contains('task-2'));
      expect(results, hasLength(1));
    });

    test('matches title and description across tasks', () async {
      await insertTasks();

      final results = await repository.searchTasks('report');

      expect(results.map((t) => t.id).toSet(), equals({'task-2', 'task-4'}));
      expect(results, hasLength(2));
    });

    test('returns empty list when no task matches', () async {
      await insertTasks();

      final results = await repository.searchTasks('nonexistent');

      expect(results, isEmpty);
    });

    test('preserves deterministic ordering across matching tasks', () async {
      await insertTasks();

      final results = await repository.searchTasks('report');

      // task-4 created at 11:00 comes before task-2 created at 9:00
      // because ordering is by createdAt DESC within the same priority.
      expect(results.map((t) => t.id).toList(), equals(['task-4', 'task-2']));
    });

    test('LIKE wildcard characters match as pattern operators', () async {
      await repository.insert(
        Task(
          id: 'task-percent',
          title: '100% done',
          description: null,
          createdAt: DateTime(2026, 8, 1, 8),
          updatedAt: DateTime(2026, 8, 1, 8),
        ),
      );

      // '%' in the query acts as a LIKE wildcard matching any sequence,
      // so '100%' matches '100% done'.
      final results = await repository.searchTasks('100%');

      expect(results.map((t) => t.id), contains('task-percent'));
      expect(results, hasLength(1));
    });

    test('search works with completed tasks', () async {
      await repository.insert(
        Task(
          id: 'completed-task',
          title: 'Finished work',
          description: null,
          completed: true,
          createdAt: DateTime(2026, 8, 1, 8),
          updatedAt: DateTime(2026, 8, 1, 8),
        ),
      );

      final results = await repository.searchTasks('finished');

      expect(results.map((t) => t.id), contains('completed-task'));
      expect(results.first.completed, isTrue);
    });

    test('search does not mutate stored tasks', () async {
      await insertTasks();
      final before = await repository.getById('task-1');

      await repository.searchTasks('groceries');
      final after = await repository.getById('task-1');

      expect(before, after);
    });

    test('search is case-insensitive for mixed-case queries', () async {
      await insertTasks();

      final lower = await repository.searchTasks('GROCERIES');
      final upper = await repository.searchTasks('groceries');
      final mixed = await repository.searchTasks('GrOcErIeS');

      expect(lower.map((t) => t.id), equals(upper.map((t) => t.id)));
      expect(lower.map((t) => t.id), equals(mixed.map((t) => t.id)));
    });
  });
}
