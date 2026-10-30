import 'package:flutter_test/flutter_test.dart';
import 'package:systum/features/focus/models/focus_session.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/models/focus_session_status.dart';
import 'package:systum/features/focus/models/pomodoro_cycle_state.dart';
import 'package:systum/features/focus/models/pomodoro_settings.dart';

void main() {
  final settings = PomodoroSettings(
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
  );

  test('advances focus, short breaks, and long break through four rounds', () {
    final history = <FocusSessionTransition>[];
    for (var round = 1; round <= 4; round++) {
      history.add(
        _transition(
          id: 'focus-$round',
          mode: FocusSessionMode.pomodoro,
          round: round,
          startedAtMs: round * 1000,
          status: FocusSessionStatus.completed,
        ),
      );
      final afterFocus = PomodoroCycleState.fromHistory(
        history,
        settings: settings,
      )!;
      expect(afterFocus.round, round);
      expect(
        afterFocus.nextMode,
        round == 4 ? FocusSessionMode.longBreak : FocusSessionMode.shortBreak,
      );
      expect(afterFocus.nextRound, round);

      if (round < 4) {
        history.add(
          _transition(
            id: 'short-$round',
            mode: FocusSessionMode.shortBreak,
            round: round,
            startedAtMs: round * 1000 + 500,
            status: FocusSessionStatus.completed,
          ),
        );
        final afterBreak = PomodoroCycleState.fromHistory(
          history,
          settings: settings,
        )!;
        expect(afterBreak.nextMode, FocusSessionMode.pomodoro);
        expect(afterBreak.nextRound, round + 1);
      }
    }

    history.add(
      _transition(
        id: 'long-4',
        mode: FocusSessionMode.longBreak,
        round: 4,
        startedAtMs: 4500,
        status: FocusSessionStatus.completed,
      ),
    );
    final complete = PomodoroCycleState.fromHistory(
      history,
      settings: settings,
    )!;
    expect(complete.isComplete, isTrue);
    expect(complete.nextMode, isNull);
  });

  test('cancelled or interrupted focus does not advance its round', () {
    for (final status in [
      FocusSessionStatus.cancelled,
      FocusSessionStatus.interrupted,
    ]) {
      final cycle = PomodoroCycleState.fromHistory([
        _transition(
          id: 'focus-$status',
          mode: FocusSessionMode.pomodoro,
          round: 2,
          startedAtMs: 1000,
          status: status,
        ),
      ], settings: settings)!;

      expect(cycle.nextMode, FocusSessionMode.pomodoro);
      expect(cycle.nextRound, 2);
      expect(cycle.requiresRecovery, isTrue);
    }
  });

  test('cancelled break requires retry and retains its focus round', () {
    final cycle = PomodoroCycleState.fromHistory([
      _transition(
        id: 'focus-1',
        mode: FocusSessionMode.pomodoro,
        round: 1,
        startedAtMs: 1000,
        status: FocusSessionStatus.completed,
      ),
      _transition(
        id: 'short-1',
        mode: FocusSessionMode.shortBreak,
        round: 1,
        startedAtMs: 2000,
        status: FocusSessionStatus.cancelled,
      ),
    ], settings: settings)!;

    expect(cycle.nextMode, FocusSessionMode.shortBreak);
    expect(cycle.nextRound, 1);
    expect(cycle.requiresRecovery, isTrue);
  });

  test('a dismissed cycle is not recovered after reopening', () {
    final cycle = PomodoroCycleState.fromHistory(
      [
        _transition(
          id: 'focus-1',
          mode: FocusSessionMode.pomodoro,
          round: 1,
          startedAtMs: 1000,
          status: FocusSessionStatus.completed,
        ),
      ],
      settings: settings,
      dismissedCycleIds: ['cycle-1'],
    );

    expect(cycle, isNull);
  });

  test('running cycle exposes current round and next segment', () {
    final cycle = PomodoroCycleState.fromHistory([
      _transition(
        id: 'focus-1',
        mode: FocusSessionMode.pomodoro,
        round: 1,
        startedAtMs: 1000,
        status: FocusSessionStatus.running,
      ),
    ], settings: settings)!;

    expect(cycle.isActive, isTrue);
    expect(cycle.round, 1);
    expect(cycle.activeNextSegmentLabel, 'Next after focus: Short break');
  });
}

FocusSessionTransition _transition({
  required String id,
  required FocusSessionMode mode,
  required int round,
  required int startedAtMs,
  required FocusSessionStatus status,
}) {
  var transition = FocusSession.start(
    id: id,
    mode: mode,
    startedAtMs: startedAtMs,
    plannedDurationMs: 1000,
    cycleId: 'cycle-1',
    cycleRound: round,
  );
  if (status == FocusSessionStatus.completed) {
    transition = transition.session.complete(
      intervals: transition.intervals,
      atMs: startedAtMs + 100,
    );
  } else if (status == FocusSessionStatus.cancelled) {
    transition = transition.session.cancel(
      intervals: transition.intervals,
      atMs: startedAtMs + 100,
    );
  } else if (status == FocusSessionStatus.interrupted) {
    transition = transition.session.interrupt(
      intervals: transition.intervals,
      atMs: startedAtMs + 100,
    );
  }
  return transition;
}
