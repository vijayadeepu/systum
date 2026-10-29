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

  Future<void> update(Task task) async {
    await _database.update(_database.tasks).replace(task.toCompanion());
  }

  Future<void> delete(String id) async {
    await (_database.delete(
      _database.tasks,
    )..where((tasks) => tasks.id.equals(id))).go();
  }

  Future<void> setCompleted(String id, bool completed) async {
    await (_database.update(_database.tasks)
          ..where((tasks) => tasks.id.equals(id)))
        .write(TasksCompanion(completed: Value(completed)));
  }

  /// Assigns an existing top-level task to an existing goal.
  ///
  /// Subtasks are rejected until subtask support is implemented. The task's
  /// other fields, including its timestamps, are left unchanged.
  Future<void> assignToGoal(String taskId, String goalId) async {
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
        await (_database.update(_database.tasks)
              ..where((tasks) => tasks.id.equals(taskId)))
            .write(TasksCompanion(goalId: Value(goalId)));
    if (updatedRows == 0) {
      throw TaskRelationshipException('Task "$taskId" does not exist.');
    }
  }

  /// Removes a task's goal assignment without deleting the task.
  Future<void> removeFromGoal(String taskId) async {
    final updatedRows =
        await (_database.update(_database.tasks)
              ..where((tasks) => tasks.id.equals(taskId)))
            .write(const TasksCompanion(goalId: Value(null)));
    if (updatedRows == 0) {
      throw TaskRelationshipException('Task "$taskId" does not exist.');
    }
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
