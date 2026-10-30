import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../models/task.dart';

class TaskRepository {
  const TaskRepository(this._database);

  final SystumDatabase _database;

  Future<List<TaskRow>> getAll() {
    return _orderedTasks().get();
  }

  Future<TaskRow?> getById(String id) {
    return (_database.select(
      _database.tasks,
    )..where((tasks) => tasks.id.equals(id))).getSingleOrNull();
  }

  /// Returns tasks assigned to [goalId], ordered like [getAll].
  ///
  /// Returns an empty list when the goal has no tasks or when no goal with
  /// [goalId] exists. This read never creates goal or task data.
  Future<List<TaskRow>> getByGoalId(String goalId) {
    return (_orderedTasks()..where((tasks) => tasks.goalId.equals(goalId)))
        .get();
  }

  Future<void> insert(Task task) async {
    await _database.into(_database.tasks).insert(task.toCompanion());
  }

  /// Inserts [task] and assigns it to [goalId] in one transaction.
  ///
  /// This is the create-from-goal path. Unlike [assignToGoal], it is atomic:
  /// a missing goal rolls the insert back instead of leaving a standalone task.
  Future<void> insertInGoal(Task task, String goalId) async {
    await _database.transaction(() async {
      final goal = await (_database.select(
        _database.goals,
      )..where((goals) => goals.id.equals(goalId))).getSingleOrNull();
      if (goal == null) {
        throw TaskRelationshipException('Goal "$goalId" does not exist.');
      }

      await _database
          .into(_database.tasks)
          .insert(task.toCompanion().copyWith(goalId: Value(goalId)));
    });
  }

  Future<void> update(Task task) async {
    final updated = await _database
        .update(_database.tasks)
        .replace(task.toCompanion());
    if (!updated) {
      throw TaskRelationshipException('Task "${task.id}" does not exist.');
    }
  }

  /// Deletes the task with [id].
  ///
  /// Any direct subtasks are promoted to standalone tasks before the task is
  /// deleted. Promotion and deletion run in a single transaction.
  ///
  /// Deleting an ID that does not exist is intentionally a no-op so callers can
  /// retry deletes idempotently.
  Future<void> delete(String id) async {
    await _database.transaction(() async {
      final task = await getById(id);
      if (task == null) {
        return;
      }

      final children = await (_database.select(
        _database.tasks,
      )..where((tasks) => tasks.parentTaskId.equals(id))).get();
      if (children.isNotEmpty) {
        final promotedRows =
            await (_database.update(_database.tasks)
                  ..where((tasks) => tasks.parentTaskId.equals(id)))
                .write(const TasksCompanion(parentTaskId: Value(null)));
        if (promotedRows != children.length) {
          throw TaskRelationshipException(
            'Could not promote all subtasks of task "$id".',
          );
        }
      }

      final deletedRows = await (_database.delete(
        _database.tasks,
      )..where((tasks) => tasks.id.equals(id))).go();
      if (deletedRows == 0) {
        throw TaskRelationshipException('Task "$id" does not exist.');
      }
    });
  }

  Future<void> setCompleted(String id, bool completed) async {
    final updatedRows =
        await (_database.update(_database.tasks)
              ..where((tasks) => tasks.id.equals(id)))
            .write(TasksCompanion(completed: Value(completed)));
    if (updatedRows == 0) {
      throw TaskRelationshipException('Task "$id" does not exist.');
    }
  }

  /// Creates [subtask] beneath the existing [parentTaskId].
  ///
  /// Only one level of nesting is supported. The new subtask always inherits
  /// the parent's goal. If [goalId] is provided, it must match the parent's
  /// goal; the stored value is always the inherited one.
  Future<void> createSubtask(
    Task subtask,
    String parentTaskId, {
    String? goalId,
  }) async {
    await _database.transaction(() async {
      // Validation and insertion share a transaction so the parent cannot be
      // deleted or otherwise change between the hierarchy check and the write.
      final parent = await getById(parentTaskId);
      if (parent == null) {
        throw TaskRelationshipException(
          'Parent task "$parentTaskId" does not exist.',
        );
      }
      if (parent.parentTaskId != null) {
        throw TaskRelationshipException(
          'Task "$parentTaskId" is a subtask and cannot have subtasks.',
        );
      }
      if (goalId != null && goalId != parent.goalId) {
        final parentGoal = parent.goalId == null
            ? 'no goal'
            : 'goal "${parent.goalId}"';
        throw TaskRelationshipException(
          'Subtask goal "$goalId" conflicts with the parent\'s $parentGoal.',
        );
      }

      await _database
          .into(_database.tasks)
          .insert(
            subtask.toCompanion().copyWith(
              goalId: Value(parent.goalId),
              parentTaskId: Value(parentTaskId),
            ),
          );
    });
  }

  /// Assigns an existing top-level task and its direct subtasks to an existing
  /// goal.
  ///
  /// Subtasks inherit their parent's goal and cannot be assigned independently.
  /// The parent and its direct subtasks are updated in one transaction, so a
  /// failure leaves every goal assignment unchanged. The tasks' other fields,
  /// including their timestamps, are left unchanged.
  Future<void> assignToGoal(String taskId, String goalId) async {
    await _database.transaction(() async {
      final task = await getById(taskId);
      if (task == null) {
        throw TaskRelationshipException('Task "$taskId" does not exist.');
      }
      if (task.parentTaskId != null) {
        throw TaskRelationshipException(
          'Task "$taskId" is a subtask and cannot be assigned to a goal.',
        );
      }

      final goal = await (_database.select(
        _database.goals,
      )..where((goals) => goals.id.equals(goalId))).getSingleOrNull();
      if (goal == null) {
        throw TaskRelationshipException('Goal "$goalId" does not exist.');
      }

      final updatedRows =
          await (_database.update(_database.tasks)..where(
                (tasks) =>
                    tasks.id.equals(taskId) & tasks.parentTaskId.isNull(),
              ))
              .write(TasksCompanion(goalId: Value(goalId)));
      if (updatedRows == 0) {
        throw TaskRelationshipException(
          'Task "$taskId" no longer exists or is now a subtask.',
        );
      }

      await (_database.update(_database.tasks)
            ..where((tasks) => tasks.parentTaskId.equals(taskId)))
          .write(TasksCompanion(goalId: Value(goalId)));
    });
  }

  /// Removes a top-level task's goal assignment and clears the inherited goal
  /// from all of its direct subtasks.
  ///
  /// Subtasks inherit their parent's goal and cannot remove it independently.
  /// The parent and its direct subtasks are updated in one transaction, so a
  /// failure leaves every goal assignment unchanged.
  Future<void> removeFromGoal(String taskId) async {
    await _database.transaction(() async {
      final task = await getById(taskId);
      if (task == null) {
        throw TaskRelationshipException('Task "$taskId" does not exist.');
      }
      if (task.parentTaskId != null) {
        throw TaskRelationshipException(
          'Task "$taskId" is a subtask and cannot remove its inherited goal.',
        );
      }

      final updatedRows =
          await (_database.update(_database.tasks)..where(
                (tasks) =>
                    tasks.id.equals(taskId) & tasks.parentTaskId.isNull(),
              ))
              .write(const TasksCompanion(goalId: Value(null)));
      if (updatedRows == 0) {
        throw TaskRelationshipException(
          'Task "$taskId" no longer exists or is now a subtask.',
        );
      }

      await (_database.update(_database.tasks)
            ..where((tasks) => tasks.parentTaskId.equals(taskId)))
          .write(const TasksCompanion(goalId: Value(null)));
    });
  }

  SimpleSelectStatement<$TasksTable, TaskRow> _orderedTasks() {
    return _database.select(_database.tasks)..orderBy([
      (tasks) => OrderingTerm.asc(tasks.completed),
      (tasks) => OrderingTerm.desc(tasks.priority),
      (tasks) => OrderingTerm.desc(tasks.createdAt),
    ]);
  }
}

class TaskRelationshipException implements Exception {
  const TaskRelationshipException(this.message);

  final String message;

  @override
  String toString() => 'TaskRelationshipException: $message';
}
