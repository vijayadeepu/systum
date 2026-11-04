import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/recurrence_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../../tasks/widgets/create_task_dialog.dart';
import '../../tasks/widgets/task_delete_dialog.dart';
import '../models/goal_date.dart';
import '../models/goal_lifecycle.dart';
import '../models/goal_view.dart';
import '../providers/goal_provider.dart';
import '../widgets/assignment_dialogs.dart';
import '../widgets/goal_delete_dialog.dart';
import '../widgets/goal_form_dialog.dart';
import '../widgets/goal_status_chip.dart';
import '../widgets/goal_task_tile.dart';

class GoalDetailPage extends ConsumerWidget {
  const GoalDetailPage({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(goalDetailProvider(goalId));
    final detail = detailState.value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Goal'),
        actions: [
          if (detail != null)
            IconButton(
              tooltip: 'Edit goal',
              onPressed: () => _editGoal(context, ref, detail.goal),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (detail != null)
            IconButton(
              tooltip: 'Delete goal',
              onPressed: () => _deleteGoal(context, ref, detail.goal),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: detailState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _DetailErrorView(error: error, onRetry: () => _refresh(ref)),
        data: (detail) {
          if (detail == null) {
            return _MissingGoalView(onBack: () => _goBack(context));
          }
          return _GoalDetailBody(
            detail: detail,
            onEditGoal: () => _editGoal(context, ref, detail.goal),
            onDeleteGoal: () => _deleteGoal(context, ref, detail.goal),
            onCreateTask: () => _createTaskInGoal(context, ref),
            onAssignTask: () => _assignExistingTask(context, ref),
            onToggleTask: (task, completed) =>
                _setCompleted(context, ref, task, completed),
            onOpenTask: (task) => _editTask(context, ref, task),
            onAddSubtask: (task) => _addSubtask(context, ref, task),
            onRemoveTaskFromGoal: (task) => _removeFromGoal(context, ref, task),
            onDeleteTask: (task, subtaskCount) =>
                _deleteTask(context, ref, task, subtaskCount: subtaskCount),
          );
        },
      ),
    );
  }

  void _goBack(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    router?.go('/goals');
  }

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.read(goalProvider.notifier).refresh(),
      ref.read(taskProvider.notifier).refresh(),
    ]);
  }

  Future<void> _editGoal(
    BuildContext context,
    WidgetRef ref,
    GoalRow goal,
  ) async {
    final updated = await showDialog<GoalRow>(
      context: context,
      builder: (_) => GoalFormDialog(goal: goal),
    );

    if (updated == null || !context.mounted) {
      return;
    }

    try {
      await ref.read(goalProvider.notifier).updateGoal(updated);
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, 'Could not save goal', error);
      }
    }
  }

  Future<void> _deleteGoal(
    BuildContext context,
    WidgetRef ref,
    GoalRow goal,
  ) async {
    final confirmed = await confirmGoalDeletion(context, goal);
    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await ref.read(goalProvider.notifier).deleteGoal(goal.id);
      if (context.mounted) {
        _goBack(context);
      }
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, 'Could not delete goal', error);
      }
    }
  }

  Future<void> _createTaskInGoal(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<CreateTaskResult>(
      context: context,
      builder: (_) => const CreateTaskDialog(),
    );

    if (result == null || !context.mounted) {
      return;
    }

    try {
      final recurrence = result.recurrence;
      if (recurrence == null) {
        await ref
            .read(taskProvider.notifier)
            .createTaskInGoal(result.task, goalId);
      } else {
        await ref
            .read(recurrenceActionsProvider)
            .createTaskInGoalWithRecurrence(result.task, goalId, recurrence);
      }
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, 'Could not create task', error);
      }
    }
  }

  Future<void> _assignExistingTask(BuildContext context, WidgetRef ref) async {
    final tasks = ref.read(taskProvider).value ?? const <TaskRow>[];
    final standaloneTasks = [
      for (final task in tasks)
        if (task.goalId == null && task.parentTaskId == null) task,
    ];

    final taskId = await showDialog<String>(
      context: context,
      builder: (_) => TaskPickerDialog(standaloneTasks: standaloneTasks),
    );

    if (taskId == null || !context.mounted) {
      return;
    }

    try {
      await ref.read(taskProvider.notifier).assignToGoal(taskId, goalId);
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, 'Could not assign task', error);
      }
    }
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

  Future<void> _removeFromGoal(
    BuildContext context,
    WidgetRef ref,
    TaskRow task,
  ) async {
    try {
      await ref.read(taskProvider.notifier).removeFromGoal(task.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task removed from goal. It remains in your tasks.'),
          ),
        );
      }
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
    final content = switch (error) {
      GoalMutationReloadException(:final cause) =>
        'Goal change succeeded, but the goal could not be refreshed: $cause',
      TaskMutationReloadException(:final cause) =>
        'Task change succeeded, but tasks could not be refreshed: $cause',
      _ => '$message: $error',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(content)));
  }
}

class _GoalDetailBody extends StatelessWidget {
  const _GoalDetailBody({
    required this.detail,
    required this.onEditGoal,
    required this.onDeleteGoal,
    required this.onCreateTask,
    required this.onAssignTask,
    required this.onToggleTask,
    required this.onOpenTask,
    required this.onAddSubtask,
    required this.onRemoveTaskFromGoal,
    required this.onDeleteTask,
  });

  final GoalDetail detail;
  final VoidCallback onEditGoal;
  final VoidCallback onDeleteGoal;
  final VoidCallback onCreateTask;
  final VoidCallback onAssignTask;
  final void Function(TaskRow task, bool? completed) onToggleTask;
  final void Function(TaskRow task) onOpenTask;
  final void Function(TaskRow task) onAddSubtask;
  final void Function(TaskRow task) onRemoveTaskFromGoal;
  final void Function(TaskRow task, int subtaskCount) onDeleteTask;

  @override
  Widget build(BuildContext context) {
    final goal = detail.goal;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: AppTypography.headline.copyWith(fontSize: 28),
                ),
              ),
              if (!detail.status.isActive) ...[
                const SizedBox(width: AppSpacing.xs),
                GoalStatusChip(status: detail.status),
              ],
            ],
          ),
          if (goal.description != null && goal.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(goal.description!, style: AppTypography.body),
          ],
          const SizedBox(height: AppSpacing.sm),
          _TargetDateLine(status: detail.status, targetDate: goal.targetDate),
          const SizedBox(height: AppSpacing.lg),
          _ProgressSection(detail: detail),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: Text('Tasks', style: AppTypography.title)),
              Text(
                detail.hasTasks
                    ? '${detail.tasks.length} assigned'
                    : 'None assigned',
                style: AppTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton.tonalIcon(
                onPressed: onCreateTask,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add task'),
              ),
              OutlinedButton.icon(
                onPressed: onAssignTask,
                icon: const Icon(Icons.link_rounded),
                label: const Text('Assign existing task'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!detail.hasTasks)
            const _EmptyTasksView()
          else
            for (final root in detail.hierarchy.roots) ...[
              GoalTaskTile(
                task: root,
                subtaskCount: detail.hierarchy.childCountOf(root.id),
                onToggle: (completed) => onToggleTask(root, completed),
                onOpen: () => onOpenTask(root),
                onAddSubtask: () => onAddSubtask(root),
                onRemoveFromGoal: () => onRemoveTaskFromGoal(root),
                onDelete: () =>
                    onDeleteTask(root, detail.hierarchy.childCountOf(root.id)),
              ),
              for (final child in detail.hierarchy.childrenOf(root.id))
                GoalTaskTile(
                  task: child,
                  isSubtask: true,
                  onToggle: (completed) => onToggleTask(child, completed),
                  onOpen: () => onOpenTask(child),
                  onDelete: () => onDeleteTask(child, 0),
                ),
            ],
        ],
      ),
    );
  }
}

class _TargetDateLine extends StatelessWidget {
  const _TargetDateLine({required this.status, required this.targetDate});

  final GoalStatus status;
  final GoalDate? targetDate;

  bool get _isOverdue => status.isOverdue;
  bool get _isCompleted => status.isCompleted;
  int? get _daysUntilTarget => status.daysUntilTarget;

  @override
  Widget build(BuildContext context) {
    if (targetDate == null) {
      return Text('No target date', style: AppTypography.bodySmall);
    }

    final detail = _dateDetail();
    final color = _isOverdue ? Theme.of(context).colorScheme.error : null;

    return Row(
      children: [
        Icon(Icons.event_outlined, size: 18, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            'Target ${targetDate!.toIso8601String()}$detail',
            style: AppTypography.bodySmall.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  String _dateDetail() {
    if (_isOverdue && _daysUntilTarget != null) {
      final days = -_daysUntilTarget!;
      return days == 1 ? ' • 1 day overdue' : ' • $days days overdue';
    }
    if (_isCompleted || _daysUntilTarget == null) {
      return '';
    }
    if (_daysUntilTarget == 0) {
      return ' • due today';
    }
    if (_daysUntilTarget! < 0) {
      return '';
    }
    return _daysUntilTarget == 1
        ? ' • 1 day left'
        : ' • $_daysUntilTarget days left';
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.detail});

  final GoalDetail detail;

  @override
  Widget build(BuildContext context) {
    final progress = detail.progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Progress', style: AppTypography.title)),
            if (progress.hasActionableTasks)
              Text(
                '${progress.percentage}%',
                style: AppTypography.title.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          label: 'Goal progress',
          value: progress.hasActionableTasks
              ? '${progress.completedLeaves} of '
                    '${progress.totalLeaves} actionable tasks complete'
              : 'No actionable tasks',
          child: ClipRRect(
            borderRadius: AppRadius.small,
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 8,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (progress.hasActionableTasks)
          Wrap(
            spacing: AppSpacing.xxl,
            runSpacing: AppSpacing.sm,
            children: [
              _Metric(label: 'Completed', value: '${progress.completedLeaves}'),
              _Metric(label: 'Total', value: '${progress.totalLeaves}'),
              _Metric(label: 'Remaining', value: '${detail.remainingLeaves}'),
            ],
          )
        else
          Text(
            'No actionable tasks yet. A goal with no tasks stays open until '
            'you add and complete work.',
            style: AppTypography.bodySmall,
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTypography.title),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}

class _EmptyTasksView extends StatelessWidget {
  const _EmptyTasksView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const Icon(
            Icons.playlist_add_check_circle_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'No tasks in this goal yet.\nAdd a new task or assign an existing one.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MissingGoalView extends StatelessWidget {
  const _MissingGoalView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_outlined, size: 56),
            const SizedBox(height: AppSpacing.md),
            Text('Goal not found', style: AppTypography.title),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'This goal no longer exists. Its tasks are still available in '
              'your task list.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onBack, child: const Text('Back to goals')),
          ],
        ),
      ),
    );
  }
}

class _DetailErrorView extends StatelessWidget {
  const _DetailErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not load this goal: $error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
