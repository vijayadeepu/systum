import 'package:drift/drift.dart';

import '../../features/goals/models/goal_date.dart';
import '../../features/goals/models/goal_table.dart';
import '../../features/focus/models/focus_session_table.dart';
import '../../features/focus/models/focus_session_interval.dart';
import '../../features/focus/models/focus_session_mode.dart';
import '../../features/focus/models/focus_session_status.dart';
import '../../features/tasks/models/task_table.dart';
import 'database_connection.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Goals,
    Tasks,
    FocusSessions,
    FocusSessionIntervals,
    TaskRecurrenceRules,
    TaskOccurrences,
  ],
)
final class SystumDatabase extends _$SystumDatabase {
  SystumDatabase() : super(openDatabaseConnection());

  SystumDatabase.test(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await transaction(() async {
        await migrator.createAll();
        await _createFocusIndexes();
      });
    },
    onUpgrade: (migrator, from, to) => transaction(() async {
      if (from < 2) {
        await migrator.createTable(goals);
        await migrator.addColumn(tasks, tasks.goalId);
        await migrator.addColumn(tasks, tasks.parentTaskId);
        await migrator.createAll();
      }

      if (from < 3) {
        await _migrateGoalTargetDates();
      }
      if (from < 4) {
        await migrator.createTable(focusSessions);
        await migrator.createTable(focusSessionIntervals);
        await _createFocusIndexes();
      }
      if (from < 5) {
        await migrator.addColumn(tasks, tasks.dueTime);
        await migrator.addColumn(tasks, tasks.dueTimezone);
      }
      if (from < 6) {
        await migrator.createTable(taskRecurrenceRules);
        await migrator.createTable(taskOccurrences);
      }
      if (from >= 6 && from < 7) {
        await migrator.addColumn(
          taskRecurrenceRules,
          taskRecurrenceRules.isActive,
        );
        await _normalizeRecurrenceDates();
      }
      if (from < 7) {
        await _createRecurrenceIndexes();
      }
    }),
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createFocusIndexes() async {
    for (final statement in FocusSchemaV4.indexStatements) {
      await customStatement(statement);
    }
  }

  /// Creates every recurrence index with `IF NOT EXISTS` so the migration is
  /// safe for both fresh v6 databases (which already have the non-unique
  /// indexes) and databases upgraded from earlier versions.
  Future<void> _createRecurrenceIndexes() async {
    for (final statement in const [
      'CREATE INDEX IF NOT EXISTS task_recurrence_rules_parent_task_id_idx '
          'ON task_recurrence_rules (parent_task_id)',
      'CREATE UNIQUE INDEX IF NOT EXISTS '
          'task_recurrence_rules_parent_unique_idx '
          'ON task_recurrence_rules (parent_task_id)',
      'CREATE INDEX IF NOT EXISTS task_occurrences_rule_id_idx '
          'ON task_occurrences (rule_id)',
      'CREATE INDEX IF NOT EXISTS task_occurrences_occurrence_date_idx '
          'ON task_occurrences (occurrence_date)',
      'CREATE UNIQUE INDEX IF NOT EXISTS '
          'task_occurrences_rule_date_unique_idx '
          'ON task_occurrences (rule_id, occurrence_date)',
    ]) {
      await customStatement(statement);
    }
  }

  /// Version 6 stored recurrence dates as local-midnight epoch milliseconds.
  /// Version 7 stores them as UTC-midnight epoch milliseconds so a calendar
  /// date survives timezone changes. Existing values are converted using the
  /// local calendar date active during the migration.
  Future<void> _normalizeRecurrenceDates() async {
    final rules = await customSelect(
      'SELECT id, start_date, end_date FROM task_recurrence_rules',
    ).get();
    for (final row in rules) {
      final start = _legacyRecurrenceDate(row.read<int>('start_date'));
      final rawEnd = row.readNullable<int>('end_date');
      await customStatement(
        'UPDATE task_recurrence_rules SET start_date = ?, end_date = ? '
        'WHERE id = ?',
        [
          start.millisecondsSinceEpoch,
          rawEnd == null
              ? null
              : _legacyRecurrenceDate(rawEnd).millisecondsSinceEpoch,
          row.read<String>('id'),
        ],
      );
    }

    final occurrences = await customSelect(
      'SELECT id, occurrence_date, due_date FROM task_occurrences',
    ).get();
    for (final row in occurrences) {
      final occurrenceDate = _legacyRecurrenceDate(
        row.read<int>('occurrence_date'),
      );
      final rawDueDate = row.readNullable<int>('due_date');
      await customStatement(
        'UPDATE task_occurrences SET occurrence_date = ?, due_date = ? '
        'WHERE id = ?',
        [
          occurrenceDate.millisecondsSinceEpoch,
          rawDueDate == null
              ? null
              : _legacyRecurrenceDate(rawDueDate).millisecondsSinceEpoch,
          row.read<String>('id'),
        ],
      );
    }

    await _deduplicateRecurrenceRows();
  }

  DateTime _legacyRecurrenceDate(int milliseconds) {
    final local = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// Old generation code could create duplicate occurrences under concurrent
  /// calls. The unique index introduced in version 7 needs a clean table; the
  /// earliest row (by rowid) is retained.
  Future<void> _deduplicateRecurrenceRows() async {
    // Remove occurrences that belong to duplicate rules that are about to be
    // discarded so the migration never creates orphaned occurrences.
    await customStatement(
      'DELETE FROM task_occurrences WHERE rule_id IN ('
      'SELECT id FROM task_recurrence_rules WHERE parent_task_id IS NOT NULL '
      'AND rowid NOT IN (SELECT MIN(rowid) FROM task_recurrence_rules '
      'WHERE parent_task_id IS NOT NULL GROUP BY parent_task_id))',
    );
    await customStatement(
      'DELETE FROM task_occurrences WHERE rule_id IS NOT NULL AND rowid NOT IN '
      '(SELECT MIN(rowid) FROM task_occurrences WHERE rule_id IS NOT NULL '
      'GROUP BY rule_id, occurrence_date)',
    );
    await customStatement(
      'DELETE FROM task_recurrence_rules WHERE parent_task_id IS NOT NULL '
      'AND rowid NOT IN '
      '(SELECT MIN(rowid) FROM task_recurrence_rules '
      'WHERE parent_task_id IS NOT NULL GROUP BY parent_task_id)',
    );
  }

  Future<void> _migrateGoalTargetDates() async {
    // Version 2 stored local-midnight DateTimes as Unix seconds. Interpret
    // each instant in the timezone active during migration and preserve that
    // displayed local calendar date; the original timezone is unrecoverable.
    final legacyDates = await customSelect(
      'SELECT id, target_date FROM goals WHERE target_date IS NOT NULL',
    ).get();
    for (final row in legacyDates) {
      final legacySeconds = row.read<int>('target_date');
      final localDate = DateTime.fromMillisecondsSinceEpoch(
        legacySeconds * 1000,
      );
      final goalDate = GoalDate.fromDateTime(localDate);
      await customStatement('UPDATE goals SET target_date = ? WHERE id = ?', [
        goalDate.epochDay,
        row.read<String>('id'),
      ]);
    }
  }
}

extension FocusSessionIntervalRowDomain on FocusSessionIntervalRow {
  FocusSessionInterval toDomain() => FocusSessionInterval(
    sessionId: sessionId,
    startedAtMs: startedAtMs,
    endedAtMs: endedAtMs,
  );
}
