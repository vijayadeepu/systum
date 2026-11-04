import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/models/task_sort.dart';
import 'package:systum/features/tasks/providers/task_provider.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  group('TaskNotifier', () {
    late SystumDatabase database;

    setUp(() {
      database = SystumDatabase.test(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    ProviderContainer createContainer({TaskRepository? repository}) {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          if (repository != null)
            taskRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('createSubtask persists the child and refreshes flat state', () async {
      final goal = await _insertGoal(database);
      final parent = _task(id: 'parent', title: 'Parent');
      final repository = TaskRepository(database);
      await repository.insert(parent);
      await repository.assignToGoal(parent.id, goal.id);
      final container = createContainer();
      await container.read(taskProvider.future);

      await container
          .read(taskProvider.notifier)
          .createSubtask(_task(id: 'child', title: 'Child'), parent.id);

      final tasks = container.read(taskProvider).requireValue;
      expect(tasks, hasLength(2));

      final storedChild = tasks.firstWhere((task) => task.id == 'child');
      expect(storedChild.parentTaskId, parent.id);
      expect(storedChild.goalId, goal.id);

      final persistedChild = await repository.getById('child');
      expect(persistedChild?.parentTaskId, parent.id);
      expect(persistedChild?.goalId, goal.id);
    });

    test(
      'completing and reopening a subtask updates state and storage',
      () async {
        final parent = _task(id: 'parent');
        final child = _task(id: 'child');
        final repository = TaskRepository(database);
        await repository.insert(parent);
        await repository.createSubtask(child, parent.id);
        final container = createContainer();
        await container.read(taskProvider.future);

        await container
            .read(taskProvider.notifier)
            .setCompleted(child.id, true);

        expect(
          container
              .read(taskProvider)
              .requireValue
              .firstWhere((task) => task.id == child.id)
              .completed,
          isTrue,
        );
        expect((await repository.getById(child.id))?.completed, isTrue);
        expect((await repository.getById(parent.id))?.completed, isFalse);

        await container
            .read(taskProvider.notifier)
            .setCompleted(child.id, false);

        expect(
          container
              .read(taskProvider)
              .requireValue
              .firstWhere((task) => task.id == child.id)
              .completed,
          isFalse,
        );
        expect((await repository.getById(child.id))?.completed, isFalse);
      },
    );

    test('deleting a subtask removes only that child from state', () async {
      final parent = _task(id: 'parent');
      final firstChild = _task(id: 'child-1');
      final secondChild = _task(id: 'child-2');
      final repository = TaskRepository(database);
      await repository.insert(parent);
      await repository.createSubtask(firstChild, parent.id);
      await repository.createSubtask(secondChild, parent.id);
      final container = createContainer();
      await container.read(taskProvider.future);

      await container.read(taskProvider.notifier).deleteTask(firstChild.id);

      final tasks = container.read(taskProvider).requireValue;
      expect(tasks.map((task) => task.id), containsAll(['parent', 'child-2']));
      expect(tasks.any((task) => task.id == firstChild.id), isFalse);
      expect((await repository.getById(firstChild.id)), isNull);
      expect(
        (await repository.getById(secondChild.id))?.parentTaskId,
        parent.id,
      );
    });

    test(
      'deleting a parent promotes its children in refreshed state',
      () async {
        final parent = _task(id: 'parent');
        final child = _task(id: 'child');
        final repository = TaskRepository(database);
        await repository.insert(parent);
        await repository.createSubtask(child, parent.id);
        final container = createContainer();
        await container.read(taskProvider.future);

        await container.read(taskProvider.notifier).deleteTask(parent.id);

        final tasks = container.read(taskProvider).requireValue;
        expect(tasks, hasLength(1));
        expect(tasks.single.id, child.id);
        expect(tasks.single.parentTaskId, isNull);
        expect((await repository.getById(parent.id)), isNull);
        expect((await repository.getById(child.id))?.parentTaskId, isNull);
      },
    );

    test('a failed subtask write leaves state and storage unchanged', () async {
      final parent = _task(id: 'parent');
      final repository = TaskRepository(database);
      await repository.insert(parent);
      final container = createContainer(
        repository: _FailingSubtaskRepository(database),
      );
      await container.read(taskProvider.future);

      await expectLater(
        container
            .read(taskProvider.notifier)
            .createSubtask(_task(id: 'child'), parent.id),
        throwsA(isA<StateError>()),
      );

      final tasks = container.read(taskProvider).requireValue;
      expect(tasks.single.id, parent.id);
      expect(await repository.getById('child'), isNull);
    });

    test('a failed reload is reported after a successful write', () async {
      final parent = _task(id: 'parent');
      final repository = _FailingReloadSubtaskRepository(database);
      await TaskRepository(database).insert(parent);
      final container = createContainer(repository: repository);
      await container.read(taskProvider.future);

      await expectLater(
        container
            .read(taskProvider.notifier)
            .createSubtask(_task(id: 'child'), parent.id),
        throwsA(isA<TaskMutationReloadException>()),
      );

      expect(await TaskRepository(database).getById('child'), isNotNull);
      expect(container.read(taskProvider).requireValue.single.id, parent.id);
    });

    test('an older initial load cannot overwrite a newer mutation', () async {
      final repository = _BlockingInitialLoadRepository(database);
      await TaskRepository(database).insert(_task(id: 'existing'));
      final container = createContainer(repository: repository);

      final initialLoad = container.read(taskProvider.future);
      await repository.initialLoadCaptured.future;

      await container.read(taskProvider.notifier).addTask(_task(id: 'new'));
      expect(
        container.read(taskProvider).requireValue.map((task) => task.id),
        contains('new'),
      );

      repository.releaseInitialLoad.complete();
      await repository.initialLoadSettled.future;
      await container.pump();
      await initialLoad;

      expect(
        container.read(taskProvider).requireValue.map((task) => task.id),
        containsAll(['existing', 'new']),
      );
    });

    test(
      'an older initial-load error cannot overwrite a newer mutation',
      () async {
        final repository = _BlockingInitialLoadRepository(
          database,
          failInitialLoad: true,
        );
        final container = createContainer(repository: repository);

        final initialLoad = container.read(taskProvider.future);
        await repository.initialLoadCaptured.future;

        await container.read(taskProvider.notifier).addTask(_task(id: 'new'));
        expect(
          container.read(taskProvider).requireValue.map((task) => task.id),
          contains('new'),
        );

        repository.releaseInitialLoad.complete();
        await repository.initialLoadSettled.future;
        expect(repository.initialLoadFailure, isA<StateError>());
        await container.pump();
        await initialLoad;

        expect(
          container.read(taskProvider).requireValue.map((task) => task.id),
          contains('new'),
        );
      },
    );
  });
}

Task _task({required String id, String? title}) {
  final now = DateTime(2026, 8, 1, 8);
  return Task(
    id: id,
    title: title ?? 'Task $id',
    createdAt: now,
    updatedAt: now,
  );
}

Future<GoalRow> _insertGoal(SystumDatabase database) async {
  final now = DateTime(2026, 8, 1);
  final goal = GoalRow(
    id: 'goal-1',
    title: 'Goal',
    createdAt: now,
    updatedAt: now,
  );
  await database.into(database.goals).insert(goal.toCompanion(true));
  return goal;
}

class _FailingSubtaskRepository extends TaskRepository {
  _FailingSubtaskRepository(super._database);

  @override
  Future<void> createSubtask(
    Task subtask,
    String parentTaskId, {
    String? goalId,
  }) async {
    throw StateError('simulated create failure');
  }
}

class _FailingReloadSubtaskRepository extends TaskRepository {
  _FailingReloadSubtaskRepository(super._database);

  bool _failNextReload = false;

  @override
  Future<void> createSubtask(
    Task subtask,
    String parentTaskId, {
    String? goalId,
  }) async {
    await super.createSubtask(subtask, parentTaskId, goalId: goalId);
    _failNextReload = true;
  }

  @override
  Future<List<TaskRow>> getAll({TaskSort? sort}) async {
    if (_failNextReload) {
      _failNextReload = false;
      throw StateError('simulated reload failure');
    }
    return super.getAll(sort: sort);
  }
}

class _BlockingInitialLoadRepository extends TaskRepository {
  _BlockingInitialLoadRepository(
    super._database, {
    this.failInitialLoad = false,
  });

  final bool failInitialLoad;
  final initialLoadCaptured = Completer<void>();
  final releaseInitialLoad = Completer<void>();
  final initialLoadSettled = Completer<void>();
  Object? initialLoadFailure;
  bool _isInitialLoad = true;

  @override
  Future<List<TaskRow>> getAll({TaskSort? sort}) async {
    if (!_isInitialLoad) {
      return super.getAll(sort: sort);
    }

    _isInitialLoad = false;
    final snapshot = await super.getAll(sort: sort);
    initialLoadCaptured.complete();
    try {
      await releaseInitialLoad.future;
      if (failInitialLoad) {
        throw StateError('simulated initial-load failure');
      }
      return snapshot;
    } catch (error, stackTrace) {
      initialLoadFailure = error;
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      initialLoadSettled.complete();
    }
  }
}
