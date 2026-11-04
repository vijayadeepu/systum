import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/database/database.dart';
import '../providers/task_provider.dart';
import '../repository/task_repository.dart';

/// Status of a task's countdown to its deadline.
enum CountdownStatus {
  /// The deadline is in the future.
  active,

  /// The deadline has just been reached (within the current second).
  dueNow,

  /// The deadline has passed.
  overdue,

  /// No countdown applies (no due time, completed task, etc.).
  none,
}

/// Result of computing the countdown for one task.
class CountdownResult {
  const CountdownResult({required this.status, this.remaining, this.deadline});

  final CountdownStatus status;
  final Duration? remaining;
  final DateTime? deadline;

  bool get isActive => status == CountdownStatus.active;
  bool get isDueNow => status == CountdownStatus.dueNow;
  bool get isOverdue => status == CountdownStatus.overdue;

  /// True when a countdown is actively being displayed (active or due now).
  bool get hasCountdown =>
      status == CountdownStatus.active || status == CountdownStatus.dueNow;
}

/// Formats a [Duration] for countdown display.
///
/// - Days > 0: "Xd Yh Zm"
/// - Hours > 0: "Xh Ym Zs"
/// - Minutes > 0: "Xm Ys"
/// - Seconds > 0: "Xs"
String formatCountdown(Duration duration) {
  final totalSeconds = duration.inSeconds;
  if (totalSeconds <= 0) {
    return '0s';
  }

  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  final parts = <String>[];
  if (days > 0) {
    parts.add('${days}d');
    parts.add('${hours}h');
    parts.add('${minutes}m');
  } else if (hours > 0) {
    parts.add('${hours}h');
    parts.add('${minutes}m');
    parts.add('${seconds}s');
  } else if (minutes > 0) {
    parts.add('${minutes}m');
    parts.add('${seconds}s');
  } else {
    parts.add('${seconds}s');
  }

  return parts.join(' ');
}

/// Computes the countdown result for a single task row.
///
/// Only tasks with both [dueDate] and [dueTime] set, that are not completed,
/// receive an active countdown. Date-only tasks (due date without due time)
/// return [CountdownStatus.none].
CountdownResult computeTaskCountdown(TaskRow task) {
  if (task.completed || task.dueDate == null || task.dueTime == null) {
    return const CountdownResult(status: CountdownStatus.none);
  }

  final location = task.dueTimezone != null
      ? tz.getLocation(task.dueTimezone!)
      : tz.local;

  // dueDate is stored as UTC milliseconds representing midnight in the
  // task's timezone. Reinterpret it in that timezone, then apply the due
  // time offset.
  final utcDate = DateTime.fromMillisecondsSinceEpoch(
    task.dueDate!.millisecondsSinceEpoch,
    isUtc: true,
  );
  final tzDate = tz.TZDateTime.from(utcDate, location);
  final deadline = tzDate.add(Duration(seconds: task.dueTime!));
  final deadlineUtc = deadline.toUtc();

  final now = tz.TZDateTime.now(location).toUtc();

  if (now.isAfter(deadlineUtc)) {
    return const CountdownResult(status: CountdownStatus.overdue);
  }

  final diff = deadlineUtc.difference(now);
  if (diff.inSeconds <= 0) {
    return const CountdownResult(status: CountdownStatus.dueNow);
  }

  return CountdownResult(
    status: CountdownStatus.active,
    remaining: diff,
    deadline: deadlineUtc,
  );
}

/// Computes countdown results for all tasks with due times.
Map<String, CountdownResult> computeAllCountdowns(List<TaskRow> tasks) {
  return <String, CountdownResult>{
    for (final task in tasks) task.id: computeTaskCountdown(task),
  };
}

/// Provides countdown results for all tasks that have a due date and due time.
///
/// Results are computed on demand. Call [CountdownNotifier.refresh] to
/// recompute from the database. The UI is responsible for refreshing at an
/// appropriate interval while it is visible.
final countdownProvider =
    AsyncNotifierProvider<CountdownNotifier, Map<String, CountdownResult>>(
      CountdownNotifier.new,
    );

class CountdownNotifier extends AsyncNotifier<Map<String, CountdownResult>> {
  late final TaskRepository _repository;

  @override
  Future<Map<String, CountdownResult>> build() async {
    _repository = ref.read(taskRepositoryProvider);
    return _refresh();
  }

  Future<Map<String, CountdownResult>> _refresh() async {
    final tasks = await _repository.getTasksWithDueTimes();
    return computeAllCountdowns(tasks);
  }

  /// Returns the countdown result for [taskId], or [CountdownStatus.none] if
  /// no countdown applies.
  CountdownResult resultFor(String taskId) {
    final current = state.value;
    if (current == null) {
      return const CountdownResult(status: CountdownStatus.none);
    }
    return current[taskId] ??
        const CountdownResult(status: CountdownStatus.none);
  }

  /// Refreshes the countdowns from the database.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_refresh);
  }
}
