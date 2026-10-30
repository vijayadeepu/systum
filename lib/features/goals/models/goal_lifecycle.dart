import 'goal_date.dart';
import 'goal_progress.dart';

/// The derived lifecycle of a goal.
///
/// The lifecycle is never stored. It is recalculated from the goal's target
/// date and its [GoalProgress], which keeps completion and overdue state
/// consistent with the task data.
enum GoalLifecycle { active, completed, overdue }

extension GoalLifecycleLabel on GoalLifecycle {
  String get label {
    switch (this) {
      case GoalLifecycle.active:
        return 'Active';
      case GoalLifecycle.completed:
        return 'Completed';
      case GoalLifecycle.overdue:
        return 'Overdue';
    }
  }
}

/// A goal's lifecycle plus deterministic calendar information.
///
/// Rules:
/// - A goal is completed only when it has at least one actionable leaf task
///   and all of them are complete. An empty goal is never complete.
/// - A goal is overdue when it is not complete, has remaining actionable work,
///   and its target calendar day is before today.
/// - Otherwise it is active. An empty goal with a past target date therefore
///   stays active: there is no outstanding work to be overdue, and it must not
///   silently become complete.
class GoalStatus {
  const GoalStatus({required this.lifecycle, this.daysUntilTarget});

  factory GoalStatus.evaluate({
    required GoalProgress progress,
    required GoalDate? targetDate,
    required DateTime now,
  }) {
    final targetDay = targetDate?.epochDay;
    final today = GoalDate.fromDateTime(now).epochDay;
    final daysUntilTarget = targetDay == null ? null : targetDay - today;

    if (progress.isComplete) {
      return GoalStatus(
        lifecycle: GoalLifecycle.completed,
        daysUntilTarget: daysUntilTarget,
      );
    }

    if (progress.hasActionableTasks &&
        daysUntilTarget != null &&
        daysUntilTarget < 0) {
      return GoalStatus(
        lifecycle: GoalLifecycle.overdue,
        daysUntilTarget: daysUntilTarget,
      );
    }

    return GoalStatus(
      lifecycle: GoalLifecycle.active,
      daysUntilTarget: daysUntilTarget,
    );
  }

  final GoalLifecycle lifecycle;

  /// Calendar days from today to the target day.
  ///
  /// Negative values are in the past, zero is today, and `null` means the goal
  /// has no target date.
  final int? daysUntilTarget;

  bool get isCompleted => lifecycle == GoalLifecycle.completed;

  bool get isOverdue => lifecycle == GoalLifecycle.overdue;

  bool get isActive => lifecycle == GoalLifecycle.active;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GoalStatus &&
            lifecycle == other.lifecycle &&
            daysUntilTarget == other.daysUntilTarget;
  }

  @override
  int get hashCode => Object.hash(lifecycle, daysUntilTarget);
}
