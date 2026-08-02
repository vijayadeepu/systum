import 'package:drift/drift.dart';

import 'database_connection.dart';

part 'database.g.dart';

@DriftDatabase(tables: [])
final class SystumDatabase extends _$SystumDatabase {
  SystumDatabase() : super(openDatabaseConnection());

  @override
  int get schemaVersion => 1;
}
