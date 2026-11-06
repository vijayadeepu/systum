import 'package:drift/drift.dart';

import '../../tasks/models/task_table.dart';

/// Persisted scheduling intent for a task reminder.
///
/// This table stores *when* a reminder should fire. Android notification
/// delivery and reconciliation are separate concerns and never authoritative.
@DataClassName('ReminderRow')
@TableIndex(name: 'reminders_task_id_idx', columns: {#taskId})
@TableIndex(name: 'reminders_status_idx', columns: {#status})
class Reminders extends Table {
  TextColumn get id => text()();

  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();

  /// One of `once`, `daily`, `weekly`, `monthly`, or `custom`.
  TextColumn get scheduleType => text()();

  /// IANA timezone identifier (for example `America/New_York`). Null means
  /// the device-local timezone. Recurring schedules persist this so later
  /// scheduling can resolve local time across DST transitions.
  TextColumn get timezoneId => text().nullable()();

  /// Absolute trigger instant for a one-time reminder, in UTC epoch ms.
  IntColumn get scheduledAtUtcMs => integer().nullable()();

  /// Local wall-clock time for recurring reminders, as seconds since local
  /// midnight (0-86399).
  IntColumn get localTimeSeconds => integer().nullable()();

  /// Every N days/weeks/months for recurring schedules.
  IntColumn get interval => integer().withDefault(const Constant(1))();

  /// Weekly weekday bitmask (bit 0 = Sunday). Null for other schedule types.
  IntColumn get weekdays => integer().nullable()();

  /// First eligible local calendar date for a recurring schedule, stored as
  /// UTC-midnight epoch ms so the calendar date survives timezone changes.
  IntColumn get startDate => integer().nullable()();

  /// Last eligible local calendar date, stored as UTC-midnight epoch ms.
  IntColumn get endDate => integer().nullable()();

  /// Maximum number of reminder occurrences, or null for no explicit cap.
  IntColumn get maxOccurrences => integer().nullable()();

  /// One of `scheduled` or `cancelled`.
  TextColumn get status => text().withDefault(const Constant('scheduled'))();

  /// Why a reminder was cancelled: `user` or `taskCompleted`.
  TextColumn get cancellationReason => text().nullable()();

  IntColumn get cancelledAtMs => integer().nullable()();

  IntColumn get createdAtMs => integer()();

  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
