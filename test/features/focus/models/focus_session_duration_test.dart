import 'package:flutter_test/flutter_test.dart';
import 'package:systum/features/focus/models/focus_session.dart';
import 'package:systum/features/focus/models/focus_session_duration.dart';
import 'package:systum/features/focus/models/focus_session_interval.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';

void main() {
  group('FocusSessionDuration', () {
    test('sums only running intervals and excludes paused gaps', () {
      final intervals = [_closed(100, 200), _closed(300, 350), _open(400)];

      expect(
        FocusSessionDuration.elapsedActiveMilliseconds(
          intervals: intervals,
          atMs: 500,
        ),
        250,
      );
    });

    test('supports zero-length and pre-epoch intervals', () {
      expect(
        FocusSessionDuration.elapsedActiveMilliseconds(
          intervals: [_closed(-200, -100), _closed(0, 0)],
          atMs: 0,
        ),
        100,
      );
    });

    test('rejects unordered and overlapping intervals', () {
      expect(
        () => FocusSessionDuration.elapsedActiveMilliseconds(
          intervals: [_closed(200, 300), _closed(100, 150)],
          atMs: 300,
        ),
        throwsArgumentError,
      );
      expect(
        () => FocusSessionDuration.elapsedActiveMilliseconds(
          intervals: [_closed(100, 250), _closed(200, 300)],
          atMs: 300,
        ),
        throwsArgumentError,
      );
    });

    test(
      'rejects multiple open intervals and times before an interval end',
      () {
        expect(
          () => FocusSessionDuration.elapsedActiveMilliseconds(
            intervals: [_open(100), _open(200)],
            atMs: 300,
          ),
          throwsArgumentError,
        );
        expect(
          () => FocusSessionDuration.elapsedActiveMilliseconds(
            intervals: [_closed(100, 250)],
            atMs: 200,
          ),
          throwsArgumentError,
        );
      },
    );

    test('timed sessions become eligible at or beyond planned active time', () {
      final started = _start(plannedDurationMs: 1000);
      final paused = started.session.pause(
        intervals: started.intervals,
        atMs: 600,
      );
      final resumed = paused.session.resume(
        intervals: paused.intervals,
        atMs: 10_000,
      );

      expect(
        FocusSessionDuration.canCompleteByDuration(
          session: resumed.session,
          intervals: resumed.intervals,
          atMs: 10_499,
        ),
        isFalse,
      );
      expect(
        FocusSessionDuration.canCompleteByDuration(
          session: resumed.session,
          intervals: resumed.intervals,
          atMs: 10_500,
        ),
        isTrue,
      );
    });

    test('eligibility rejects intervals belonging to another session', () {
      final started = _start(plannedDurationMs: 1000);

      expect(
        () => FocusSessionDuration.canCompleteByDuration(
          session: started.session,
          intervals: [_open(100, sessionId: 'another-session')],
          atMs: 2_000,
        ),
        throwsArgumentError,
      );
    });

    test('eligibility rejects an open interval for a paused session', () {
      final started = _start(plannedDurationMs: 1000);
      final paused = started.session.pause(
        intervals: started.intervals,
        atMs: 500,
      );

      expect(
        () => FocusSessionDuration.canCompleteByDuration(
          session: paused.session,
          intervals: [_open(100)],
          atMs: 2_000,
        ),
        throwsArgumentError,
      );
    });

    test('untimed and terminal sessions are not duration-completable', () {
      final untimed = _start();
      final completed = untimed.session.complete(
        intervals: untimed.intervals,
        atMs: 200,
      );

      expect(
        FocusSessionDuration.canCompleteByDuration(
          session: untimed.session,
          intervals: untimed.intervals,
          atMs: 200,
        ),
        isFalse,
      );
      expect(
        FocusSessionDuration.canCompleteByDuration(
          session: completed.session,
          intervals: completed.intervals,
          atMs: 200,
        ),
        isFalse,
      );
    });
  });
}

FocusSessionInterval _closed(int startMs, int endMs) => FocusSessionInterval(
  sessionId: 'session',
  startedAtMs: startMs,
  endedAtMs: endMs,
);

FocusSessionInterval _open(int startMs, {String sessionId = 'session'}) =>
    FocusSessionInterval(sessionId: sessionId, startedAtMs: startMs);

FocusSessionTransition _start({int? plannedDurationMs}) => FocusSession.start(
  id: 'session',
  mode: FocusSessionMode.pomodoro,
  startedAtMs: 100,
  plannedDurationMs: plannedDurationMs,
);
