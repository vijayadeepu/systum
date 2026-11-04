import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/models/task_sort.dart';
import 'package:systum/features/tasks/providers/task_provider.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  group('TaskSortNotifier', () {
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

    test('default sort is creation date descending', () async {
      final container = createContainer();
      final sort = container.read(taskSortProvider);
      expect(sort.mode, TaskSortMode.creationDate);
      expect(sort.order, TaskSortOrder.descending);
    });

    test('toggling the same mode reverses the order', () async {
      final container = createContainer();

      final notifier = container.read(taskSortProvider.notifier);
      expect(container.read(taskSortProvider).order, TaskSortOrder.descending);

      notifier.setMode(TaskSortMode.priority);
      expect(container.read(taskSortProvider).mode, TaskSortMode.priority);
      expect(container.read(taskSortProvider).order, TaskSortOrder.descending);

      // Toggle same mode -> reverses order
      notifier.setMode(TaskSortMode.priority);
      expect(container.read(taskSortProvider).order, TaskSortOrder.ascending);

      // Toggle again -> back to descending
      notifier.setMode(TaskSortMode.priority);
      expect(container.read(taskSortProvider).order, TaskSortOrder.descending);
    });

    test('switching to a new mode uses default descending order', () async {
      final container = createContainer();

      final notifier = container.read(taskSortProvider.notifier);
      notifier.setMode(TaskSortMode.alphabetical);
      expect(container.read(taskSortProvider).mode, TaskSortMode.alphabetical);
      expect(container.read(taskSortProvider).order, TaskSortOrder.descending);
    });

    test('setOrder changes only the order', () async {
      final container = createContainer();

      final notifier = container.read(taskSortProvider.notifier);
      notifier.setMode(TaskSortMode.priority);
      expect(container.read(taskSortProvider).order, TaskSortOrder.descending);

      notifier.setOrder(TaskSortOrder.ascending);
      expect(container.read(taskSortProvider).mode, TaskSortMode.priority);
      expect(container.read(taskSortProvider).order, TaskSortOrder.ascending);
    });

    test('sort provider refreshes task list when sort changes', () async {
      final container = createContainer();

      final repository = container.read(taskRepositoryProvider);
      await repository.insert(
        Task(
          id: 'task-1',
          title: 'Task one',
          description: null,
          completed: false,
          createdAt: DateTime(2026, 8, 1, 8),
          updatedAt: DateTime(2026, 8, 1, 8),
        ),
      );
      await repository.insert(
        Task(
          id: 'task-2',
          title: 'Task two',
          description: null,
          completed: false,
          createdAt: DateTime(2026, 8, 1, 9),
          updatedAt: DateTime(2026, 8, 1, 9),
        ),
      );

      // Initial: creation date descending -> task-2 first
      await container.read(taskProvider.future);
      expect(
        container.read(taskProvider).requireValue.map((t) => t.id).toList(),
        equals(['task-2', 'task-1']),
      );

      // Change sort to creation date ascending -> task-1 first
      container
          .read(taskSortProvider.notifier)
          .setMode(TaskSortMode.creationDate);
      container
          .read(taskSortProvider.notifier)
          .setOrder(TaskSortOrder.ascending);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        container.read(taskProvider).requireValue.map((t) => t.id).toList(),
        equals(['task-1', 'task-2']),
      );
    });
  });
}
