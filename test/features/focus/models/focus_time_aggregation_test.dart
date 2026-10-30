import 'package:flutter_test/flutter_test.dart';
import 'package:systum/features/focus/models/focus_session.dart';
import 'package:systum/features/focus/models/focus_session_interval.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/models/focus_session_status.dart';
import 'package:systum/features/focus/models/focus_time_aggregation.dart';

void main() {
  group('FocusTimeAggregation', () {
    test(
      'splits UTC intervals at local midnight and preserves task snapshots',
      () {
        final localStart = DateTime(2026, 10, 30, 23, 30);
        final startMs = localStart.toUtc().millisecondsSinceEpoch;
        final endMs = startMs + const Duration(hours: 1).inMilliseconds;
        final result = FocusTimeAggregation.fromHistory([
          _session(
            id: 'cross-midnight',
            mode: FocusSessionMode.pomodoro,
            status: FocusSessionStatus.completed,
            startMs: startMs,
            endMs: endMs,
            taskIdSnapshot: 'deleted-task',
          ),
        ]);

        final firstDay = DateTime(
          localStart.year,
          localStart.month,
          localStart.day,
        );
        final nextLocalDay = localStart.add(const Duration(days: 1));
        final secondDay = DateTime(
          nextLocalDay.year,
          nextLocalDay.month,
          nextLocalDay.day,
        );
        expect(result.dailyFocusMilliseconds[firstDay], 30 * 60 * 1000);
        expect(result.dailyFocusMilliseconds[secondDay], 30 * 60 * 1000);
        expect(result.taskFocusMilliseconds['deleted-task'], 60 * 60 * 1000);
        expect(
          result.dailyTaskFocusMilliseconds[(
            day: firstDay,
            taskId: 'deleted-task',
          )],
          30 * 60 * 1000,
        );
        expect(result.completedFocusSessions, 1);
      },
    );

    test(
      'includes interrupted time but excludes cancelled sessions and breaks',
      () {
        final result = FocusTimeAggregation.fromHistory([
          _session(
            id: 'interrupted',
            mode: FocusSessionMode.standard,
            status: FocusSessionStatus.interrupted,
            startMs: 100,
            endMs: 300,
            taskId: 'task-a',
          ),
          _session(
            id: 'cancelled',
            mode: FocusSessionMode.standard,
            status: FocusSessionStatus.cancelled,
            startMs: 400,
            endMs: 700,
            taskId: 'task-a',
          ),
          _session(
            id: 'break',
            mode: FocusSessionMode.shortBreak,
            status: FocusSessionStatus.completed,
            startMs: 800,
            endMs: 1100,
          ),
        ]);

        expect(result.taskFocusMilliseconds, {'task-a': 200});
        expect(result.dailyFocusMilliseconds.values, [200]);
        expect(result.completedFocusSessions, 0);
      },
    );

    test('rejects overlapping intervals across sessions', () {
      expect(
        () => FocusTimeAggregation.fromHistory([
          _session(
            id: 'first',
            mode: FocusSessionMode.standard,
            status: FocusSessionStatus.completed,
            startMs: 100,
            endMs: 300,
          ),
          _session(
            id: 'overlapping',
            mode: FocusSessionMode.custom,
            status: FocusSessionStatus.completed,
            startMs: 200,
            endMs: 400,
          ),
        ]),
        throwsArgumentError,
      );
    });
  });
}

FocusSessionTransition _session({
  required String id,
  required FocusSessionMode mode,
  required FocusSessionStatus status,
  required int startMs,
  required int endMs,
  String? taskId,
  String? taskIdSnapshot,
}) => FocusSessionTransition(
  session: FocusSession(
    id: id,
    taskId: taskId,
    taskIdSnapshot: taskIdSnapshot ?? taskId,
    taskTitleSnapshot: (taskIdSnapshot ?? taskId) == null ? null : 'Snapshot',
    mode: mode,
    status: status,
    startedAtMs: startMs,
    endedAtMs: endMs,
    actualDurationMs: endMs - startMs,
    updatedAtMs: endMs,
  ),
  intervals: [
    FocusSessionInterval(sessionId: id, startedAtMs: startMs, endedAtMs: endMs),
  ],
);
