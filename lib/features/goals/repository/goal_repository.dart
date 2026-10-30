import 'package:drift/drift.dart';

import '../../../core/database/database.dart';

class GoalRepository {
  const GoalRepository(this._database);

  final SystumDatabase _database;

  Future<void> create(GoalRow goal) async {
    await _database.into(_database.goals).insert(goal.toCompanion(true));
  }

  /// Returns every goal, newest first.
  ///
  /// The secondary `id` ordering keeps the result deterministic when two goals
  /// share a creation timestamp.
  Future<List<GoalRow>> getAll() {
    return (_database.select(_database.goals)..orderBy([
          (goals) => OrderingTerm.desc(goals.createdAt),
          (goals) => OrderingTerm.asc(goals.id),
        ]))
        .get();
  }

  Future<GoalRow?> getById(String id) {
    return (_database.select(
      _database.goals,
    )..where((goals) => goals.id.equals(id))).getSingleOrNull();
  }

  Future<void> update(GoalRow goal) async {
    // `false` includes explicitly null nullable fields. Using `true` would
    // omit them, silently preventing users from clearing a description or
    // target date.
    final updated = await _database
        .update(_database.goals)
        .replace(goal.toCompanion(false));
    if (!updated) {
      throw GoalNotFoundException(goal.id);
    }
  }

  /// Deletes a goal.
  ///
  /// Tasks are intentionally preserved. The schema's `ON DELETE SET NULL`
  /// foreign key clears their goal assignment while keeping every task and
  /// subtask relationship intact. Deleting a missing ID is a no-op so callers
  /// can retry idempotently.
  Future<void> delete(String id) async {
    await (_database.delete(
      _database.goals,
    )..where((goals) => goals.id.equals(id))).go();
  }
}

class GoalNotFoundException implements Exception {
  const GoalNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'GoalNotFoundException: goal "$id" does not exist.';
}
