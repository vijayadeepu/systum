import '../database/database.dart';
import '../../features/focus/models/pomodoro_settings.dart';
import '../../features/focus/repository/pomodoro_settings_store.dart';

enum DiagnosticSeverity { healthy, warning, error, inconclusive }

final class DiagnosticIssue {
  const DiagnosticIssue({
    required this.name,
    required this.severity,
    required this.message,
    this.records = const [],
    this.guidance,
  });

  final String name;
  final DiagnosticSeverity severity;
  final String message;
  final List<String> records;

  /// Read-only next step shown to the user. Diagnostics never repair data.
  final String? guidance;
}

final class DiagnosticReport {
  const DiagnosticReport({required this.issues, required this.completedAt});

  final List<DiagnosticIssue> issues;
  final DateTime completedAt;

  bool get hasErrors => issues.any(
    (issue) =>
        issue.severity == DiagnosticSeverity.error ||
        issue.severity == DiagnosticSeverity.inconclusive,
  );

  int count(DiagnosticSeverity severity) =>
      issues.where((issue) => issue.severity == severity).length;
}

/// Read-only checks for SQLite structure and application-level relationships.
///
/// No check writes, repairs, or deletes user data. A failed check is reported
/// as [DiagnosticSeverity.inconclusive] instead of hiding the problem.
final class DatabaseDiagnosticsService {
  DatabaseDiagnosticsService(
    this._database, {
    PomodoroSettingsStore? settingsStore,
  }) : _settingsStore = settingsStore ?? PomodoroSettingsStore();

  final SystumDatabase _database;
  final PomodoroSettingsStore _settingsStore;

  static const requiredTables = <String, Set<String>>{
    'goals': {
      'id',
      'title',
      'description',
      'target_date',
      'created_at',
      'updated_at',
    },
    'tasks': {
      'id',
      'title',
      'description',
      'completed',
      'created_at',
      'updated_at',
      'due_date',
      'due_time',
      'due_timezone',
      'priority',
      'category',
      'goal_id',
      'parent_task_id',
    },
    'task_recurrence_rules': {
      'id',
      'parent_task_id',
      'recurrence_type',
      'interval',
      'weekdays',
      'start_date',
      'end_date',
      'max_occurrences',
      'is_active',
      'created_at',
      'updated_at',
    },
    'task_occurrences': {
      'id',
      'rule_id',
      'occurrence_date',
      'due_date',
      'due_time',
      'due_timezone',
      'completed',
      'is_deleted',
      'created_at',
      'updated_at',
    },
    'reminders': {
      'id',
      'task_id',
      'schedule_type',
      'timezone_id',
      'scheduled_at_utc_ms',
      'local_time_seconds',
      'interval',
      'weekdays',
      'start_date',
      'end_date',
      'max_occurrences',
      'status',
      'cancellation_reason',
      'cancelled_at_ms',
      'created_at_ms',
      'updated_at_ms',
    },
    'hydration_entries': {'id', 'amount_ms', 'logged_at_ms'},
    'hydration_settings_table': {'id', 'hydration_enabled', 'daily_target_ml'},
    'focus_sessions': {
      'id',
      'task_id',
      'task_id_at_start',
      'task_title_at_start',
      'mode',
      'status',
      'started_at_ms',
      'ended_at_ms',
      'planned_duration_ms',
      'actual_duration_ms',
      'cycle_id',
      'cycle_round',
      'updated_at_ms',
    },
    'focus_session_intervals': {
      'id',
      'session_id',
      'started_at_ms',
      'ended_at_ms',
    },
  };

  static const requiredIndexes = {
    'tasks_goal_id_idx',
    'tasks_parent_task_id_idx',
    'focus_sessions_one_unresolved_idx',
    'focus_session_intervals_one_open_idx',
    'focus_sessions_history_idx',
    'focus_sessions_task_history_idx',
    'focus_sessions_task_snapshot_history_idx',
    'focus_session_intervals_order_idx',
    'task_recurrence_rules_parent_task_id_idx',
    'task_recurrence_rules_parent_unique_idx',
    'task_occurrences_rule_id_idx',
    'task_occurrences_occurrence_date_idx',
    'task_occurrences_rule_date_unique_idx',
    'reminders_task_id_idx',
    'reminders_status_idx',
  };

  Future<DiagnosticReport> run() async {
    final issues = <DiagnosticIssue>[
      await _sqliteIntegrity(),
      await _foreignKeys(),
      await _schemaStructure(),
      await _taskRelationships(),
      await _recurrenceConsistency(),
      await _reminderConsistency(),
      await _focusConsistency(),
      await _pomodoroConsistency(),
    ];
    return DiagnosticReport(
      issues: List.unmodifiable(issues),
      completedAt: DateTime.now().toUtc(),
    );
  }

  Future<DiagnosticIssue> _sqliteIntegrity() async {
    try {
      final rows = await _database.customSelect('PRAGMA integrity_check').get();
      final values = rows
          .map((row) => row.data.values.firstOrNull?.toString() ?? '')
          .toList();
      final failed = values.where((value) => value != 'ok').toList();
      return DiagnosticIssue(
        name: 'SQLite integrity',
        severity: failed.isEmpty
            ? DiagnosticSeverity.healthy
            : DiagnosticSeverity.error,
        message: failed.isEmpty
            ? 'SQLite integrity_check completed successfully.'
            : 'SQLite integrity_check reported structural errors.',
        records: failed,
        guidance: failed.isEmpty
            ? null
            : 'Keep the current data in place and restore a verified backup '
                  'only after reviewing the reported pages.',
      );
    } on Object catch (error) {
      return _inconclusive('SQLite integrity', error);
    }
  }

  Future<DiagnosticIssue> _foreignKeys() async {
    try {
      final rows = await _database
          .customSelect('PRAGMA foreign_key_check')
          .get();
      final records = rows
          .map((row) => row.data.values.map((value) => '$value').join(':'))
          .toList();
      return DiagnosticIssue(
        name: 'Foreign-key consistency',
        severity: records.isEmpty
            ? DiagnosticSeverity.healthy
            : DiagnosticSeverity.error,
        message: records.isEmpty
            ? 'No foreign-key violations were found.'
            : 'Foreign-key violations were found.',
        records: records,
        guidance: records.isEmpty
            ? null
            : 'Review the listed table/row identifiers before editing or '
                  'restoring data.',
      );
    } on Object catch (error) {
      return _inconclusive('Foreign-key consistency', error);
    }
  }

  Future<DiagnosticIssue> _schemaStructure() async {
    try {
      final versionRows = await _database
          .customSelect('PRAGMA user_version')
          .get();
      final version = versionRows.isEmpty
          ? null
          : versionRows.single.read<int>('user_version');
      final tables = await _database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final indexes = await _database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final tableNames = tables.map((row) => row.read<String>('name')).toSet();
      final indexNames = indexes.map((row) => row.read<String>('name')).toSet();

      final records = <String>[];
      if (version != _database.schemaVersion) {
        records.add(
          'schema_version:expected ${_database.schemaVersion} got ${version ?? 'missing'}',
        );
      }

      final missingTables =
          requiredTables.keys
              .where((table) => !tableNames.contains(table))
              .toList()
            ..sort();
      records.addAll(missingTables.map((table) => 'missing_table:$table'));

      final existingTables = requiredTables.keys.where(tableNames.contains);
      for (final table in existingTables) {
        final columns = await _database
            .customSelect('PRAGMA table_info("$table")')
            .get();
        final columnNames = columns
            .map((row) => row.read<String>('name'))
            .toSet();
        final missing =
            requiredTables[table]!
                .where((column) => !columnNames.contains(column))
                .toList()
              ..sort();
        records.addAll(
          missing.map((column) => 'missing_column:$table.$column'),
        );
      }

      final missingIndexes =
          requiredIndexes.where((index) => !indexNames.contains(index)).toList()
            ..sort();
      records.addAll(missingIndexes.map((index) => 'missing_index:$index'));

      return DiagnosticIssue(
        name: 'Schema structure',
        severity: records.isEmpty
            ? DiagnosticSeverity.healthy
            : DiagnosticSeverity.error,
        message: records.isEmpty
            ? 'Schema v${_database.schemaVersion} has all required tables, columns, and indexes.'
            : 'Required database structures are missing or at the wrong version.',
        records: records,
        guidance: records.isEmpty
            ? null
            : 'Do not edit the database file directly. Preserve it and restore '
                  'a verified backup if the application cannot migrate safely.',
      );
    } on Object catch (error) {
      return _inconclusive('Schema structure', error);
    }
  }

  Future<DiagnosticIssue> _taskRelationships() async {
    try {
      final rows = await _database.customSelect('''
        SELECT t.id AS record_id, 'missing_goal' AS kind
        FROM tasks t LEFT JOIN goals g ON g.id = t.goal_id
        WHERE t.goal_id IS NOT NULL AND g.id IS NULL
        UNION ALL
        SELECT child.id AS record_id, 'missing_parent' AS kind
        FROM tasks child LEFT JOIN tasks parent
          ON parent.id = child.parent_task_id
        WHERE child.parent_task_id IS NOT NULL AND parent.id IS NULL
        UNION ALL
        SELECT id AS record_id, 'self_parent' AS kind
        FROM tasks WHERE parent_task_id = id
        UNION ALL
        SELECT child.id AS record_id, 'nested_parent' AS kind
        FROM tasks child JOIN tasks parent ON parent.id = child.parent_task_id
        WHERE parent.parent_task_id IS NOT NULL
        UNION ALL
        SELECT child.id AS record_id, 'goal_mismatch' AS kind
        FROM tasks child JOIN tasks parent ON parent.id = child.parent_task_id
        WHERE COALESCE(child.goal_id, '') <> COALESCE(parent.goal_id, '')
      ''').get();
      final records = rows
          .map(
            (row) =>
                '${row.read<String>('record_id')}:${row.read<String>('kind')}',
          )
          .toList();

      final tasks = await _database.select(_database.tasks).get();
      final byId = {for (final task in tasks) task.id: task};
      for (final task in tasks) {
        final seen = <String>{};
        var current = task;
        while (current.parentTaskId != null) {
          if (!seen.add(current.id)) {
            records.add('${task.id}:cycle');
            break;
          }
          final parent = byId[current.parentTaskId];
          if (parent == null) break;
          current = parent;
        }
      }

      final sorted = records.toSet().toList()..sort();
      return DiagnosticIssue(
        name: 'Task relationships',
        severity: sorted.isEmpty
            ? DiagnosticSeverity.healthy
            : DiagnosticSeverity.error,
        message: sorted.isEmpty
            ? 'Task hierarchy and goal relationships are consistent.'
            : 'Task relationships require review.',
        records: sorted,
        guidance: sorted.isEmpty
            ? null
            : 'Review the listed tasks in the task list. Relationship changes '
                  'are only safe through the application UI.',
      );
    } on Object catch (error) {
      return _inconclusive('Task relationships', error);
    }
  }

  Future<DiagnosticIssue> _recurrenceConsistency() async {
    try {
      final rows = await _database.customSelect('''
        SELECT r.id AS record_id, 'missing_parent' AS kind
        FROM task_recurrence_rules r
        LEFT JOIN tasks t ON t.id = r.parent_task_id
        WHERE r.parent_task_id IS NOT NULL AND t.id IS NULL
        UNION ALL
        SELECT o.id AS record_id, 'missing_rule' AS kind
        FROM task_occurrences o
        LEFT JOIN task_recurrence_rules r ON r.id = o.rule_id
        WHERE o.rule_id IS NULL OR r.id IS NULL
        UNION ALL
        SELECT id AS record_id, 'invalid_type' AS kind
        FROM task_recurrence_rules
        WHERE recurrence_type NOT IN ('daily', 'weekly', 'monthly', 'custom')
        UNION ALL
        SELECT id AS record_id, 'invalid_interval' AS kind
        FROM task_recurrence_rules
        WHERE interval < 1 OR interval > 999
        UNION ALL
        SELECT id AS record_id, 'invalid_weekdays' AS kind
        FROM task_recurrence_rules
        WHERE recurrence_type = 'weekly'
          AND (weekdays IS NULL OR weekdays <= 0 OR weekdays > 127)
        UNION ALL
        SELECT id AS record_id, 'end_before_start' AS kind
        FROM task_recurrence_rules
        WHERE end_date IS NOT NULL AND end_date < start_date
        UNION ALL
        SELECT id AS record_id, 'invalid_max_occurrences' AS kind
        FROM task_recurrence_rules
        WHERE max_occurrences IS NOT NULL
          AND (max_occurrences < 1 OR max_occurrences > 10000)
        UNION ALL
        SELECT id AS record_id, 'non_canonical_date' AS kind
        FROM task_recurrence_rules
        WHERE start_date % 86400000 <> 0
           OR (end_date IS NOT NULL AND end_date % 86400000 <> 0)
        UNION ALL
        SELECT id AS record_id, 'duplicate_parent_rule' AS kind
        FROM task_recurrence_rules
        WHERE parent_task_id IS NOT NULL
        GROUP BY parent_task_id
        HAVING COUNT(*) > 1
        UNION ALL
        SELECT id AS record_id, 'non_canonical_date' AS kind
        FROM task_occurrences
        WHERE occurrence_date % 86400000 <> 0
           OR (due_date IS NOT NULL AND due_date % 86400000 <> 0)
        UNION ALL
        SELECT id AS record_id, 'duplicate_occurrence' AS kind
        FROM task_occurrences
        WHERE rule_id IS NOT NULL
        GROUP BY rule_id, occurrence_date
        HAVING COUNT(*) > 1
      ''').get();
      final records =
          rows
              .map(
                (row) =>
                    '${row.read<String>('record_id')}:${row.read<String>('kind')}',
              )
              .toSet()
              .toList()
            ..sort();
      return DiagnosticIssue(
        name: 'Recurrence rules and occurrences',
        severity: records.isEmpty
            ? DiagnosticSeverity.healthy
            : DiagnosticSeverity.error,
        message: records.isEmpty
            ? 'Recurrence rules and occurrences are consistent.'
            : 'Recurrence persistence records require review.',
        records: records,
        guidance: records.isEmpty
            ? null
            : 'Review the listed recurring tasks in the task detail screen. '
                  'Do not edit recurrence rows manually.',
      );
    } on Object catch (error) {
      return _inconclusive('Recurrence rules and occurrences', error);
    }
  }

  Future<DiagnosticIssue> _reminderConsistency() async {
    try {
      final rows = await _database.customSelect('''
        SELECT r.id AS record_id, 'missing_task' AS kind
        FROM reminders r
        LEFT JOIN tasks t ON t.id = r.task_id
        WHERE t.id IS NULL
        UNION ALL
        SELECT id AS record_id, 'invalid_schedule_type' AS kind
        FROM reminders
        WHERE schedule_type NOT IN ('once', 'daily', 'weekly', 'monthly',
                                    'custom')
        UNION ALL
        SELECT id AS record_id, 'invalid_status' AS kind
        FROM reminders
        WHERE status NOT IN ('scheduled', 'cancelled')
        UNION ALL
        SELECT id AS record_id, 'invalid_cancellation_reason' AS kind
        FROM reminders
        WHERE cancellation_reason IS NOT NULL
          AND cancellation_reason NOT IN ('user', 'taskCompleted')
        UNION ALL
        SELECT id AS record_id, 'blank_timezone' AS kind
        FROM reminders
        WHERE timezone_id IS NOT NULL AND length(trim(timezone_id)) = 0
        UNION ALL
        SELECT id AS record_id, 'updated_before_created' AS kind
        FROM reminders
        WHERE updated_at_ms < created_at_ms
        UNION ALL
        SELECT id AS record_id, 'once_missing_trigger' AS kind
        FROM reminders
        WHERE schedule_type = 'once' AND scheduled_at_utc_ms IS NULL
        UNION ALL
        SELECT id AS record_id, 'once_has_recurrence' AS kind
        FROM reminders
        WHERE schedule_type = 'once'
          AND (local_time_seconds IS NOT NULL OR weekdays IS NOT NULL
               OR start_date IS NOT NULL OR end_date IS NOT NULL
               OR max_occurrences IS NOT NULL OR interval <> 1)
        UNION ALL
        SELECT id AS record_id, 'recurring_has_trigger' AS kind
        FROM reminders
        WHERE schedule_type <> 'once' AND scheduled_at_utc_ms IS NOT NULL
        UNION ALL
        SELECT id AS record_id, 'invalid_local_time' AS kind
        FROM reminders
        WHERE schedule_type <> 'once'
          AND (local_time_seconds IS NULL OR local_time_seconds < 0
               OR local_time_seconds > 86399)
        UNION ALL
        SELECT id AS record_id, 'recurring_missing_start' AS kind
        FROM reminders
        WHERE schedule_type <> 'once' AND start_date IS NULL
        UNION ALL
        SELECT id AS record_id, 'invalid_interval' AS kind
        FROM reminders
        WHERE schedule_type <> 'once' AND (interval < 1 OR interval > 999)
        UNION ALL
        SELECT id AS record_id, 'invalid_weekdays' AS kind
        FROM reminders
        WHERE schedule_type = 'weekly'
          AND (weekdays IS NULL OR weekdays <= 0 OR weekdays > 127)
        UNION ALL
        SELECT id AS record_id, 'weekdays_without_weekly' AS kind
        FROM reminders
        WHERE schedule_type <> 'weekly' AND weekdays IS NOT NULL
        UNION ALL
        SELECT id AS record_id, 'end_before_start' AS kind
        FROM reminders
        WHERE end_date IS NOT NULL AND start_date IS NOT NULL
          AND end_date < start_date
        UNION ALL
        SELECT id AS record_id, 'invalid_max_occurrences' AS kind
        FROM reminders
        WHERE max_occurrences IS NOT NULL
          AND (max_occurrences < 1 OR max_occurrences > 10000)
        UNION ALL
        SELECT id AS record_id, 'non_canonical_date' AS kind
        FROM reminders
        WHERE (start_date IS NOT NULL AND start_date % 86400000 <> 0)
           OR (end_date IS NOT NULL AND end_date % 86400000 <> 0)
        UNION ALL
        SELECT id AS record_id, 'cancelled_without_reason' AS kind
        FROM reminders
        WHERE status = 'cancelled' AND cancellation_reason IS NULL
        UNION ALL
        SELECT id AS record_id, 'cancelled_without_time' AS kind
        FROM reminders
        WHERE status = 'cancelled' AND cancelled_at_ms IS NULL
        UNION ALL
        SELECT id AS record_id, 'scheduled_with_cancel_metadata' AS kind
        FROM reminders
        WHERE status = 'scheduled'
          AND (cancellation_reason IS NOT NULL OR cancelled_at_ms IS NOT NULL)
        UNION ALL
        SELECT r.id AS record_id, 'scheduled_for_completed_task' AS kind
        FROM reminders r
        JOIN tasks t ON t.id = r.task_id
        WHERE r.status = 'scheduled' AND t.completed = 1
      ''').get();
      final records =
          rows
              .map(
                (row) =>
                    '${row.read<String>('record_id')}:${row.read<String>('kind')}',
              )
              .toSet()
              .toList()
            ..sort();
      return DiagnosticIssue(
        name: 'Reminder schedules',
        severity: records.isEmpty
            ? DiagnosticSeverity.healthy
            : DiagnosticSeverity.error,
        message: records.isEmpty
            ? 'Reminder schedules and task lifecycle state are consistent.'
            : 'Reminder persistence records require review.',
        records: records,
        guidance: records.isEmpty
            ? null
            : 'Review reminders on the affected tasks. Do not edit reminder '
                  'rows manually; restore a verified backup if needed.',
      );
    } on Object catch (error) {
      return _inconclusive('Reminder schedules', error);
    }
  }

  Future<DiagnosticIssue> _focusConsistency() async {
    try {
      final rows = await _database.customSelect('''
        SELECT i.id AS record_id, 'orphan_interval' AS kind
        FROM focus_session_intervals i
        LEFT JOIN focus_sessions s ON s.id = i.session_id
        WHERE s.id IS NULL
        UNION ALL
        SELECT a.id AS record_id, 'overlapping_intervals' AS kind
        FROM focus_session_intervals a
        JOIN focus_session_intervals b
          ON a.session_id = b.session_id AND a.id < b.id
         AND a.started_at_ms < COALESCE(b.ended_at_ms, 9223372036854775807)
         AND b.started_at_ms < COALESCE(a.ended_at_ms, 9223372036854775807)
        UNION ALL
        SELECT id AS record_id, 'invalid_interval_bounds' AS kind
        FROM focus_session_intervals
        WHERE ended_at_ms IS NOT NULL AND ended_at_ms < started_at_ms
        UNION ALL
        SELECT id AS record_id, 'incomplete_cycle_fields' AS kind
        FROM focus_sessions
        WHERE (cycle_id IS NULL) <> (cycle_round IS NULL)
           OR (cycle_round IS NOT NULL AND cycle_round < 1)
        UNION ALL
        SELECT s.id AS record_id, 'terminal_open_interval' AS kind
        FROM focus_sessions s
        JOIN focus_session_intervals i ON i.session_id = s.id
        WHERE s.status NOT IN ('running', 'paused') AND i.ended_at_ms IS NULL
        UNION ALL
        SELECT s.id AS record_id, 'unresolved_open_interval' AS kind
        FROM focus_sessions s
        LEFT JOIN focus_session_intervals i
          ON i.session_id = s.id AND i.ended_at_ms IS NULL
        WHERE s.status IN ('running', 'paused')
        GROUP BY s.id, s.status
        HAVING COUNT(i.id) <> CASE WHEN s.status = 'running' THEN 1 ELSE 0 END
        UNION ALL
        SELECT s.id AS record_id, 'terminal_without_intervals' AS kind
        FROM focus_sessions s
        WHERE s.status NOT IN ('running', 'paused')
          AND NOT EXISTS (
            SELECT 1 FROM focus_session_intervals i
            WHERE i.session_id = s.id
          )
        UNION ALL
        SELECT s.id AS record_id, 'interval_before_session' AS kind
        FROM focus_sessions s
        JOIN focus_session_intervals i ON i.session_id = s.id
        WHERE i.started_at_ms < s.started_at_ms
        UNION ALL
        SELECT s.id AS record_id, 'duration_mismatch' AS kind
        FROM focus_sessions s
        JOIN (
          SELECT session_id,
                 SUM(COALESCE(ended_at_ms, started_at_ms) - started_at_ms)
                   AS recorded_ms
          FROM focus_session_intervals
          GROUP BY session_id
        ) i ON i.session_id = s.id
        WHERE s.status NOT IN ('running', 'paused')
          AND s.actual_duration_ms IS NOT NULL
          AND s.actual_duration_ms <> i.recorded_ms
        UNION ALL
        SELECT s.id AS record_id, 'end_time_mismatch' AS kind
        FROM focus_sessions s
        JOIN (
          SELECT session_id, MAX(ended_at_ms) AS last_end_ms
          FROM focus_session_intervals
          WHERE ended_at_ms IS NOT NULL
          GROUP BY session_id
        ) i ON i.session_id = s.id
        WHERE s.status NOT IN ('running', 'paused')
          AND s.ended_at_ms IS NOT NULL
          AND s.ended_at_ms <> i.last_end_ms
      ''').get();
      final records = rows
          .map(
            (row) =>
                '${row.read<String>('record_id')}:${row.read<String>('kind')}',
          )
          .toList();
      final unresolved = await (_database.select(
        _database.focusSessions,
      )..where((session) => session.status.isIn(['running', 'paused']))).get();
      if (unresolved.length > 1) records.add('sessions:multiple_unresolved');
      final sorted = records.toSet().toList()..sort();
      return DiagnosticIssue(
        name: 'Focus sessions and intervals',
        severity: sorted.isEmpty
            ? DiagnosticSeverity.healthy
            : DiagnosticSeverity.error,
        message: sorted.isEmpty
            ? 'Focus sessions, intervals, and cycle fields are consistent.'
            : 'Focus persistence records require review.',
        records: sorted,
        guidance: sorted.isEmpty
            ? null
            : 'Resolve any active session in the Focus screen before editing '
                  'history. Do not delete interval rows manually.',
      );
    } on Object catch (error) {
      return _inconclusive('Focus sessions and intervals', error);
    }
  }

  Future<DiagnosticIssue> _pomodoroConsistency() async {
    try {
      final settings = await _settingsStore.load();
      final valid =
          settings.focusMinutes >= PomodoroSettings.minimumMinutes &&
          settings.focusMinutes <= PomodoroSettings.maximumMinutes &&
          settings.shortBreakMinutes >= PomodoroSettings.minimumMinutes &&
          settings.shortBreakMinutes <= PomodoroSettings.maximumMinutes &&
          settings.longBreakMinutes >= PomodoroSettings.minimumMinutes &&
          settings.longBreakMinutes <= PomodoroSettings.maximumMinutes;
      final records = <String>[];
      if (!valid) records.add('settings:out_of_bounds');
      try {
        await _settingsStore.loadDismissedCycleIds();
      } on FormatException {
        records.add('dismissed_cycles:malformed');
      }
      return DiagnosticIssue(
        name: 'Pomodoro settings',
        severity: records.isEmpty
            ? DiagnosticSeverity.healthy
            : DiagnosticSeverity.error,
        message: records.isEmpty
            ? 'Pomodoro settings are valid.'
            : 'Pomodoro settings are invalid or malformed.',
        records: records,
        guidance: records.isEmpty
            ? null
            : 'Open the Pomodoro settings dialog and save supported durations '
                  'to replace malformed local settings.',
      );
    } on ArgumentError {
      return DiagnosticIssue(
        name: 'Pomodoro settings',
        severity: DiagnosticSeverity.error,
        message: 'Pomodoro settings are outside supported bounds.',
        records: const ['settings:out_of_bounds'],
        guidance:
            'Open the Pomodoro settings dialog and save supported durations.',
      );
    } on FormatException {
      return DiagnosticIssue(
        name: 'Pomodoro settings',
        severity: DiagnosticSeverity.error,
        message: 'Pomodoro settings are malformed.',
        records: const ['settings:malformed'],
        guidance: 'Open the Pomodoro settings dialog and save valid durations.',
      );
    } on Object catch (error) {
      return _inconclusive('Pomodoro settings', error);
    }
  }

  DiagnosticIssue _inconclusive(String name, Object error) => DiagnosticIssue(
    name: name,
    severity: DiagnosticSeverity.inconclusive,
    message: 'The check could not be completed safely.',
    records: [error.runtimeType.toString()],
    guidance:
        'Restart Systum and run diagnostics again. If this persists, preserve '
        'the data and restore a verified backup only after review.',
  );
}

extension on Iterable<Object?> {
  Object? get firstOrNull => isEmpty ? null : first;
}
