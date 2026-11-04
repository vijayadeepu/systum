import 'package:flutter/material.dart';

/// The active task view.
///
/// Views determine which subset of tasks is displayed. Views intersect
/// logically with filters: a task must match both the active view and every
/// active filter dimension to be included.
enum TaskView {
  all,
  today,
  upcoming,
  overdue,
  completed,
  byGoal,
  byPriority,
  recentlyUpdated,
}

/// Human-readable label for a task view.
String taskViewLabel(TaskView view) {
  switch (view) {
    case TaskView.all:
      return 'All tasks';
    case TaskView.today:
      return 'Today';
    case TaskView.upcoming:
      return 'Upcoming';
    case TaskView.overdue:
      return 'Overdue';
    case TaskView.completed:
      return 'Completed';
    case TaskView.byGoal:
      return 'By goal';
    case TaskView.byPriority:
      return 'By priority';
    case TaskView.recentlyUpdated:
      return 'Recently updated';
  }
}

/// Icon data for a task view.
IconData taskViewIcon(TaskView view) {
  switch (view) {
    case TaskView.all:
      return Icons.task_alt_rounded;
    case TaskView.today:
      return Icons.today_rounded;
    case TaskView.upcoming:
      return Icons.calendar_today_rounded;
    case TaskView.overdue:
      return Icons.warning_rounded;
    case TaskView.completed:
      return Icons.check_circle_rounded;
    case TaskView.byGoal:
      return Icons.flag_rounded;
    case TaskView.byPriority:
      return Icons.priority_high_rounded;
    case TaskView.recentlyUpdated:
      return Icons.update_rounded;
  }
}

/// Whether the view groups tasks into sections rather than rendering a flat
/// list.
bool taskViewIsGrouped(TaskView view) {
  switch (view) {
    case TaskView.byGoal:
    case TaskView.byPriority:
      return true;
    case TaskView.all:
    case TaskView.today:
    case TaskView.upcoming:
    case TaskView.overdue:
    case TaskView.completed:
    case TaskView.recentlyUpdated:
      return false;
  }
}

/// The field by which tasks are sorted.
enum TaskSortMode {
  creationDate,
  updatedDate,
  dueDate,
  priority,
  alphabetical,
  completionStatus,
}

/// The sort direction.
enum TaskSortOrder { ascending, descending }

/// A sorting configuration applied to the task collection.
///
/// Sorting never mutates stored task data. When multiple tasks share the same
/// sort value, a deterministic tie-breaker (createdAt DESC, then id ASC)
/// ensures a stable, repeatable order.
class TaskSort {
  const TaskSort({
    this.mode = TaskSortMode.creationDate,
    this.order = TaskSortOrder.descending,
  });

  final TaskSortMode mode;
  final TaskSortOrder order;

  bool get isDescending => order == TaskSortOrder.descending;

  TaskSort copyWith({TaskSortMode? mode, TaskSortOrder? order}) {
    return TaskSort(mode: mode ?? this.mode, order: order ?? this.order);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TaskSort && mode == other.mode && order == other.order;
  }

  @override
  int get hashCode => Object.hash(mode, order);
}

/// Human-readable label for a sort mode.
String taskSortModeLabel(TaskSortMode mode) {
  switch (mode) {
    case TaskSortMode.creationDate:
      return 'Created';
    case TaskSortMode.updatedDate:
      return 'Updated';
    case TaskSortMode.dueDate:
      return 'Due date';
    case TaskSortMode.priority:
      return 'Priority';
    case TaskSortMode.alphabetical:
      return 'Title';
    case TaskSortMode.completionStatus:
      return 'Completion';
  }
}

/// Human-readable label for a sort order.
String taskSortOrderLabel(TaskSortOrder order) {
  switch (order) {
    case TaskSortOrder.ascending:
      return 'Ascending';
    case TaskSortOrder.descending:
      return 'Descending';
  }
}
