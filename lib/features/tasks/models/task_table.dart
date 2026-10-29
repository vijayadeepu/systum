import 'package:drift/drift.dart';

import '../../goals/models/goal_table.dart';

@DataClassName('TaskRow')
@TableIndex(name: 'tasks_goal_id_idx', columns: {#goalId})
@TableIndex(name: 'tasks_parent_task_id_idx', columns: {#parentTaskId})
class Tasks extends Table {
  // UUID strings are used instead of auto-increment IDs to support future sync.
  TextColumn get id => text()();

  TextColumn get title => text().withLength(min: 1, max: 120)();

  TextColumn get description => text().nullable()();

  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get dueDate => dateTime().nullable()();

  IntColumn get priority => integer().withDefault(const Constant(2))();

  TextColumn get category => text().withLength(max: 80).nullable()();

  TextColumn get goalId =>
      text().nullable().references(Goals, #id, onDelete: KeyAction.setNull)();

  TextColumn get parentTaskId => text().nullable().references(Tasks, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
