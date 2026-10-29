import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../models/task.dart';

class TaskRepository {
  const TaskRepository(this._database);

  final SystumDatabase _database;

  Future<List<TaskRow>> getAll() {
    return (_database.select(_database.tasks)..orderBy([
          (tasks) => OrderingTerm.asc(tasks.completed),
          (tasks) => OrderingTerm.desc(tasks.priority),
          (tasks) => OrderingTerm.desc(tasks.createdAt),
        ]))
        .get();
  }

  Future<TaskRow?> getById(String id) {
    return (_database.select(
      _database.tasks,
    )..where((tasks) => tasks.id.equals(id))).getSingleOrNull();
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
}
