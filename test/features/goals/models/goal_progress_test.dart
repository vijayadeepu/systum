import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/goals/models/goal_progress.dart';

void main() {
  group('GoalProgress', () {
    test('a goal with no tasks has no actionable work', () {
      final progress = GoalProgress.fromTasks('goal-1', const []);

      expect(progress.goalId, 'goal-1');
      expect(progress.completedLeaves, 0);
      expect(progress.totalLeaves, 0);
      expect(progress.hasActionableTasks, isFalse);
      expect(progress.isComplete, isFalse);
      expect(progress.fraction, 0);
      expect(progress.percentage, 0);
    });

    test('top-level tasks are counted as leaves', () {
      final progress = GoalProgress.fromTasks('goal-1', [
        _taskRow(id: 'done', goalId: 'goal-1', completed: true),
        _taskRow(id: 'open', goalId: 'goal-1'),
      ]);

      expect(progress.completedLeaves, 1);
      expect(progress.totalLeaves, 2);
      expect(progress.fraction, 0.5);
      expect(progress.percentage, 50);
      expect(progress.isComplete, isFalse);
    });

    test('a parent with children is a heading, not a counted leaf', () {
      final progress = GoalProgress.fromTasks('goal-1', [
        _taskRow(id: 'parent', goalId: 'goal-1'),
        _taskRow(id: 'child-1', goalId: 'goal-1', parentTaskId: 'parent'),
        _taskRow(
          id: 'child-2',
          goalId: 'goal-1',
          parentTaskId: 'parent',
          completed: true,
        ),
      ]);

      expect(progress.completedLeaves, 1);
      expect(progress.totalLeaves, 2);
      expect(progress.fraction, 0.5);
    });

    test('a completed parent does not complete incomplete children', () {
      final progress = GoalProgress.fromTasks('goal-1', [
        _taskRow(id: 'parent', goalId: 'goal-1', completed: true),
        _taskRow(id: 'child-1', goalId: 'goal-1', parentTaskId: 'parent'),
        _taskRow(id: 'child-2', goalId: 'goal-1', parentTaskId: 'parent'),
      ]);

      expect(progress.completedLeaves, 0);
      expect(progress.totalLeaves, 2);
      expect(progress.isComplete, isFalse);
    });

    test('a completed top-level task without children is complete', () {
      final progress = GoalProgress.fromTasks('goal-1', [
        _taskRow(id: 'done', goalId: 'goal-1', completed: true),
      ]);

      expect(progress.completedLeaves, 1);
      expect(progress.totalLeaves, 1);
      expect(progress.isComplete, isTrue);
      expect(progress.percentage, 100);
    });

    test('promoted children count as leaves', () {
      final progress = GoalProgress.fromTasks('goal-1', [
        _taskRow(id: 'promoted', goalId: 'goal-1', completed: true),
      ]);

      expect(progress.totalLeaves, 1);
      expect(progress.completedLeaves, 1);
      expect(progress.isComplete, isTrue);
    });

    test('tasks without a goal are ignored', () {
      final progress = GoalProgress.fromTasks('goal-1', [
        _taskRow(id: 'goal-task', goalId: 'goal-1'),
        _taskRow(id: 'ungoalized'),
        _taskRow(id: 'other-goal', goalId: 'goal-2', completed: true),
      ]);

      expect(progress.totalLeaves, 1);
      expect(progress.completedLeaves, 0);
    });

    test('a child pointing at a missing parent is still actionable', () {
      final progress = GoalProgress.fromTasks('goal-1', [
        _taskRow(
          id: 'orphan',
          goalId: 'goal-1',
          parentTaskId: 'missing-parent',
          completed: true,
        ),
      ]);

      expect(progress.totalLeaves, 1);
      expect(progress.completedLeaves, 1);
    });

    test('calculation is deterministic and does not mutate inputs', () {
      final tasks = [
        _taskRow(id: 'parent', goalId: 'goal-1'),
        _taskRow(id: 'child', goalId: 'goal-1', parentTaskId: 'parent'),
      ];
      final before = tasks.map((task) => task.toJson()).toList();

      final first = GoalProgress.fromTasks('goal-1', tasks);
      final second = GoalProgress.fromTasks('goal-1', tasks);

      expect(first, equals(second));
      expect(tasks.map((task) => task.toJson()).toList(), equals(before));
    });
  });
}

TaskRow _taskRow({
  required String id,
  String? goalId,
  String? parentTaskId,
  bool completed = false,
}) {
  final now = DateTime(2026, 8, 1, 8);
  return TaskRow(
    id: id,
    title: 'Task $id',
    completed: completed,
    createdAt: now,
    updatedAt: now,
    priority: 2,
    goalId: goalId,
    parentTaskId: parentTaskId,
  );
}
