import '../../../core/database/database.dart';

/// Deterministic progress for one goal.
///
/// Counting rule:
/// - Only actionable leaf tasks are counted. A leaf is a task with no direct
///   children among the supplied tasks.
/// - A parent task with children is treated as a heading and is not counted
///   alongside its children.
/// - Only tasks assigned to [goalId] count. Tasks without a goal are ignored.
/// - A goal with no actionable tasks has `totalLeaves == 0`, a fraction of
///   `0.0`, and is never considered complete.
///
/// The calculation is pure: it never writes task data and does not depend on
/// widget or timer state.
class GoalProgress {
  const GoalProgress({
    required this.goalId,
    required this.completedLeaves,
    required this.totalLeaves,
  });

  factory GoalProgress.fromTasks(String goalId, Iterable<TaskRow> tasks) {
    final allTasks = List<TaskRow>.unmodifiable(tasks);
    final taskIds = {for (final task in allTasks) task.id};

    // A parent is only a heading when it still exists. Corrupt rows pointing
    // at a missing parent are treated as actionable so their work is not lost.
    final parentIds = <String>{
      for (final task in allTasks)
        if (task.parentTaskId != null &&
            task.parentTaskId != task.id &&
            taskIds.contains(task.parentTaskId))
          task.parentTaskId!,
    };

    var completedLeaves = 0;
    var totalLeaves = 0;
    for (final task in allTasks) {
      if (task.goalId != goalId || parentIds.contains(task.id)) {
        continue;
      }

      totalLeaves++;
      if (task.completed) {
        completedLeaves++;
      }
    }

    return GoalProgress(
      goalId: goalId,
      completedLeaves: completedLeaves,
      totalLeaves: totalLeaves,
    );
  }

  final String goalId;
  final int completedLeaves;
  final int totalLeaves;

  bool get hasActionableTasks => totalLeaves > 0;

  bool get isComplete => hasActionableTasks && completedLeaves == totalLeaves;

  double get fraction => totalLeaves == 0 ? 0 : completedLeaves / totalLeaves;

  int get percentage => (fraction * 100).round();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GoalProgress &&
            goalId == other.goalId &&
            completedLeaves == other.completedLeaves &&
            totalLeaves == other.totalLeaves;
  }

  @override
  int get hashCode => Object.hash(goalId, completedLeaves, totalLeaves);
}
