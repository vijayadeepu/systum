import 'focus_session.dart';
import 'focus_session_mode.dart';
import 'focus_session_status.dart';

/// Factual focus time derived from persisted intervals.
///
/// Completed and interrupted focus sessions contribute active interval time;
/// cancelled sessions and break segments do not. Only completed sessions
/// contribute to [completedFocusSessions]. Daily buckets use the device's
/// current local timezone, so historical buckets can regroup after a timezone
/// change while the persisted UTC instants remain unchanged.
final class FocusTimeAggregation {
  FocusTimeAggregation._({
    required this.dailyFocusMilliseconds,
    required this.taskFocusMilliseconds,
    required this.dailyTaskFocusMilliseconds,
    required this.completedFocusSessions,
    required this.dailyCompletedFocusSessions,
    required this.dailyInterruptedFocusSessions,
  });

  factory FocusTimeAggregation.fromHistory(
    Iterable<FocusSessionTransition> history,
  ) {
    final daily = <DateTime, int>{};
    final tasks = <String, int>{};
    final dailyTasks = <({DateTime day, String taskId}), int>{};
    final dailyCompleted = <DateTime, int>{};
    final dailyInterrupted = <DateTime, int>{};
    final ranges = <({int start, int end, String? taskId})>[];
    var completedCount = 0;

    for (final transition in history) {
      final session = transition.session;
      if (!_isFocusMode(session.mode) ||
          (session.status != FocusSessionStatus.completed &&
              session.status != FocusSessionStatus.interrupted)) {
        continue;
      }
      if (session.status == FocusSessionStatus.completed) completedCount++;
      final sessionDay = DateTime.fromMillisecondsSinceEpoch(
        session.startedAtMs,
        isUtc: true,
      ).toLocal();
      final day = DateTime(sessionDay.year, sessionDay.month, sessionDay.day);
      final sessionCounts = session.status == FocusSessionStatus.completed
          ? dailyCompleted
          : dailyInterrupted;
      sessionCounts.update(day, (value) => value + 1, ifAbsent: () => 1);
      final taskId = session.taskIdSnapshot ?? session.taskId;
      for (final interval in transition.intervals) {
        final end = interval.endedAtMs;
        if (end == null) {
          throw ArgumentError(
            'Terminal focus sessions cannot have open intervals.',
          );
        }
        if (end > interval.startedAtMs) {
          ranges.add((start: interval.startedAtMs, end: end, taskId: taskId));
        }
      }
    }

    ranges.sort((first, second) => first.start.compareTo(second.start));
    var previousEndMs = -0x7fffffffffffffff;
    for (final range in ranges) {
      if (range.start < previousEndMs) {
        throw ArgumentError(
          'Focus intervals across sessions must not overlap.',
        );
      }
      previousEndMs = range.end;
      var cursor = range.start;
      while (cursor < range.end) {
        final local = DateTime.fromMillisecondsSinceEpoch(
          cursor,
          isUtc: true,
        ).toLocal();
        final day = DateTime(local.year, local.month, local.day);
        final nextDay = DateTime(local.year, local.month, local.day + 1);
        final boundary = nextDay.toUtc().millisecondsSinceEpoch;
        final segmentEnd = range.end < boundary ? range.end : boundary;
        final duration = segmentEnd - cursor;
        daily.update(
          day,
          (value) => value + duration,
          ifAbsent: () => duration,
        );
        if (range.taskId case final taskId?) {
          tasks.update(
            taskId,
            (value) => value + duration,
            ifAbsent: () => duration,
          );
          final key = (day: day, taskId: taskId);
          dailyTasks.update(
            key,
            (value) => value + duration,
            ifAbsent: () => duration,
          );
        }
        cursor = segmentEnd;
      }
    }

    return FocusTimeAggregation._(
      dailyFocusMilliseconds: Map.unmodifiable(daily),
      taskFocusMilliseconds: Map.unmodifiable(tasks),
      dailyTaskFocusMilliseconds: Map.unmodifiable(dailyTasks),
      completedFocusSessions: completedCount,
      dailyCompletedFocusSessions: Map.unmodifiable(dailyCompleted),
      dailyInterruptedFocusSessions: Map.unmodifiable(dailyInterrupted),
    );
  }

  final Map<DateTime, int> dailyFocusMilliseconds;
  final Map<String, int> taskFocusMilliseconds;
  final Map<({DateTime day, String taskId}), int> dailyTaskFocusMilliseconds;
  final int completedFocusSessions;
  final Map<DateTime, int> dailyCompletedFocusSessions;
  final Map<DateTime, int> dailyInterruptedFocusSessions;

  static bool _isFocusMode(FocusSessionMode mode) =>
      mode == FocusSessionMode.standard ||
      mode == FocusSessionMode.pomodoro ||
      mode == FocusSessionMode.custom;
}
