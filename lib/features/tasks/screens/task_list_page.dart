import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../goals/providers/goal_provider.dart';
import '../../goals/widgets/assignment_dialogs.dart';

import '../models/task.dart';
import '../models/task_filter.dart';
import '../models/task_recurrence.dart';
import '../models/task_sort.dart';
import '../providers/countdown_provider.dart';
import '../providers/recurrence_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/create_task_dialog.dart';
import '../widgets/task_delete_dialog.dart';
import '../widgets/task_tile.dart';
import 'daily_agenda_page.dart';

class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSearchActive = ref.watch(taskSearchIsActiveProvider);
    final filter = ref.watch(taskFilterProvider);
    final searchState = ref.watch(taskSearchProvider);
    final tasksState = ref.watch(taskProvider);
    final hierarchy = ref.watch(taskHierarchyProvider);
    final goalsState = ref.watch(goalProvider);
    final goalTitles = {
      for (final goal in goalsState.value ?? const <GoalRow>[])
        goal.id: goal.title,
    };
    final showFilters = filter.isAnyActive;
    final view = ref.watch(taskViewProvider);
    final showSearchResults =
        isSearchActive || showFilters || view != TaskView.all;
    final sort = ref.watch(taskSortProvider);
    final groupedView = view == TaskView.byGoal || view == TaskView.byPriority;
    final countdownState = ref.watch(countdownProvider);
    final countdowns =
        countdownState.value ?? const <String, CountdownResult>{};
    final recurrenceRules =
        ref.watch(allTaskRecurrenceRulesProvider).value ??
        const <String, TaskRecurrenceRule>{};

    return Scaffold(
      appBar: AppBar(
        title: isSearchActive ? const _SearchField() : const Text('Tasks'),
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Open navigation menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
        ),
        actions: [
          if (isSearchActive)
            IconButton(
              tooltip: 'Close search',
              onPressed: () {
                ref.read(taskSearchIsActiveProvider.notifier).setActive(false);
                ref.read(taskSearchQueryProvider.notifier).setQuery('');
                ref.read(taskSearchProvider.notifier).search('');
              },
              icon: const Icon(Icons.close_rounded),
            )
          else
            IconButton(
              tooltip: 'Search tasks',
              onPressed: () =>
                  ref.read(taskSearchIsActiveProvider.notifier).setActive(true),
              icon: const Icon(Icons.search_rounded),
            ),
          TextButton.icon(
            onPressed: () => _showSortBottomSheet(context, ref),
            icon: const Icon(Icons.sort_rounded),
            label: Text(
              '${taskSortModeLabel(sort.mode)} ${taskSortOrderLabel(sort.order)}',
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, ref),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showDialog<CreateTaskResult>(
            context: context,
            builder: (_) => const CreateTaskDialog(),
          );

          if (result != null && context.mounted) {
            try {
              final recurrence = result.recurrence;
              if (recurrence == null) {
                await ref.read(taskProvider.notifier).addTask(result.task);
              } else {
                await ref
                    .read(recurrenceActionsProvider)
                    .createTaskWithRecurrence(result.task, recurrence);
              }
            } catch (error) {
              if (context.mounted) {
                _showMutationError(context, 'Could not create task', error);
              }
            }
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create task'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task filter row: compact readable labels for the most common views.
          // Horizontally scrollable so it stays safe on narrow screens.
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              clipBehavior: Clip.none,
              children: [
                _FilterButton(
                  label: 'All',
                  selected: view == TaskView.all,
                  onTap: () {
                    ref.read(taskViewProvider.notifier).setView(TaskView.all);
                    ref.read(taskFilterProvider.notifier).clearAll();
                    if (isSearchActive) {
                      ref.read(taskSearchQueryProvider.notifier).setQuery('');
                      ref.read(taskSearchProvider.notifier).search('');
                    }
                  },
                ),
                _FilterButton(
                  label: 'Today',
                  selected: view == TaskView.today,
                  onTap: () {
                    ref.read(taskViewProvider.notifier).setView(TaskView.today);
                    ref.read(taskFilterProvider.notifier).clearAll();
                    if (isSearchActive) {
                      ref.read(taskSearchQueryProvider.notifier).setQuery('');
                      ref.read(taskSearchProvider.notifier).search('');
                    }
                  },
                ),
                _FilterButton(
                  label: 'Upcoming',
                  selected: view == TaskView.upcoming,
                  onTap: () {
                    ref
                        .read(taskViewProvider.notifier)
                        .setView(TaskView.upcoming);
                    ref.read(taskFilterProvider.notifier).clearAll();
                    if (isSearchActive) {
                      ref.read(taskSearchQueryProvider.notifier).setQuery('');
                      ref.read(taskSearchProvider.notifier).search('');
                    }
                  },
                ),
                _FilterButton(
                  label: 'Overdue',
                  selected: view == TaskView.overdue,
                  onTap: () {
                    ref
                        .read(taskViewProvider.notifier)
                        .setView(TaskView.overdue);
                    ref.read(taskFilterProvider.notifier).clearAll();
                    if (isSearchActive) {
                      ref.read(taskSearchQueryProvider.notifier).setQuery('');
                      ref.read(taskSearchProvider.notifier).search('');
                    }
                  },
                ),
              ],
            ),
          ),
          if (showFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ..._buildFilterChips(ref, filter),
                  if (showFilters)
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.read(taskFilterProvider.notifier).clearAll();
                        if (isSearchActive) {
                          ref
                              .read(taskSearchQueryProvider.notifier)
                              .setQuery('');
                          ref.read(taskSearchProvider.notifier).search('');
                        }
                      },
                      icon: const Icon(Icons.clear_all_rounded, size: 18),
                      label: const Text('Clear filters'),
                    ),
                ],
              ),
            ),
          Expanded(
            child: showSearchResults
                ? _buildViewResultsBody(
                    context,
                    ref,
                    searchState,
                    view,
                    groupedView,
                  )
                : tasksState.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) {
                      final message = error.toString();

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 48),
                              const SizedBox(height: AppSpacing.md),
                              Text(message, textAlign: TextAlign.center),
                              const SizedBox(height: AppSpacing.sm),
                              FilledButton.icon(
                                onPressed: () =>
                                    ref.read(taskProvider.notifier).refresh(),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    data: (tasks) {
                      if (tasks.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.task_alt_outlined, size: 48),
                                SizedBox(height: AppSpacing.md),
                                Text('No tasks yet'),
                                SizedBox(height: AppSpacing.xs),
                                Text('Create your first task to get started.'),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        itemCount: hierarchy.roots.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final task = hierarchy.roots[index];
                          final subtasks = hierarchy.childrenOf(task.id);

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TaskTile(
                                task: task,
                                subtaskCount: subtasks.length,
                                goalTitle: goalTitles[task.goalId],
                                countdown: countdowns[task.id],
                                recurrenceSummary:
                                    recurrenceRules[task.id]?.summary,
                                onOpenGoal: task.goalId == null
                                    ? null
                                    : () =>
                                          context.push('/goal/${task.goalId}'),
                                onAssignGoal: () =>
                                    _assignGoal(context, ref, task),
                                onRemoveFromGoal: task.goalId == null
                                    ? null
                                    : () => _removeFromGoal(context, ref, task),
                                onAddSubtask: () =>
                                    _addSubtask(context, ref, task),
                                onEdit: () => _editTask(context, ref, task),
                                onStartFocus: () => context.push(
                                  Uri(
                                    path: '/focus',
                                    queryParameters: {'taskId': task.id},
                                  ).toString(),
                                ),
                                onDelete: () => _deleteTask(
                                  context,
                                  ref,
                                  task,
                                  subtaskCount: subtasks.length,
                                ),
                                onToggle: (completed) => _setCompleted(
                                  context,
                                  ref,
                                  task,
                                  completed,
                                ),
                              ),
                              for (final subtask in subtasks)
                                TaskTile(
                                  task: subtask,
                                  isSubtask: true,
                                  goalTitle: goalTitles[subtask.goalId],
                                  countdown: countdowns[subtask.id],
                                  recurrenceSummary:
                                      recurrenceRules[subtask.id]?.summary,
                                  onOpenGoal: subtask.goalId == null
                                      ? null
                                      : () => context.push(
                                          '/goal/${subtask.goalId}',
                                        ),
                                  onEdit: () =>
                                      _editTask(context, ref, subtask),
                                  onStartFocus: () => context.push(
                                    Uri(
                                      path: '/focus',
                                      queryParameters: {'taskId': subtask.id},
                                    ).toString(),
                                  ),
                                  onDelete: () =>
                                      _deleteTask(context, ref, subtask),
                                  onToggle: (completed) => _setCompleted(
                                    context,
                                    ref,
                                    subtask,
                                    completed,
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _editTask(
    BuildContext context,
    WidgetRef ref,
    TaskRow taskRow,
  ) async {
    try {
      final existingRule = await ref
          .read(taskProvider.notifier)
          .getRecurrenceForTask(taskRow.id);
      if (!context.mounted) {
        return;
      }
      final result = await showDialog<CreateTaskResult>(
        context: context,
        builder: (_) => CreateTaskDialog(
          task: Task.fromRow(taskRow),
          existingRecurrence: existingRule,
        ),
      );

      if (result == null || !context.mounted) {
        return;
      }

      await ref
          .read(recurrenceActionsProvider)
          .updateTaskWithRecurrence(
            result.task,
            result.recurrence,
            existingRule: existingRule,
          );
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, 'Could not edit task', error);
      }
    }
  }

  Future<void> _addSubtask(
    BuildContext context,
    WidgetRef ref,
    TaskRow parent,
  ) async {
    final result = await showDialog<CreateTaskResult>(
      context: context,
      builder: (_) => CreateTaskDialog(parentTitle: parent.title),
    );

    if (result == null || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(taskProvider.notifier)
          .createSubtask(result.task, parent.id);
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, 'Could not add subtask', error);
      }
    }
  }

  Future<void> _setCompleted(
    BuildContext context,
    WidgetRef ref,
    TaskRow task,
    bool? completed,
  ) async {
    if (completed == null) {
      return;
    }

    try {
      await ref.read(taskProvider.notifier).setCompleted(task.id, completed);
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, 'Could not update task', error);
      }
    }
  }

  Future<void> _assignGoal(
    BuildContext context,
    WidgetRef ref,
    TaskRow task,
  ) async {
    final goalState = ref.read(goalProvider);
    if (goalState case AsyncError(:final error)) {
      _showGoalLoadError(context, ref, error);
      return;
    }

    final List<GoalRow> goals;
    try {
      goals = goalState.hasValue
          ? goalState.requireValue
          : await ref.read(goalProvider.future);
    } catch (error) {
      if (context.mounted) {
        _showGoalLoadError(context, ref, error);
      }
      return;
    }

    if (!context.mounted) {
      return;
    }

    final goalId = await showDialog<String>(
      context: context,
      builder: (_) => GoalPickerDialog(goals: goals, taskTitle: task.title),
    );

    if (goalId == null || !context.mounted) {
      return;
    }

    try {
      await ref.read(taskProvider.notifier).assignToGoal(task.id, goalId);
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, 'Could not assign task to goal', error);
      }
    }
  }

  void _showGoalLoadError(BuildContext context, WidgetRef ref, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not load goals: $error'),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => ref.read(goalProvider.notifier).refresh(),
        ),
      ),
    );
  }

  Future<void> _removeFromGoal(
    BuildContext context,
    WidgetRef ref,
    TaskRow task,
  ) async {
    try {
      await ref.read(taskProvider.notifier).removeFromGoal(task.id);
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, 'Could not remove task from goal', error);
      }
    }
  }

  Future<void> _deleteTask(
    BuildContext context,
    WidgetRef ref,
    TaskRow task, {
    int subtaskCount = 0,
  }) async {
    final confirmed = await confirmTaskDeletion(
      context,
      task,
      subtaskCount: subtaskCount,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await ref.read(taskProvider.notifier).deleteTask(task.id);
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, 'Could not delete task', error);
      }
    }
  }

  void _showMutationError(BuildContext context, String message, Object error) {
    if (!context.mounted) {
      return;
    }
    final content = switch (error) {
      TaskMutationReloadException(:final cause) =>
        'Task change succeeded, but the task list could not be refreshed: '
            '$cause',
      _ => '$message: $error',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(content)));
  }

  Widget _buildViewResultsBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<TaskRow>> state,
    TaskView view,
    bool groupedView,
  ) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Could not load tasks: $error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: () {
                    final query = ref.read(taskSearchQueryProvider);
                    ref.read(taskSearchProvider.notifier).search(query);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
      data: (results) {
        if (results.isEmpty) {
          return _buildEmptyViewState(view);
        }
        final recurrenceRules =
            ref.watch(allTaskRecurrenceRulesProvider).value ??
            const <String, TaskRecurrenceRule>{};

        if (groupedView) {
          return _buildGroupedViewBody(context, ref, results, view);
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
          itemBuilder: (context, index) {
            final task = results[index];
            return TaskTile(
              task: task,
              goalTitle: goalTitlesForSearch(ref, task.goalId),
              recurrenceSummary: recurrenceRules[task.id]?.summary,
              onOpenGoal: task.goalId == null
                  ? null
                  : () => context.push('/goal/${task.goalId}'),
              onAssignGoal: () => _assignGoalFromSearch(context, ref, task),
              onRemoveFromGoal: task.goalId == null
                  ? null
                  : () => _removeFromGoal(context, ref, task),
              onAddSubtask: () => _addSubtask(context, ref, task),
              onEdit: () => _editTask(context, ref, task),
              onStartFocus: () => context.push(
                Uri(
                  path: '/focus',
                  queryParameters: {'taskId': task.id},
                ).toString(),
              ),
              onDelete: () => _deleteTask(context, ref, task),
              onToggle: (completed) =>
                  _setCompleted(context, ref, task, completed),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyViewState(TaskView view) {
    final iconData = taskViewIcon(view);
    final label = taskViewLabel(view);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 48),
            SizedBox(height: AppSpacing.md),
            Text('No $label'),
            SizedBox(height: AppSpacing.xs),
            Text('There are no tasks matching this view.'),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedViewBody(
    BuildContext context,
    WidgetRef ref,
    List<TaskRow> results,
    TaskView view,
  ) {
    if (view == TaskView.byGoal) {
      return _buildGoalGroupedBody(context, ref, results);
    }
    if (view == TaskView.byPriority) {
      return _buildPriorityGroupedBody(context, ref, results);
    }
    final recurrenceRules =
        ref.watch(allTaskRecurrenceRulesProvider).value ??
        const <String, TaskRecurrenceRule>{};
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final task = results[index];
        return TaskTile(
          task: task,
          goalTitle: goalTitlesForSearch(ref, task.goalId),
          recurrenceSummary: recurrenceRules[task.id]?.summary,
          onOpenGoal: task.goalId == null
              ? null
              : () => context.push('/goal/${task.goalId}'),
          onAssignGoal: () => _assignGoalFromSearch(context, ref, task),
          onRemoveFromGoal: task.goalId == null
              ? null
              : () => _removeFromGoal(context, ref, task),
          onAddSubtask: () => _addSubtask(context, ref, task),
          onEdit: () => _editTask(context, ref, task),
          onStartFocus: () => context.push(
            Uri(
              path: '/focus',
              queryParameters: {'taskId': task.id},
            ).toString(),
          ),
          onDelete: () => _deleteTask(context, ref, task),
          onToggle: (completed) => _setCompleted(context, ref, task, completed),
        );
      },
    );
  }

  Widget _buildGoalGroupedBody(
    BuildContext context,
    WidgetRef ref,
    List<TaskRow> results,
  ) {
    final goalsState = ref.watch(goalProvider);
    final goalTitles = <String, String>{};
    if (goalsState case AsyncData(:final value)) {
      for (final goal in value) {
        goalTitles[goal.id] = goal.title;
      }
    }

    final unassigned = <TaskRow>[];
    final byGoal = <String, List<TaskRow>>{};

    for (final task in results) {
      final taskGoalId = task.goalId;
      if (taskGoalId == null) {
        unassigned.add(task);
      } else {
        byGoal.putIfAbsent(taskGoalId, () => []).add(task);
      }
    }

    final sortedGoalIds = byGoal.keys.toList()
      ..sort((a, b) => (goalTitles[a] ?? a).compareTo(goalTitles[b] ?? b));

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        // Unassigned group first.
        if (unassigned.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              'No goal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          ..._buildGroupTaskTiles(context, ref, unassigned),
          const Divider(height: 1),
        ],
        // Goal groups sorted by title.
        for (final goalId in sortedGoalIds) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              goalTitles[goalId] ?? goalId,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          ..._buildGroupTaskTiles(context, ref, byGoal[goalId]!),
          const Divider(height: 1),
        ],
      ],
    );
  }

  Widget _buildPriorityGroupedBody(
    BuildContext context,
    WidgetRef ref,
    List<TaskRow> results,
  ) {
    final byPriority = <int, List<TaskRow>>{};

    for (final task in results) {
      byPriority.putIfAbsent(task.priority, () => []).add(task);
    }

    final sortedPriorities = byPriority.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        for (final priority in sortedPriorities) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              'Priority $priority',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          ..._buildGroupTaskTiles(context, ref, byPriority[priority]!),
          const Divider(height: 1),
        ],
      ],
    );
  }

  List<Widget> _buildGroupTaskTiles(
    BuildContext context,
    WidgetRef ref,
    List<TaskRow> tasks,
  ) {
    final recurrenceRules =
        ref.watch(allTaskRecurrenceRulesProvider).value ??
        const <String, TaskRecurrenceRule>{};
    return [
      for (final task in tasks)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TaskTile(
              task: task,
              goalTitle: goalTitlesForSearch(ref, task.goalId),
              recurrenceSummary: recurrenceRules[task.id]?.summary,
              onOpenGoal: task.goalId == null
                  ? null
                  : () => context.push('/goal/${task.goalId}'),
              onAssignGoal: () => _assignGoalFromSearch(context, ref, task),
              onRemoveFromGoal: task.goalId == null
                  ? null
                  : () => _removeFromGoal(context, ref, task),
              onAddSubtask: () => _addSubtask(context, ref, task),
              onEdit: () => _editTask(context, ref, task),
              onStartFocus: () => context.push(
                Uri(
                  path: '/focus',
                  queryParameters: {'taskId': task.id},
                ).toString(),
              ),
              onDelete: () => _deleteTask(context, ref, task),
              onToggle: (completed) =>
                  _setCompleted(context, ref, task, completed),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
    ];
  }

  String? goalTitlesForSearch(WidgetRef ref, String? goalId) {
    if (goalId == null) return null;
    final goalsState = ref.read(goalProvider);
    if (goalsState case AsyncData(:final value)) {
      final goal = value.where((g) => g.id == goalId).firstOrNull;
      return goal?.title;
    }
    return null;
  }

  Future<void> _assignGoalFromSearch(
    BuildContext context,
    WidgetRef ref,
    TaskRow task,
  ) async {
    final goalState = ref.read(goalProvider);
    if (goalState case AsyncError(:final error)) {
      _showGoalLoadError(context, ref, error);
      return;
    }

    final List<GoalRow> goals;
    try {
      goals = goalState.hasValue
          ? goalState.requireValue
          : await ref.read(goalProvider.future);
    } catch (error) {
      if (context.mounted) {
        _showGoalLoadError(context, ref, error);
      }
      return;
    }

    if (!context.mounted) return;

    final goalId = await showDialog<String>(
      context: context,
      builder: (_) => GoalPickerDialog(goals: goals, taskTitle: task.title),
    );

    if (goalId == null || !context.mounted) return;

    try {
      await ref.read(taskProvider.notifier).assignToGoal(task.id, goalId);
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, 'Could not assign task to goal', error);
      }
    }
  }

  /// Builds filter chips for each active filter dimension.
  List<Widget> _buildFilterChips(WidgetRef ref, TaskFilter filter) {
    final chips = <Widget>[];

    switch (filter.status) {
      case TaskStatusFilter.active:
        chips.add(
          _FilterChip(
            label: 'Active',
            onDelete: () => ref
                .read(taskFilterProvider.notifier)
                .updateFilter(status: TaskStatusFilter.all),
          ),
        );
        break;
      case TaskStatusFilter.completed:
        chips.add(
          _FilterChip(
            label: 'Completed',
            onDelete: () => ref
                .read(taskFilterProvider.notifier)
                .updateFilter(status: TaskStatusFilter.all),
          ),
        );
        break;
      case TaskStatusFilter.all:
        break;
    }

    switch (filter.time) {
      case TaskTimeFilter.today:
        chips.add(
          _FilterChip(
            label: 'Today',
            onDelete: () => ref
                .read(taskFilterProvider.notifier)
                .updateFilter(time: TaskTimeFilter.all),
          ),
        );
        break;
      case TaskTimeFilter.upcoming:
        chips.add(
          _FilterChip(
            label: 'Upcoming',
            onDelete: () => ref
                .read(taskFilterProvider.notifier)
                .updateFilter(time: TaskTimeFilter.all),
          ),
        );
        break;
      case TaskTimeFilter.overdue:
        chips.add(
          _FilterChip(
            label: 'Overdue',
            onDelete: () => ref
                .read(taskFilterProvider.notifier)
                .updateFilter(time: TaskTimeFilter.all),
          ),
        );
        break;
      case TaskTimeFilter.custom:
        chips.add(
          _FilterChip(
            label: 'Custom range',
            onDelete: () => ref
                .read(taskFilterProvider.notifier)
                .updateFilter(time: TaskTimeFilter.all),
          ),
        );
        break;
      case TaskTimeFilter.all:
        break;
    }

    if (filter.priority != null) {
      chips.add(
        _FilterChip(
          label: 'Priority ${filter.priority}',
          onDelete: () => ref
              .read(taskFilterProvider.notifier)
              .updateFilter(priority: null, clearPriority: true),
        ),
      );
    }

    if (filter.goalId != null) {
      final goalTitle =
          _goalTitleForFilter(ref, filter.goalId) ?? filter.goalId!;
      chips.add(
        _FilterChip(
          label: 'Goal: $goalTitle',
          onDelete: () => ref
              .read(taskFilterProvider.notifier)
              .updateFilter(goalId: null, clearGoal: true),
        ),
      );
    }

    if (filter.parentTaskId != null) {
      chips.add(
        _FilterChip(
          label: 'Parent task',
          onDelete: () => ref
              .read(taskFilterProvider.notifier)
              .updateFilter(parentTaskId: null, clearParent: true),
        ),
      );
    }

    if (filter.includeSubtasks == true) {
      chips.add(
        _FilterChip(
          label: 'Subtasks only',
          onDelete: () => ref
              .read(taskFilterProvider.notifier)
              .updateFilter(includeSubtasks: null, clearSubtasks: true),
        ),
      );
    } else if (filter.includeSubtasks == false) {
      chips.add(
        _FilterChip(
          label: 'Top-level only',
          onDelete: () => ref
              .read(taskFilterProvider.notifier)
              .updateFilter(includeSubtasks: null, clearSubtasks: true),
        ),
      );
    }

    if (filter.category != null) {
      chips.add(
        _FilterChip(
          label: 'Category: ${filter.category}',
          onDelete: () => ref
              .read(taskFilterProvider.notifier)
              .updateFilter(category: null, clearCategory: true),
        ),
      );
    }

    if (filter.startDate != null || filter.endDate != null) {
      chips.add(
        _FilterChip(
          label: 'Date range',
          onDelete: () => ref
              .read(taskFilterProvider.notifier)
              .updateFilter(
                startDate: null,
                endDate: null,
                clearDateRange: true,
              ),
        ),
      );
    }

    return chips;
  }

  /// Returns the goal title for [goalId], or the ID if the goal is not loaded.
  String? _goalTitleForFilter(WidgetRef ref, String? goalId) {
    if (goalId == null) return null;
    final goalsState = ref.read(goalProvider);
    if (goalsState case AsyncData(:final value)) {
      final goal = value.where((g) => g.id == goalId).firstOrNull;
      return goal?.title;
    }
    return null;
  }

  /// Shows a bottom sheet for configuring task sort mode and order.
  void _showSortBottomSheet(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(taskSortProvider.notifier);

    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final currentSort = ref.watch(taskSortProvider);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sort tasks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Sort by', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: TaskSortMode.values.map((mode) {
                      return _FilterButton(
                        label: taskSortModeLabel(mode),
                        selected: currentSort.mode == mode,
                        onTap: () => notifier.setMode(mode),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Order', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: TaskSortOrder.values.map((order) {
                      return _FilterButton(
                        label: taskSortOrderLabel(order),
                        selected: currentSort.order == order,
                        onTap: () => notifier.setOrder(order),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(bottomSheetContext).pop();
                      },
                      child: const Text('Done'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Left navigation drawer with destinations moved from the old top bar and
  /// three-dot menu. Search and Sort remain on the top bar and are not
  /// duplicated here.
  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: AppColors.primary),
              child: const Text(
                'Systum',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.task_rounded),
              title: const Text('Tasks'),
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded),
              title: const Text('Goals'),
              onTap: () {
                Navigator.pop(context);
                context.push('/goals');
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_rounded),
              title: const Text('Agenda'),
              onTap: () {
                Navigator.pop(context);
                context.go(DailyAgendaPage.route);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_rounded),
              title: const Text('Calendar'),
              onTap: () {
                Navigator.pop(context);
                context.push('/calendar');
              },
            ),
            ListTile(
              leading: const Icon(Icons.center_focus_strong_rounded),
              title: const Text('Focus'),
              onTap: () {
                Navigator.pop(context);
                context.push('/focus');
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_drink_rounded),
              title: const Text('Hydration'),
              onTap: () {
                Navigator.pop(context);
                context.push('/hydration');
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_rounded),
              title: const Text('Reminders'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Focus History'),
              onTap: () {
                Navigator.pop(context);
                context.push('/focus/history');
              },
            ),
            ListTile(
              leading: const Icon(Icons.backup_rounded),
              title: const Text('Backup & Restore'),
              onTap: () {
                Navigator.pop(context);
                context.push('/backup');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A removable filter chip showing one active filter dimension.
class _FilterChip extends Chip {
  _FilterChip({required String label, required VoidCallback onDelete})
    : super(
        label: Text(label),
        onDeleted: onDelete,
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.primary),
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      );
}

/// A selectable filter button.
class _FilterButton extends RawChip {
  _FilterButton({
    required String label,
    required super.selected,
    required VoidCallback onTap,
  }) : super(
         label: Text(label),
         onSelected: (_) => onTap(),
         showCheckmark: false,
         labelStyle: TextStyle(
           fontSize: 12,
           color: selected ? Colors.white : AppColors.primary,
         ),
         backgroundColor: selected
             ? AppColors.primary
             : AppColors.primary.withValues(alpha: 0.12),
       );
}

/// Inline search field shown in the app bar when search is active.
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _controller;
  bool _ignoreNextChange = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(taskSearchQueryProvider);

    return TextField(
      controller: _controller,
      autofocus: true,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        hintText: 'Search tasks',
        hintStyle: const TextStyle(color: Colors.black54),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        suffixIcon: query.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _ignoreNextChange = true;
                  _controller.clear();
                  ref.read(taskSearchQueryProvider.notifier).setQuery('');
                  ref.read(taskSearchProvider.notifier).search('');
                },
              )
            : null,
      ),
      onChanged: (value) {
        if (_ignoreNextChange) {
          _ignoreNextChange = false;
          return;
        }
        ref.read(taskSearchQueryProvider.notifier).setQuery(value);
        ref.read(taskSearchProvider.notifier).search(value);
      },
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
    );
  }
}
