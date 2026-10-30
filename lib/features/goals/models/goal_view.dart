import '../../../core/database/database.dart';
import '../../tasks/models/task_hierarchy.dart';
import 'goal_lifecycle.dart';
import 'goal_progress.dart';

/// A goal plus its derived progress and lifecycle for list rendering.
class GoalOverview {
  const GoalOverview({
    required this.goal,
    required this.progress,
    required this.status,
  });

  factory GoalOverview.fromRows({
    required GoalRow goal,
    required Iterable<TaskRow> allTasks,
    required DateTime now,
  }) {
    final progress = GoalProgress.fromTasks(goal.id, allTasks);
    return GoalOverview(
      goal: goal,
      progress: progress,
      status: GoalStatus.evaluate(
        progress: progress,
        targetDate: goal.targetDate,
        now: now,
      ),
    );
  }

  final GoalRow goal;
  final GoalProgress progress;
  final GoalStatus status;
}

/// The complete read model for a goal detail screen.
///
/// [tasks] contains only tasks assigned to the goal; [hierarchy] nests their
/// direct subtasks. Progress is counted from actionable leaves so parent
/// headings are never double-counted.
class GoalDetail {
  const GoalDetail({
    required this.goal,
    required this.tasks,
    required this.hierarchy,
    required this.progress,
    required this.status,
  });

  factory GoalDetail.fromRows({
    required GoalRow goal,
    required Iterable<TaskRow> allTasks,
    required DateTime now,
  }) {
    final assignedTasks = <TaskRow>[
      for (final task in allTasks)
        if (task.goalId == goal.id) task,
    ];
    final progress = GoalProgress.fromTasks(goal.id, assignedTasks);
    return GoalDetail(
      goal: goal,
      tasks: List<TaskRow>.unmodifiable(assignedTasks),
      hierarchy: TaskHierarchy.fromRows(assignedTasks),
      progress: progress,
      status: GoalStatus.evaluate(
        progress: progress,
        targetDate: goal.targetDate,
        now: now,
      ),
    );
  }

  final GoalRow goal;

  /// Flat list of tasks assigned to the goal, in repository order.
  final List<TaskRow> tasks;
  final TaskHierarchy hierarchy;
  final GoalProgress progress;
  final GoalStatus status;

  int get remainingLeaves => progress.totalLeaves - progress.completedLeaves;

  bool get hasTasks => tasks.isNotEmpty;
}
