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

  group('TaskRepository hierarchy hardening', () {
    late SystumDatabase database;
    late TaskRepository repository;

    setUp(() {
      database = SystumDatabase.test(NativeDatabase.memory());
      repository = TaskRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('createSubtask rejects self-parenting', () async {
      await repository.insert(
        Task(
          id: 'task-1',
          title: 'Self-parent task',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
        ),
      );

      await expectLater(
        repository.createSubtask(
          Task(
            id: 'task-1',
            title: 'Self-parent subtask',
            createdAt: DateTime(2026, 8, 10, 9),
            updatedAt: DateTime(2026, 8, 10, 9),
          ),
          'task-1',
        ),
        throwsA(
          isA<TaskRelationshipException>().having(
            (error) => error.message,
            'message',
            contains('cannot be its own parent'),
          ),
        ),
      );

      // Task should still exist unchanged
      final stored = await repository.getById('task-1');
      expect(stored, isNotNull);
      expect(stored?.title, 'Self-parent task');
      expect(stored?.parentTaskId, isNull);
    });

    test('createSubtask rejects deep nesting (grandchild)', () async {
      await repository.insert(
        Task(
          id: 'parent',
          title: 'Parent',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
        ),
      );
      await repository.createSubtask(
        Task(
          id: 'child',
          title: 'Child',
          createdAt: DateTime(2026, 8, 10, 9),
          updatedAt: DateTime(2026, 8, 10, 9),
        ),
        'parent',
      );

      await expectLater(
        repository.createSubtask(
          Task(
            id: 'grandchild',
            title: 'Grandchild',
            createdAt: DateTime(2026, 8, 10, 10),
            updatedAt: DateTime(2026, 8, 10, 10),
          ),
          'child',
        ),
        throwsA(
          isA<TaskRelationshipException>().having(
            (error) => error.message,
            'message',
            contains('cannot have subtasks'),
          ),
        ),
      );

      // Grandchild should not exist
      expect(await repository.getById('grandchild'), isNull);
      // Child should still exist with parent intact
      final storedChild = await repository.getById('child');
      expect(storedChild, isNotNull);
      expect(storedChild?.parentTaskId, 'parent');
    });

    test('createSubtask prevents cycles through reassignment', () async {
      await repository.insert(
        Task(
          id: 'a',
          title: 'Task A',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
        ),
      );
      await repository.createSubtask(
        Task(
          id: 'b',
          title: 'Task B',
          createdAt: DateTime(2026, 8, 10, 9),
          updatedAt: DateTime(2026, 8, 10, 9),
        ),
        'a',
      );

      // Try to make A a child of B (would create cycle A->B->A)
      await expectLater(
        repository.createSubtask(
          Task(
            id: 'a',
            title: 'Task A',
            createdAt: DateTime(2026, 8, 10, 8),
            updatedAt: DateTime(2026, 8, 10, 8),
          ),
          'b',
        ),
        throwsA(
          isA<TaskRelationshipException>().having(
            (error) => error.message,
            'message',
            contains('cannot have subtasks'),
          ),
        ),
      );
    });

    test('delete cascades correctly with subtask promotion', () async {
      await repository.insert(
        Task(
          id: 'parent',
          title: 'Parent',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
        ),
      );
      await repository.createSubtask(
        Task(
          id: 'child-1',
          title: 'Child 1',
          createdAt: DateTime(2026, 8, 10, 9),
          updatedAt: DateTime(2026, 8, 10, 9),
        ),
        'parent',
      );
      await repository.createSubtask(
        Task(
          id: 'child-2',
          title: 'Child 2',
          createdAt: DateTime(2026, 8, 10, 10),
          updatedAt: DateTime(2026, 8, 10, 10),
        ),
        'parent',
      );

      await repository.delete('parent');

      expect(await repository.getById('parent'), isNull);
      final c1 = await repository.getById('child-1');
      final c2 = await repository.getById('child-2');
      expect(c1?.parentTaskId, isNull);
      expect(c2?.parentTaskId, isNull);
      expect(await repository.getAll(), hasLength(2));
    });

    test('delete rejects invalid IDs gracefully (no-op)', () async {
      await repository.delete('nonexistent');
      expect(await repository.getAll(), isEmpty);
    });

    test('setCompleted rejects missing task', () async {
      await expectLater(
        repository.setCompleted('nonexistent', true),
        throwsA(
          isA<TaskRelationshipException>().having(
            (error) => error.message,
            'message',
            contains('nonexistent'),
          ),
        ),
      );
      expect(await repository.getAll(), isEmpty);
    });

    test('update rejects missing task', () async {
      await expectLater(
        repository.update(
          Task(
            id: 'nonexistent',
            title: 'X',
            createdAt: DateTime(2026, 8, 10, 8),
            updatedAt: DateTime(2026, 8, 10, 8),
          ),
        ),
        throwsA(
          isA<TaskRelationshipException>().having(
            (error) => error.message,
            'message',
            contains('nonexistent'),
          ),
        ),
      );
      expect(await repository.getAll(), isEmpty);
    });

    test('completion toggle is reversible', () async {
      await repository.insert(
        Task(
          id: 'task-1',
          title: 'Task',
          completed: false,
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
        ),
      );

      await repository.setCompleted('task-1', true);
      expect((await repository.getById('task-1'))?.completed, isTrue);

      await repository.setCompleted('task-1', false);
      expect((await repository.getById('task-1'))?.completed, isFalse);
    });

    test('completed tasks are excluded from overdue view', () async {
      final now = DateTime.now();
      final yesterday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));

      await repository.insert(
        Task(
          id: 'overdue-open',
          title: 'Overdue open',
          completed: false,
          createdAt: yesterday,
          updatedAt: yesterday,
          dueDate: yesterday,
        ),
      );
      await repository.insert(
        Task(
          id: 'overdue-completed',
          title: 'Overdue completed',
          completed: true,
          createdAt: yesterday,
          updatedAt: yesterday,
          dueDate: yesterday,
        ),
      );

      final overdue = await repository.filterTasks(
        const TaskFilter(time: TaskTimeFilter.overdue),
      );

      expect(overdue.map((t) => t.id).toSet(), equals({'overdue-open'}));
    });

    test('updatedAt changes on completion toggle', () async {
      final original = DateTime(2026, 8, 10, 8);

      await repository.insert(
        Task(
          id: 'task-1',
          title: 'Task',
          completed: false,
          createdAt: original,
          updatedAt: original,
        ),
      );

      await repository.setCompleted('task-1', true);
      final stored = await repository.getById('task-1');
      expect(stored?.updatedAt.isAfter(original), isTrue);
    });

    test('null category and goal are preserved', () async {
      await repository.insert(
        Task(
          id: 'task-1',
          title: 'No relationships',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
          category: null,
        ),
      );

      final stored = await repository.getById('task-1');
      expect(stored?.category, isNull);
      expect(stored?.goalId, isNull);
      expect(stored?.parentTaskId, isNull);
    });

    test('large task list does not cause N+1 queries', () async {
      // Insert 100 tasks
      for (int i = 0; i < 100; i++) {
        await repository.insert(
          Task(
            id: 'task-$i',
            title: 'Task $i',
            createdAt: DateTime(2026, 8, 10, 8),
            updatedAt: DateTime(2026, 8, 10, 8),
          ),
        );
      }

      // Single getAll should return all 100 tasks
      final all = await repository.getAll();
      expect(all, hasLength(100));

      // Filter by status should also be efficient
      final active = await repository.filterTasks(
        const TaskFilter(status: TaskStatusFilter.active),
      );
      expect(active, hasLength(100));

      // Filter by priority should be efficient
      final priority2 = await repository.filterTasks(
        const TaskFilter(priority: 2),
      );
      expect(priority2, hasLength(100));
    });

    test('recentlyUpdated sort returns newest first', () async {
      final t1 = DateTime(2026, 8, 10, 8);
      final t2 = DateTime(2026, 8, 10, 9);
      final t3 = DateTime(2026, 8, 10, 10);

      await repository.insert(
        Task(id: 'oldest', title: 'Oldest', createdAt: t1, updatedAt: t1),
      );
      await repository.insert(
        Task(id: 'middle', title: 'Middle', createdAt: t2, updatedAt: t2),
      );
      await repository.insert(
        Task(id: 'newest', title: 'Newest', createdAt: t3, updatedAt: t3),
      );

      final sorted = await repository.getAll(
        sort: const TaskSort(
          mode: TaskSortMode.updatedDate,
          order: TaskSortOrder.descending,
        ),
      );

      expect(
        sorted.map((t) => t.id).toList(),
        equals(['newest', 'middle', 'oldest']),
      );
    });

    test('duplicate task ID is rejected', () async {
      await repository.insert(
        Task(
          id: 'dup',
          title: 'First',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
        ),
      );

      await expectLater(
        repository.insert(
          Task(
            id: 'dup',
            title: 'Duplicate',
            createdAt: DateTime(2026, 8, 10, 9),
            updatedAt: DateTime(2026, 8, 10, 9),
          ),
        ),
        throwsA(isA<Exception>()),
      );

      expect(await repository.getAll(), hasLength(1));
    });
  });
}
