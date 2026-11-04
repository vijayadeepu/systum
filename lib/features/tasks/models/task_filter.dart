/// Status dimension of a task filter.
enum TaskStatusFilter { all, active, completed }

/// Time dimension of a task filter.
///
/// All date boundaries use the local calendar date, matching the date-only
/// semantics of persisted due dates. Tasks without a due date never match a
/// time-based filter.
enum TaskTimeFilter { all, today, upcoming, overdue, custom }

/// A composable filter over the task collection.
///
/// All dimensions are optional and intersect logically: a task must match
/// every active dimension to be included. Clearing one dimension leaves the
/// others untouched.
class TaskFilter {
  const TaskFilter({
    this.status = TaskStatusFilter.all,
    this.time = TaskTimeFilter.all,
    this.priority,
    this.goalId,
    this.parentTaskId,
    this.includeSubtasks,
    this.category,
    this.startDate,
    this.endDate,
  });

  /// Status filter: all, active, or completed tasks.
  final TaskStatusFilter status;

  /// Time filter: all, today, upcoming, overdue, or a custom date range.
  final TaskTimeFilter time;

  /// Exact priority value to match, or null to match any priority.
  final int? priority;

  /// Goal ID to match, or null to match any goal (including none).
  final String? goalId;

  /// Parent task ID to match (direct children only), or null to not filter by
  /// parentage via this dimension.
  final String? parentTaskId;

  /// When true, only subtasks (tasks with a parent) match. When false, only
  /// top-level tasks match. When null, no subtask filtering is applied.
  final bool? includeSubtasks;

  /// Category to match, or null to match any category (including none).
  final String? category;

  /// Inclusive start date for a custom range, or null for no lower bound.
  final DateTime? startDate;

  /// Inclusive end date for a custom range, or null for no upper bound.
  final DateTime? endDate;

  bool get isAnyActive {
    return status != TaskStatusFilter.all ||
        time != TaskTimeFilter.all ||
        priority != null ||
        goalId != null ||
        parentTaskId != null ||
        includeSubtasks != null ||
        category != null ||
        startDate != null ||
        endDate != null;
  }

  TaskFilter copyWith({
    TaskStatusFilter? status,
    TaskTimeFilter? time,
    int? priority,
    String? goalId,
    String? parentTaskId,
    bool? includeSubtasks,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    bool clearPriority = false,
    bool clearGoal = false,
    bool clearParent = false,
    bool clearSubtasks = false,
    bool clearCategory = false,
    bool clearDateRange = false,
  }) {
    return TaskFilter(
      status: status ?? this.status,
      time: time ?? this.time,
      priority: clearPriority ? null : (priority ?? this.priority),
      goalId: clearGoal ? null : (goalId ?? this.goalId),
      parentTaskId: clearParent ? null : (parentTaskId ?? this.parentTaskId),
      includeSubtasks: clearSubtasks
          ? null
          : (includeSubtasks ?? this.includeSubtasks),
      category: clearCategory ? null : (category ?? this.category),
      startDate: clearDateRange ? null : (startDate ?? this.startDate),
      endDate: clearDateRange ? null : (endDate ?? this.endDate),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TaskFilter &&
            status == other.status &&
            time == other.time &&
            priority == other.priority &&
            goalId == other.goalId &&
            parentTaskId == other.parentTaskId &&
            includeSubtasks == other.includeSubtasks &&
            category == other.category &&
            startDate == other.startDate &&
            endDate == other.endDate;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      time,
      priority,
      goalId,
      parentTaskId,
      includeSubtasks,
      category,
      startDate,
      endDate,
    );
  }
}
