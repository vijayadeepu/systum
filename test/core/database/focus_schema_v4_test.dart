import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/models/focus_session_status.dart';
import 'package:systum/features/goals/models/goal_date.dart';

void main() {
  group('focus schema v4', () {
    test(
      'fresh schema has required columns, nullability, and foreign keys',
      () async {
        final database = SystumDatabase.test(NativeDatabase.memory());
        addTearDown(database.close);

        expect(
          await _tableNames(database),
          containsAll([
            'focus_sessions',
            'focus_session_intervals',
            'tasks',
            'goals',
          ]),
        );
        expect(await _columnNullability(database, 'focus_sessions'), {
          'id': false,
          'task_id': true,
          'task_id_at_start': true,
          'task_title_at_start': true,
          'mode': false,
          'status': false,
          'started_at_ms': false,
          'ended_at_ms': true,
          'planned_duration_ms': true,
          'actual_duration_ms': true,
          'cycle_id': true,
          'cycle_round': true,
          'updated_at_ms': false,
        });
        expect(await _columnNullability(database, 'focus_session_intervals'), {
          'id': false,
          'session_id': false,
          'started_at_ms': false,
          'ended_at_ms': true,
        });

        final sessionForeignKeys = await database
            .customSelect('PRAGMA foreign_key_list(focus_sessions)')
            .get();
        expect(sessionForeignKeys, hasLength(1));
        expect(sessionForeignKeys.single.read<String>('table'), 'tasks');
        expect(sessionForeignKeys.single.read<String>('from'), 'task_id');
        expect(sessionForeignKeys.single.read<String>('on_delete'), 'SET NULL');

        final intervalForeignKeys = await database
            .customSelect('PRAGMA foreign_key_list(focus_session_intervals)')
            .get();
        expect(intervalForeignKeys, hasLength(1));
        expect(
          intervalForeignKeys.single.read<String>('table'),
          'focus_sessions',
        );
        expect(intervalForeignKeys.single.read<String>('from'), 'session_id');
        expect(
          intervalForeignKeys.single.read<String>('on_delete'),
          'RESTRICT',
        );
        expect(await _indexNames(database), containsAll(_focusIndexNames));

        final sqliteVersion =
            (await database
                    .customSelect('SELECT sqlite_version() AS version')
                    .getSingle())
                .read<String>('version');
        expect(_versionNumber(sqliteVersion), greaterThanOrEqualTo(3009000));
      },
    );

    test(
      'stores explicit mode and status strings without enum names',
      () async {
        final database = SystumDatabase.test(NativeDatabase.memory());
        addTearDown(database.close);
        await _insertSession(
          database,
          id: 'mapped-session',
          mode: 'short_break',
          status: 'running',
        );

        final row = await (database.select(
          database.focusSessions,
        )..where((session) => session.id.equals('mapped-session'))).getSingle();
        expect(row.mode, FocusSessionMode.shortBreak);
        expect(row.status, FocusSessionStatus.running);
        expect(
          (await database
                  .customSelect(
                    "SELECT mode, status FROM focus_sessions "
                    "WHERE id = 'mapped-session'",
                  )
                  .getSingle())
              .read<String>('mode'),
          'short_break',
        );
      },
    );

    test('preserves negative epoch timestamps', () async {
      final database = SystumDatabase.test(NativeDatabase.memory());
      addTearDown(database.close);
      await _insertSession(
        database,
        id: 'pre-epoch',
        startedAtMs: -500,
        updatedAtMs: -500,
      );

      final row = await (database.select(
        database.focusSessions,
      )..where((session) => session.id.equals('pre-epoch'))).getSingle();
      expect(row.startedAtMs, -500);
      expect(row.updatedAtMs, -500);
    });

    test('rejects invalid session field constraints', () async {
      final database = SystumDatabase.test(NativeDatabase.memory());
      addTearDown(database.close);

      await expectLater(
        _insertSession(database, id: 'bad-mode', mode: 'break'),
        throwsA(anything),
      );
      await expectLater(
        _insertSession(database, id: 'bad-status', status: 'active'),
        throwsA(anything),
      );
      await expectLater(
        _insertSession(database, id: 'negative-planned', plannedDurationMs: -1),
        throwsA(anything),
      );
      await expectLater(
        _insertSession(
          database,
          id: 'negative-actual',
          status: 'completed',
          endedAtMs: 200,
          actualDurationMs: -1,
          updatedAtMs: 200,
        ),
        throwsA(anything),
      );
      await expectLater(
        _insertSession(
          database,
          id: 'missing-terminal-fields',
          status: 'completed',
        ),
        throwsA(anything),
      );
      await expectLater(
        _insertSession(
          database,
          id: 'active-with-end',
          endedAtMs: 200,
          updatedAtMs: 200,
        ),
        throwsA(anything),
      );
      await expectLater(
        _insertSession(
          database,
          id: 'end-after-update',
          status: 'completed',
          endedAtMs: 201,
          actualDurationMs: 101,
          updatedAtMs: 200,
        ),
        throwsA(anything),
      );
      await expectLater(
        _insertSession(
          database,
          id: 'duration-over-wall-time',
          status: 'completed',
          endedAtMs: 200,
          actualDurationMs: 101,
          updatedAtMs: 200,
        ),
        throwsA(anything),
      );
      await expectLater(
        _insertSession(
          database,
          id: 'cycle-id-without-round',
          cycleId: 'cycle',
        ),
        throwsA(anything),
      );
      await expectLater(
        _insertSession(database, id: 'round-without-cycle', cycleRound: 1),
        throwsA(anything),
      );
      await expectLater(
        _insertSession(
          database,
          id: 'zero-cycle-round',
          cycleId: 'cycle',
          cycleRound: 0,
        ),
        throwsA(anything),
      );
      await expectLater(
        _insertSession(database, id: 'snapshot-id-only', taskIdAtStart: 'task'),
        throwsA(anything),
      );
      await expectLater(
        _insertSession(
          database,
          id: 'snapshot-title-only',
          taskTitleAtStart: 'Task title',
        ),
        throwsA(anything),
      );
    });

    test('rejects a live task that differs from its paired snapshot', () async {
      final database = SystumDatabase.test(NativeDatabase.memory());
      addTearDown(database.close);
      await database.into(database.tasks).insert(_taskCompanion('live-task'));

      await expectLater(
        _insertSession(
          database,
          id: 'mismatched-snapshot',
          taskId: 'live-task',
          taskIdAtStart: 'different-task',
          taskTitleAtStart: 'Task title',
        ),
        throwsA(anything),
      );
    });

    test(
      'enforces one unresolved session globally and permits another after terminal',
      () async {
        final database = SystumDatabase.test(NativeDatabase.memory());
        addTearDown(database.close);
        await _insertSession(database, id: 'running');
        await expectLater(
          _insertSession(
            database,
            id: 'cannot-pause-alongside-running',
            status: 'paused',
          ),
          throwsA(anything),
        );

        await database.customStatement(
          "UPDATE focus_sessions SET status = 'completed', ended_at_ms = 100, "
          'actual_duration_ms = 0, updated_at_ms = 100 WHERE id = ?',
          ['running'],
        );
        await _insertSession(
          database,
          id: 'paused-after-terminal',
          status: 'paused',
        );
        await expectLater(
          _insertSession(database, id: 'running-alongside-paused'),
          throwsA(anything),
        );
      },
    );

    test(
      'enforces one open interval per session and interval ordering',
      () async {
        final database = SystumDatabase.test(NativeDatabase.memory());
        addTearDown(database.close);
        await _insertSession(database, id: 'session');
        await _insertInterval(database, id: 'open-one', sessionId: 'session');

        await expectLater(
          _insertInterval(database, id: 'open-two', sessionId: 'session'),
          throwsA(anything),
        );
        await expectLater(
          _insertInterval(
            database,
            id: 'negative-interval',
            sessionId: 'session',
            startedAtMs: 200,
            endedAtMs: 199,
          ),
          throwsA(anything),
        );
      },
    );

    test(
      'enforces interval foreign keys and session delete restriction',
      () async {
        final database = SystumDatabase.test(NativeDatabase.memory());
        addTearDown(database.close);
        await expectLater(
          _insertInterval(database, id: 'orphan', sessionId: 'missing'),
          throwsA(anything),
        );

        await _insertSession(database, id: 'session');
        await _insertInterval(database, id: 'interval', sessionId: 'session');
        await expectLater(
          database.customStatement(
            "DELETE FROM focus_sessions WHERE id = 'session'",
          ),
          throwsA(anything),
        );
      },
    );

    test('task deletion clears only the live task foreign key', () async {
      final database = SystumDatabase.test(NativeDatabase.memory());
      addTearDown(database.close);
      await database.into(database.tasks).insert(_taskCompanion('task-1'));
      await _insertSession(
        database,
        id: 'task-session',
        taskId: 'task-1',
        taskIdAtStart: 'task-1',
        taskTitleAtStart: 'Original task title',
      );

      await (database.delete(
        database.tasks,
      )..where((task) => task.id.equals('task-1'))).go();
      final session = await (database.select(
        database.focusSessions,
      )..where((row) => row.id.equals('task-session'))).getSingle();
      expect(session.taskId, isNull);
      expect(session.taskIdAtStart, 'task-1');
      expect(session.taskTitleAtStart, 'Original task title');
    });

    test(
      'v3 migration preserves tasks and goals and matches fresh indexes',
      () async {
        final warnAboutMultipleDatabases =
            driftRuntimeOptions.dontWarnAboutMultipleDatabases;
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        final directory = await Directory.systemTemp.createTemp(
          'systum_focus_v3_migration_',
        );
        final databaseFile = File('${directory.path}/systum.sqlite');
        final migrated = SystumDatabase.test(
          NativeDatabase(databaseFile, setup: _createVersion3Fixture),
        );
        final fresh = SystumDatabase.test(NativeDatabase.memory());

        try {
          expect(
            (await migrated.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            7,
          );
          expect(
            (await migrated.select(migrated.goals).getSingle()).title,
            'Preserved goal',
          );
          final task = await migrated.select(migrated.tasks).getSingle();
          expect(task.id, 'preserved-task');
          expect(task.title, 'Preserved task');
          expect(task.goalId, 'goal-1');
          expect(
            task.createdAt,
            DateTime.fromMillisecondsSinceEpoch(1_000_000),
          );
          expect(await _focusSchema(migrated), await _focusSchema(fresh));

          await migrated.close();
          final reopened = SystumDatabase.test(NativeDatabase(databaseFile));
          try {
            expect(await _tableNames(reopened), contains('focus_sessions'));
            expect(
              (await reopened.select(reopened.tasks).getSingle()).title,
              'Preserved task',
            );
          } finally {
            await reopened.close();
          }
        } finally {
          await migrated.close();
          await fresh.close();
          await directory.delete(recursive: true);
          driftRuntimeOptions.dontWarnAboutMultipleDatabases =
              warnAboutMultipleDatabases;
        }
      },
    );

    test('v3 migration failure rolls back new tables and version', () async {
      final warnAboutMultipleDatabases =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final directory = await Directory.systemTemp.createTemp(
        'systum_focus_v3_rollback_',
      );
      final databaseFile = File('${directory.path}/systum.sqlite');
      final failedMigration = SystumDatabase.test(
        NativeDatabase(
          databaseFile,
          setup: (legacyDatabase) =>
              _createVersion3Fixture(legacyDatabase, indexCollision: true),
        ),
      );
      SystumDatabase? inspector;

      try {
        await expectLater(
          failedMigration.customSelect('SELECT id FROM focus_sessions').get(),
          throwsA(anything),
        );
        await failedMigration.close();
        inspector = SystumDatabase.test(
          NativeDatabase(databaseFile, enableMigrations: false),
        );

        expect(
          (await inspector.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          3,
        );
        expect(await _tableNames(inspector), isNot(contains('focus_sessions')));
        expect(
          await _tableNames(inspector),
          isNot(contains('focus_session_intervals')),
        );
      } finally {
        await failedMigration.close();
        await inspector?.close();
        await directory.delete(recursive: true);
        driftRuntimeOptions.dontWarnAboutMultipleDatabases =
            warnAboutMultipleDatabases;
      }
    });
  });
}

void _createVersion3Fixture(dynamic database, {bool indexCollision = false}) {
  database.execute('PRAGMA foreign_keys = ON');
  database.execute('''
    CREATE TABLE goals (
      id TEXT NOT NULL PRIMARY KEY,
      title TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 120),
      description TEXT,
      target_date INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE tasks (
      id TEXT NOT NULL PRIMARY KEY,
      title TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 120),
      description TEXT,
      completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      due_date INTEGER,
      priority INTEGER NOT NULL DEFAULT 2,
      category TEXT CHECK (length(category) <= 80),
      goal_id TEXT REFERENCES goals (id) ON DELETE SET NULL,
      parent_task_id TEXT REFERENCES tasks (id)
    )
  ''');
  database.execute('CREATE INDEX tasks_goal_id_idx ON tasks (goal_id)');
  database.execute(
    'CREATE INDEX tasks_parent_task_id_idx ON tasks (parent_task_id)',
  );
  if (indexCollision) {
    database.execute(
      'CREATE INDEX focus_sessions_one_unresolved_idx ON tasks (id)',
    );
  }
  database.execute(
    '''
    INSERT INTO goals (id, title, target_date, created_at, updated_at)
    VALUES ('goal-1', 'Preserved goal', ?, ?, ?)
    ''',
    [GoalDate.fromDateTime(DateTime(2026, 9, 1)).epochDay, 1000, 2000],
  );
  database.execute(
    '''
    INSERT INTO tasks (
      id, title, completed, created_at, updated_at, priority, goal_id
    ) VALUES ('preserved-task', 'Preserved task', 0, ?, ?, 3, 'goal-1')
    ''',
    [1000, 2000],
  );
  database.execute('PRAGMA user_version = 3');
}

Future<void> _insertSession(
  SystumDatabase database, {
  required String id,
  String? taskId,
  String? taskIdAtStart,
  String? taskTitleAtStart,
  String mode = 'standard',
  String status = 'running',
  int startedAtMs = 100,
  int? endedAtMs,
  int? plannedDurationMs,
  int? actualDurationMs,
  String? cycleId,
  int? cycleRound,
  int? updatedAtMs,
}) {
  return database.customStatement(
    '''
    INSERT INTO focus_sessions (
      id, task_id, task_id_at_start, task_title_at_start, mode, status,
      started_at_ms, ended_at_ms, planned_duration_ms, actual_duration_ms,
      cycle_id, cycle_round, updated_at_ms
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      id,
      taskId,
      taskIdAtStart,
      taskTitleAtStart,
      mode,
      status,
      startedAtMs,
      endedAtMs,
      plannedDurationMs,
      actualDurationMs,
      cycleId,
      cycleRound,
      updatedAtMs ?? startedAtMs,
    ],
  );
}

Future<void> _insertInterval(
  SystumDatabase database, {
  required String id,
  required String sessionId,
  int startedAtMs = 100,
  int? endedAtMs,
}) {
  return database.customStatement(
    'INSERT INTO focus_session_intervals '
    '(id, session_id, started_at_ms, ended_at_ms) VALUES (?, ?, ?, ?)',
    [id, sessionId, startedAtMs, endedAtMs],
  );
}

TasksCompanion _taskCompanion(String id) {
  final now = DateTime(2026, 8, 1);
  return TasksCompanion.insert(
    id: id,
    title: id,
    createdAt: now,
    updatedAt: now,
  );
}

const _focusIndexNames = {
  'focus_sessions_one_unresolved_idx',
  'focus_session_intervals_one_open_idx',
  'focus_sessions_history_idx',
  'focus_sessions_task_history_idx',
  'focus_sessions_task_snapshot_history_idx',
  'focus_session_intervals_order_idx',
};

int _versionNumber(String version) {
  final parts = version.split('.').map(int.parse).toList();
  return parts[0] * 1000000 + parts[1] * 1000 + parts[2];
}

Future<Map<String, bool>> _columnNullability(
  SystumDatabase database,
  String table,
) async {
  final columns = await database
      .customSelect('PRAGMA table_info($table)')
      .get();
  return {
    for (final column in columns)
      column.read<String>('name'): column.read<int>('notnull') == 0,
  };
}

Future<Set<String>> _tableNames(SystumDatabase database) async {
  final rows = await database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Set<String>> _indexNames(SystumDatabase database) async {
  final rows = await database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Map<String, String?>> _focusSchema(SystumDatabase database) async {
  final rows = await database
      .customSelect(
        "SELECT name, sql FROM sqlite_master "
        "WHERE name LIKE 'focus_%' ORDER BY name",
      )
      .get();
  return {
    for (final row in rows)
      row.read<String>('name'): row.readNullable<String>('sql'),
  };
}
