import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../goals/providers/goal_provider.dart';
import '../../goals/widgets/assignment_dialogs.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/create_task_dialog.dart';
import '../widgets/task_delete_dialog.dart';
import '../widgets/task_tile.dart';

class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(taskProvider);
    final hierarchy = ref.watch(taskHierarchyProvider);
    final goalsState = ref.watch(goalProvider);
    final goalTitles = {
      for (final goal in goalsState.value ?? const <GoalRow>[])
        goal.id: goal.title,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/goals'),
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Goals'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final task = await showDialog<Task>(
            context: context,
            builder: (_) => const CreateTaskDialog(),
          );

          if (task != null && context.mounted) {
            try {
              await ref.read(taskProvider.notifier).addTask(task);
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
      body: tasksState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
                    onPressed: () => ref.read(taskProvider.notifier).refresh(),
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
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: hierarchy.roots.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
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
                    onOpenGoal: task.goalId == null
                        ? null
                        : () => context.push('/goal/${task.goalId}'),
                    onAssignGoal: () => _assignGoal(context, ref, task),
                    onRemoveFromGoal: task.goalId == null
                        ? null
                        : () => _removeFromGoal(context, ref, task),
                    onAddSubtask: () => _addSubtask(context, ref, task),
                    onEdit: () => _editTask(context, ref, task),
                    onDelete: () => _deleteTask(
                      context,
                      ref,
                      task,
                      subtaskCount: subtasks.length,
                    ),
                    onToggle: (completed) =>
                        _setCompleted(context, ref, task, completed),
                  ),
                  for (final subtask in subtasks)
                    TaskTile(
                      task: subtask,
                      isSubtask: true,
                      goalTitle: goalTitles[subtask.goalId],
                      onOpenGoal: subtask.goalId == null
                          ? null
                          : () => context.push('/goal/${subtask.goalId}'),
                      onEdit: () => _editTask(context, ref, subtask),
                      onDelete: () => _deleteTask(context, ref, subtask),
                      onToggle: (completed) =>
                          _setCompleted(context, ref, subtask, completed),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editTask(
    BuildContext context,
    WidgetRef ref,
    TaskRow taskRow,
  ) async {
    final task = await showDialog<Task>(
      context: context,
      builder: (_) => CreateTaskDialog(task: Task.fromRow(taskRow)),
    );

    if (task == null || !context.mounted) {
      return;
    }

    try {
      await ref.read(taskProvider.notifier).updateTask(task);
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
    final subtask = await showDialog<Task>(
      context: context,
      builder: (_) => CreateTaskDialog(parentTitle: parent.title),
    );

    if (subtask == null || !context.mounted) {
      return;
    }

    try {
      await ref.read(taskProvider.notifier).createSubtask(subtask, parent.id);
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
}
