import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

const _databaseName = 'systum';

DatabaseConnection openDatabaseConnection() {
  return driftDatabase(name: _databaseName);
}
