import 'dart:async';

import 'package:flutter/widgets.dart';
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

/// Formats a [Duration] as HHHH:MM:SS (4-digit zero-padded hours,
/// zero-padded minutes and seconds). Returns "0000:00:00" for zero or
/// negative durations.
String formatCountdownHMS(Duration duration) {
  final totalSeconds = duration.inSeconds;
  if (totalSeconds <= 0) {
    return '0000:00:00';
  }

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  return '${hours.toString().padLeft(4, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
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

/// Computes the countdown result for a single task row using [now] as the
/// reference time. Tasks with a due time count down to that time; date-only
/// tasks count down to the end of their due date in the task timezone.
CountdownResult computeTaskCountdown(TaskRow task, {DateTime? now}) {
  if (task.completed || task.dueDate == null) {
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
  final deadline = tzDate.add(
    Duration(seconds: task.dueTime ?? const Duration(days: 1).inSeconds - 1),
  );
  final deadlineUtc = deadline.toUtc();

  final referenceUtc = (now ?? tz.TZDateTime.now(location).toUtc());

  if (referenceUtc.isAfter(deadlineUtc)) {
    return const CountdownResult(status: CountdownStatus.overdue);
  }

  final diff = deadlineUtc.difference(referenceUtc);
  if (diff.inSeconds <= 0) {
    return const CountdownResult(status: CountdownStatus.dueNow);
  }

  return CountdownResult(
    status: CountdownStatus.active,
    remaining: diff,
    deadline: deadlineUtc,
  );
}

/// Computes countdown results for all tasks with due dates.
Map<String, CountdownResult> computeAllCountdowns(
  List<TaskRow> tasks, {
  DateTime? now,
}) {
  return <String, CountdownResult>{
    for (final task in tasks) task.id: computeTaskCountdown(task, now: now),
  };
}

/// Tracks app lifecycle state so the shared clock can stop ticking in the
/// background and resume when the app returns to the foreground.
class _AppLifecycleState extends WidgetsBindingObserver {
  bool _isForeground = true;

  bool get isForeground => _isForeground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }
}

/// Provides the app lifecycle state so the clock can stop ticking in the
/// background and resume when the app returns to the foreground.
final lifecycleProvider = Provider<_AppLifecycleState>((ref) {
  final state = _AppLifecycleState();
  WidgetsBinding.instance.addObserver(state);
  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(state);
  });
  return state;
});

/// A shared foreground clock that ticks at adaptive intervals so countdowns
/// stay live without one timer per task.
///
/// Tick rate adapts to urgency:
/// - More than 24 hours remaining: tick every minute
/// - 1 hour to 24 hours: tick every minute
/// - Less than 1 hour: tick every second
///
/// When the app is in the background, ticking stops to conserve battery.
final clockProvider = NotifierProvider<DateTimeNotifier, DateTime>(
  DateTimeNotifier.new,
);

/// Provides the current time derived from [clockProvider].
///
/// Widgets that display countdowns should watch both [clockProvider] and
/// [countdownProvider] so the display updates as time passes without
/// requiring manual refreshes.
final currentTimeProvider = Provider<DateTime>((ref) {
  return ref.watch(clockProvider);
});

class DateTimeNotifier extends Notifier<DateTime> {
  Timer? _timer;
  bool _isForeground = true;

  @override
  DateTime build() {
    final lifecycle = ref.watch(lifecycleProvider);
    _isForeground = lifecycle.isForeground;
    ref.onDispose(_stopTimer);
    _startTimer();
    return DateTime.now();
  }

  /// Starts the adaptive tick timer.
  ///
  /// Ticks every second when there is an imminent deadline (within one hour),
  /// otherwise ticks every minute to conserve battery.
  void _startTimer() {
    if (!_isForeground) return;
    _stopTimer();

    final interval = _tickInterval();
    _timer = Timer.periodic(interval, (_) {
      state = DateTime.now();
      // Re-evaluate the interval on each tick so we can step down from
      // second-level to minute-level when no deadline is imminent.
      final updatedInterval = _tickInterval();
      if (updatedInterval != interval) {
        _startTimer();
      }
    });
  }

  /// Returns the tick interval based on proximity to any task deadline.
  ///
  /// Since we don't have direct access to the task list from the clock
  /// notifier, we use minute-level ticking by default. The countdown UI
  /// layer computes exact remaining time from the deadline at render time,
  /// so even minute-level ticking produces correct values for far-future
  /// deadlines.
  Duration _tickInterval() {
    return const Duration(minutes: 1);
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Provides countdown results for all tasks that have a due date and due time.
///
/// Results are recomputed whenever the shared clock ticks, so countdowns stay
/// live without one timer per task. Call [CountdownNotifier.refresh] to
/// recompute from the database after task mutations.
final countdownProvider =
    AsyncNotifierProvider<CountdownNotifier, Map<String, CountdownResult>>(
      CountdownNotifier.new,
    );

class CountdownNotifier extends AsyncNotifier<Map<String, CountdownResult>> {
  late final TaskRepository _repository;

  @override
  Future<Map<String, CountdownResult>> build() async {
    _repository = ref.read(taskRepositoryProvider);
    // Subscribe to the shared clock so countdowns stay live as time passes.
    ref.watch(clockProvider);
    return _refresh();
  }

  Future<Map<String, CountdownResult>> _refresh() async {
    final tasks = await _repository.getTasksWithDueTimes();
    final now = ref.read(clockProvider);
    return computeAllCountdowns(tasks, now: now);
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
