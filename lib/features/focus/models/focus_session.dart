import 'focus_session_duration.dart';
import 'focus_session_interval.dart';
import 'focus_session_mode.dart';
import 'focus_session_status.dart';

/// A persisted focus or break segment.
///
/// Timestamps are UTC epoch milliseconds. Elapsed duration is derived from
/// [FocusSessionInterval] records, not from UI timer ticks.
final class FocusSession {
  FocusSession({
    required this.id,
    this.taskId,
    this.taskIdSnapshot,
    this.taskTitleSnapshot,
    required this.mode,
    required this.status,
    required this.startedAtMs,
    this.endedAtMs,
    this.plannedDurationMs,
    this.actualDurationMs,
    this.cycleId,
    this.cycleRound,
    required this.updatedAtMs,
  }) {
    if (plannedDurationMs != null && plannedDurationMs! < 0) {
      throw ArgumentError.value(
        plannedDurationMs,
        'plannedDurationMs',
        'Must not be negative.',
      );
    }
    if (actualDurationMs != null && actualDurationMs! < 0) {
      throw ArgumentError.value(
        actualDurationMs,
        'actualDurationMs',
        'Must not be negative.',
      );
    }
    if (updatedAtMs < startedAtMs) {
      throw ArgumentError.value(
        updatedAtMs,
        'updatedAtMs',
        'Must not precede startedAtMs.',
      );
    }
    if ((cycleId == null) != (cycleRound == null)) {
      throw ArgumentError(
        'cycleId and cycleRound must either both be set or both be null.',
      );
    }
    if (cycleRound != null && cycleRound! < 1) {
      throw ArgumentError.value(cycleRound, 'cycleRound', 'Must be positive.');
    }

    if (status.isTerminal) {
      if (endedAtMs == null || actualDurationMs == null) {
        throw ArgumentError(
          'Terminal sessions require endedAtMs and actualDurationMs.',
        );
      }
      if (endedAtMs! < startedAtMs || endedAtMs! > updatedAtMs) {
        throw ArgumentError.value(
          endedAtMs,
          'endedAtMs',
          'Must be between startedAtMs and updatedAtMs.',
        );
      }
    } else if (endedAtMs != null || actualDurationMs != null) {
      throw ArgumentError(
        'Non-terminal sessions cannot have endedAtMs or actualDurationMs.',
      );
    }
  }

  final String id;
  final String? taskId;
  final String? taskIdSnapshot;
  final String? taskTitleSnapshot;
  final FocusSessionMode mode;
  final FocusSessionStatus status;
  final int startedAtMs;
  final int? endedAtMs;
  final int? plannedDurationMs;
  final int? actualDurationMs;
  final String? cycleId;
  final int? cycleRound;
  final int updatedAtMs;

  static FocusSessionTransition start({
    required String id,
    String? taskId,
    String? taskIdSnapshot,
    String? taskTitleSnapshot,
    required FocusSessionMode mode,
    required int startedAtMs,
    int? plannedDurationMs,
    String? cycleId,
    int? cycleRound,
  }) {
    final session = FocusSession(
      id: id,
      taskId: taskId,
      taskIdSnapshot: taskIdSnapshot,
      taskTitleSnapshot: taskTitleSnapshot,
      mode: mode,
      status: FocusSessionStatus.running,
      startedAtMs: startedAtMs,
      plannedDurationMs: plannedDurationMs,
      cycleId: cycleId,
      cycleRound: cycleRound,
      updatedAtMs: startedAtMs,
    );
    return FocusSessionTransition(
      session: session,
      intervals: [
        FocusSessionInterval(sessionId: id, startedAtMs: startedAtMs),
      ],
    );
  }

  FocusSessionTransition pause({
    required Iterable<FocusSessionInterval> intervals,
    required int atMs,
  }) {
    _requireStatus(FocusSessionStatus.running);
    _requireTransitionTime(atMs);
    final current = _validateIntervals(intervals, atMs: atMs);
    final openInterval = current.last;
    if (!openInterval.isOpen) {
      throw StateError('A running session must have an open interval.');
    }
    return FocusSessionTransition(
      session: _copy(status: FocusSessionStatus.paused, updatedAtMs: atMs),
      intervals: [
        ...current.take(current.length - 1),
        openInterval.closeAt(atMs),
      ],
    );
  }

  FocusSessionTransition resume({
    required Iterable<FocusSessionInterval> intervals,
    required int atMs,
  }) {
    _requireStatus(FocusSessionStatus.paused);
    _requireTransitionTime(atMs);
    final current = _validateIntervals(intervals, atMs: atMs);
    if (current.any((interval) => interval.isOpen)) {
      throw StateError('A paused session cannot have an open interval.');
    }
    return FocusSessionTransition(
      session: _copy(status: FocusSessionStatus.running, updatedAtMs: atMs),
      intervals: [
        ...current,
        FocusSessionInterval(sessionId: id, startedAtMs: atMs),
      ],
    );
  }

  FocusSessionTransition complete({
    required Iterable<FocusSessionInterval> intervals,
    required int atMs,
  }) => _finish(
    intervals: intervals,
    atMs: atMs,
    status: FocusSessionStatus.completed,
  );

  FocusSessionTransition cancel({
    required Iterable<FocusSessionInterval> intervals,
    required int atMs,
  }) => _finish(
    intervals: intervals,
    atMs: atMs,
    status: FocusSessionStatus.cancelled,
  );

  FocusSessionTransition interrupt({
    required Iterable<FocusSessionInterval> intervals,
    required int atMs,
  }) => _finish(
    intervals: intervals,
    atMs: atMs,
    status: FocusSessionStatus.interrupted,
  );

  FocusSessionTransition _finish({
    required Iterable<FocusSessionInterval> intervals,
    required int atMs,
    required FocusSessionStatus status,
  }) {
    if (this.status.isTerminal) {
      throw StateError('Terminal sessions cannot transition.');
    }
    _requireTransitionTime(atMs);
    final current = _validateIntervals(intervals, atMs: atMs);
    final closedIntervals = this.status == FocusSessionStatus.running
        ? [...current.take(current.length - 1), current.last.closeAt(atMs)]
        : current;
    if (this.status == FocusSessionStatus.running && !current.last.isOpen) {
      throw StateError('A running session must have an open interval.');
    }
    if (this.status == FocusSessionStatus.paused &&
        current.any((interval) => interval.isOpen)) {
      throw StateError('A paused session cannot have an open interval.');
    }

    final actualDurationMs = FocusSessionDuration.elapsedActiveMilliseconds(
      intervals: closedIntervals,
      atMs: atMs,
    );
    return FocusSessionTransition(
      session: _copy(
        status: status,
        endedAtMs: atMs,
        actualDurationMs: actualDurationMs,
        updatedAtMs: atMs,
      ),
      intervals: closedIntervals,
    );
  }

  List<FocusSessionInterval> _validateIntervals(
    Iterable<FocusSessionInterval> intervals, {
    required int atMs,
  }) {
    final result = List<FocusSessionInterval>.unmodifiable(intervals);
    if (result.isEmpty || result.any((interval) => interval.sessionId != id)) {
      throw ArgumentError('Intervals must belong to this session.');
    }
    FocusSessionDuration.elapsedActiveMilliseconds(
      intervals: result,
      atMs: atMs,
    );
    return result;
  }

  void _requireStatus(FocusSessionStatus requiredStatus) {
    if (status != requiredStatus) {
      throw StateError(
        'Cannot transition a $status session; expected $requiredStatus.',
      );
    }
  }

  void _requireTransitionTime(int atMs) {
    if (atMs < updatedAtMs) {
      throw ArgumentError.value(
        atMs,
        'atMs',
        'Must not precede the previous session transition.',
      );
    }
  }

  FocusSession _copy({
    required FocusSessionStatus status,
    required int updatedAtMs,
    int? endedAtMs,
    int? actualDurationMs,
  }) {
    return FocusSession(
      id: id,
      taskId: taskId,
      taskIdSnapshot: taskIdSnapshot,
      taskTitleSnapshot: taskTitleSnapshot,
      mode: mode,
      status: status,
      startedAtMs: startedAtMs,
      endedAtMs: endedAtMs,
      plannedDurationMs: plannedDurationMs,
      actualDurationMs: actualDurationMs,
      cycleId: cycleId,
      cycleRound: cycleRound,
      updatedAtMs: updatedAtMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusSession &&
          id == other.id &&
          taskId == other.taskId &&
          taskIdSnapshot == other.taskIdSnapshot &&
          taskTitleSnapshot == other.taskTitleSnapshot &&
          mode == other.mode &&
          status == other.status &&
          startedAtMs == other.startedAtMs &&
          endedAtMs == other.endedAtMs &&
          plannedDurationMs == other.plannedDurationMs &&
          actualDurationMs == other.actualDurationMs &&
          cycleId == other.cycleId &&
          cycleRound == other.cycleRound &&
          updatedAtMs == other.updatedAtMs;

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    taskIdSnapshot,
    taskTitleSnapshot,
    mode,
    status,
    startedAtMs,
    endedAtMs,
    plannedDurationMs,
    actualDurationMs,
    cycleId,
    cycleRound,
    updatedAtMs,
  );
}

/// A session plus its updated intervals, returned atomically by transitions.
final class FocusSessionTransition {
  FocusSessionTransition({
    required this.session,
    required Iterable<FocusSessionInterval> intervals,
  }) : intervals = List<FocusSessionInterval>.unmodifiable(intervals) {
    if (this.intervals.isEmpty ||
        this.intervals.any((interval) => interval.sessionId != session.id)) {
      throw ArgumentError('Intervals must belong to the session.');
    }
    if (this.intervals.any(
      (interval) => interval.startedAtMs < session.startedAtMs,
    )) {
      throw ArgumentError('Intervals cannot start before the session.');
    }
    final openCount = this.intervals
        .where((interval) => interval.isOpen)
        .length;
    final expectedOpenCount = session.status == FocusSessionStatus.running
        ? 1
        : 0;
    if (openCount != expectedOpenCount) {
      throw ArgumentError(
        'Session status ${session.status} requires $expectedOpenCount '
        'open interval(s).',
      );
    }
    if (session.status.isTerminal &&
        this.intervals.any(
          (interval) => interval.endedAtMs! > session.endedAtMs!,
        )) {
      throw ArgumentError('Terminal intervals cannot extend beyond the end.');
    }
    final actualDurationMs = FocusSessionDuration.elapsedActiveMilliseconds(
      intervals: this.intervals,
      atMs: session.updatedAtMs,
    );
    if (session.status.isTerminal &&
        actualDurationMs != session.actualDurationMs) {
      throw ArgumentError(
        'Terminal actualDurationMs must match the recorded intervals.',
      );
    }
  }

  final FocusSession session;
  final List<FocusSessionInterval> intervals;
}
