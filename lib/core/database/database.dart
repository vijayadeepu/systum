import 'package:drift/drift.dart';

import '../../features/goals/models/goal_table.dart';
import '../../features/tasks/models/task_table.dart';
import 'database_connection.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Goals, Tasks])
final class SystumDatabase extends _$SystumDatabase {
  SystumDatabase() : super(openDatabaseConnection());

  SystumDatabase.test(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(goals);
        await migrator.addColumn(tasks, tasks.goalId);
        await migrator.addColumn(tasks, tasks.parentTaskId);
        await migrator.createAll();
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
