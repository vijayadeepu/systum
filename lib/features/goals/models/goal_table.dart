import 'package:drift/drift.dart';

import 'goal_date.dart';

@DataClassName('GoalRow')
class Goals extends Table {
  TextColumn get id => text()();

  TextColumn get title => text().withLength(min: 1, max: 120)();

  TextColumn get description => text().nullable()();

  IntColumn get targetDate =>
      integer().map(const GoalDateConverter()).nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
