import 'package:flutter_test/flutter_test.dart';
import 'package:systum/features/goals/models/goal_date.dart';
import 'package:systum/features/goals/models/goal_lifecycle.dart';
import 'package:systum/features/goals/models/goal_progress.dart';

void main() {
  group('GoalStatus', () {
    final now = DateTime(2026, 8, 10, 12);

    test('a goal without a target date is active', () {
      final status = GoalStatus.evaluate(
        progress: _progress(completed: 1, total: 3),
        targetDate: null,
        now: now,
      );

      expect(status.lifecycle, GoalLifecycle.active);
      expect(status.isActive, isTrue);
      expect(status.daysUntilTarget, isNull);
    });

    test('a future target date is active and reports days remaining', () {
      final status = GoalStatus.evaluate(
        progress: _progress(completed: 1, total: 3),
        targetDate: GoalDate.fromDateTime(DateTime(2026, 8, 15)),
        now: now,
      );

      expect(status.lifecycle, GoalLifecycle.active);
      expect(status.daysUntilTarget, 5);
    });

    test('a target date today is active and reports zero days', () {
      final status = GoalStatus.evaluate(
        progress: _progress(total: 1),
        targetDate: GoalDate.fromDateTime(DateTime(2026, 8, 10, 23, 59)),
        now: now,
      );

      expect(status.lifecycle, GoalLifecycle.active);
      expect(status.daysUntilTarget, 0);
    });

    test('a past target with remaining work is overdue', () {
      final status = GoalStatus.evaluate(
        progress: _progress(completed: 1, total: 3),
        targetDate: GoalDate.fromDateTime(DateTime(2026, 8, 7)),
        now: now,
      );

      expect(status.lifecycle, GoalLifecycle.overdue);
      expect(status.isOverdue, isTrue);
      expect(status.daysUntilTarget, -3);
    });

    test('completion wins over a past target date', () {
      final status = GoalStatus.evaluate(
        progress: _progress(completed: 2, total: 2),
        targetDate: GoalDate.fromDateTime(DateTime(2026, 8, 1)),
        now: now,
      );

      expect(status.lifecycle, GoalLifecycle.completed);
      expect(status.isCompleted, isTrue);
      expect(status.isOverdue, isFalse);
    });

    test('an empty goal never completes and is not overdue', () {
      final status = GoalStatus.evaluate(
        progress: _progress(),
        targetDate: GoalDate.fromDateTime(DateTime(2026, 8, 1)),
        now: now,
      );

      expect(status.lifecycle, GoalLifecycle.active);
      expect(status.isCompleted, isFalse);
      expect(status.isOverdue, isFalse);
    });

    test('a goal with only completed work is completed', () {
      final status = GoalStatus.evaluate(
        progress: _progress(completed: 3, total: 3),
        targetDate: null,
        now: now,
      );

      expect(status.lifecycle, GoalLifecycle.completed);
      expect(status.daysUntilTarget, isNull);
    });

    test('date-only comparison ignores time of day', () {
      final status = GoalStatus.evaluate(
        progress: _progress(total: 1),
        targetDate: GoalDate.fromDateTime(DateTime(2026, 8, 9, 23, 59)),
        now: DateTime(2026, 8, 10, 0, 1),
      );

      expect(status.lifecycle, GoalLifecycle.overdue);
      expect(status.daysUntilTarget, -1);
    });

    test('calendar comparison is stable across a DST transition', () {
      final status = GoalStatus.evaluate(
        progress: _progress(total: 1),
        targetDate: GoalDate.fromDateTime(DateTime(2026, 3, 8)),
        now: DateTime(2026, 3, 7, 12),
      );

      expect(status.daysUntilTarget, 1);
      expect(status.lifecycle, GoalLifecycle.active);
    });

    test('lifecycle labels are stable for presentation', () {
      expect(GoalLifecycle.active.label, 'Active');
      expect(GoalLifecycle.completed.label, 'Completed');
      expect(GoalLifecycle.overdue.label, 'Overdue');
    });

    test('value equality includes lifecycle and remaining days', () {
      const first = GoalStatus(
        lifecycle: GoalLifecycle.overdue,
        daysUntilTarget: -2,
      );
      const second = GoalStatus(
        lifecycle: GoalLifecycle.overdue,
        daysUntilTarget: -2,
      );
      const different = GoalStatus(
        lifecycle: GoalLifecycle.overdue,
        daysUntilTarget: -1,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });
  });
}

GoalProgress _progress({int completed = 0, int total = 0}) {
  return GoalProgress(
    goalId: 'goal-1',
    completedLeaves: completed,
    totalLeaves: total,
  );
}
