import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/goals/models/goal_progress.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('TaskRepository', () {
    late SystumDatabase database;
    late TaskRepository repository;

    setUp(() {
      database = SystumDatabase.test(NativeDatabase.memory());
      repository = TaskRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('getAll returns empty list when database has no tasks', () async {
      final tasks = await repository.getAll();

      expect(tasks, isEmpty);
    });

    test('insert stores a task with matching values', () async {
      final task = _buildTask();

      await repository.insert(task);
      final storedTask = await repository.getById(task.id);

      expect(storedTask, isNotNull);
      expect(Task.fromRow(storedTask!), equals(task));
    });

    test('getById returns the matching task when it exists', () async {
      final task = _buildTask();
      await repository.insert(task);

      final storedTask = await repository.getById(task.id);

      expect(storedTask?.id, task.id);
      expect(storedTask?.title, task.title);
    });

    test('getById returns null when the task does not exist', () async {
      final storedTask = await repository.getById('missing-task');

      expect(storedTask, isNull);
    });

    test(
      'getAll orders tasks by completed, priority, then createdAt',
      () async {
        final olderHighPriority = _buildTask(
          id: 'older-high-priority',
          priority: 3,
          createdAt: DateTime(2026, 8, 1, 9),
          updatedAt: DateTime(2026, 8, 1, 9),
        );
        final newerHighPriority = _buildTask(
          id: 'newer-high-priority',
          priority: 3,
          createdAt: DateTime(2026, 8, 1, 10),
          updatedAt: DateTime(2026, 8, 1, 10),
        );
        final lowerPriority = _buildTask(
          id: 'lower-priority',
          priority: 1,
          createdAt: DateTime(2026, 8, 1, 11),
          updatedAt: DateTime(2026, 8, 1, 11),
        );
        final completedTask = _buildTask(
          id: 'completed-task',
          completed: true,
          priority: 5,
          createdAt: DateTime(2026, 8, 1, 12),
          updatedAt: DateTime(2026, 8, 1, 12),
        );

        await repository.insert(olderHighPriority);
        await repository.insert(lowerPriority);
        await repository.insert(completedTask);
        await repository.insert(newerHighPriority);

        final tasks = await repository.getAll();

        expect(tasks.map((task) => task.id).toList(), [
          'newer-high-priority',
          'older-high-priority',
          'lower-priority',
          'completed-task',
        ]);
      },
    );

    test('update persists a changed title', () async {
      final task = _buildTask(title: 'Original title');
      await repository.insert(task);

      await repository.update(task.copyWith(title: 'Updated title'));
      final updatedTask = await repository.getById(task.id);

      expect(updatedTask?.title, 'Updated title');
    });

    test(
      'update persists editable fields and preserves task identity',
      () async {
        final task = _buildTask(
          completed: true,
          dueDate: DateTime(2026, 8, 2),
          priority: 2,
        );
        await repository.insert(task);
        final updatedAt = DateTime(2026, 8, 3);

        await repository.update(
          task.copyWith(
            title: 'Updated title',
            description: 'Updated description',
            dueDate: DateTime(2026, 8, 4),
            priority: 3,
            updatedAt: updatedAt,
          ),
        );
        final updatedTask = Task.fromRow((await repository.getById(task.id))!);

        expect(updatedTask.id, task.id);
        expect(updatedTask.createdAt, task.createdAt);
        expect(updatedTask.completed, task.completed);
        expect(updatedTask.category, task.category);
        expect(updatedTask.title, 'Updated title');
        expect(updatedTask.description, 'Updated description');
        expect(updatedTask.dueDate, DateTime(2026, 8, 4));
        expect(updatedTask.priority, 3);
        expect(updatedTask.updatedAt, updatedAt);
      },
    );

    test('update persists a changed completion status', () async {
      final task = _buildTask(completed: false);
      await repository.insert(task);

      await repository.update(task.copyWith(completed: true));
      final updatedTask = await repository.getById(task.id);

      expect(updatedTask?.completed, isTrue);
    });

    test('delete removes an existing task', () async {
      final task = _buildTask();
      await repository.insert(task);

      await repository.delete(task.id);
      final deletedTask = await repository.getById(task.id);

      expect(deletedTask, isNull);
    });

    test('setCompleted persists both completion transitions', () async {
      final task = _buildTask(completed: false);
      await repository.insert(task);

      await repository.setCompleted(task.id, true);
      expect((await repository.getById(task.id))?.completed, isTrue);

      await repository.setCompleted(task.id, false);
      expect((await repository.getById(task.id))?.completed, isFalse);
    });

    test(
      'assignToGoal links a standalone task without changing its fields',
      () async {
        final goal = await _insertGoal(database, id: 'goal-1');
        final task = _buildTask(
          id: 'assigned-task',
          title: 'Assigned task',
          description: 'Keep every field',
          completed: true,
          createdAt: DateTime(2026, 8, 1, 8),
          updatedAt: DateTime(2026, 8, 2, 9),
          dueDate: DateTime(2026, 8, 10),
          priority: 4,
          category: 'Work',
        );
        await repository.insert(task);

        await repository.assignToGoal(task.id, goal.id);

        final storedTask = (await repository.getById(task.id))!;
        expect(storedTask.goalId, goal.id);
        expect(storedTask.id, task.id);
        expect(storedTask.title, task.title);
        expect(storedTask.description, task.description);
        expect(storedTask.completed, task.completed);
        expect(storedTask.createdAt, task.createdAt);
        expect(storedTask.updatedAt, task.updatedAt);
        expect(storedTask.dueDate, task.dueDate);
        expect(storedTask.priority, task.priority);
        expect(storedTask.category, task.category);
        expect(storedTask.parentTaskId, isNull);
      },
    );

    test('removeFromGoal clears the goal without deleting the task', () async {
      final goal = await _insertGoal(database, id: 'goal-1');
      final task = _buildTask(dueDate: DateTime(2026, 8, 10), priority: 4);
      await repository.insert(task);
      await repository.assignToGoal(task.id, goal.id);

      await repository.removeFromGoal(task.id);

      final storedTask = await repository.getById(task.id);
      expect(storedTask, isNotNull);
      expect(storedTask?.goalId, isNull);
      expect(storedTask?.parentTaskId, isNull);
      expect(Task.fromRow(storedTask!), equals(task));
      expect(await repository.getAll(), hasLength(1));
    });

    test(
      'assignToGoal updates all direct subtasks and preserves their fields',
      () async {
        final firstGoal = await _insertGoal(database, id: 'goal-1');
        final secondGoal = await _insertGoal(database, id: 'goal-2');
        final parent = _buildTask(
          id: 'parent-task',
          title: 'Parent task',
          description: 'Parent description',
          completed: true,
          dueDate: DateTime(2026, 8, 10),
          priority: 4,
          category: 'Work',
        );
        await repository.insert(parent);
        await repository.assignToGoal(parent.id, firstGoal.id);
        final firstChild = _buildTask(
          id: 'child-1',
          title: 'First child',
          description: 'First description',
          completed: true,
          dueDate: DateTime(2026, 8, 11),
          priority: 3,
          category: 'Home',
        );
        final secondChild = _buildTask(
          id: 'child-2',
          title: 'Second child',
          description: null,
          completed: false,
          dueDate: null,
          priority: 1,
          category: null,
        );
        await repository.createSubtask(firstChild, parent.id);
        await repository.createSubtask(secondChild, parent.id);

        await repository.assignToGoal(parent.id, secondGoal.id);

        final storedParent = (await repository.getById(parent.id))!;
        final storedFirstChild = (await repository.getById(firstChild.id))!;
        final storedSecondChild = (await repository.getById(secondChild.id))!;
        expect(storedParent.goalId, secondGoal.id);
        expect(storedFirstChild.goalId, secondGoal.id);
        expect(storedSecondChild.goalId, secondGoal.id);
        expect(Task.fromRow(storedParent), equals(parent));
        expect(Task.fromRow(storedFirstChild), equals(firstChild));
        expect(Task.fromRow(storedSecondChild), equals(secondChild));
        expect(await repository.getByGoalId(firstGoal.id), isEmpty);
        expect(
          (await repository.getByGoalId(secondGoal.id)).map((task) => task.id),
          containsAll([parent.id, firstChild.id, secondChild.id]),
        );
      },
    );

    test(
      'removeFromGoal clears the goal from the parent and all direct subtasks',
      () async {
        final goal = await _insertGoal(database, id: 'goal-1');
        final parent = _buildTask(id: 'parent-task');
        await repository.insert(parent);
        await repository.assignToGoal(parent.id, goal.id);
        final firstChild = _buildTask(
          id: 'child-1',
          title: 'First child',
          completed: true,
          dueDate: DateTime(2026, 8, 11),
          priority: 3,
          category: 'Home',
        );
        final secondChild = _buildTask(
          id: 'child-2',
          title: 'Second child',
          description: null,
          dueDate: null,
          priority: 1,
          category: null,
        );
        await repository.createSubtask(firstChild, parent.id);
        await repository.createSubtask(secondChild, parent.id);

        await repository.removeFromGoal(parent.id);

        final storedParent = (await repository.getById(parent.id))!;
        final storedFirstChild = (await repository.getById(firstChild.id))!;
        final storedSecondChild = (await repository.getById(secondChild.id))!;
        expect(storedParent.goalId, isNull);
        expect(storedFirstChild.goalId, isNull);
        expect(storedSecondChild.goalId, isNull);
        expect(Task.fromRow(storedParent), equals(parent));
        expect(Task.fromRow(storedFirstChild), equals(firstChild));
        expect(Task.fromRow(storedSecondChild), equals(secondChild));
        expect(await repository.getByGoalId(goal.id), isEmpty);
      },
    );

    test(
      'assignToGoal rejects a missing goal without changing subtasks',
      () async {
        final originalGoal = await _insertGoal(database, id: 'goal-1');
        final parent = _buildTask(id: 'parent-task');
        await repository.insert(parent);
        await repository.assignToGoal(parent.id, originalGoal.id);
        final child = _buildTask(id: 'child-task');
        await repository.createSubtask(child, parent.id);

        await expectLater(
          repository.assignToGoal(parent.id, 'missing-goal'),
          throwsA(
            isA<TaskRelationshipException>().having(
              (error) => error.message,
              'message',
              contains('missing-goal'),
            ),
          ),
        );

        expect((await repository.getById(parent.id))?.goalId, originalGoal.id);
        expect((await repository.getById(child.id))?.goalId, originalGoal.id);
      },
    );

    test(
      'assignToGoal rolls back parent and sibling goals when a child update fails',
      () async {
        final firstGoal = await _insertGoal(database, id: 'goal-1');
        final secondGoal = await _insertGoal(database, id: 'goal-2');
        final parent = _buildTask(id: 'parent-task');
        await repository.insert(parent);
        await repository.assignToGoal(parent.id, firstGoal.id);
        final firstChild = _buildTask(id: 'child-1');
        final secondChild = _buildTask(id: 'child-2');
        await repository.createSubtask(firstChild, parent.id);
        await repository.createSubtask(secondChild, parent.id);
        await database.customStatement('''
          CREATE TABLE goal_update_attempts (id INTEGER PRIMARY KEY AUTOINCREMENT);
          CREATE TRIGGER fail_second_child_goal_assignment
          BEFORE UPDATE OF goal_id ON tasks
          WHEN OLD.parent_task_id IS NOT NULL
          BEGIN
            INSERT INTO goal_update_attempts (id) VALUES (NULL);
            SELECT RAISE(ABORT, 'simulated child goal update failure')
            WHERE (SELECT COUNT(*) FROM goal_update_attempts) >= 2;
          END;
        ''');

        await expectLater(
          repository.assignToGoal(parent.id, secondGoal.id),
          throwsA(isA<SqliteException>()),
        );

        expect((await repository.getById(parent.id))?.goalId, firstGoal.id);
        expect((await repository.getById(firstChild.id))?.goalId, firstGoal.id);
        expect(
          (await repository.getById(secondChild.id))?.goalId,
          firstGoal.id,
        );
      },
    );

    test(
      'removeFromGoal rolls back parent and sibling goals when a child update fails',
      () async {
        final goal = await _insertGoal(database, id: 'goal-1');
        final parent = _buildTask(id: 'parent-task');
        await repository.insert(parent);
        await repository.assignToGoal(parent.id, goal.id);
        final firstChild = _buildTask(id: 'child-1');
        final secondChild = _buildTask(id: 'child-2');
        await repository.createSubtask(firstChild, parent.id);
        await repository.createSubtask(secondChild, parent.id);
        await database.customStatement('''
          CREATE TABLE goal_removal_attempts (id INTEGER PRIMARY KEY AUTOINCREMENT);
          CREATE TRIGGER fail_second_child_goal_removal
          BEFORE UPDATE OF goal_id ON tasks
          WHEN OLD.parent_task_id IS NOT NULL
          BEGIN
            INSERT INTO goal_removal_attempts (id) VALUES (NULL);
            SELECT RAISE(ABORT, 'simulated child goal removal failure')
            WHERE (SELECT COUNT(*) FROM goal_removal_attempts) >= 2;
          END;
        ''');

        await expectLater(
          repository.removeFromGoal(parent.id),
          throwsA(isA<SqliteException>()),
        );

        expect((await repository.getById(parent.id))?.goalId, goal.id);
        expect((await repository.getById(firstChild.id))?.goalId, goal.id);
        expect((await repository.getById(secondChild.id))?.goalId, goal.id);
      },
    );

    test('GoalProgress reflects cascaded parent goal changes', () async {
      final firstGoal = await _insertGoal(database, id: 'goal-1');
      final secondGoal = await _insertGoal(database, id: 'goal-2');
      final parent = _buildTask(id: 'parent-task');
      await repository.insert(parent);
      await repository.assignToGoal(parent.id, firstGoal.id);
      final completedChild = _buildTask(id: 'child-1', completed: true);
      final openChild = _buildTask(id: 'child-2');
      await repository.createSubtask(completedChild, parent.id);
      await repository.createSubtask(openChild, parent.id);

      final before = GoalProgress.fromTasks(
        firstGoal.id,
        await repository.getAll(),
      );
      expect(before.completedLeaves, 1);
      expect(before.totalLeaves, 2);
      expect(before.fraction, 0.5);

      await repository.assignToGoal(parent.id, secondGoal.id);

      final oldGoal = GoalProgress.fromTasks(
        firstGoal.id,
        await repository.getAll(),
      );
      final newGoal = GoalProgress.fromTasks(
        secondGoal.id,
        await repository.getAll(),
      );
      expect(oldGoal.hasActionableTasks, isFalse);
      expect(newGoal.completedLeaves, 1);
      expect(newGoal.totalLeaves, 2);
      expect(newGoal.fraction, 0.5);

      await repository.removeFromGoal(parent.id);

      final afterRemoval = GoalProgress.fromTasks(
        secondGoal.id,
        await repository.getAll(),
      );
      expect(afterRemoval.hasActionableTasks, isFalse);
    });

    test('getByGoalId returns matching tasks in repository order', () async {
      final firstGoal = await _insertGoal(database, id: 'goal-1');
      final secondGoal = await _insertGoal(database, id: 'goal-2');
      final emptyGoal = await _insertGoal(database, id: 'goal-3');
      final tasks = [
        _buildTask(
          id: 'older-high-priority',
          priority: 3,
          createdAt: DateTime(2026, 8, 1, 9),
        ),
        _buildTask(
          id: 'newer-high-priority',
          priority: 3,
          createdAt: DateTime(2026, 8, 1, 10),
        ),
        _buildTask(
          id: 'lower-priority',
          priority: 1,
          createdAt: DateTime(2026, 8, 1, 11),
        ),
        _buildTask(
          id: 'completed-task',
          completed: true,
          priority: 5,
          createdAt: DateTime(2026, 8, 1, 12),
        ),
        _buildTask(id: 'other-goal-task'),
        _buildTask(id: 'standalone-task'),
      ];
      for (final task in tasks) {
        await repository.insert(task);
      }
      await repository.assignToGoal('older-high-priority', firstGoal.id);
      await repository.assignToGoal('newer-high-priority', firstGoal.id);
      await repository.assignToGoal('lower-priority', firstGoal.id);
      await repository.assignToGoal('completed-task', firstGoal.id);
      await repository.assignToGoal('other-goal-task', secondGoal.id);

      final goalTasks = await repository.getByGoalId(firstGoal.id);

      expect(goalTasks.map((task) => task.id).toList(), [
        'newer-high-priority',
        'older-high-priority',
        'lower-priority',
        'completed-task',
      ]);
      expect(await repository.getByGoalId(emptyGoal.id), isEmpty);
      expect(await repository.getByGoalId('missing-goal'), isEmpty);
      expect(await repository.getAll(), hasLength(tasks.length));
    });

    test(
      'assignToGoal rejects a missing goal and keeps the old assignment',
      () async {
        final originalGoal = await _insertGoal(database, id: 'goal-1');
        final task = _buildTask();
        await repository.insert(task);
        await repository.assignToGoal(task.id, originalGoal.id);

        await expectLater(
          repository.assignToGoal(task.id, 'missing-goal'),
          throwsA(
            isA<TaskRelationshipException>().having(
              (error) => error.message,
              'message',
              contains('missing-goal'),
            ),
          ),
        );

        expect((await repository.getById(task.id))?.goalId, originalGoal.id);
      },
    );

    test(
      'assignToGoal rejects a missing task without creating a task',
      () async {
        final goal = await _insertGoal(database, id: 'goal-1');

        await expectLater(
          repository.assignToGoal('missing-task', goal.id),
          throwsA(
            isA<TaskRelationshipException>().having(
              (error) => error.message,
              'message',
              contains('missing-task'),
            ),
          ),
        );

        expect(await repository.getAll(), isEmpty);
      },
    );

    test('removeFromGoal rejects a missing task', () async {
      await expectLater(
        repository.removeFromGoal('missing-task'),
        throwsA(
          isA<TaskRelationshipException>().having(
            (error) => error.message,
            'message',
            contains('missing-task'),
          ),
        ),
      );

      expect(await repository.getAll(), isEmpty);
    });

    test(
      'assignToGoal rejects a subtask and preserves its inherited goal',
      () async {
        final firstGoal = await _insertGoal(database, id: 'goal-1');
        final secondGoal = await _insertGoal(database, id: 'goal-2');
        final parent = _buildTask(id: 'parent-task');
        await repository.insert(parent);
        await repository.assignToGoal(parent.id, firstGoal.id);
        final child = _buildTask(id: 'child-task');
        await repository.createSubtask(child, parent.id);

        await expectLater(
          repository.assignToGoal(child.id, secondGoal.id),
          throwsA(
            isA<TaskRelationshipException>().having(
              (error) => error.message,
              'message',
              contains('subtask'),
            ),
          ),
        );

        final storedParent = (await repository.getById(parent.id))!;
        expect(storedParent.goalId, firstGoal.id);
        expect(storedParent.parentTaskId, isNull);

        final storedChild = (await repository.getById(child.id))!;
        expect(storedChild.goalId, firstGoal.id);
        expect(storedChild.parentTaskId, parent.id);
        expect(Task.fromRow(storedChild), equals(child));

        expect(await repository.getByGoalId(firstGoal.id), hasLength(2));
        expect(await repository.getByGoalId(secondGoal.id), isEmpty);
      },
    );

    test(
      'removeFromGoal rejects a subtask and preserves its inherited goal',
      () async {
        final goal = await _insertGoal(database, id: 'goal-1');
        final parent = _buildTask(id: 'parent-task');
        await repository.insert(parent);
        await repository.assignToGoal(parent.id, goal.id);
        final child = _buildTask(id: 'child-task');
        await repository.createSubtask(child, parent.id);

        await expectLater(
          repository.removeFromGoal(child.id),
          throwsA(
            isA<TaskRelationshipException>().having(
              (error) => error.message,
              'message',
              contains('subtask'),
            ),
          ),
        );

        final storedParent = (await repository.getById(parent.id))!;
        expect(storedParent.goalId, goal.id);
        expect(storedParent.parentTaskId, isNull);

        final storedChild = (await repository.getById(child.id))!;
        expect(storedChild.goalId, goal.id);
        expect(storedChild.parentTaskId, parent.id);
        expect(Task.fromRow(storedChild), equals(child));

        expect(await repository.getByGoalId(goal.id), hasLength(2));
      },
    );

    test(
      'editing and completing a task preserves its goal assignment',
      () async {
        final goal = await _insertGoal(database, id: 'goal-1');
        final task = _buildTask();
        await repository.insert(task);
        await repository.assignToGoal(task.id, goal.id);

        await repository.update(task.copyWith(title: 'Updated title'));
        var storedTask = (await repository.getById(task.id))!;
        expect(storedTask.goalId, goal.id);
        expect(storedTask.title, 'Updated title');

        await repository.setCompleted(task.id, true);
        storedTask = (await repository.getById(task.id))!;
        expect(storedTask.goalId, goal.id);
        expect(storedTask.completed, isTrue);
      },
    );

    test('standalone tasks remain usable without a goal', () async {
      final task = _buildTask();
      await repository.insert(task);

      expect((await repository.getById(task.id))?.goalId, isNull);

      await repository.update(task.copyWith(title: 'Edited standalone'));
      await repository.setCompleted(task.id, true);
      final editedTask = (await repository.getById(task.id))!;
      expect(editedTask.goalId, isNull);
      expect(editedTask.title, 'Edited standalone');
      expect(editedTask.completed, isTrue);

      await repository.delete(task.id);
      expect(await repository.getById(task.id), isNull);
    });

    test(
      'createSubtask inherits the parent goal and preserves its fields',
      () async {
        final goal = await _insertGoal(database, id: 'goal-1');
        final parent = _buildTask(id: 'parent-task', title: 'Parent task');
        await repository.insert(parent);
        await repository.assignToGoal(parent.id, goal.id);
        final subtask = _buildTask(
          id: 'subtask',
          title: 'Subtask title',
          description: 'Subtask description',
          completed: true,
          createdAt: DateTime(2026, 8, 2, 8),
          updatedAt: DateTime(2026, 8, 3, 9),
          dueDate: DateTime(2026, 8, 20),
          priority: 4,
          category: 'Home',
        );

        await repository.createSubtask(subtask, parent.id);

        final storedSubtask = (await repository.getById(subtask.id))!;
        expect(storedSubtask.parentTaskId, parent.id);
        expect(storedSubtask.goalId, goal.id);
        expect(Task.fromRow(storedSubtask), equals(subtask));

        final storedParent = (await repository.getById(parent.id))!;
        expect(storedParent.parentTaskId, isNull);
        expect(storedParent.goalId, goal.id);
      },
    );

    test(
      'createSubtask keeps the goal null when the parent has none',
      () async {
        final parent = _buildTask(id: 'parent-task');
        await repository.insert(parent);
        final subtask = _buildTask(id: 'subtask');

        await repository.createSubtask(subtask, parent.id);

        final storedSubtask = (await repository.getById(subtask.id))!;
        expect(storedSubtask.parentTaskId, parent.id);
        expect(storedSubtask.goalId, isNull);
      },
    );

    test('createSubtask rejects a missing parent', () async {
      final subtask = _buildTask(id: 'subtask');

      await expectLater(
        repository.createSubtask(subtask, 'missing-parent'),
        throwsA(
          isA<TaskRelationshipException>().having(
            (error) => error.message,
            'message',
            contains('missing-parent'),
          ),
        ),
      );

      expect(await repository.getById(subtask.id), isNull);
    });

    test('createSubtask rejects a subtask as a parent', () async {
      final parent = _buildTask(id: 'parent-task');
      await repository.insert(parent);
      final child = _buildTask(id: 'child-task');
      await repository.createSubtask(child, parent.id);
      final grandchild = _buildTask(id: 'grandchild-task');

      await expectLater(
        repository.createSubtask(grandchild, child.id),
        throwsA(
          isA<TaskRelationshipException>().having(
            (error) => error.message,
            'message',
            contains('cannot have subtasks'),
          ),
        ),
      );

      expect(await repository.getById(grandchild.id), isNull);
      expect((await repository.getById(child.id))?.parentTaskId, parent.id);
    });

    test('createSubtask rejects a conflicting goal', () async {
      final parentGoal = await _insertGoal(database, id: 'goal-1');
      final otherGoal = await _insertGoal(database, id: 'goal-2');
      final parent = _buildTask(id: 'parent-task');
      await repository.insert(parent);
      await repository.assignToGoal(parent.id, parentGoal.id);
      final subtask = _buildTask(id: 'subtask');

      await expectLater(
        repository.createSubtask(subtask, parent.id, goalId: otherGoal.id),
        throwsA(
          isA<TaskRelationshipException>().having(
            (error) => error.message,
            'message',
            contains(otherGoal.id),
          ),
        ),
      );

      expect(await repository.getById(subtask.id), isNull);

      await repository.createSubtask(subtask, parent.id, goalId: parentGoal.id);
      expect((await repository.getById(subtask.id))?.goalId, parentGoal.id);
    });

    test('delete removes only the requested subtask', () async {
      final goal = await _insertGoal(database, id: 'goal-1');
      final parent = _buildTask(id: 'parent-task');
      await repository.insert(parent);
      await repository.assignToGoal(parent.id, goal.id);
      final firstChild = _buildTask(id: 'child-1', title: 'First child');
      final secondChild = _buildTask(id: 'child-2', title: 'Second child');
      await repository.createSubtask(firstChild, parent.id);
      await repository.createSubtask(secondChild, parent.id);

      await repository.delete(firstChild.id);

      expect(await repository.getById(firstChild.id), isNull);

      final storedParent = (await repository.getById(parent.id))!;
      expect(storedParent.parentTaskId, isNull);
      expect(storedParent.goalId, goal.id);

      final storedSibling = (await repository.getById(secondChild.id))!;
      expect(storedSibling.parentTaskId, parent.id);
      expect(storedSibling.goalId, goal.id);
      expect(Task.fromRow(storedSibling), equals(secondChild));
    });

    test('delete promotes all subtasks and preserves their fields', () async {
      final goal = await _insertGoal(database, id: 'goal-1');
      final parent = _buildTask(id: 'parent-task');
      await repository.insert(parent);
      await repository.assignToGoal(parent.id, goal.id);
      final firstChild = _buildTask(
        id: 'child-1',
        title: 'First child',
        description: 'First description',
        completed: true,
        createdAt: DateTime(2026, 8, 2, 8),
        updatedAt: DateTime(2026, 8, 3, 9),
        dueDate: DateTime(2026, 8, 20),
        priority: 4,
        category: 'Work',
      );
      final secondChild = _buildTask(
        id: 'child-2',
        title: 'Second child',
        description: null,
        completed: false,
        createdAt: DateTime(2026, 8, 4, 10),
        updatedAt: DateTime(2026, 8, 5, 11),
        dueDate: null,
        priority: 1,
        category: null,
      );
      await repository.createSubtask(firstChild, parent.id);
      await repository.createSubtask(secondChild, parent.id);

      await repository.delete(parent.id);

      expect(await repository.getById(parent.id), isNull);

      final storedFirstChild = (await repository.getById(firstChild.id))!;
      expect(storedFirstChild.parentTaskId, isNull);
      expect(storedFirstChild.goalId, goal.id);
      expect(Task.fromRow(storedFirstChild), equals(firstChild));

      final storedSecondChild = (await repository.getById(secondChild.id))!;
      expect(storedSecondChild.parentTaskId, isNull);
      expect(storedSecondChild.goalId, goal.id);
      expect(Task.fromRow(storedSecondChild), equals(secondChild));

      expect(await repository.getAll(), hasLength(2));
    });

    test('delete removes a parent without children', () async {
      final parent = _buildTask(id: 'parent-task');
      final unrelatedTask = _buildTask(id: 'unrelated-task');
      await repository.insert(parent);
      await repository.insert(unrelatedTask);

      await repository.delete(parent.id);

      expect(await repository.getById(parent.id), isNull);
      expect(await repository.getById(unrelatedTask.id), isNotNull);
    });

    test('delete rolls back when subtask promotion fails', () async {
      final parent = _buildTask(id: 'parent-task');
      final child = _buildTask(id: 'child-task');
      await repository.insert(parent);
      await repository.createSubtask(child, parent.id);
      await database.customStatement('''
        CREATE TRIGGER fail_subtask_promotion
        BEFORE UPDATE OF parent_task_id ON tasks
        WHEN OLD.parent_task_id IS NOT NULL AND NEW.parent_task_id IS NULL
        BEGIN
          SELECT RAISE(ABORT, 'simulated promotion failure');
        END;
      ''');

      await expectLater(
        repository.delete(parent.id),
        throwsA(isA<SqliteException>()),
      );

      expect(await repository.getById(parent.id), isNotNull);
      final storedChild = (await repository.getById(child.id))!;
      expect(storedChild.parentTaskId, parent.id);
      expect(Task.fromRow(storedChild), equals(child));
    });

    test('delete rolls back promotion when parent deletion fails', () async {
      final parent = _buildTask(id: 'parent-task');
      final child = _buildTask(id: 'child-task');
      await repository.insert(parent);
      await repository.createSubtask(child, parent.id);
      await database.customStatement('''
        CREATE TRIGGER fail_parent_deletion
        BEFORE DELETE ON tasks
        WHEN OLD.id = 'parent-task'
        BEGIN
          SELECT RAISE(ABORT, 'simulated delete failure');
        END;
      ''');

      await expectLater(
        repository.delete(parent.id),
        throwsA(isA<SqliteException>()),
      );

      expect(await repository.getById(parent.id), isNotNull);
      expect((await repository.getById(child.id))?.parentTaskId, parent.id);
    });

    test('foreign keys reject invalid goal references', () async {
      final task = _buildTask();
      await repository.insert(task);

      await expectLater(
        database
            .into(database.tasks)
            .insert(
              TasksCompanion.insert(
                id: 'invalid-task',
                title: 'Invalid task',
                createdAt: DateTime(2026, 8, 1),
                updatedAt: DateTime(2026, 8, 1),
                goalId: const Value('missing-goal'),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
      expect(await repository.getById('invalid-task'), isNull);

      await expectLater(
        database.customStatement(
          "UPDATE tasks SET goal_id = 'missing-goal' WHERE id = '${task.id}'",
        ),
        throwsA(isA<SqliteException>()),
      );
      expect((await repository.getById(task.id))?.goalId, isNull);
    });

    test(
      'foreign keys prevent raw deletion of a referenced parent task',
      () async {
        await _insertTaskRow(database, id: 'parent-task');
        await _insertTaskRow(
          database,
          id: 'child-task',
          parentTaskId: 'parent-task',
        );

        await expectLater(
          database.customStatement(
            "DELETE FROM tasks WHERE id = 'parent-task'",
          ),
          throwsA(isA<SqliteException>()),
        );

        expect(await repository.getById('parent-task'), isNotNull);
        expect(await repository.getById('child-task'), isNotNull);
      },
    );

    test(
      'update rejects a missing task instead of silently succeeding',
      () async {
        await expectLater(
          repository.update(_buildTask(id: 'missing-task')),
          throwsA(
            isA<TaskRelationshipException>().having(
              (error) => error.message,
              'message',
              contains('missing-task'),
            ),
          ),
        );

        expect(await repository.getAll(), isEmpty);
      },
    );

    test('setCompleted rejects a missing task', () async {
      await expectLater(
        repository.setCompleted('missing-task', true),
        throwsA(
          isA<TaskRelationshipException>().having(
            (error) => error.message,
            'message',
            contains('missing-task'),
          ),
        ),
      );

      expect(await repository.getAll(), isEmpty);
    });

    test('insert rejects duplicate task IDs', () async {
      final task = _buildTask();
      await repository.insert(task);

      await expectLater(
        repository.insert(task),
        throwsA(isA<SqliteException>()),
      );

      expect(await repository.getAll(), hasLength(1));
    });

    test('editing a subtask preserves its parent and inherited goal', () async {
      final goal = await _insertGoal(database, id: 'goal-1');
      final parent = _buildTask(id: 'parent-task');
      await repository.insert(parent);
      await repository.assignToGoal(parent.id, goal.id);
      final child = _buildTask(id: 'child-task');
      await repository.createSubtask(child, parent.id);

      await repository.update(child.copyWith(title: 'Edited child'));

      final storedChild = (await repository.getById(child.id))!;
      expect(storedChild.title, 'Edited child');
      expect(storedChild.parentTaskId, parent.id);
      expect(storedChild.goalId, goal.id);
    });

    test('concurrent sibling creation keeps one level of nesting', () async {
      final parent = _buildTask(id: 'parent-task');
      await repository.insert(parent);
      final firstChild = _buildTask(id: 'child-1');
      final secondChild = _buildTask(id: 'child-2');

      await Future.wait([
        repository.createSubtask(firstChild, parent.id),
        repository.createSubtask(secondChild, parent.id),
      ]);

      expect(
        (await repository.getById(firstChild.id))?.parentTaskId,
        parent.id,
      );
      expect(
        (await repository.getById(secondChild.id))?.parentTaskId,
        parent.id,
      );
      expect((await repository.getById(parent.id))?.parentTaskId, isNull);
    });

    test('concurrent nested creation is rejected for every attempt', () async {
      final parent = _buildTask(id: 'parent-task');
      await repository.insert(parent);
      final child = _buildTask(id: 'child-task');
      await repository.createSubtask(child, parent.id);
      final firstGrandchild = _buildTask(id: 'grandchild-1');
      final secondGrandchild = _buildTask(id: 'grandchild-2');

      final results = await Future.wait([
        repository
            .createSubtask(firstGrandchild, child.id)
            .then((_) => true, onError: (Object _) => false),
        repository
            .createSubtask(secondGrandchild, child.id)
            .then((_) => true, onError: (Object _) => false),
      ]);

      expect(results, [false, false]);
      expect(await repository.getById(firstGrandchild.id), isNull);
      expect(await repository.getById(secondGrandchild.id), isNull);
      expect((await repository.getById(child.id))?.parentTaskId, parent.id);
    });

    test(
      'deleting a goal unassigns a parent and its subtask together',
      () async {
        final goal = await _insertGoal(database, id: 'goal-1');
        final parent = _buildTask(id: 'parent-task');
        await repository.insert(parent);
        await repository.assignToGoal(parent.id, goal.id);
        final child = _buildTask(id: 'child-task');
        await repository.createSubtask(child, parent.id);

        await database.delete(database.goals).go();

        final storedParent = (await repository.getById(parent.id))!;
        final storedChild = (await repository.getById(child.id))!;
        expect(storedParent.goalId, isNull);
        expect(storedChild.goalId, isNull);
        expect(storedChild.parentTaskId, parent.id);
      },
    );

    test(
      'concurrent parent deletion and subtask creation never orphans a child',
      () async {
        for (var index = 0; index < 10; index++) {
          final parent = _buildTask(id: 'parent-$index');
          await repository.insert(parent);
          final child = _buildTask(id: 'child-$index');

          final create = repository
              .createSubtask(child, parent.id)
              .then<void>((_) {}, onError: (Object _) {});
          final delete = repository.delete(parent.id);
          await Future.wait([create, delete]);

          final storedParent = await repository.getById(parent.id);
          final storedChild = await repository.getById(child.id);
          if (storedChild == null) {
            continue;
          }

          if (storedParent == null) {
            expect(storedChild.parentTaskId, isNull);
          } else {
            expect(storedChild.parentTaskId, parent.id);
          }

          final parentId = storedChild.parentTaskId;
          if (parentId != null) {
            expect(await repository.getById(parentId), isNotNull);
          }
        }
      },
    );

    test('task hierarchy persists after reopening a file database', () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'systum_task_hierarchy_test_',
      );
      SystumDatabase? fileDatabase;

      try {
        final databaseFile = File('${temporaryDirectory.path}/tasks.sqlite');
        fileDatabase = SystumDatabase.test(NativeDatabase(databaseFile));
        final fileRepository = TaskRepository(fileDatabase);
        final parent = _buildTask(id: 'persistent-parent');
        final child = _buildTask(id: 'persistent-child');
        await fileRepository.insert(parent);
        await fileRepository.createSubtask(child, parent.id);

        await fileDatabase.close();
        fileDatabase = null;

        fileDatabase = SystumDatabase.test(NativeDatabase(databaseFile));
        final storedChild = await TaskRepository(
          fileDatabase,
        ).getById(child.id);

        expect(storedChild?.parentTaskId, parent.id);
      } finally {
        try {
          await fileDatabase?.close();
        } finally {
          await temporaryDirectory.delete(recursive: true);
        }
      }
    });
  });
}

Future<GoalRow> _insertGoal(
  SystumDatabase database, {
  String id = 'goal-1',
}) async {
  final now = DateTime(2026, 8, 1);
  final goal = GoalRow(
    id: id,
    title: 'Goal $id',
    createdAt: now,
    updatedAt: now,
  );
  await database.into(database.goals).insert(goal.toCompanion(true));
  return goal;
}

Future<void> _insertTaskRow(
  SystumDatabase database, {
  required String id,
  String? goalId,
  String? parentTaskId,
}) async {
  final now = DateTime(2026, 8, 1);
  await database
      .into(database.tasks)
      .insert(
        TasksCompanion.insert(
          id: id,
          title: id,
          createdAt: now,
          updatedAt: now,
          goalId: Value(goalId),
          parentTaskId: Value(parentTaskId),
        ),
      );
}

Task _buildTask({
  String id = 'task-1',
  String title = 'Write tests',
  String? description = 'Repository coverage',
  bool completed = false,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? dueDate,
  int priority = 2,
  String? category = 'Work',
}) {
  return Task(
    id: id,
    title: title,
    description: description,
    completed: completed,
    createdAt: createdAt ?? DateTime(2026, 8, 1, 8),
    updatedAt: updatedAt ?? DateTime(2026, 8, 1, 8),
    dueDate: dueDate,
    priority: priority,
    category: category,
  );
}
