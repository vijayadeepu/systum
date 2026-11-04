import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/models/task_filter.dart';
import 'package:systum/features/tasks/models/task_sort.dart';
import 'package:systum/features/tasks/providers/task_provider.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  group('TaskViewNotifier', () {
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

    test('default view is all', () async {
      final container = createContainer();
      expect(container.read(taskViewProvider), TaskView.all);
    });

    test('setView changes the active view', () async {
      final container = createContainer();

      final notifier = container.read(taskViewProvider.notifier);
      notifier.setView(TaskView.today);
      expect(container.read(taskViewProvider), TaskView.today);

      notifier.setView(TaskView.upcoming);
      expect(container.read(taskViewProvider), TaskView.upcoming);

      notifier.setView(TaskView.overdue);
      expect(container.read(taskViewProvider), TaskView.overdue);

      notifier.setView(TaskView.completed);
      expect(container.read(taskViewProvider), TaskView.completed);

      notifier.setView(TaskView.byGoal);
      expect(container.read(taskViewProvider), TaskView.byGoal);

      notifier.setView(TaskView.byPriority);
      expect(container.read(taskViewProvider), TaskView.byPriority);

      notifier.setView(TaskView.recentlyUpdated);
      expect(container.read(taskViewProvider), TaskView.recentlyUpdated);

      notifier.setView(TaskView.all);
      expect(container.read(taskViewProvider), TaskView.all);
    });

    test('search results respect view changes', () async {
      final container = createContainer();

      final repository = container.read(taskRepositoryProvider);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await repository.insert(
        Task(
          id: 'task-today',
          title: 'Task today',
          completed: false,
          createdAt: today,
          updatedAt: today,
          dueDate: today,
        ),
      );
      await repository.insert(
        Task(
          id: 'task-tomorrow',
          title: 'Task tomorrow',
          completed: false,
          createdAt: today,
          updatedAt: today,
          dueDate: today.add(const Duration(days: 1)),
        ),
      );

      // Wait for build() to complete
      await container.read(taskSearchProvider.future);

      // Default view is all -> both tasks
      expect(
        container
            .read(taskSearchProvider)
            .requireValue
            .map((t) => t.id)
            .toSet(),
        equals({'task-today', 'task-tomorrow'}),
      );

      // Switch to today view -> only task-today
      container.read(taskViewProvider.notifier).setView(TaskView.today);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(
        container
            .read(taskSearchProvider)
            .requireValue
            .map((t) => t.id)
            .toSet(),
        equals({'task-today'}),
      );

      // Switch to upcoming view -> only task-tomorrow
      container.read(taskViewProvider.notifier).setView(TaskView.upcoming);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(
        container
            .read(taskSearchProvider)
            .requireValue
            .map((t) => t.id)
            .toSet(),
        equals({'task-tomorrow'}),
      );
    });

    test('view changes do not clear filters', () async {
      final container = createContainer();

      final repository = container.read(taskRepositoryProvider);
      await repository.insert(
        Task(
          id: 'task-1',
          title: 'Task one',
          completed: true,
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
        ),
      );
      await repository.insert(
        Task(
          id: 'task-2',
          title: 'Task two',
          completed: false,
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
        ),
      );

      // Wait for build() to complete
      await container.read(taskSearchProvider.future);

      // Apply completed filter
      container
          .read(taskFilterProvider.notifier)
          .updateFilter(status: TaskStatusFilter.completed);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(
        container
            .read(taskSearchProvider)
            .requireValue
            .map((t) => t.id)
            .toSet(),
        equals({'task-1'}),
      );

      // Switch view to today (no tasks due today) -> still empty due to filter
      container.read(taskViewProvider.notifier).setView(TaskView.today);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(container.read(taskSearchProvider).requireValue, isEmpty);

      // Clear view back to all -> filter still applies
      container.read(taskViewProvider.notifier).setView(TaskView.all);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(
        container
            .read(taskSearchProvider)
            .requireValue
            .map((t) => t.id)
            .toSet(),
        equals({'task-1'}),
      );
    });
  });
}
