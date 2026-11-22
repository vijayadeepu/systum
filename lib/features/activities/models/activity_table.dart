import 'package:drift/drift.dart';

/// First-class recurring attention obligations, independent of Tasks.
@DataClassName('ActivityRow')
class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get targetName => text()();
  TextColumn get targetType => text()();
  TextColumn get accountIdentifier => text().nullable()();
  TextColumn get cadenceType => text()();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  IntColumn get weekdays => integer().nullable()();
  IntColumn get startDateMs => integer()();
  IntColumn get localTimeSeconds => integer().nullable()();
  TextColumn get timezoneId => text().nullable()();
  IntColumn get lastCompletedAtMs => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  BoolColumn get notificationEnabled =>
      boolean().withDefault(const Constant(false))();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'activity_completions_activity_idx', columns: {#activityId})
@DataClassName('ActivityCompletionRow')
class ActivityCompletions extends Table {
  TextColumn get id => text()();
  TextColumn get activityId =>
      text().references(Activities, #id, onDelete: KeyAction.cascade)();
  IntColumn get completedAtMs => integer()();
  IntColumn get previousDueAtMs => integer().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
