import 'package:drift/drift.dart';

import '../../tasks/models/task_table.dart';
import 'focus_session_mode.dart';
import 'focus_session_status.dart';

@DataClassName('FocusSessionRow')
class FocusSessions extends Table {
  TextColumn get id => text()();

  TextColumn get taskId =>
      text().nullable().references(Tasks, #id, onDelete: KeyAction.setNull)();

  TextColumn get taskIdAtStart => text().nullable()();

  TextColumn get taskTitleAtStart => text().nullable()();

  TextColumn get mode => text().map(const FocusSessionModeConverter())();

  TextColumn get status => text().map(const FocusSessionStatusConverter())();

  IntColumn get startedAtMs => integer()();

  IntColumn get endedAtMs => integer().nullable()();

  IntColumn get plannedDurationMs => integer().nullable()();

  IntColumn get actualDurationMs => integer().nullable()();

  TextColumn get cycleId => text().nullable()();

  IntColumn get cycleRound => integer().nullable()();

  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    "CHECK (mode IN ('standard', 'pomodoro', 'short_break', 'long_break', 'custom'))",
    "CHECK (status IN ('running', 'paused', 'completed', 'interrupted', 'cancelled'))",
    'CHECK (planned_duration_ms IS NULL OR planned_duration_ms >= 0)',
    'CHECK (actual_duration_ms IS NULL OR actual_duration_ms >= 0)',
    'CHECK (updated_at_ms >= started_at_ms)',
    '''
    CHECK (
      (cycle_id IS NULL AND cycle_round IS NULL) OR
      (cycle_id IS NOT NULL AND cycle_round IS NOT NULL AND cycle_round >= 1)
    )
    ''',
    '''
    CHECK (
      (task_id_at_start IS NULL AND task_title_at_start IS NULL) OR
      (
        task_id_at_start IS NOT NULL AND
        task_title_at_start IS NOT NULL AND
        (task_id IS NULL OR task_id = task_id_at_start)
      )
    )
    ''',
    '''
    CHECK (
      (
        status IN ('running', 'paused') AND
        ended_at_ms IS NULL AND actual_duration_ms IS NULL
      ) OR (
        status IN ('completed', 'interrupted', 'cancelled') AND
        ended_at_ms IS NOT NULL AND actual_duration_ms IS NOT NULL AND
        ended_at_ms >= started_at_ms AND
        ended_at_ms <= updated_at_ms AND
        actual_duration_ms <= ended_at_ms - started_at_ms
      )
    )
    ''',
  ];
}

@DataClassName('FocusSessionIntervalRow')
class FocusSessionIntervals extends Table {
  TextColumn get id => text()();

  TextColumn get sessionId =>
      text().references(FocusSessions, #id, onDelete: KeyAction.restrict)();

  IntColumn get startedAtMs => integer()();

  IntColumn get endedAtMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'CHECK (ended_at_ms IS NULL OR ended_at_ms >= started_at_ms)',
  ];
}

class FocusSessionModeConverter
    extends TypeConverter<FocusSessionMode, String> {
  const FocusSessionModeConverter();

  @override
  FocusSessionMode fromSql(String fromDb) => switch (fromDb) {
    'standard' => FocusSessionMode.standard,
    'pomodoro' => FocusSessionMode.pomodoro,
    'short_break' => FocusSessionMode.shortBreak,
    'long_break' => FocusSessionMode.longBreak,
    'custom' => FocusSessionMode.custom,
    _ => throw ArgumentError.value(fromDb, 'fromDb', 'Unknown focus mode.'),
  };

  @override
  String toSql(FocusSessionMode value) => switch (value) {
    FocusSessionMode.standard => 'standard',
    FocusSessionMode.pomodoro => 'pomodoro',
    FocusSessionMode.shortBreak => 'short_break',
    FocusSessionMode.longBreak => 'long_break',
    FocusSessionMode.custom => 'custom',
  };
}

class FocusSessionStatusConverter
    extends TypeConverter<FocusSessionStatus, String> {
  const FocusSessionStatusConverter();

  @override
  FocusSessionStatus fromSql(String fromDb) => switch (fromDb) {
    'running' => FocusSessionStatus.running,
    'paused' => FocusSessionStatus.paused,
    'completed' => FocusSessionStatus.completed,
    'interrupted' => FocusSessionStatus.interrupted,
    'cancelled' => FocusSessionStatus.cancelled,
    _ => throw ArgumentError.value(fromDb, 'fromDb', 'Unknown session status.'),
  };

  @override
  String toSql(FocusSessionStatus value) => switch (value) {
    FocusSessionStatus.running => 'running',
    FocusSessionStatus.paused => 'paused',
    FocusSessionStatus.completed => 'completed',
    FocusSessionStatus.interrupted => 'interrupted',
    FocusSessionStatus.cancelled => 'cancelled',
  };
}

abstract final class FocusSchemaV4 {
  static const indexStatements = [
    '''
    CREATE UNIQUE INDEX focus_sessions_one_unresolved_idx
    ON focus_sessions ((1))
    WHERE status IN ('running', 'paused')
    ''',
    '''
    CREATE UNIQUE INDEX focus_session_intervals_one_open_idx
    ON focus_session_intervals (session_id)
    WHERE ended_at_ms IS NULL
    ''',
    '''
    CREATE INDEX focus_sessions_history_idx
    ON focus_sessions (started_at_ms DESC, id DESC)
    ''',
    '''
    CREATE INDEX focus_sessions_task_history_idx
    ON focus_sessions (task_id, started_at_ms DESC)
    ''',
    '''
    CREATE INDEX focus_sessions_task_snapshot_history_idx
    ON focus_sessions (task_id_at_start, started_at_ms DESC)
    ''',
    '''
    CREATE INDEX focus_session_intervals_order_idx
    ON focus_session_intervals (session_id, started_at_ms, id)
    ''',
  ];
}
