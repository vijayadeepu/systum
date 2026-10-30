import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart' show NativeDatabase, SqliteException;
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/focus/models/focus_session.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/models/focus_session_status.dart';
import 'package:systum/features/focus/repository/focus_repository.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('FocusRepository', () {
    late SystumDatabase database;
    late FocusRepository repository;

    setUp(() {
      database = SystumDatabase.test(NativeDatabase.memory());
      repository = FocusRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'starts a standalone session and persists its first interval',
      () async {
        final started = await repository.startSession(
          mode: FocusSessionMode.standard,
          startedAtMs: 1000,
        );

        expect(started.session.id, matches(_uuidPattern));
        expect(started.session.status, FocusSessionStatus.running);
        expect(started.session.taskId, isNull);
        expect(started.session.taskIdSnapshot, isNull);
        expect(started.session.taskTitleSnapshot, isNull);
        expect(started.intervals, hasLength(1));
        expect(started.intervals.single.isOpen, isTrue);

        final persisted = await repository.getById(started.session.id);
        expect(persisted, isNotNull);
        expect(persisted!.session, started.session);
        expect(persisted.intervals, started.intervals);
      },
    );

    test('captures task ID and title inside the start transaction', () async {
      final task = _task(id: 'task-1', title: 'Focus title');
      await TaskRepository(database).insert(task);

      final started = await repository.startSession(
        taskId: task.id,
        mode: FocusSessionMode.pomodoro,
        startedAtMs: 1000,
        plannedDurationMs: 1500,
        cycleId: 'cycle-1',
        cycleRound: 1,
      );

      expect(started.session.taskId, task.id);
      expect(started.session.taskIdSnapshot, task.id);
      expect(started.session.taskTitleSnapshot, task.title);
      expect(started.session.plannedDurationMs, 1500);
      expect(started.session.cycleId, 'cycle-1');
      expect(started.session.cycleRound, 1);
    });

    test('rejects a missing task without persisting a session', () async {
      await expectLater(
        repository.startSession(
          taskId: 'missing-task',
          mode: FocusSessionMode.standard,
          startedAtMs: 1000,
        ),
        throwsA(isA<FocusTaskNotFoundException>()),
      );

      expect(await repository.getHistory(), isEmpty);
    });

    test('rolls back session creation if interval insertion fails', () async {
      final existing = await _start(repository);
      await repository.completeSession(existing.session.id, atMs: 1100);
      await database.customStatement(
        'CREATE UNIQUE INDEX repository_interval_failure_test_idx '
        'ON focus_session_intervals (started_at_ms)',
      );

      await expectLater(
        repository.startSession(
          mode: FocusSessionMode.standard,
          startedAtMs: 1000,
        ),
        throwsA(isA<SqliteException>()),
      );

      expect(await repository.getHistory(), hasLength(1));
    });

    test(
      'pause and resume persist intervals and exclude paused time',
      () async {
        final started = await _start(repository);
        final paused = await repository.pauseSession(
          started.session.id,
          atMs: 1500,
        );

        expect(paused.session.status, FocusSessionStatus.paused);
        expect(paused.intervals.single.endedAtMs, 1500);
        expect(
          (await repository.getUnresolvedSession())?.session.status,
          FocusSessionStatus.paused,
        );

        final resumed = await repository.resumeSession(
          started.session.id,
          atMs: 2000,
        );
        expect(resumed.session.status, FocusSessionStatus.running);
        expect(resumed.intervals, hasLength(2));
        expect(resumed.intervals.last.isOpen, isTrue);

        final completed = await repository.completeSession(
          started.session.id,
          atMs: 3000,
        );
        expect(completed.session.status, FocusSessionStatus.completed);
        expect(completed.session.actualDurationMs, 1500);
        expect(completed.intervals.map((interval) => interval.endedAtMs), [
          1500,
          3000,
        ]);
        expect(await repository.getUnresolvedSession(), isNull);
      },
    );

    test('supports pause and resume at the same millisecond', () async {
      final started = await _start(repository);
      await repository.pauseSession(started.session.id, atMs: 1000);
      await repository.resumeSession(started.session.id, atMs: 1000);

      final completed = await repository.completeSession(
        started.session.id,
        atMs: 1001,
      );

      expect(completed.session.actualDurationMs, 1);
      expect(completed.intervals.map((interval) => interval.startedAtMs), [
        1000,
        1000,
      ]);
      expect(completed.intervals.map((interval) => interval.endedAtMs), [
        1000,
        1001,
      ]);
    });

    test(
      'allows early completion and persists interval-derived duration',
      () async {
        final started = await repository.startSession(
          mode: FocusSessionMode.custom,
          startedAtMs: 1000,
          plannedDurationMs: 10_000,
        );

        final completed = await repository.completeSession(
          started.session.id,
          atMs: 1250,
        );

        expect(completed.session.status, FocusSessionStatus.completed);
        expect(completed.session.actualDurationMs, 250);
      },
    );

    test(
      'finishes a paused session without creating or closing intervals',
      () async {
        final started = await _start(repository);
        await repository.pauseSession(started.session.id, atMs: 1500);

        final cancelled = await repository.cancelSession(
          started.session.id,
          atMs: 2000,
        );

        expect(cancelled.session.status, FocusSessionStatus.cancelled);
        expect(cancelled.session.actualDurationMs, 500);
        expect(cancelled.session.endedAtMs, 2000);
        expect(cancelled.intervals, hasLength(1));
        expect(cancelled.intervals.single.endedAtMs, 1500);
      },
    );

    test('interrupts a running session and closes its interval', () async {
      final started = await _start(repository);

      final interrupted = await repository.interruptSession(
        started.session.id,
        atMs: 1800,
      );

      expect(interrupted.session.status, FocusSessionStatus.interrupted);
      expect(interrupted.session.actualDurationMs, 800);
      expect(interrupted.intervals.single.endedAtMs, 1800);
    });

    test('only one running or paused session can exist globally', () async {
      final first = await _start(repository);
      await repository.pauseSession(first.session.id, atMs: 1200);

      await expectLater(
        _start(repository),
        throwsA(
          isA<FocusSessionAlreadyUnresolvedException>().having(
            (error) => error.sessionId,
            'sessionId',
            first.session.id,
          ),
        ),
      );
      expect(await repository.getHistory(), hasLength(1));

      await repository.cancelSession(first.session.id, atMs: 1500);
      final second = await _start(repository, startedAtMs: 2000);
      expect(second.session.id, isNot(first.session.id));
    });

    test(
      'terminal session history cannot be changed by lifecycle operations',
      () async {
        final started = await _start(repository);
        final completed = await repository.completeSession(
          started.session.id,
          atMs: 1500,
        );

        await expectLater(
          repository.pauseSession(started.session.id, atMs: 1600),
          throwsStateError,
        );
        await expectLater(
          repository.resumeSession(started.session.id, atMs: 1600),
          throwsStateError,
        );
        await expectLater(
          repository.completeSession(started.session.id, atMs: 1600),
          throwsStateError,
        );
        await expectLater(
          repository.cancelSession(started.session.id, atMs: 1600),
          throwsStateError,
        );
        await expectLater(
          repository.interruptSession(started.session.id, atMs: 1600),
          throwsStateError,
        );

        final persisted = await repository.getById(started.session.id);
        expect(persisted?.session, completed.session);
        expect(persisted?.intervals, completed.intervals);
      },
    );

    test('rejects invalid transition times without partial writes', () async {
      final started = await _start(repository);

      await expectLater(
        repository.pauseSession(started.session.id, atMs: 999),
        throwsA(isA<ArgumentError>()),
      );

      final persisted = await repository.getById(started.session.id);
      expect(persisted?.session, started.session);
      expect(persisted?.intervals, started.intervals);
      expect(persisted!.intervals.single.isOpen, isTrue);
    });

    test(
      'getHistory orders sessions newest first with a stable tie break',
      () async {
        final older = await _start(repository, startedAtMs: 1000);
        await repository.completeSession(older.session.id, atMs: 1100);
        final tied = await _start(repository, startedAtMs: 1000);
        await repository.completeSession(tied.session.id, atMs: 1100);

        final history = await repository.getHistory();

        expect(history.map((entry) => entry.session.startedAtMs), [1000, 1000]);
        expect(history.map((entry) => entry.session.id), [
          if (older.session.id.compareTo(tied.session.id) > 0)
            older.session.id
          else
            tied.session.id,
          if (older.session.id.compareTo(tied.session.id) > 0)
            tied.session.id
          else
            older.session.id,
        ]);
      },
    );

    test('task deletion clears only the live task link', () async {
      await TaskRepository(database).insert(_task(id: 'task-delete'));
      final started = await repository.startSession(
        taskId: 'task-delete',
        mode: FocusSessionMode.standard,
        startedAtMs: 1000,
      );

      await TaskRepository(database).delete('task-delete');

      final persisted = await repository.getById(started.session.id);
      expect(persisted!.session.taskId, isNull);
      expect(persisted.session.taskIdSnapshot, 'task-delete');
      expect(persisted.session.taskTitleSnapshot, 'Task title');
    });

    test(
      'rejects persisted sessions whose intervals violate state invariants',
      () async {
        await database
            .into(database.focusSessions)
            .insert(
              FocusSessionsCompanion.insert(
                id: 'corrupt-session',
                mode: FocusSessionMode.standard,
                status: FocusSessionStatus.running,
                startedAtMs: 1000,
                updatedAtMs: 1000,
              ),
            );

        await expectLater(
          repository.getById('corrupt-session'),
          throwsA(isA<FocusSessionIntegrityException>()),
        );
      },
    );

    test('retrieval returns null for a missing session', () async {
      expect(await repository.getById('missing'), isNull);
      expect(await repository.getUnresolvedSession(), isNull);
    });
  });
}

Future<FocusSessionTransition> _start(
  FocusRepository repository, {
  int startedAtMs = 1000,
}) {
  return repository.startSession(
    mode: FocusSessionMode.standard,
    startedAtMs: startedAtMs,
  );
}

Task _task({required String id, String title = 'Task title'}) => Task(
  id: id,
  title: title,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
);

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
