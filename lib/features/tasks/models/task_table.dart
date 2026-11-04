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

  /// Seconds since midnight (0-86399) in [dueTimezone], or null when no due
  /// time is set.
  IntColumn get dueTime => integer().nullable()();

  /// IANA timezone identifier (e.g. "America/New_York") used to interpret
  /// [dueTime] against [dueDate]. Null means the local device timezone.
  TextColumn get dueTimezone => text().nullable()();

  IntColumn get priority => integer().withDefault(const Constant(2))();

  TextColumn get category => text().withLength(max: 80).nullable()();

  TextColumn get goalId =>
      text().nullable().references(Goals, #id, onDelete: KeyAction.setNull)();

  TextColumn get parentTaskId => text().nullable().references(Tasks, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Recurrence rule for a task. Defines how occurrences of a parent task are
/// generated over time.
@DataClassName('TaskRecurrenceRuleRow')
@TableIndex(
  name: 'task_recurrence_rules_parent_task_id_idx',
  columns: {#parentTaskId},
)
@TableIndex(
  name: 'task_recurrence_rules_parent_unique_idx',
  columns: {#parentTaskId},
  unique: true,
)
class TaskRecurrenceRules extends Table {
  TextColumn get id => text()();

  /// The parent/template task this rule belongs to.
  TextColumn get parentTaskId =>
      text().nullable().references(Tasks, #id, onDelete: KeyAction.cascade)();

  /// Recurrence type: 'daily', 'weekly', 'monthly', 'custom'.
  TextColumn get recurrenceType => text()();

  /// Interval: every N days/weeks/months.
  IntColumn get interval => integer().withDefault(const Constant(1))();

  /// Bitmask of weekdays for weekly recurrence (bit 0 = Sunday, etc.).
  /// Null for daily/monthly/custom.
  IntColumn get weekdays => integer().nullable()();

  /// Start date (epoch ms, date only).
  IntColumn get startDate => integer()();

  /// End date (epoch ms, date only), or null for no end.
  IntColumn get endDate => integer().nullable()();

  /// Maximum number of occurrences to generate, or null for unlimited.
  IntColumn get maxOccurrences => integer().nullable()();

  /// Whether generation is enabled. Stopping a rule sets this to false while
  /// preserving every already-generated occurrence.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One generated occurrence of a recurring task. Each occurrence is a
/// standalone task instance with its own due date and completion status.
@DataClassName('TaskOccurrenceRow')
@TableIndex(name: 'task_occurrences_rule_id_idx', columns: {#ruleId})
@TableIndex(
  name: 'task_occurrences_occurrence_date_idx',
  columns: {#occurrenceDate},
)
@TableIndex(
  name: 'task_occurrences_rule_date_unique_idx',
  columns: {#ruleId, #occurrenceDate},
  unique: true,
)
class TaskOccurrences extends Table {
  TextColumn get id => text()();

  /// The recurrence rule this occurrence belongs to.
  TextColumn get ruleId => text().nullable().references(
    TaskRecurrenceRules,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Occurrence date (epoch ms, date only).
  IntColumn get occurrenceDate => integer()();

  /// Due date for this occurrence (epoch ms, date only), or null if none.
  IntColumn get dueDate => integer().nullable()();

  /// Due time (seconds since midnight), or null for date-only.
  IntColumn get dueTime => integer().nullable()();

  /// Due timezone (IANA ID), or null for local.
  TextColumn get dueTimezone => text().nullable()();

  /// Whether this occurrence is completed.
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  /// Whether this occurrence was manually deleted (soft delete).
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
