import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/providers/countdown_provider.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('formatCountdown', () {
    test('formats zero duration', () {
      expect(formatCountdown(Duration.zero), '0s');
    });

    test('formats seconds only', () {
      expect(formatCountdown(Duration(seconds: 5)), '5s');
      expect(formatCountdown(Duration(seconds: 45)), '45s');
    });

    test('formats minutes and seconds', () {
      expect(formatCountdown(Duration(minutes: 2, seconds: 30)), '2m 30s');
      expect(formatCountdown(Duration(minutes: 10, seconds: 5)), '10m 5s');
    });

    test('formats hours, minutes, and seconds', () {
      expect(
        formatCountdown(Duration(hours: 1, minutes: 5, seconds: 30)),
        '1h 5m 30s',
      );
      expect(
        formatCountdown(Duration(hours: 3, minutes: 0, seconds: 0)),
        '3h 0m 0s',
      );
    });

    test('formats days, hours, and minutes', () {
      expect(
        formatCountdown(Duration(days: 2, hours: 3, minutes: 10, seconds: 5)),
        '2d 3h 10m',
      );
      expect(
        formatCountdown(Duration(days: 1, hours: 0, minutes: 0, seconds: 0)),
        '1d 0h 0m',
      );
    });
  });

  group('computeTaskCountdown', () {
    test('counts down to the end of a date-only task', () {
      final task = TaskRow(
        id: 'date-only',
        title: 'Date only',
        description: null,
        completed: false,
        createdAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
        dueDate: DateTime(2026, 8, 15),
        dueTime: null,
        dueTimezone: null,
        priority: 2,
        category: null,
        goalId: null,
        parentTaskId: null,
      );

      final result = computeTaskCountdown(
        task,
        now: DateTime(2026, 8, 14, 12),
      );
      expect(result.status, CountdownStatus.active);
      expect(result.hasCountdown, isTrue);
    });

    test('returns none for completed task with due time', () {
      final task = TaskRow(
        id: 'completed',
        title: 'Completed',
        description: null,
        completed: true,
        createdAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
        dueDate: DateTime(2026, 8, 15),
        dueTime: 3600,
        dueTimezone: 'UTC',
        priority: 2,
        category: null,
        goalId: null,
        parentTaskId: null,
      );

      final result = computeTaskCountdown(task);
      expect(result.status, CountdownStatus.none);
    });

    test('returns none for task without due date or time', () {
      final task = TaskRow(
        id: 'no-date',
        title: 'No date',
        description: null,
        completed: false,
        createdAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
        dueDate: null,
        dueTime: null,
        dueTimezone: null,
        priority: 2,
        category: null,
        goalId: null,
        parentTaskId: null,
      );

      final result = computeTaskCountdown(task);
      expect(result.status, CountdownStatus.none);
    });

    test('returns active countdown for future deadline in UTC', () {
      final now = DateTime.now();
      final future = DateTime(now.year, now.month, now.day + 1, 12, 0, 0);

      final task = TaskRow(
        id: 'future-task',
        title: 'Future task',
        description: null,
        completed: false,
        createdAt: now,
        updatedAt: now,
        dueDate: future,
        dueTime: 0, // midnight
        dueTimezone: 'UTC',
        priority: 2,
        category: null,
        goalId: null,
        parentTaskId: null,
      );

      final result = computeTaskCountdown(task);
      expect(result.status, CountdownStatus.active);
      expect(result.hasCountdown, isTrue);
      expect(result.remaining, isNotNull);
      expect(result.remaining!.inSeconds, greaterThan(0));
    });

    test('returns overdue for past deadline in UTC', () {
      final now = DateTime.now();
      final past = DateTime(now.year, now.month, now.day - 1, 12, 0, 0);

      final task = TaskRow(
        id: 'past-task',
        title: 'Past task',
        description: null,
        completed: false,
        createdAt: past,
        updatedAt: past,
        dueDate: past,
        dueTime: 43200, // 12:00 PM
        dueTimezone: 'UTC',
        priority: 2,
        category: null,
        goalId: null,
        parentTaskId: null,
      );

      final result = computeTaskCountdown(task);
      expect(result.status, CountdownStatus.overdue);
    });

    test('returns active countdown for deadline a few minutes in future', () {
      final now = DateTime.now();
      // dueDate is tomorrow at midnight, dueTime is 1 minute after midnight
      final dueDate = DateTime(now.year, now.month, now.day + 1);
      final dueTime = 60; // 12:01 AM

      final task = TaskRow(
        id: 'future-task',
        title: 'Future task',
        description: null,
        completed: false,
        createdAt: now,
        updatedAt: now,
        dueDate: dueDate,
        dueTime: dueTime,
        dueTimezone: 'UTC',
        priority: 2,
        category: null,
        goalId: null,
        parentTaskId: null,
      );

      final result = computeTaskCountdown(task);
      expect(result.status, CountdownStatus.active);
      expect(result.hasCountdown, isTrue);
      expect(result.remaining, isNotNull);
      expect(result.remaining!.inSeconds, greaterThan(0));
    });

    test('computeAllCountdowns returns map keyed by task ID', () {
      final now = DateTime.now();
      final future = DateTime(now.year, now.month, now.day + 1, 12, 0, 0);

      final tasks = [
        TaskRow(
          id: 'task-1',
          title: 'Task 1',
          description: null,
          completed: false,
          createdAt: now,
          updatedAt: now,
          dueDate: future,
          dueTime: 3600,
          dueTimezone: 'UTC',
          priority: 2,
          category: null,
          goalId: null,
          parentTaskId: null,
        ),
        TaskRow(
          id: 'task-2',
          title: 'Task 2',
          description: null,
          completed: false,
          createdAt: now,
          updatedAt: now,
          dueDate: null,
          dueTime: null,
          dueTimezone: null,
          priority: 2,
          category: null,
          goalId: null,
          parentTaskId: null,
        ),
      ];

      final results = computeAllCountdowns(tasks);
      expect(results, hasLength(2));
      expect(results['task-1']?.status, CountdownStatus.active);
      expect(results['task-2']?.status, CountdownStatus.none);
    });
  });

  group('formatCountdownHMS', () {
    test('formats zero duration', () {
      expect(formatCountdownHMS(Duration.zero), '0000:00:00');
    });

    test('formats negative duration as zero', () {
      expect(formatCountdownHMS(Duration(seconds: -5)), '0000:00:00');
    });

    test('formats seconds only', () {
      expect(formatCountdownHMS(Duration(seconds: 5)), '0000:00:05');
      expect(formatCountdownHMS(Duration(seconds: 45)), '0000:00:45');
    });

    test('formats minutes and seconds', () {
      expect(
        formatCountdownHMS(Duration(minutes: 22, seconds: 14)),
        '0000:22:14',
      );
      expect(
        formatCountdownHMS(Duration(minutes: 1, seconds: 5)),
        '0000:01:05',
      );
    });

    test('formats hours, minutes, and seconds', () {
      expect(
        formatCountdownHMS(Duration(hours: 22, minutes: 14, seconds: 37)),
        '0022:14:37',
      );
      expect(
        formatCountdownHMS(Duration(hours: 3, minutes: 0, seconds: 0)),
        '0003:00:00',
      );
    });

    test('formats hours beyond 24', () {
      expect(
        formatCountdownHMS(Duration(hours: 100, minutes: 5, seconds: 3)),
        '0100:05:03',
      );
    });
  });

  group('computeTaskCountdown extended', () {
    test('returns dueNow at exact deadline', () {
      final now = DateTime.utc(2026, 8, 10, 12, 0, 0);
      final dueDate = DateTime.utc(2026, 8, 10);

      final task = TaskRow(
        id: 'exact-deadline',
        title: 'Exact deadline',
        description: null,
        completed: false,
        createdAt: now,
        updatedAt: now,
        dueDate: dueDate,
        dueTime: 43200, // 12:00 PM
        dueTimezone: 'UTC',
        priority: 2,
        category: null,
        goalId: null,
        parentTaskId: null,
      );

      final result = computeTaskCountdown(task, now: now);
      expect(result.status, CountdownStatus.dueNow);
      expect(result.hasCountdown, isTrue);
    });

    test('returns active countdown for subtask with due time', () {
      final now = DateTime.now();
      final future = DateTime(now.year, now.month, now.day + 1, 12, 0, 0);

      final task = TaskRow(
        id: 'subtask-with-time',
        title: 'Subtask',
        description: null,
        completed: false,
        createdAt: now,
        updatedAt: now,
        dueDate: future,
        dueTime: 3600,
        dueTimezone: 'UTC',
        priority: 2,
        category: null,
        goalId: null,
        parentTaskId: 'parent-task',
      );

      final result = computeTaskCountdown(task);
      expect(result.status, CountdownStatus.active);
      expect(result.hasCountdown, isTrue);
    });

    test('computes deadline in task timezone', () {
      final now = DateTime.utc(2026, 8, 10, 12, 0, 0); // noon UTC
      // Midnight Aug 11 in America/New_York (EDT, UTC-4) = 04:00 UTC Aug 11
      final dueDate = DateTime.utc(2026, 8, 11, 4, 0, 0);

      final task = TaskRow(
        id: 'tz-task',
        title: 'TZ task',
        description: null,
        completed: false,
        createdAt: now,
        updatedAt: now,
        dueDate: dueDate,
        dueTime: 0,
        dueTimezone: 'America/New_York',
        priority: 2,
        category: null,
        goalId: null,
        parentTaskId: null,
      );

      final result = computeTaskCountdown(task, now: now);
      expect(result.status, CountdownStatus.active);
      expect(result.deadline, DateTime.utc(2026, 8, 11, 4, 0, 0));
    });
  });
}
