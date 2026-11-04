import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/models/task_filter.dart';
import 'package:systum/features/tasks/models/task_sort.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('TaskRepository sorting', () {
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
          title: 'Alpha task',
          description: null,
          completed: false,
          createdAt: DateTime(2026, 8, 1, 8),
          updatedAt: DateTime(2026, 8, 1, 8),
          dueDate: DateTime(2026, 8, 10),
          priority: 2,
          category: null,
        ),
      );
      await repository.insert(
        Task(
          id: 'task-2',
          title: 'Beta task',
          description: null,
          completed: true,
          createdAt: DateTime(2026, 8, 1, 9),
          updatedAt: DateTime(2026, 8, 2, 9),
          dueDate: DateTime(2026, 8, 5),
          priority: 4,
          category: null,
        ),
      );
      await repository.insert(
        Task(
          id: 'task-3',
          title: 'Gamma task',
          description: null,
          completed: false,
          createdAt: DateTime(2026, 8, 1, 10),
          updatedAt: DateTime(2026, 8, 1, 10),
          dueDate: null,
          priority: 1,
          category: null,
        ),
      );
      await repository.insert(
        Task(
          id: 'task-4',
          title: 'Delta task',
          description: null,
          completed: true,
          createdAt: DateTime(2026, 8, 1, 11),
          updatedAt: DateTime(2026, 8, 3, 11),
          dueDate: DateTime(2026, 8, 1),
          priority: 3,
          category: null,
        ),
      );
    }

    test('getAll uses default ordering when no sort is specified', () async {
      await insertTasks();

      final results = await repository.getAll();

      // Default ordering: completed ASC, priority DESC, createdAt DESC
      // completed=false: task-1 (p=2), task-3 (p=1) -> priority DESC: task-1, task-3
      // completed=true: task-2 (p=4), task-4 (p=3) -> priority DESC: task-2, task-4
      expect(results.map((t) => t.id).toList(), [
        'task-1',
        'task-3',
        'task-2',
        'task-4',
      ]);
    });

    test('sort by creation date ascending', () async {
      await insertTasks();

      final results = await repository.getAll(
        sort: const TaskSort(
          mode: TaskSortMode.creationDate,
          order: TaskSortOrder.ascending,
        ),
      );

      expect(
        results.map((t) => t.id).toList(),
        equals(['task-1', 'task-2', 'task-3', 'task-4']),
      );
    });

    test('sort by creation date descending', () async {
      await insertTasks();

      final results = await repository.getAll(
        sort: const TaskSort(
          mode: TaskSortMode.creationDate,
          order: TaskSortOrder.descending,
        ),
      );

      // task-4 (11:00), task-3 (10:00), task-2 (09:00), task-1 (08:00)
      expect(
        results.map((t) => t.id).toList(),
        equals(['task-4', 'task-3', 'task-2', 'task-1']),
      );
    });

    test('sort by updated date ascending', () async {
      await insertTasks();

      final results = await repository.getAll(
        sort: const TaskSort(
          mode: TaskSortMode.updatedDate,
          order: TaskSortOrder.ascending,
        ),
      );

      expect(
        results.map((t) => t.id).toList(),
        equals(['task-1', 'task-3', 'task-2', 'task-4']),
      );
    });

    test('sort by priority ascending', () async {
      await insertTasks();

      final results = await repository.getAll(
        sort: const TaskSort(
          mode: TaskSortMode.priority,
          order: TaskSortOrder.ascending,
        ),
      );

      // priority 1, 2, 3, 4
      expect(
        results.map((t) => t.id).toList(),
        equals(['task-3', 'task-1', 'task-4', 'task-2']),
      );
    });

    test('sort by priority descending', () async {
      await insertTasks();

      final results = await repository.getAll(
        sort: const TaskSort(
          mode: TaskSortMode.priority,
          order: TaskSortOrder.descending,
        ),
      );

      // priority 4, 3, 2, 1
      expect(
        results.map((t) => t.id).toList(),
        equals(['task-2', 'task-4', 'task-1', 'task-3']),
      );
    });

    test('sort alphabetical ascending', () async {
      await insertTasks();

      final results = await repository.getAll(
        sort: const TaskSort(
          mode: TaskSortMode.alphabetical,
          order: TaskSortOrder.ascending,
        ),
      );

      // Alpha (task-1), Beta (task-2), Delta (task-4), Gamma (task-3)
      expect(
        results.map((t) => t.id).toList(),
        equals(['task-1', 'task-2', 'task-4', 'task-3']),
      );
    });

    test('sort alphabetical descending', () async {
      await insertTasks();

      final results = await repository.getAll(
        sort: const TaskSort(
          mode: TaskSortMode.alphabetical,
          order: TaskSortOrder.descending,
        ),
      );

      // Gamma (task-3), Delta (task-4), Beta (task-2), Alpha (task-1)
      expect(
        results.map((t) => t.id).toList(),
        equals(['task-3', 'task-4', 'task-2', 'task-1']),
      );
    });

    test('sort by completion status ascending (active first)', () async {
      await insertTasks();

      final results = await repository.getAll(
        sort: const TaskSort(
          mode: TaskSortMode.completionStatus,
          order: TaskSortOrder.ascending,
        ),
      );

      // completed=false first (task-1, task-3), then completed=true (task-2, task-4)
      expect(
        results.take(2).map((t) => t.id).toSet(),
        equals({'task-1', 'task-3'}),
      );
      expect(
        results.skip(2).map((t) => t.id).toSet(),
        equals({'task-2', 'task-4'}),
      );
    });

    test('sort by due date ascending, nulls last', () async {
      await insertTasks();

      final results = await repository.getAll(
        sort: const TaskSort(
          mode: TaskSortMode.dueDate,
          order: TaskSortOrder.ascending,
        ),
      );

      // task-4 (Aug 1), task-2 (Aug 5), task-1 (Aug 10), task-3 (null last)
      expect(
        results.map((t) => t.id).toList(),
        equals(['task-4', 'task-2', 'task-1', 'task-3']),
      );
    });

    test('sort by due date descending, nulls last', () async {
      await insertTasks();

      final results = await repository.getAll(
        sort: const TaskSort(
          mode: TaskSortMode.dueDate,
          order: TaskSortOrder.descending,
        ),
      );

      // task-1 (Aug 10), task-2 (Aug 5), task-4 (Aug 1), task-3 (null last)
      expect(
        results.map((t) => t.id).toList(),
        equals(['task-1', 'task-2', 'task-4', 'task-3']),
      );
    });

    test('sorting is deterministic with tie-breaker', () async {
      await insertTasks();

      final results1 = await repository.getAll(
        sort: const TaskSort(
          mode: TaskSortMode.priority,
          order: TaskSortOrder.ascending,
        ),
      );
      final results2 = await repository.getAll(
        sort: const TaskSort(
          mode: TaskSortMode.priority,
          order: TaskSortOrder.ascending,
        ),
      );

      expect(
        results1.map((t) => t.id).toList(),
        equals(results2.map((t) => t.id).toList()),
      );
    });

    test('search respects sort order', () async {
      await insertTasks();

      final results = await repository.searchTasks(
        'task',
        sort: const TaskSort(
          mode: TaskSortMode.alphabetical,
          order: TaskSortOrder.ascending,
        ),
      );

      // Alpha (task-1), Beta (task-2), Delta (task-4), Gamma (task-3)
      expect(
        results.map((t) => t.id).toList(),
        equals(['task-1', 'task-2', 'task-4', 'task-3']),
      );
    });

    test('filter respects sort order', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(status: TaskStatusFilter.active),
        sort: const TaskSort(
          mode: TaskSortMode.priority,
          order: TaskSortOrder.descending,
        ),
      );

      // Active tasks: task-1 (priority=2), task-3 (priority=1)
      // Descending priority: task-1 first, then task-3
      expect(results.map((t) => t.id).toList(), equals(['task-1', 'task-3']));
    });
  });
}
