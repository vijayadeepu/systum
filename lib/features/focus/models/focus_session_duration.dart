import 'focus_session.dart';
import 'focus_session_interval.dart';

abstract final class FocusSessionDuration {
  /// Sums recorded running intervals, using [atMs] only for an open interval.
  ///
  /// Intervals must be in chronological order, may not overlap, and may
  /// contain at most one open interval, which must be last.
  static int elapsedActiveMilliseconds({
    required Iterable<FocusSessionInterval> intervals,
    required int atMs,
  }) {
    var elapsed = 0;
    int? previousEndMs;
    var openIntervalSeen = false;

    for (final interval in intervals) {
      if (openIntervalSeen) {
        throw ArgumentError('An open interval must be the final interval.');
      }
      if (previousEndMs != null && interval.startedAtMs < previousEndMs) {
        throw ArgumentError('Intervals must be ordered and must not overlap.');
      }

      final endMs = interval.endedAtMs ?? atMs;
      if (endMs < interval.startedAtMs) {
        throw ArgumentError.value(
          atMs,
          'atMs',
          'Must not precede an open interval start.',
        );
      }
      if (endMs > atMs) {
        throw ArgumentError.value(
          atMs,
          'atMs',
          'Must not precede an interval end.',
        );
      }
      elapsed += endMs - interval.startedAtMs;
      previousEndMs = endMs;
      openIntervalSeen = interval.isOpen;
    }

    return elapsed;
  }

  /// Returns whether a timed session has reached its planned active duration.
  ///
  /// Eligibility is based on [intervals], not wall-clock time since the
  /// session started. Completion is not gated by this result: users may
  /// complete a timed session early.
  static bool canCompleteByDuration({
    required FocusSession session,
    required Iterable<FocusSessionInterval> intervals,
    required int atMs,
  }) {
    final recordedIntervals = List<FocusSessionInterval>.unmodifiable(
      intervals,
    );
    FocusSessionTransition(session: session, intervals: recordedIntervals);

    final plannedDurationMs = session.plannedDurationMs;
    if (session.status.isTerminal || plannedDurationMs == null) {
      return false;
    }
    if (atMs < session.updatedAtMs) {
      throw ArgumentError.value(
        atMs,
        'atMs',
        'Must not precede the session update time.',
      );
    }
    return elapsedActiveMilliseconds(
          intervals: recordedIntervals,
          atMs: atMs,
        ) >=
        plannedDurationMs;
  }
}
