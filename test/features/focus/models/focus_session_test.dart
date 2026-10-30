import 'package:flutter_test/flutter_test.dart';
import 'package:systum/features/focus/models/focus_session.dart';
import 'package:systum/features/focus/models/focus_session_interval.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/models/focus_session_status.dart';

void main() {
  group('FocusSession', () {
    test('exposes all supported modes and terminal states', () {
      expect(FocusSessionMode.values, hasLength(5));
      expect(FocusSessionMode.shortBreak.isBreak, isTrue);
      expect(FocusSessionMode.longBreak.isBreak, isTrue);
      expect(FocusSessionMode.pomodoro.isBreak, isFalse);
      expect(FocusSessionStatus.running.isTerminal, isFalse);
      expect(FocusSessionStatus.paused.isTerminal, isFalse);
      expect(FocusSessionStatus.completed.isTerminal, isTrue);
      expect(FocusSessionStatus.interrupted.isTerminal, isTrue);
      expect(FocusSessionStatus.cancelled.isTerminal, isTrue);
    });

    test('start creates a running session and exactly one open interval', () {
      final started = FocusSession.start(
        id: 'session-1',
        taskId: 'task-1',
        taskIdSnapshot: 'task-1',
        taskTitleSnapshot: 'Write tests',
        mode: FocusSessionMode.pomodoro,
        startedAtMs: 1_000,
        plannedDurationMs: 25 * 60 * 1000,
        cycleId: 'cycle-1',
        cycleRound: 1,
      );

      expect(started.session.status, FocusSessionStatus.running);
      expect(started.session.startedAtMs, 1_000);
      expect(started.session.updatedAtMs, 1_000);
      expect(started.session.taskTitleSnapshot, 'Write tests');
      expect(started.session.cycleId, 'cycle-1');
      expect(started.intervals, [
        FocusSessionInterval(sessionId: 'session-1', startedAtMs: 1_000),
      ]);
    });

    test('pause closes the running interval and excludes the paused gap', () {
      final started = _start();
      final paused = started.session.pause(
        intervals: started.intervals,
        atMs: 1_500,
      );

      expect(paused.session.status, FocusSessionStatus.paused);
      expect(paused.session.updatedAtMs, 1_500);
      expect(paused.session.actualDurationMs, isNull);
      expect(paused.intervals.single.endedAtMs, 1_500);
    });

    test('resume starts a new interval without counting the paused gap', () {
      final started = _start();
      final paused = started.session.pause(
        intervals: started.intervals,
        atMs: 1_500,
      );
      final resumed = paused.session.resume(
        intervals: paused.intervals,
        atMs: 5_000,
      );

      expect(resumed.session.status, FocusSessionStatus.running);
      expect(resumed.intervals, [
        FocusSessionInterval(
          sessionId: 'session-1',
          startedAtMs: 1_000,
          endedAtMs: 1_500,
        ),
        FocusSessionInterval(sessionId: 'session-1', startedAtMs: 5_000),
      ]);
    });

    test('complete finalizes active duration across multiple intervals', () {
      final started = _start();
      final paused = started.session.pause(
        intervals: started.intervals,
        atMs: 1_500,
      );
      final resumed = paused.session.resume(
        intervals: paused.intervals,
        atMs: 5_000,
      );
      final completed = resumed.session.complete(
        intervals: resumed.intervals,
        atMs: 5_600,
      );

      expect(completed.session.status, FocusSessionStatus.completed);
      expect(completed.session.endedAtMs, 5_600);
      expect(completed.session.updatedAtMs, 5_600);
      expect(completed.session.actualDurationMs, 1_100);
      expect(completed.intervals.every((interval) => !interval.isOpen), isTrue);
    });

    test('complete while paused finalizes without adding paused time', () {
      final started = _start();
      final paused = started.session.pause(
        intervals: started.intervals,
        atMs: 1_500,
      );
      final completed = paused.session.complete(
        intervals: paused.intervals,
        atMs: 10_000,
      );

      expect(completed.session.actualDurationMs, 500);
      expect(completed.session.endedAtMs, 10_000);
      expect(completed.intervals.every((interval) => !interval.isOpen), isTrue);
    });

    test(
      'a timed session can complete early with recorded active duration',
      () {
        final started = FocusSession.start(
          id: 'session-1',
          mode: FocusSessionMode.pomodoro,
          startedAtMs: 1_000,
          plannedDurationMs: 25 * 60 * 1000,
        );
        final completed = started.session.complete(
          intervals: started.intervals,
          atMs: 1_500,
        );

        expect(completed.session.status, FocusSessionStatus.completed);
        expect(completed.session.actualDurationMs, 500);
        expect(completed.session.actualDurationMs, isNot(25 * 60 * 1000));
        expect(completed.intervals.single.endedAtMs, 1_500);
      },
    );

    for (final (label, transition, status) in [
      (
        'cancel',
        (FocusSession session, List<FocusSessionInterval> intervals) =>
            session.cancel(intervals: intervals, atMs: 2_000),
        FocusSessionStatus.cancelled,
      ),
      (
        'interrupt',
        (FocusSession session, List<FocusSessionInterval> intervals) =>
            session.interrupt(intervals: intervals, atMs: 2_000),
        FocusSessionStatus.interrupted,
      ),
    ]) {
      test('$label finalizes a running interval', () {
        final started = _start();
        final result = transition(started.session, started.intervals);

        expect(result.session.status, status);
        expect(result.session.actualDurationMs, 1_000);
        expect(result.session.endedAtMs, 2_000);
        expect(result.intervals.single.isOpen, isFalse);
      });
    }

    test('crash recovery leaves a running session running', () {
      final started = _start();

      expect(started.session.status, FocusSessionStatus.running);
      expect(started.intervals.single.isOpen, isTrue);
    });

    test('rejects invalid transitions and a backward transition time', () {
      final started = _start();

      expect(
        () => started.session.resume(intervals: started.intervals, atMs: 2_000),
        throwsStateError,
      );
      expect(
        () => started.session.pause(intervals: started.intervals, atMs: 999),
        throwsArgumentError,
      );
      final completed = started.session.complete(
        intervals: started.intervals,
        atMs: 2_000,
      );
      expect(
        () => completed.session.cancel(
          intervals: completed.intervals,
          atMs: 3_000,
        ),
        throwsStateError,
      );
    });

    test('rejects intervals that do not belong to this session', () {
      final started = _start();

      expect(
        () => FocusSessionTransition(
          session: started.session,
          intervals: [
            FocusSessionInterval(sessionId: 'other', startedAtMs: 1_000),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects an interval starting before a running session', () {
      final started = _start();

      expect(
        () => FocusSessionTransition(
          session: started.session,
          intervals: [
            FocusSessionInterval(
              sessionId: started.session.id,
              startedAtMs: 999,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid session and interval data', () {
      expect(
        () => FocusSessionInterval(
          sessionId: 'session-1',
          startedAtMs: 100,
          endedAtMs: 99,
        ),
        throwsArgumentError,
      );
      expect(
        () => FocusSession.start(
          id: 'session-1',
          mode: FocusSessionMode.custom,
          startedAtMs: 100,
          plannedDurationMs: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => FocusSession.start(
          id: 'session-1',
          mode: FocusSessionMode.custom,
          startedAtMs: 100,
          cycleRound: 1,
        ),
        throwsArgumentError,
      );
    });

    test('terminal intervals cannot extend beyond the session end', () {
      final session = FocusSession(
        id: 'session-1',
        mode: FocusSessionMode.standard,
        status: FocusSessionStatus.completed,
        startedAtMs: 100,
        endedAtMs: 500,
        actualDurationMs: 500,
        updatedAtMs: 600,
      );

      expect(
        () => FocusSessionTransition(
          session: session,
          intervals: [
            FocusSessionInterval(
              sessionId: 'session-1',
              startedAtMs: 100,
              endedAtMs: 600,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('terminal intervals cannot start before the session start', () {
      final session = FocusSession(
        id: 'session-1',
        mode: FocusSessionMode.standard,
        status: FocusSessionStatus.completed,
        startedAtMs: 100,
        endedAtMs: 500,
        actualDurationMs: 400,
        updatedAtMs: 500,
      );

      expect(
        () => FocusSessionTransition(
          session: session,
          intervals: [
            FocusSessionInterval(
              sessionId: 'session-1',
              startedAtMs: 0,
              endedAtMs: 400,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}

FocusSessionTransition _start() => FocusSession.start(
  id: 'session-1',
  taskId: null,
  mode: FocusSessionMode.standard,
  startedAtMs: 1_000,
);
