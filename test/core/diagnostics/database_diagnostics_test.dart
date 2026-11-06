import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/core/diagnostics/database_diagnostics.dart';

void main() {
  late SystumDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = SystumDatabase.test(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<DiagnosticReport> run() {
    return DatabaseDiagnosticsService(database).run();
  }

  DiagnosticIssue issue(DiagnosticReport report, String name) {
    return report.issues.singleWhere((issue) => issue.name == name);
  }

  test('reports a healthy fresh database without mutating it', () async {
    final report = await run();

    expect(report.hasErrors, isFalse);
    expect(report.count(DiagnosticSeverity.healthy), report.issues.length);
    expect(
      report.issues.map((issue) => issue.name),
      containsAll([
        'SQLite integrity',
        'Foreign-key consistency',
        'Schema structure',
        'Task relationships',
        'Recurrence rules and occurrences',
        'Reminder schedules',
        'Focus sessions and intervals',
        'Pomodoro settings',
      ]),
    );
    expect(issue(report, 'Schema structure').message, contains('Schema v8'));
    expect(await database.select(database.tasks).get(), isEmpty);
    expect(await database.select(database.goals).get(), isEmpty);
    expect(await database.select(database.focusSessions).get(), isEmpty);
  });

  test(
    'reports missing indexes, tables, columns, and version mismatches',
    () async {
      await database.customStatement('DROP INDEX tasks_goal_id_idx');
      await database.customStatement('ALTER TABLE tasks DROP COLUMN category');
      await database.customStatement('DROP TABLE focus_session_intervals');
      await database.customStatement('PRAGMA user_version = 3');

      final report = await run();
      final schema = issue(report, 'Schema structure');

      expect(schema.severity, DiagnosticSeverity.error);
      expect(schema.records, contains('missing_index:tasks_goal_id_idx'));
      expect(schema.records, contains('missing_column:tasks.category'));
      expect(schema.records, contains('missing_table:focus_session_intervals'));
      expect(schema.records, contains('schema_version:expected 8 got 3'));
      expect(schema.guidance, isNotNull);
    },
  );

  test('reports orphaned, nested, mismatched, and cyclic tasks', () async {
    await database.customStatement('PRAGMA foreign_keys = OFF');
    await database.customStatement('''
      INSERT INTO goals (id, title, created_at, updated_at)
      VALUES ('goal', 'Goal', 0, 0)
    ''');
    await database.customStatement('''
      INSERT INTO tasks
        (id, title, completed, created_at, updated_at, priority, goal_id,
         parent_task_id)
      VALUES
        ('orphan', 'Orphan', 0, 0, 0, 2, 'missing-goal', 'missing-parent'),
        ('self', 'Self', 0, 0, 0, 2, NULL, 'self'),
        ('grandparent', 'Grandparent', 0, 0, 0, 2, 'goal', NULL),
        ('parent', 'Parent', 0, 0, 0, 2, 'goal', 'grandparent'),
        ('nested', 'Nested', 0, 0, 0, 2, 'goal', 'parent'),
        ('mismatch', 'Mismatch', 0, 0, 0, 2, NULL, 'grandparent')
    ''');
    await database.customStatement('PRAGMA foreign_keys = ON');

    final report = await run();
    final tasks = issue(report, 'Task relationships');

    expect(tasks.severity, DiagnosticSeverity.error);
    expect(tasks.records, contains('orphan:missing_goal'));
    expect(tasks.records, contains('orphan:missing_parent'));
    expect(tasks.records, contains('self:self_parent'));
    expect(tasks.records, contains('self:cycle'));
    expect(tasks.records, contains('nested:nested_parent'));
    expect(tasks.records, contains('mismatch:goal_mismatch'));
    expect(tasks.guidance, isNotNull);
  });

  test('reports inconsistent focus sessions and intervals', () async {
    await database.customStatement('PRAGMA foreign_keys = OFF');
    await database.customStatement('''
      INSERT INTO focus_sessions
        (id, mode, status, started_at_ms, ended_at_ms, actual_duration_ms,
         updated_at_ms)
      VALUES
        ('overlap', 'standard', 'completed', 0, 1000, 700, 1000),
        ('empty', 'standard', 'completed', 2000, 3000, 0, 3000)
    ''');
    await database.customStatement('''
      INSERT INTO focus_session_intervals
        (id, session_id, started_at_ms, ended_at_ms)
      VALUES
        ('i1', 'overlap', 0, 500),
        ('i2', 'overlap', 400, 600)
    ''');
    await database.customStatement('''
      INSERT INTO focus_sessions
        (id, mode, status, started_at_ms, updated_at_ms)
      VALUES ('running', 'standard', 'running', 4000, 4000)
    ''');
    await database.customStatement('PRAGMA foreign_keys = ON');

    final report = await run();
    final focus = issue(report, 'Focus sessions and intervals');

    expect(focus.severity, DiagnosticSeverity.error);
    expect(focus.records, contains('i1:overlapping_intervals'));
    expect(focus.records, contains('overlap:end_time_mismatch'));
    expect(focus.records, contains('empty:terminal_without_intervals'));
    expect(focus.records, contains('running:unresolved_open_interval'));
    expect(focus.guidance, isNotNull);
  });

  test('reports inconsistent reminder schedules', () async {
    await database.customStatement('PRAGMA foreign_keys = OFF');
    await database.customStatement('''
      INSERT INTO tasks
        (id, title, completed, created_at, updated_at, priority)
      VALUES ('completed', 'Completed', 1, 0, 0, 2)
    ''');
    await database.customStatement('''
      INSERT INTO reminders
        (id, task_id, schedule_type, timezone_id, scheduled_at_utc_ms,
         local_time_seconds, interval, weekdays, start_date, end_date,
         max_occurrences, status, cancellation_reason, cancelled_at_ms,
         created_at_ms, updated_at_ms)
      VALUES
        ('missing-task', 'absent', 'once', NULL, 1000, NULL, 1, NULL, NULL,
         NULL, NULL, 'scheduled', NULL, NULL, 0, 0),
        ('bad-type', 'completed', 'hourly', NULL, 1000, NULL, 1, NULL, NULL,
         NULL, NULL, 'scheduled', NULL, NULL, 0, 0),
        ('once-missing', 'completed', 'once', NULL, NULL, NULL, 1, NULL, NULL,
         NULL, NULL, 'scheduled', NULL, NULL, 0, 0),
        ('bad-recurring', 'completed', 'weekly', NULL, NULL, 90000, 0, 0, NULL,
         NULL, NULL, 'scheduled', NULL, NULL, 0, 0),
        ('completed-task', 'completed', 'once', NULL, 1000, NULL, 1, NULL,
         NULL, NULL, NULL, 'scheduled', NULL, NULL, 0, 0),
        ('bad-metadata', 'completed', 'once', '', 1000, NULL, 1, NULL, NULL,
         NULL, NULL, 'scheduled', NULL, NULL, 10, 0)
    ''');
    await database.customStatement('PRAGMA foreign_keys = ON');

    final report = await run();
    final reminders = issue(report, 'Reminder schedules');

    expect(reminders.severity, DiagnosticSeverity.error);
    expect(reminders.records, contains('missing-task:missing_task'));
    expect(reminders.records, contains('bad-type:invalid_schedule_type'));
    expect(reminders.records, contains('once-missing:once_missing_trigger'));
    expect(reminders.records, contains('bad-recurring:invalid_local_time'));
    expect(reminders.records, contains('bad-recurring:invalid_interval'));
    expect(reminders.records, contains('bad-recurring:invalid_weekdays'));
    expect(
      reminders.records,
      contains('completed-task:scheduled_for_completed_task'),
    );
    expect(reminders.records, contains('bad-metadata:blank_timezone'));
    expect(reminders.records, contains('bad-metadata:updated_before_created'));
    expect(reminders.guidance, isNotNull);
  });

  test('reports out-of-bounds persisted Pomodoro settings', () async {
    SharedPreferences.setMockInitialValues({
      'focus.pomodoro.settings.v1':
          '{"focusMinutes":0,"shortBreakMinutes":5,"longBreakMinutes":15}',
    });

    final report = await run();
    final pomodoro = issue(report, 'Pomodoro settings');

    expect(pomodoro.severity, DiagnosticSeverity.error);
    expect(pomodoro.records, contains('settings:out_of_bounds'));
    expect(pomodoro.guidance, isNotNull);
  });

  test('reports malformed dismissed Pomodoro cycles', () async {
    SharedPreferences.setMockInitialValues({
      'focus.pomodoro.dismissed_cycles.v1': 'not-json',
    });

    final report = await run();
    final pomodoro = issue(report, 'Pomodoro settings');

    expect(pomodoro.severity, DiagnosticSeverity.error);
    expect(pomodoro.records, contains('dismissed_cycles:malformed'));
  });
}
