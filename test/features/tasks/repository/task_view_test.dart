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

  group('TaskRepository filtering with views', () {
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
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));

      // Task due today, active
      await repository.insert(
        Task(
          id: 'due-today-active',
          title: 'Due today active',
          completed: false,
          createdAt: today,
          updatedAt: today,
          dueDate: today,
        ),
      );
      // Task due today, completed
      await repository.insert(
        Task(
          id: 'due-today-completed',
          title: 'Due today completed',
          completed: true,
          createdAt: today,
          updatedAt: today,
          dueDate: today,
        ),
      );
      // Task due yesterday, active (overdue)
      await repository.insert(
        Task(
          id: 'due-yesterday-active',
          title: 'Due yesterday active',
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
      // Task due tomorrow, active (upcoming)
      await repository.insert(
        Task(
          id: 'due-tomorrow-active',
          title: 'Due tomorrow active',
          completed: false,
          createdAt: tomorrow,
          updatedAt: tomorrow,
          dueDate: tomorrow,
        ),
      );
      // Task without due date
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

    test('all view returns all tasks', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(),
        view: TaskView.all,
      );

      expect(results, hasLength(6));
    });

    test('today view returns tasks due today', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(),
        view: TaskView.today,
      );

      expect(
        results.map((t) => t.id).toSet(),
        equals({'due-today-active', 'due-today-completed'}),
      );
    });

    test('upcoming view returns active tasks due after today', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(),
        view: TaskView.upcoming,
      );

      expect(results.map((t) => t.id).toSet(), equals({'due-tomorrow-active'}));
    });

    test('upcoming view excludes completed tasks', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(),
        view: TaskView.upcoming,
      );

      expect(results.map((t) => t.id), isNot(contains('due-today-completed')));
    });

    test('overdue view returns incomplete tasks due before today', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(),
        view: TaskView.overdue,
      );

      expect(
        results.map((t) => t.id).toSet(),
        equals({'due-yesterday-active'}),
      );
    });

    test('overdue view excludes completed tasks', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(),
        view: TaskView.overdue,
      );

      expect(
        results.map((t) => t.id),
        isNot(contains('due-yesterday-completed')),
      );
    });

    test('completed view returns completed tasks', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(),
        view: TaskView.completed,
      );

      expect(
        results.map((t) => t.id).toSet(),
        equals({'due-today-completed', 'due-yesterday-completed'}),
      );
    });

    test('recently updated view sorts by updatedAt descending', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(),
        view: TaskView.recentlyUpdated,
        sort: const TaskSort(
          mode: TaskSortMode.updatedDate,
          order: TaskSortOrder.descending,
        ),
      );

      // due-today-completed (updatedAt=today) comes before due-yesterday-active
      // (updatedAt=yesterday), but due-tomorrow-active has updatedAt=tomorrow
      expect(results.first.id, 'due-tomorrow-active');
    });

    test('view intersects with status filter', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(status: TaskStatusFilter.active),
        view: TaskView.today,
      );

      expect(results.map((t) => t.id).toSet(), equals({'due-today-active'}));
    });

    test('view intersects with priority filter', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(priority: 5),
        view: TaskView.all,
      );

      expect(results, isEmpty);
    });

    test('view intersects with goal filter', () async {
      await insertTasks();

      final results = await repository.filterTasks(
        const TaskFilter(goalId: 'nonexistent-goal'),
        view: TaskView.all,
      );

      expect(results, isEmpty);
    });

    test('search respects view constraints', () async {
      await insertTasks();

      final results = await repository.searchAndFilter(
        'due',
        const TaskFilter(),
        view: TaskView.today,
      );

      expect(
        results.map((t) => t.id).toSet(),
        equals({'due-today-active', 'due-today-completed'}),
      );
    });

    test('search respects view constraints with no matches', () async {
      await insertTasks();

      final results = await repository.searchAndFilter(
        'due',
        const TaskFilter(),
        view: TaskView.overdue,
      );

      expect(
        results.map((t) => t.id).toSet(),
        equals({'due-yesterday-active'}),
      );
    });

    test('view does not mutate stored tasks', () async {
      await insertTasks();
      final before = await repository.getById('due-today-active');

      await repository.filterTasks(const TaskFilter(), view: TaskView.today);
      final after = await repository.getById('due-today-active');

      expect(before, after);
    });
  });

  group('TaskView model', () {
    test('taskViewLabel returns correct labels', () {
      expect(taskViewLabel(TaskView.all), 'All tasks');
      expect(taskViewLabel(TaskView.today), 'Today');
      expect(taskViewLabel(TaskView.upcoming), 'Upcoming');
      expect(taskViewLabel(TaskView.overdue), 'Overdue');
      expect(taskViewLabel(TaskView.completed), 'Completed');
      expect(taskViewLabel(TaskView.byGoal), 'By goal');
      expect(taskViewLabel(TaskView.byPriority), 'By priority');
      expect(taskViewLabel(TaskView.recentlyUpdated), 'Recently updated');
    });

    test('taskViewIsGrouped returns true for byGoal and byPriority', () {
      expect(taskViewIsGrouped(TaskView.byGoal), isTrue);
      expect(taskViewIsGrouped(TaskView.byPriority), isTrue);
      expect(taskViewIsGrouped(TaskView.all), isFalse);
      expect(taskViewIsGrouped(TaskView.today), isFalse);
      expect(taskViewIsGrouped(TaskView.upcoming), isFalse);
      expect(taskViewIsGrouped(TaskView.overdue), isFalse);
      expect(taskViewIsGrouped(TaskView.completed), isFalse);
      expect(taskViewIsGrouped(TaskView.recentlyUpdated), isFalse);
    });

    test('taskViewIcon returns non-null icons', () {
      expect(taskViewIcon(TaskView.all), isNotNull);
      expect(taskViewIcon(TaskView.today), isNotNull);
      expect(taskViewIcon(TaskView.byGoal), isNotNull);
    });
  });
}
