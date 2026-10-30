import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/goals/models/goal_date.dart';
import 'package:systum/features/goals/models/goal_lifecycle.dart';
import 'package:systum/features/goals/providers/goal_provider.dart';
import 'package:systum/features/goals/repository/goal_repository.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/providers/task_provider.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoalNotifier and derived providers', () {
    late SystumDatabase database;

    setUp(() {
      database = SystumDatabase.test(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    ProviderContainer createContainer({GoalRepository? repository}) {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          if (repository != null)
            goalRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> loadAll(ProviderContainer container) async {
      await container.read(goalProvider.future);
      await container.read(taskProvider.future);
    }

    test('initial load exposes an empty list and empty overviews', () async {
      final container = createContainer();
      await loadAll(container);

      expect(container.read(goalProvider).requireValue, isEmpty);
      expect(container.read(goalOverviewsProvider).requireValue, isEmpty);
    });

    test('initial load exposes a loading state before data', () async {
      final repository = _BlockingInitialGoalRepository(database);
      final container = createContainer(repository: repository);

      final initialLoad = container.read(goalProvider.future);
      await repository.initialLoadCaptured.future;

      expect(container.read(goalProvider), isA<AsyncLoading>());

      repository.releaseInitialLoad.complete();
      await repository.initialLoadSettled.future;
      await container.pump();
      await initialLoad;

      expect(container.read(goalProvider), isA<AsyncData>());
    });

    test('create persists a goal and refreshes state', () async {
      final container = createContainer();
      await loadAll(container);
      final goal = _goal(id: 'goal-1', title: 'Read one book');

      await container.read(goalProvider.notifier).createGoal(goal);

      expect(container.read(goalProvider).requireValue, [goal]);
      expect(await GoalRepository(database).getById(goal.id), goal);
      final overviews = container.read(goalOverviewsProvider).requireValue;
      expect(overviews.single.goal.id, goal.id);
      expect(overviews.single.progress.totalLeaves, 0);
      expect(overviews.single.status.isCompleted, isFalse);
    });

    test('update persists changed fields and keeps identity', () async {
      final goal = _goal(id: 'goal-1', title: 'Original');
      final container = createContainer();
      await loadAll(container);
      await container.read(goalProvider.notifier).createGoal(goal);

      await container
          .read(goalProvider.notifier)
          .updateGoal(
            goal.copyWith(
              title: 'Updated',
              description: Value('New description'),
              targetDate: Value(GoalDate.fromDateTime(DateTime(2026, 9, 1))),
              updatedAt: DateTime(2026, 8, 4),
            ),
          );

      final stored = await GoalRepository(database).getById(goal.id);
      expect(stored?.title, 'Updated');
      expect(stored?.description, 'New description');
      expect(stored?.targetDate, GoalDate.fromDateTime(DateTime(2026, 9, 1)));
      expect(stored?.createdAt, goal.createdAt);
      expect(container.read(goalProvider).requireValue.single.title, 'Updated');
    });

    test('missing goal produces a loaded null detail', () async {
      final container = createContainer();
      await loadAll(container);

      final detail = container.read(goalDetailProvider('missing-goal'));

      expect(detail.hasValue, isTrue);
      expect(detail.requireValue, isNull);
    });

    test(
      'detail exposes assigned tasks, hierarchy and leaf progress',
      () async {
        final goal = _goal(id: 'goal-1');
        await GoalRepository(database).create(goal);
        final tasks = TaskRepository(database);
        final parent = _task(id: 'parent');
        await tasks.insert(parent);
        await tasks.assignToGoal(parent.id, goal.id);
        await tasks.createSubtask(_task(id: 'child-1'), parent.id);
        await tasks.createSubtask(
          _task(id: 'child-2', completed: true),
          parent.id,
        );
        await tasks.insert(_task(id: 'standalone'));

        final container = createContainer();
        await loadAll(container);
        final detail = container
            .read(goalDetailProvider(goal.id))
            .requireValue!;

        expect(
          detail.tasks.map((task) => task.id),
          containsAll(['parent', 'child-1', 'child-2']),
        );
        expect(detail.hierarchy.roots.map((task) => task.id), ['parent']);
        expect(detail.hierarchy.childrenOf(parent.id).map((task) => task.id), [
          'child-1',
          'child-2',
        ]);
        expect(detail.progress.completedLeaves, 1);
        expect(detail.progress.totalLeaves, 2);
        expect(detail.remainingLeaves, 1);
        expect(detail.status.lifecycle, GoalLifecycle.active);
      },
    );

    test('assignment and unassignment refresh overview and detail', () async {
      final goal = _goal(id: 'goal-1');
      await GoalRepository(database).create(goal);
      await TaskRepository(database).insert(_task(id: 'task-1'));
      final container = createContainer();
      await loadAll(container);

      await container
          .read(taskProvider.notifier)
          .assignToGoal('task-1', goal.id);

      var overview = container.read(goalOverviewsProvider).requireValue.single;
      expect(overview.progress.totalLeaves, 1);
      expect(
        container
            .read(goalDetailProvider(goal.id))
            .requireValue!
            .tasks
            .single
            .id,
        'task-1',
      );

      await container.read(taskProvider.notifier).removeFromGoal('task-1');

      overview = container.read(goalOverviewsProvider).requireValue.single;
      expect(overview.progress.totalLeaves, 0);
      expect(
        container.read(goalDetailProvider(goal.id)).requireValue!.tasks,
        isEmpty,
      );
      expect(
        (await TaskRepository(database).getById('task-1'))?.goalId,
        isNull,
      );
    });

    test(
      'progress updates when an assigned leaf is completed and reopened',
      () async {
        final goal = _goal(id: 'goal-1');
        await GoalRepository(database).create(goal);
        final tasks = TaskRepository(database);
        await tasks.insert(_task(id: 'task-1'));
        await tasks.assignToGoal('task-1', goal.id);
        final container = createContainer();
        await loadAll(container);

        await container
            .read(taskProvider.notifier)
            .setCompleted('task-1', true);

        var overview = container
            .read(goalOverviewsProvider)
            .requireValue
            .single;
        expect(overview.progress.completedLeaves, 1);
        expect(overview.progress.totalLeaves, 1);
        expect(overview.status.isCompleted, isTrue);
        expect(
          container
              .read(goalDetailProvider(goal.id))
              .requireValue!
              .status
              .isCompleted,
          isTrue,
        );

        await container
            .read(taskProvider.notifier)
            .setCompleted('task-1', false);

        overview = container.read(goalOverviewsProvider).requireValue.single;
        expect(overview.progress.completedLeaves, 0);
        expect(overview.status.isCompleted, isFalse);
      },
    );

    test('deleting a goal preserves tasks and refreshes task state', () async {
      final goal = _goal(id: 'goal-1');
      await GoalRepository(database).create(goal);
      final tasks = TaskRepository(database);
      await tasks.insert(_task(id: 'parent'));
      await tasks.assignToGoal('parent', goal.id);
      await tasks.createSubtask(_task(id: 'child'), 'parent');
      final container = createContainer();
      await loadAll(container);

      await container.read(goalProvider.notifier).deleteGoal(goal.id);

      expect(container.read(goalProvider).requireValue, isEmpty);
      expect(await GoalRepository(database).getById(goal.id), isNull);
      final taskState = container.read(taskProvider).requireValue;
      expect(taskState, hasLength(2));
      expect(taskState.every((task) => task.goalId == null), isTrue);
      expect(
        taskState.firstWhere((task) => task.id == 'child').parentTaskId,
        'parent',
      );
      final storedChild = await tasks.getById('child');
      expect(storedChild?.goalId, isNull);
      expect(storedChild?.parentTaskId, 'parent');
    });

    test('failed create is reported and leaves state unchanged', () async {
      final container = createContainer(
        repository: _FailingCreateGoalRepository(database),
      );
      await loadAll(container);

      await expectLater(
        container.read(goalProvider.notifier).createGoal(_goal(id: 'goal-1')),
        throwsA(isA<StateError>()),
      );

      expect(container.read(goalProvider).requireValue, isEmpty);
      expect(await GoalRepository(database).getAll(), isEmpty);
    });

    test(
      'failed delete is reported and preserves goal and task state',
      () async {
        final goal = _goal(id: 'goal-1');
        await GoalRepository(database).create(goal);
        final tasks = TaskRepository(database);
        await tasks.insert(_task(id: 'task-1'));
        await tasks.assignToGoal('task-1', goal.id);
        final container = createContainer(
          repository: _FailingDeleteGoalRepository(database),
        );
        await loadAll(container);

        await expectLater(
          container.read(goalProvider.notifier).deleteGoal(goal.id),
          throwsA(isA<StateError>()),
        );

        expect(container.read(goalProvider).requireValue.single.id, goal.id);
        expect(await GoalRepository(database).getById(goal.id), isNotNull);
        expect((await tasks.getById('task-1'))?.goalId, goal.id);
        expect(
          container.read(taskProvider).requireValue.single.goalId,
          goal.id,
        );
      },
    );

    test('failed initial load surfaces as an error in derived state', () async {
      final container = createContainer(
        repository: _FailingInitialGoalRepository(database),
      );

      await expectLater(
        container.read(goalProvider.future),
        throwsA(isA<StateError>()),
      );

      expect(container.read(goalProvider), isA<AsyncError>());
      expect(container.read(goalOverviewsProvider), isA<AsyncError>());
    });

    test('a reload failure after a successful create is explicit', () async {
      final container = createContainer(
        repository: _FailingReloadGoalRepository(database),
      );
      await loadAll(container);

      await expectLater(
        container.read(goalProvider.notifier).createGoal(_goal(id: 'goal-1')),
        throwsA(isA<GoalMutationReloadException>()),
      );

      expect(container.read(goalProvider).requireValue, isEmpty);
      expect(await GoalRepository(database).getById('goal-1'), isNotNull);
    });

    test('an older initial load cannot overwrite a newer mutation', () async {
      final repository = _BlockingInitialGoalRepository(database);
      await GoalRepository(database).create(_goal(id: 'existing'));
      final container = createContainer(repository: repository);

      final initialLoad = container.read(goalProvider.future);
      await repository.initialLoadCaptured.future;

      await container.read(goalProvider.notifier).createGoal(_goal(id: 'new'));
      expect(
        container.read(goalProvider).requireValue.map((goal) => goal.id),
        contains('new'),
      );

      repository.releaseInitialLoad.complete();
      await repository.initialLoadSettled.future;
      await container.pump();
      await initialLoad;

      expect(
        container.read(goalProvider).requireValue.map((goal) => goal.id),
        containsAll(['existing', 'new']),
      );
    });
  });
}

GoalRow _goal({required String id, String title = 'Goal'}) {
  final now = DateTime(2026, 8, 1);
  return GoalRow(id: id, title: title, createdAt: now, updatedAt: now);
}

Task _task({required String id, bool completed = false}) {
  final now = DateTime(2026, 8, 1);
  return Task(
    id: id,
    title: 'Task $id',
    completed: completed,
    createdAt: now,
    updatedAt: now,
  );
}

class _FailingCreateGoalRepository extends GoalRepository {
  _FailingCreateGoalRepository(super._database);

  @override
  Future<void> create(GoalRow goal) async {
    throw StateError('simulated goal create failure');
  }
}

class _FailingInitialGoalRepository extends GoalRepository {
  _FailingInitialGoalRepository(super._database);

  @override
  Future<List<GoalRow>> getAll() async {
    throw StateError('simulated goal load failure');
  }
}

class _FailingDeleteGoalRepository extends GoalRepository {
  _FailingDeleteGoalRepository(super._database);

  @override
  Future<void> delete(String id) async {
    throw StateError('simulated goal delete failure');
  }
}

class _FailingReloadGoalRepository extends GoalRepository {
  _FailingReloadGoalRepository(super._database);

  bool _failNextReload = false;

  @override
  Future<void> create(GoalRow goal) async {
    await super.create(goal);
    _failNextReload = true;
  }

  @override
  Future<List<GoalRow>> getAll() async {
    if (_failNextReload) {
      _failNextReload = false;
      throw StateError('simulated goal reload failure');
    }
    return super.getAll();
  }
}

class _BlockingInitialGoalRepository extends GoalRepository {
  _BlockingInitialGoalRepository(super._database);

  final initialLoadCaptured = Completer<void>();
  final releaseInitialLoad = Completer<void>();
  final initialLoadSettled = Completer<void>();
  bool _isInitialLoad = true;

  @override
  Future<List<GoalRow>> getAll() async {
    if (!_isInitialLoad) {
      return super.getAll();
    }

    _isInitialLoad = false;
    final snapshot = await super.getAll();
    initialLoadCaptured.complete();
    try {
      await releaseInitialLoad.future;
      return snapshot;
    } finally {
      initialLoadSettled.complete();
    }
  }
}
