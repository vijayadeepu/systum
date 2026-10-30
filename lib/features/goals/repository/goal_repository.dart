import '../../../core/database/database.dart';

class GoalRepository {
  const GoalRepository(this._database);

  final SystumDatabase _database;

  Future<void> create(GoalRow goal) async {
    await _database.into(_database.goals).insert(goal.toCompanion(true));
  }

  Future<List<GoalRow>> getAll() {
    return _database.select(_database.goals).get();
  }

  Future<GoalRow?> getById(String id) {
    return (_database.select(
      _database.goals,
    )..where((goals) => goals.id.equals(id))).getSingleOrNull();
  }

  Future<void> update(GoalRow goal) async {
    final updated = await _database
        .update(_database.goals)
        .replace(goal.toCompanion(true));
    if (!updated) {
      throw GoalNotFoundException(goal.id);
    }
  }

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
