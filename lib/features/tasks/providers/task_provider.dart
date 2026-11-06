import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/providers/logger_provider.dart';
import '../../reminders/notifications/reminder_delivery_provider.dart';
import '../models/task.dart';
import '../models/task_filter.dart';
import '../models/task_hierarchy.dart';
import '../models/task_recurrence.dart';
import '../models/task_sort.dart';
import '../repository/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return TaskRepository(database);
});

/// The raw search query text entered by the user.
///
/// [NotifierProvider] is used instead of the legacy [StateProvider] because
/// Riverpod 3 does not export StateProvider from flutter_riverpod.
final taskSearchQueryProvider =
    NotifierProvider<TaskSearchQueryNotifier, String>(
      TaskSearchQueryNotifier.new,
    );

class TaskSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

/// The current task filter state.
///
/// All dimensions are optional and intersect logically. Filters are UI-only
/// state and are not persisted.
final taskFilterProvider = NotifierProvider<TaskFilterNotifier, TaskFilter>(
  TaskFilterNotifier.new,
);

class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => const TaskFilter();

  /// Updates one or more filter dimensions. Unmentioned dimensions are
  /// preserved so filters compose correctly.
  void updateFilter({
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
    state = state.copyWith(
      status: status,
      time: time,
      priority: priority,
      goalId: goalId,
      parentTaskId: parentTaskId,
      includeSubtasks: includeSubtasks,
      category: category,
      startDate: startDate,
      endDate: endDate,
      clearPriority: clearPriority,
      clearGoal: clearGoal,
      clearParent: clearParent,
      clearSubtasks: clearSubtasks,
      clearCategory: clearCategory,
      clearDateRange: clearDateRange,
    );
  }

  /// Clears every filter dimension.
  void clearAll() => state = const TaskFilter();
}

/// The current task view.
///
/// Views determine which subset of tasks is displayed. Views intersect
/// logically with filters: switching views does not clear filters or search.
final taskViewProvider = NotifierProvider<TaskViewNotifier, TaskView>(
  TaskViewNotifier.new,
);

class TaskViewNotifier extends Notifier<TaskView> {
  @override
  TaskView build() => TaskView.all;

  /// Sets the active view. Filters and search are preserved so they compose
  /// with the view constraints.
  void setView(TaskView view) => state = view;
}

/// The current task sort configuration.
final taskSortProvider = NotifierProvider<TaskSortNotifier, TaskSort>(
  TaskSortNotifier.new,
);

class TaskSortNotifier extends Notifier<TaskSort> {
  @override
  TaskSort build() => const TaskSort();

  /// Sets the sort mode. Toggling the same mode reverses the order;
  /// switching to a new mode uses the default order for that mode.
  void setMode(TaskSortMode mode) {
    if (state.mode == mode) {
      state = state.copyWith(
        order: state.order == TaskSortOrder.ascending
            ? TaskSortOrder.descending
            : TaskSortOrder.ascending,
      );
    } else {
      state = TaskSort(mode: mode);
    }
  }

  /// Sets the sort order directly.
  void setOrder(TaskSortOrder order) => state = state.copyWith(order: order);
}

/// Aggregated data for the task detail view.
class TaskDetail {
  const TaskDetail({required this.task, this.focusSessions = const []});

  final TaskRow task;
  final List<FocusSessionRow> focusSessions;

  bool get hasFocusSessions => focusSessions.isNotEmpty;
}

/// Thrown when the requested task does not exist.
class TaskNotFoundException implements Exception {
  const TaskNotFoundException(this.taskId);

  final String taskId;

  @override
  String toString() => 'TaskNotFoundException: Task "$taskId" does not exist.';
}

/// Detail for one task, including its linked focus sessions.
final taskDetailProvider = FutureProvider.family<TaskDetail, String>((
  ref,
  taskId,
) async {
  final repository = ref.watch(taskRepositoryProvider);
  final task = await repository.getById(taskId);
  if (task == null) {
    throw TaskNotFoundException(taskId);
  }
  final focusSessions = await repository.getFocusSessionsForTask(taskId);
  return TaskDetail(task: task, focusSessions: focusSessions);
});

/// Whether the search field is currently active in the UI.
final taskSearchIsActiveProvider =
    NotifierProvider<TaskSearchIsActiveNotifier, bool>(
      TaskSearchIsActiveNotifier.new,
    );

class TaskSearchIsActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setActive(bool value) => state = value;
}

/// Debounced task search results, combined with the active task filter.
///
/// The notifier debounces user input (300 ms) to avoid excessive database
/// queries. Each search call increments a revision so only the latest
/// pending query can update state, preventing stale results when queries
/// change rapidly or the screen is disposed during a pending query.
///
/// When the query is empty, results reflect the active filter only (or all
/// tasks when no filter is set). When the query is non-empty, results match
/// both the query and the filter. The provider also refreshes when the
/// underlying task list changes ([taskProvider]) or when the filter changes
/// ([taskFilterProvider]), so results stay consistent after mutations.
final taskSearchProvider =
    AsyncNotifierProvider<TaskSearchNotifier, List<TaskRow>>(
      TaskSearchNotifier.new,
    );

class TaskSearchNotifier extends AsyncNotifier<List<TaskRow>> {
  late final TaskRepository _repository;
  Timer? _debounceTimer;
  int _revision = 0;
  bool _disposed = false;
  String _currentQuery = '';

  static const _debounceDuration = Duration(milliseconds: 300);

  @override
  Future<List<TaskRow>> build() async {
    _repository = ref.read(taskRepositoryProvider);
    ref.onDispose(() {
      _disposed = true;
      _debounceTimer?.cancel();
    });

    // Re-run the search whenever the filter changes so filtered results stay
    // in sync with the active filter.
    ref.listen(taskFilterProvider, (_, _) {
      if (!_disposed) {
        search(_currentQuery);
      }
    });

    // Re-run the search whenever the underlying task list changes (for
    // example, after a create/edit/delete) so results reflect the latest data.
    ref.listen(taskProvider, (_, _) {
      if (!_disposed) {
        search(_currentQuery);
      }
    });

    // Re-run the search whenever the sort changes so results stay sorted.
    ref.listen(taskSortProvider, (_, _) {
      if (!_disposed) {
        search(_currentQuery);
      }
    });

    // Re-run the search whenever the view changes so results reflect the new
    // view constraints while preserving filters and search.
    ref.listen(taskViewProvider, (_, _) {
      if (!_disposed) {
        search(_currentQuery);
      }
    });

    final filter = ref.read(taskFilterProvider);
    final sort = ref.read(taskSortProvider);
    final view = ref.read(taskViewProvider);
    return _repository.filterTasks(filter, sort: sort, view: view);
  }

  /// Starts a debounced search for [query], combined with the active filter,
  /// sort, and view.
  ///
  /// Empty or whitespace-only queries return tasks matching the active filter
  /// and view (or all tasks when no filter or view is set).
  Future<void> search(String query) async {
    _debounceTimer?.cancel();
    _currentQuery = query;
    final trimmed = query.trim();
    final revision = ++_revision;
    final filter = ref.read(taskFilterProvider);
    final sort = ref.read(taskSortProvider);
    final view = ref.read(taskViewProvider);

    if (!_disposed) state = const AsyncLoading<List<TaskRow>>();

    _debounceTimer = Timer(_debounceDuration, () async {
      if (_disposed) return;
      try {
        final results = await AsyncValue.guard(() {
          if (trimmed.isEmpty) {
            return _repository.filterTasks(filter, sort: sort, view: view);
          }
          return _repository.searchAndFilter(
            trimmed,
            filter,
            sort: sort,
            view: view,
          );
        });
        if (!_disposed && revision == _revision) {
          state = results;
        }
      } catch (error, stackTrace) {
        if (!_disposed && revision == _revision) {
          state = AsyncError(error, stackTrace);
        }
      }
    });
  }

  /// Cancels any pending debounce timer so stale results cannot be written
  /// after a new search is initiated.
  void cancelPending() {
    _debounceTimer?.cancel();
  }
}

/// The canonical task state is a flat collection.
///
/// Subtasks carry their `parentTaskId`, so a single list stays consistent with
/// the database and can be grouped for display without maintaining a second,
/// independently refreshable hierarchy. [taskHierarchyProvider] is a pure
/// projection of this state.
final taskProvider = AsyncNotifierProvider<TaskNotifier, List<TaskRow>>(
  TaskNotifier.new,
);

final taskHierarchyProvider = Provider<TaskHierarchy>((ref) {
  final tasks = ref.watch(taskProvider).value;
  return TaskHierarchy.fromRows(tasks ?? const []);
});

class TaskNotifier extends AsyncNotifier<List<TaskRow>> {
  late final TaskRepository _repository = ref.read(taskRepositoryProvider);
  int _stateRevision = 0;

  @override
  Future<List<TaskRow>> build() async {
    final sort = ref.read(taskSortProvider);

    // Re-sort whenever the sort configuration changes.
    ref.listen(taskSortProvider, (_, _) {
      refresh();
    });

    final revision = _stateRevision;
    final result = await AsyncValue.guard(() => _repository.getAll(sort: sort));
    if (revision != _stateRevision) {
      final currentState = state;
      if (currentState.hasValue) {
        return currentState.requireValue;
      }
      if (currentState case AsyncError(:final error, :final stackTrace)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
    if (result case AsyncError(:final error, :final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    return result.requireValue;
  }

  Future<void> loadTasks() {
    return refresh();
  }

  Future<void> addTask(Task task) {
    return _mutate(() => _repository.insert(task));
  }

  Future<void> updateTask(Task task) {
    return _mutate(() => _repository.update(task));
  }

  Future<void> createSubtask(Task subtask, String parentTaskId) {
    return _mutate(() => _repository.createSubtask(subtask, parentTaskId));
  }

  /// Creates a top-level task that belongs to [goalId] from the start.
  Future<void> createTaskInGoal(Task task, String goalId) {
    return _mutate(() => _repository.insertInGoal(task, goalId));
  }

  /// Creates a task and its recurrence rule/initial occurrences atomically.
  Future<void> createTaskWithRecurrence(Task task, RecurrenceDraft draft) {
    return _mutate(() => _repository.createTaskWithRecurrence(task, draft));
  }

  /// Creates a goal-assigned task and its recurrence atomically.
  Future<void> createTaskInGoalWithRecurrence(
    Task task,
    String goalId,
    RecurrenceDraft draft,
  ) {
    return _mutate(
      () => _repository.createTaskWithRecurrence(task, draft, goalId: goalId),
    );
  }

  /// Updates a task together with its recurrence configuration.
  Future<void> updateTaskWithRecurrence(
    Task task,
    RecurrenceDraft? draft, {
    String? existingRuleId,
  }) async {
    await _mutate(
      () => _repository.updateTaskWithRecurrence(
        task,
        draft,
        existingRuleId: existingRuleId,
      ),
    );
  }

  /// Stops future generation for a rule while preserving all history.
  Future<void> stopRecurrence(String ruleId) {
    return _mutate(() => _repository.stopRecurrence(ruleId));
  }

  /// Returns the recurrence rule for a parent task, if one exists.
  Future<TaskRecurrenceRule?> getRecurrenceForTask(String taskId) {
    return _repository.getRecurrenceRuleForParent(taskId);
  }

  /// Assigns a top-level task and its direct subtasks to a goal. The
  /// repository applies the atomic parent/child propagation rule.
  Future<void> assignToGoal(String taskId, String goalId) {
    return _mutate(() => _repository.assignToGoal(taskId, goalId));
  }

  /// Clears a top-level task's goal and the inherited goal of its subtasks.
  Future<void> removeFromGoal(String taskId) {
    return _mutate(() => _repository.removeFromGoal(taskId));
  }

  /// Deletes a task. Direct subtasks of a parent are promoted to standalone
  /// tasks by the repository and the refreshed state reflects the promotion.
  Future<void> deleteTask(String id) async {
    // Reminder rows cascade with the task, so capture their notification
    // identities before the delete and cancel them afterwards.
    final reminderIds = await _reminderIdsForTask(id);
    await _mutate(() => _repository.delete(id));
    await _cancelReminderNotifications(reminderIds);
  }

  Future<void> setCompleted(String id, bool completed) async {
    await _mutate(() => _repository.setCompleted(id, completed));
    // D2 owns completion/reopen reminder state. Mirror the persisted result
    // into Android without re-deriving the lifecycle rules here.
    await _syncTaskReminders(id);
  }

  /// Independently completes or reopens one occurrence of a recurring task.
  ///
  /// The recurrence rule and every sibling occurrence are left untouched.
  Future<void> setOccurrenceCompleted(String id, bool completed) async {
    await _mutate(() => _repository.setOccurrenceCompleted(id, completed));
  }

  /// Moves one occurrence to [dueDate] without touching its rule or any
  /// sibling occurrence.
  Future<void> rescheduleOccurrence(String id, DateTime dueDate) async {
    await _mutate(() => _repository.rescheduleOccurrence(id, dueDate));
  }

  Future<List<String>> _reminderIdsForTask(String taskId) async {
    try {
      return await ref
          .read(reminderDeliveryProvider)
          .reminderIdsForTask(taskId);
    } catch (error, stackTrace) {
      _logNotificationIssue(error, stackTrace);
      return const [];
    }
  }

  Future<void> _syncTaskReminders(String taskId) async {
    try {
      await ref.read(reminderDeliveryProvider).syncTask(taskId);
    } catch (error, stackTrace) {
      _logNotificationIssue(error, stackTrace);
    }
  }

  Future<void> _cancelReminderNotifications(
    Iterable<String> reminderIds,
  ) async {
    try {
      await ref.read(reminderDeliveryProvider).cancelReminderIds(reminderIds);
    } catch (error, stackTrace) {
      _logNotificationIssue(error, stackTrace);
    }
  }

  void _logNotificationIssue(Object error, StackTrace stackTrace) {
    ref
        .read(loggerProvider)
        .w(
          'Reminder notification sync failed after a task mutation. '
          'The task change was kept.',
          error: error,
          stackTrace: stackTrace,
        );
  }

  Future<void> refresh() async {
    final sort = ref.read(taskSortProvider);
    final revision = ++_stateRevision;
    state = const AsyncLoading<List<TaskRow>>();
    final result = await AsyncValue.guard(() => _repository.getAll(sort: sort));
    if (revision == _stateRevision) {
      state = result;
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    await action();
    final revision = ++_stateRevision;

    try {
      final sort = ref.read(taskSortProvider);
      final tasks = await _repository.getAll(sort: sort);
      if (revision == _stateRevision) {
        state = AsyncData(tasks);
      }
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(TaskMutationReloadException(error), stackTrace);
    }
  }
}

class TaskMutationReloadException implements Exception {
  const TaskMutationReloadException(this.cause);

  final Object cause;
}
