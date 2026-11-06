import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../focus/providers/focus_provider.dart';
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
    final focusState = ref.watch(focusSessionProvider);
    final unresolvedSession = focusState.when(
      data: (session) => session,
      loading: () => null,
      error: (_, _) => null,
    );
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
            onPressed: () => context.push('/goals'),
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Goals'),
          ),
          IconButton(
            tooltip: 'Daily agenda',
            onPressed: () => context.go(DailyAgendaPage.route),
            icon: const Icon(Icons.event_rounded),
          ),
          IconButton(
            tooltip: focusState.hasError
                ? 'Focus unavailable'
                : unresolvedSession == null
                ? 'Focus'
                : 'Resume focus',
            onPressed: () => context.push('/focus'),
            icon: Icon(
              focusState.hasError
                  ? Icons.error_outline_rounded
                  : unresolvedSession == null
                  ? Icons.center_focus_strong_outlined
                  : Icons.play_arrow_rounded,
            ),
          ),
          PopupMenuButton<int>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (item) {
              switch (item) {
                case 0:
                  if (showFilters) {
                    ref.read(taskFilterProvider.notifier).clearAll();
                    if (isSearchActive) {
                      ref.read(taskSearchQueryProvider.notifier).setQuery('');
                      ref.read(taskSearchProvider.notifier).search('');
                    }
                  } else {
                    _showFilterBottomSheet(context, ref);
                  }
                  break;
                case 1:
                  _showSortBottomSheet(context, ref);
                  break;
                case 2:
                  context.push('/focus/history');
                  break;
                case 3:
                  context.push('/backup');
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 0,
                child: Row(
                  children: [
                    if (showFilters)
                      const Icon(Icons.filter_none_rounded, size: 18),
                    if (!showFilters)
                      const Icon(Icons.filter_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(showFilters ? 'Clear filters' : 'Filter tasks'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: Row(
                  children: [
                    const Icon(Icons.sort_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Sort: ${taskSortModeLabel(sort.mode)} '
                      '${taskSortOrderLabel(sort.order)}',
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 2,
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Focus history'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 3,
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Backup and restore'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
          // View selector chips. Horizontally scrollable so they take a fixed
          // amount of vertical space even on narrow screens.
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              clipBehavior: Clip.none,
              children: [
                for (final viewValue in TaskView.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: _ViewChip(
                      view: viewValue,
                      active: view == viewValue,
                      onTap: () => ref
                          .read(taskViewProvider.notifier)
                          .setView(viewValue),
                    ),
                  ),
                if (showFilters || view != TaskView.all)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref
                            .read(taskViewProvider.notifier)
                            .setView(TaskView.all);
                        ref.read(taskFilterProvider.notifier).clearAll();
                        if (isSearchActive) {
                          ref
                              .read(taskSearchQueryProvider.notifier)
                              .setQuery('');
                          ref.read(taskSearchProvider.notifier).search('');
                        }
                      },
                      icon: const Icon(Icons.clear_all_rounded, size: 18),
                      label: const Text('Reset'),
                    ),
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

  /// Shows a bottom sheet for configuring task filters.
  ///
  /// Changes are applied immediately as the user interacts with the controls.
  void _showFilterBottomSheet(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(taskFilterProvider.notifier);

    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final filter = ref.watch(taskFilterProvider);
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
                    'Filter tasks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Status', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _FilterButton(
                        label: 'All',
                        selected: filter.status == TaskStatusFilter.all,
                        onTap: () =>
                            notifier.updateFilter(status: TaskStatusFilter.all),
                      ),
                      _FilterButton(
                        label: 'Active',
                        selected: filter.status == TaskStatusFilter.active,
                        onTap: () => notifier.updateFilter(
                          status: TaskStatusFilter.active,
                        ),
                      ),
                      _FilterButton(
                        label: 'Completed',
                        selected: filter.status == TaskStatusFilter.completed,
                        onTap: () => notifier.updateFilter(
                          status: TaskStatusFilter.completed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Time', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _FilterButton(
                        label: 'All',
                        selected: filter.time == TaskTimeFilter.all,
                        onTap: () =>
                            notifier.updateFilter(time: TaskTimeFilter.all),
                      ),
                      _FilterButton(
                        label: 'Today',
                        selected: filter.time == TaskTimeFilter.today,
                        onTap: () =>
                            notifier.updateFilter(time: TaskTimeFilter.today),
                      ),
                      _FilterButton(
                        label: 'Upcoming',
                        selected: filter.time == TaskTimeFilter.upcoming,
                        onTap: () => notifier.updateFilter(
                          time: TaskTimeFilter.upcoming,
                        ),
                      ),
                      _FilterButton(
                        label: 'Overdue',
                        selected: filter.time == TaskTimeFilter.overdue,
                        onTap: () =>
                            notifier.updateFilter(time: TaskTimeFilter.overdue),
                      ),
                      _FilterButton(
                        label: 'Custom range',
                        selected: filter.time == TaskTimeFilter.custom,
                        onTap: () =>
                            notifier.updateFilter(time: TaskTimeFilter.custom),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Priority', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: List.generate(5, (index) {
                      final priority = index + 1;
                      return _FilterButton(
                        label: 'P$priority',
                        selected: filter.priority == priority,
                        onTap: () => filter.priority == priority
                            ? notifier.updateFilter(
                                priority: null,
                                clearPriority: true,
                              )
                            : notifier.updateFilter(priority: priority),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text('Category', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Category',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (value) {
                      final trimmed = value.trim();
                      if (trimmed.isEmpty) {
                        notifier.updateFilter(
                          category: null,
                          clearCategory: true,
                        );
                      } else {
                        notifier.updateFilter(category: trimmed);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Sort by', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: TaskSortMode.values.map((mode) {
                      return _FilterButton(
                        label: taskSortModeLabel(mode),
                        selected: ref.watch(taskSortProvider).mode == mode,
                        onTap: () =>
                            ref.read(taskSortProvider.notifier).setMode(mode),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: TaskSortOrder.values.map((order) {
                      return _FilterButton(
                        label: taskSortOrderLabel(order),
                        selected: ref.watch(taskSortProvider).order == order,
                        onTap: () =>
                            ref.read(taskSortProvider.notifier).setOrder(order),
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
}

/// A removable filter chip showing one active filter dimension.
class _FilterChip extends Chip {
  _FilterChip({required String label, required VoidCallback onDelete})
    : super(
        label: Text(label),
        onDeleted: onDelete,
        labelStyle: const TextStyle(fontSize: 12),
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
           color: selected ? Colors.black : null,
         ),
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

/// A chip representing one task view. Tapping switches the active view.
class _ViewChip extends FilterChip {
  _ViewChip({
    required TaskView view,
    required bool active,
    required VoidCallback onTap,
  }) : super(
         label: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             Icon(taskViewIcon(view), size: 16),
             const SizedBox(width: 6),
             Text(taskViewLabel(view)),
           ],
         ),
         selected: active,
         onSelected: (_) => onTap(),
         showCheckmark: false,
         labelStyle: TextStyle(
           fontSize: 12,
           color: active ? Colors.black : null,
         ),
       );
}
