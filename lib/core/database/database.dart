import 'package:drift/drift.dart';

import '../../features/tasks/models/task_table.dart';
import 'database_connection.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Tasks])
final class SystumDatabase extends _$SystumDatabase {
  SystumDatabase() : super(openDatabaseConnection());

  @override
  int get schemaVersion => 1;
}
