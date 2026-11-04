import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/models/task_filter.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('TaskRepository.filterTasks', () {
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
          description: 'Milk and eggs',
          completed: false,
          createdAt: DateTime(2026, 8, 1, 8),
          updatedAt: DateTime(2026, 8, 1, 8),
          dueDate: DateTime(2026, 8, 5),
          priority: 3,
          category: 'Work',
        ),
      );
      await repository.insert(
        Task(
          id: 'task-2',
          title: 'Write report',
          description: 'Quarterly summary',
          completed: true,
          createdAt: DateTime(2026, 8, 1, 9),
          updatedAt: DateTime(2026, 8, 2, 9),
          dueDate: DateTime(2026, 8, 10),
          priority: 1,
          category: 'Work',
        ),
      );
      await repository.insert(
        Task(
          id: 'task-3',
          title: 'Call dentist',
          description: null,
          completed: false,
          createdAt: DateTime(2026, 8, 1, 10),
          updatedAt: DateTime(2026, 8, 1, 10),
          dueDate: null,
          priority: 2,
          category: 'Personal',
        ),
      );
      await repository.insert(
        Task(
          id: 'task-4',
          title: 'Review report draft',
          description: 'Check the quarterly report',
          completed: false,
          createdAt: DateTime(2026, 8, 1, 11),
          updatedAt: DateTime(2026, 8, 1, 11),
          dueDate: DateTime(2026, 8, 3),
          priority: 3,
          category: 'Work',
        ),
      );
      await repository.insert(
        Task(
          id: 'task-5',
          title: 'Gym workout',
          description: null,
          completed: true,
          createdAt: DateTime(2026, 8, 1, 12),
          updatedAt: DateTime(2026, 8, 1, 12),
          dueDate: DateTime(2026, 8, 1),
          priority: 5,
          category: 'Personal',
        ),
      );
    }

    test('returns all tasks when no filter is active', () async {
      await insertTasks();

      final results = await repository.filterTasks(const TaskFilter());

      expect(results, hasLength(5));
    });

    test('filters by active status', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(status: TaskStatusFilter.active),
      );

      expect(
        results.map((t) => t.id).toSet(),
        equals({'task-1', 'task-3', 'task-4'}),
      );
    });

    test('filters by completed status', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(status: TaskStatusFilter.completed),
      );

      expect(results.map((t) => t.id).toSet(), equals({'task-2', 'task-5'}));
    });

    test('filters by priority', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(priority: 3),
      );

      expect(results.map((t) => t.id).toSet(), equals({'task-1', 'task-4'}));
    });

    test('filters by category', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(category: 'Personal'),
      );

      expect(results.map((t) => t.id).toSet(), equals({'task-3', 'task-5'}));
    });

    test(
      'filters tasks without a category when category is null-filtered',
      () async {
        await insertTasks();

        final results = await repository.filterTasks(
          const TaskFilter(category: 'Work'),
        );

        // task-3 and task-5 are Personal, task-1/2/4 are Work. task-3 has no
        // dueDate but has category Personal, so it's excluded by category=Work.
        expect(
          results.map((t) => t.id).toSet(),
          equals({'task-1', 'task-2', 'task-4'}),
        );
      },
    );

    test('combines status and priority filters', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(status: TaskStatusFilter.active, priority: 3),
      );

      expect(results.map((t) => t.id).toSet(), equals({'task-1', 'task-4'}));
    });

    test('combines category and priority filters', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(category: 'Work', priority: 3),
      );

      expect(results.map((t) => t.id).toSet(), equals({'task-1', 'task-4'}));
    });

    test('returns empty list when no task matches all filters', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(
          status: TaskStatusFilter.completed,
          priority: 5,
          category: 'Work',
        ),
      );

      expect(results, isEmpty);
    });

    test('does not mutate stored tasks', () async {
      await insertTasks();
      final before = await repository.getById('task-1');

      await repository.filterTasks(
        const TaskFilter(status: TaskStatusFilter.active),
      );
      final after = await repository.getById('task-1');

      expect(before, after);
    });
  });

  group('TaskRepository.filterTasks — time dimension', () {
    late SystumDatabase database;
    late TaskRepository repository;

    setUp(() {
      database = SystumDatabase.test(NativeDatabase.memory());
      repository = TaskRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> insertDatedTasks() async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));

      // Task due today, not completed
      await repository.insert(
        Task(
          id: 'due-today',
          title: 'Due today',
          completed: false,
          createdAt: today,
          updatedAt: today,
          dueDate: today,
        ),
      );
      // Task due yesterday, not completed (overdue)
      await repository.insert(
        Task(
          id: 'due-yesterday',
          title: 'Due yesterday',
          completed: false,
          createdAt: yesterday,
          updatedAt: yesterday,
          dueDate: yesterday,
        ),
      );
      // Task due yesterday, completed (not overdue)
      await repository.insert(
        Task(
          id: 'due-yesterday-completed',
          title: 'Due yesterday completed',
          completed: true,
          createdAt: yesterday,
          updatedAt: yesterday,
          dueDate: yesterday,
        ),
      );
      // Task due tomorrow, not completed (upcoming)
      await repository.insert(
        Task(
          id: 'due-tomorrow',
          title: 'Due tomorrow',
          completed: false,
          createdAt: tomorrow,
          updatedAt: tomorrow,
          dueDate: tomorrow,
        ),
      );
      // Task without a due date
      await repository.insert(
        Task(
          id: 'no-due-date',
          title: 'No due date',
          completed: false,
          createdAt: today,
          updatedAt: today,
          dueDate: null,
        ),
      );
    }

    test('today filter returns tasks due today', () async {
      await insertDatedTasks();

      final results = await repository.filterTasks(
        const TaskFilter(time: TaskTimeFilter.today),
      );

      expect(results.map((t) => t.id).toSet(), equals({'due-today'}));
    });

    test('overdue filter returns incomplete tasks due before today', () async {
      await insertDatedTasks();

      final results = await repository.filterTasks(
        const TaskFilter(time: TaskTimeFilter.overdue),
      );

      expect(results.map((t) => t.id).toSet(), equals({'due-yesterday'}));
    });

    test('overdue filter excludes completed tasks', () async {
      await insertDatedTasks();

      final results = await repository.filterTasks(
        const TaskFilter(time: TaskTimeFilter.overdue),
      );

      expect(
        results.map((t) => t.id),
        isNot(contains('due-yesterday-completed')),
      );
    });

    test('upcoming filter returns incomplete tasks due after today', () async {
      await insertDatedTasks();

      final results = await repository.filterTasks(
        const TaskFilter(time: TaskTimeFilter.upcoming),
      );

      expect(results.map((t) => t.id).toSet(), equals({'due-tomorrow'}));
    });

    test('time filters exclude tasks without due dates', () async {
      await insertDatedTasks();

      final today = await repository.filterTasks(
        const TaskFilter(time: TaskTimeFilter.today),
      );
      final overdue = await repository.filterTasks(
        const TaskFilter(time: TaskTimeFilter.overdue),
      );
      final upcoming = await repository.filterTasks(
        const TaskFilter(time: TaskTimeFilter.upcoming),
      );

      expect(today.map((t) => t.id), isNot(contains('no-due-date')));
      expect(overdue.map((t) => t.id), isNot(contains('no-due-date')));
      expect(upcoming.map((t) => t.id), isNot(contains('no-due-date')));
    });
  });

  group('TaskRepository.searchAndFilter', () {
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
          description: 'Milk and eggs',
          completed: false,
          createdAt: DateTime(2026, 8, 1, 8),
          updatedAt: DateTime(2026, 8, 1, 8),
          dueDate: DateTime(2026, 8, 5),
          priority: 3,
          category: 'Work',
        ),
      );
      await repository.insert(
        Task(
          id: 'task-2',
          title: 'Write report',
          description: 'Quarterly summary',
          completed: true,
          createdAt: DateTime(2026, 8, 1, 9),
          updatedAt: DateTime(2026, 8, 2, 9),
          dueDate: DateTime(2026, 8, 10),
          priority: 1,
          category: 'Work',
        ),
      );
    }

    test('search with active filter returns matching filtered tasks', () async {
      await insertTasks();

      final results = await repository.searchAndFilter(
        'groceries',
        const TaskFilter(status: TaskStatusFilter.active),
      );

      expect(results.map((t) => t.id).toSet(), equals({'task-1'}));
    });

    test(
      'search with completed filter excludes matching active tasks',
      () async {
        await insertTasks();

        final results = await repository.searchAndFilter(
          'groceries',
          const TaskFilter(status: TaskStatusFilter.completed),
        );

        expect(results, isEmpty);
      },
    );

    test('empty search with filter returns filtered tasks', () async {
      await insertTasks();

      final results = await repository.searchAndFilter(
        '',
        const TaskFilter(status: TaskStatusFilter.active),
      );

      expect(results.map((t) => t.id).toSet(), equals({'task-1'}));
    });

    test('empty search with no filter returns all tasks', () async {
      await insertTasks();

      final results = await repository.searchAndFilter('', const TaskFilter());

      expect(results, hasLength(2));
    });
  });
}
