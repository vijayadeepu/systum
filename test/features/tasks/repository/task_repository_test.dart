import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';

void main() {
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
  });
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
