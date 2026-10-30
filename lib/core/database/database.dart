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

@DriftDatabase(tables: [Goals, Tasks, FocusSessions, FocusSessionIntervals])
final class SystumDatabase extends _$SystumDatabase {
  SystumDatabase() : super(openDatabaseConnection());

  SystumDatabase.test(super.executor);

  @override
  int get schemaVersion => 4;

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
