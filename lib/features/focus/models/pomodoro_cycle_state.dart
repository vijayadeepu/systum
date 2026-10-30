import 'focus_session.dart';
import 'focus_session_mode.dart';
import 'focus_session_status.dart';
import 'pomodoro_settings.dart';

/// State reconstructed from persisted Focus sessions; it has no independent
/// timer or cycle record.
final class PomodoroCycleState {
  const PomodoroCycleState({
    required this.cycleId,
    required this.lastSession,
    required this.round,
    required this.nextMode,
    required this.nextRound,
    required this.nextPlannedDurationMs,
    required this.activeNextSegmentLabel,
    required this.isComplete,
    required this.requiresRecovery,
    required this.taskId,
    required this.taskIdSnapshot,
    required this.taskTitleSnapshot,
  });

  final String cycleId;
  final FocusSessionTransition lastSession;
  final int round;
  final FocusSessionMode? nextMode;
  final int nextRound;
  final int? nextPlannedDurationMs;
  final String? activeNextSegmentLabel;
  final bool isComplete;
  final bool requiresRecovery;
  final String? taskId;
  final String? taskIdSnapshot;
  final String? taskTitleSnapshot;

  bool get isActive => !lastSession.session.status.isTerminal;

  static PomodoroCycleState? fromHistory(
    Iterable<FocusSessionTransition> history, {
    required PomodoroSettings settings,
    Iterable<String> dismissedCycleIds = const [],
  }) {
    final dismissed = dismissedCycleIds.toSet();
    final sessionsByCycle = <String, List<FocusSessionTransition>>{};
    for (final entry in history) {
      final cycleId = entry.session.cycleId;
      if (cycleId == null || dismissed.contains(cycleId)) continue;
      sessionsByCycle.putIfAbsent(cycleId, () => []).add(entry);
    }
    if (sessionsByCycle.isEmpty) return null;

    String? cycleId;
    List<FocusSessionTransition>? sessions;
    for (final candidate in sessionsByCycle.entries) {
      candidate.value.sort(_compareProgression);
      if (sessions == null ||
          _compareCycles(
                candidate.key,
                candidate.value.last,
                cycleId!,
                sessions.last,
              ) >
              0) {
        cycleId = candidate.key;
        sessions = candidate.value;
      }
    }

    final currentSessions = sessions!;
    final last = currentSessions.last;
    final session = last.session;
    final lastFocus = currentSessions.lastWhere(
      (entry) => entry.session.mode == FocusSessionMode.pomodoro,
      orElse: () => last,
    );

    FocusSessionMode? nextMode;
    var nextRound = session.cycleRound!;
    var isComplete = false;
    var requiresRecovery = false;
    if (session.status == FocusSessionStatus.completed) {
      switch (session.mode) {
        case FocusSessionMode.pomodoro:
          nextMode =
              session.cycleRound == PomodoroSettings.focusRoundsBeforeLongBreak
              ? FocusSessionMode.longBreak
              : FocusSessionMode.shortBreak;
        case FocusSessionMode.shortBreak:
          nextMode = FocusSessionMode.pomodoro;
          nextRound++;
        case FocusSessionMode.longBreak:
          isComplete = true;
        case FocusSessionMode.standard:
        case FocusSessionMode.custom:
          throw StateError('A cycle session has an unsupported mode.');
      }
    } else if (session.status.isTerminal) {
      nextMode = session.mode;
      requiresRecovery = true;
    }

    final nextDurationMs = switch (nextMode) {
      FocusSessionMode.pomodoro => settings.focusDurationMs,
      FocusSessionMode.shortBreak => settings.shortBreakDurationMs,
      FocusSessionMode.longBreak => settings.longBreakDurationMs,
      _ => null,
    };
    final activeNextSegmentLabel = switch (session.mode) {
      FocusSessionMode.pomodoro =>
        session.cycleRound == PomodoroSettings.focusRoundsBeforeLongBreak
            ? 'Next after focus: Long break'
            : 'Next after focus: Short break',
      FocusSessionMode.shortBreak =>
        'Next after break: Focus round ${session.cycleRound! + 1}',
      FocusSessionMode.longBreak => 'Next after break: New cycle',
      FocusSessionMode.standard || FocusSessionMode.custom => throw StateError(
        'A cycle session has an unsupported mode.',
      ),
    };

    return PomodoroCycleState(
      cycleId: cycleId!,
      lastSession: last,
      round: session.cycleRound!,
      nextMode: nextMode,
      nextRound: nextRound,
      nextPlannedDurationMs: nextDurationMs,
      activeNextSegmentLabel: session.status.isTerminal
          ? null
          : activeNextSegmentLabel,
      isComplete: isComplete,
      requiresRecovery: requiresRecovery,
      taskId: lastFocus.session.taskId,
      taskIdSnapshot: lastFocus.session.taskIdSnapshot,
      taskTitleSnapshot: lastFocus.session.taskTitleSnapshot,
    );
  }

  static int _compareCycles(
    String firstId,
    FocusSessionTransition first,
    String secondId,
    FocusSessionTransition second,
  ) {
    final byStart = first.session.startedAtMs.compareTo(
      second.session.startedAtMs,
    );
    if (byStart != 0) return byStart;
    final firstActive = !first.session.status.isTerminal;
    final secondActive = !second.session.status.isTerminal;
    if (firstActive != secondActive) return firstActive ? 1 : -1;
    final firstComplete =
        first.session.mode == FocusSessionMode.longBreak &&
        first.session.status == FocusSessionStatus.completed;
    final secondComplete =
        second.session.mode == FocusSessionMode.longBreak &&
        second.session.status == FocusSessionStatus.completed;
    if (firstComplete != secondComplete) return firstComplete ? -1 : 1;
    return firstId.compareTo(secondId);
  }

  static int _compareProgression(
    FocusSessionTransition first,
    FocusSessionTransition second,
  ) {
    final byRound = first.session.cycleRound!.compareTo(
      second.session.cycleRound!,
    );
    if (byRound != 0) return byRound;
    final bySegment = _segmentOrder(
      first.session.mode,
    ).compareTo(_segmentOrder(second.session.mode));
    if (bySegment != 0) return bySegment;
    final byStart = first.session.startedAtMs.compareTo(
      second.session.startedAtMs,
    );
    if (byStart != 0) return byStart;
    final byUpdate = first.session.updatedAtMs.compareTo(
      second.session.updatedAtMs,
    );
    if (byUpdate != 0) return byUpdate;
    final firstActive = !first.session.status.isTerminal;
    final secondActive = !second.session.status.isTerminal;
    if (firstActive != secondActive) return firstActive ? 1 : -1;
    return first.session.id.compareTo(second.session.id);
  }

  static int _segmentOrder(FocusSessionMode mode) => switch (mode) {
    FocusSessionMode.pomodoro => 0,
    FocusSessionMode.shortBreak => 1,
    FocusSessionMode.longBreak => 2,
    FocusSessionMode.standard || FocusSessionMode.custom => throw StateError(
      'A cycle session has an unsupported mode.',
    ),
  };
}
