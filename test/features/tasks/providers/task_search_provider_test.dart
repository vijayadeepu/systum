import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/providers/task_provider.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  group('TaskSearchNotifier', () {
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

    Future<void> insertTasks(ProviderContainer container) async {
      final repository = container.read(taskRepositoryProvider);
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
    }

    Future<void> waitForDebounce() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    test('search returns matching tasks from persisted data', () async {
      final container = createContainer();
      await insertTasks(container);

      await container.read(taskSearchProvider.notifier).search('groceries');
      await waitForDebounce();

      final results = container.read(taskSearchProvider).requireValue;
      expect(results.map((t) => t.id), contains('task-1'));
      expect(results, hasLength(1));

      final stored = await container
          .read(taskRepositoryProvider)
          .getById('task-1');
      expect(stored, isNotNull);
    });

    test('empty query returns all tasks (no filter)', () async {
      final container = createContainer();
      await insertTasks(container);

      await container.read(taskSearchProvider.notifier).search('groceries');
      await waitForDebounce();
      expect(container.read(taskSearchProvider).requireValue, hasLength(1));

      await container.read(taskSearchProvider.notifier).search('');
      await waitForDebounce();
      expect(container.read(taskSearchProvider).requireValue, hasLength(3));
    });

    test('whitespace query returns all tasks', () async {
      final container = createContainer();
      await insertTasks(container);

      await container.read(taskSearchProvider.notifier).search('   ');
      await waitForDebounce();
      expect(container.read(taskSearchProvider).requireValue, hasLength(3));
    });

    test('case-insensitive search matches uppercase query', () async {
      final container = createContainer();
      await insertTasks(container);

      await container.read(taskSearchProvider.notifier).search('GROCERIES');
      await waitForDebounce();
      final results = container.read(taskSearchProvider).requireValue;
      expect(results.map((t) => t.id), contains('task-1'));
    });

    test('partial substring match works', () async {
      final container = createContainer();
      await insertTasks(container);

      await container.read(taskSearchProvider.notifier).search('quart');
      await waitForDebounce();
      final results = container.read(taskSearchProvider).requireValue;
      expect(results.map((t) => t.id), contains('task-2'));
    });

    test('no match returns empty list', () async {
      final container = createContainer();
      await insertTasks(container);

      await container.read(taskSearchProvider.notifier).search('nonexistent');
      await waitForDebounce();
      expect(container.read(taskSearchProvider).requireValue, isEmpty);
    });

    test('build returns all tasks by default', () async {
      final container = createContainer();
      await insertTasks(container);

      // Wait for build() to complete (it applies the default filter).
      await container.read(taskSearchProvider.future);

      // build() applies the default filter (all), so all tasks are available
      // immediately without any search call.
      final results = container.read(taskSearchProvider).requireValue;
      expect(results, hasLength(3));
    });

    test('rapid query changes only produce results for latest query', () async {
      final container = createContainer();
      await insertTasks(container);

      final notifier = container.read(taskSearchProvider.notifier);
      await notifier.search('groceries');
      await notifier.search('dentist');
      await notifier.search('report');

      // Allow debounce timers to complete.
      await waitForDebounce();

      final results = container.read(taskSearchProvider).requireValue;
      expect(results.map((t) => t.id), contains('task-2'));
      expect(results, hasLength(1));
    });

    test('cancelling pending timer keeps current state', () async {
      final container = createContainer();
      await insertTasks(container);

      // Wait for build() to complete (initial state is all tasks).
      await container.read(taskSearchProvider.future);
      expect(container.read(taskSearchProvider).requireValue, hasLength(3));

      final notifier = container.read(taskSearchProvider.notifier);
      await notifier.search('groceries');
      notifier.cancelPending();

      // State should still be the build() result (all tasks) because the
      // debounce timer was cancelled before it could write results.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(container.read(taskSearchProvider).requireValue, hasLength(3));
    });

    test('disposing container cancels pending debounce', () async {
      final container = createContainer();
      await insertTasks(container);

      container.read(taskSearchProvider.notifier).search('groceries');
      container.dispose();

      // Should not throw after disposal.
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
  });
}
