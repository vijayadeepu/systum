import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/date_format.dart';
import '../../focus/models/focus_session_status.dart';
import '../../goals/providers/goal_provider.dart';
import '../../goals/widgets/assignment_dialogs.dart';
import '../models/task.dart';
import '../models/task_recurrence.dart';
import '../providers/recurrence_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/create_task_dialog.dart';
import '../widgets/task_delete_dialog.dart';

class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(taskDetailProvider(taskId));
    final goalTitles = {
      for (final goal in ref.watch(goalProvider).value ?? const <GoalRow>[])
        goal.id: goal.title,
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Task'),
        actions: [
          detailState.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (detail) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (detail.task.parentTaskId == null &&
                      detail.task.goalId != null)
                    IconButton(
                      tooltip: 'Open goal',
                      onPressed: () =>
                          context.push('/goal/${detail.task.goalId}'),
                      icon: const Icon(Icons.flag_outlined),
                    ),
                  IconButton(
                    tooltip: 'Edit task',
                    onPressed: () => _editTask(context, ref, detail.task),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete task',
                    onPressed: () =>
                        _deleteTask(context, ref, detail.task, subtaskCount: 0),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: detailState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _TaskErrorView(
          error: error,
          onRetry: () => ref.invalidate(taskDetailProvider(taskId)),
        ),
        data: (detail) {
          if (detail.task.id.isEmpty) {
            return const _MissingTaskView();
          }
          return _TaskDetailBody(
            taskId: taskId,
            task: detail.task,
            focusSessions: detail.focusSessions,
            goalTitle: goalTitles[detail.task.goalId],
            onEditTask: () => _editTask(context, ref, detail.task),
            onAssignGoal: () => _assignGoal(context, ref, detail.task),
            onRemoveFromGoal: () => _removeFromGoal(context, ref, detail.task),
            onOpenGoal: detail.task.goalId == null
                ? null
                : () => context.push('/goal/${detail.task.goalId}'),
            onToggle: (completed) =>
                _setCompleted(context, ref, detail.task, completed),
            onOpenParent: detail.task.parentTaskId == null
                ? null
                : () => context.push('/task/${detail.task.parentTaskId}'),
            onStartFocus: () => context.push(
              Uri(
                path: '/focus',
                queryParameters: {'taskId': taskId},
              ).toString(),
            ),
            onDelete: () =>
                _deleteTask(context, ref, detail.task, subtaskCount: 0),
          );
        },
      ),
      floatingActionButton: detailState.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (detail) {
          return detail.task.parentTaskId == null
              ? FloatingActionButton.extended(
                  onPressed: () => _addSubtask(context, ref, detail.task),
                  icon: const Icon(Icons.subdirectory_arrow_right_rounded),
                  label: const Text('Add subtask'),
                )
              : const SizedBox.shrink();
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
    router?.go('/');
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
      if (context.mounted) {
        _goBack(context);
      }
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
        'Task change succeeded, but the task could not be refreshed: $cause',
      _ => '$message: $error',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(content)));
  }
}

/// Read-only body of the task detail view.
class _TaskDetailBody extends StatelessWidget {
  const _TaskDetailBody({
    required this.taskId,
    required this.task,
    required this.focusSessions,
    required this.goalTitle,
    required this.onEditTask,
    required this.onAssignGoal,
    required this.onRemoveFromGoal,
    required this.onOpenGoal,
    required this.onToggle,
    required this.onOpenParent,
    required this.onStartFocus,
    required this.onDelete,
  });

  final String taskId;
  final TaskRow task;
  final List<FocusSessionRow> focusSessions;
  final String? goalTitle;
  final VoidCallback onEditTask;
  final VoidCallback onAssignGoal;
  final VoidCallback onRemoveFromGoal;
  final VoidCallback? onOpenGoal;
  final void Function(bool? completed) onToggle;
  final VoidCallback? onOpenParent;
  final VoidCallback onStartFocus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.completed;
    final dueDateText = task.dueDate == null
        ? null
        : 'Due ${formatDate(task.dueDate!)}';
    final priorityText = _priorityText(task.priority);

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
          // Header: title + completion
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: AppTypography.headline.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (task.description != null &&
                        task.description!.isNotEmpty)
                      Text(task.description!, style: AppTypography.body),
                  ],
                ),
              ),
              Checkbox(value: isCompleted, onChanged: onToggle),
            ],
          ),
          if (isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Completed',
                style: AppTypography.caption.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Metadata row
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'Priority',
                  value: priorityText,
                  icon: Icons.priority_high_rounded,
                  color: _priorityColor(task.priority),
                ),
              ),
              Expanded(
                child: _InfoTile(
                  label: 'Due date',
                  value: dueDateText ?? 'No due date',
                  icon: dueDateText == null
                      ? Icons.event_outlined
                      : Icons.event_busy_rounded,
                  color: dueDateText == null ? AppColors.textSecondary : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'Category',
                  value: task.category ?? 'No category',
                  icon: Icons.label_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: _InfoTile(
                  label: 'Created',
                  value: formatDate(task.createdAt),
                  icon: Icons.calendar_today_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'Last updated',
                  value: formatDate(task.updatedAt),
                  icon: Icons.update_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Goal section
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: Text('Goal', style: AppTypography.title)),
              if (task.goalId == null)
                FilledButton.tonalIcon(
                  onPressed: onAssignGoal,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Assign'),
                )
              else ...[
                IconButton(
                  tooltip: 'Open goal',
                  onPressed: onOpenGoal,
                  icon: const Icon(Icons.open_in_new_rounded),
                ),
                IconButton(
                  tooltip: 'Remove from goal',
                  onPressed: onRemoveFromGoal,
                  icon: const Icon(Icons.link_off_rounded),
                ),
              ],
            ],
          ),
          if (task.goalId != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Text(
                    goalTitle ?? task.goalId!,
                    style: AppTypography.body,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),

          // Hierarchy section
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: Text('Hierarchy', style: AppTypography.title)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (task.parentTaskId != null) ...[
            Row(
              children: [
                const Icon(Icons.subdirectory_arrow_left_rounded, size: 16),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: InkWell(
                    onTap: onOpenParent,
                    borderRadius: AppRadius.small,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(
                        'Parent task',
                        style: AppTypography.body.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          // Subtasks (direct children) would be displayed here when
          // multi-level hierarchy is supported. Currently one level only.
          _RecurrenceSection(taskId: task.id, onEdit: onEditTask),
          const SizedBox(height: AppSpacing.lg),

          // Focus history section
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text('Focus history', style: AppTypography.title),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.tonalIcon(
                onPressed: onStartFocus,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start focus'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (focusSessions.isEmpty)
            const _EmptyFocusHistoryView()
          else
            for (final session in focusSessions)
              _FocusSessionTile(
                session: session,
                onTap: () => context.push(
                  Uri(
                    path: '/focus',
                    queryParameters: {'sessionId': session.id},
                  ).toString(),
                ),
              ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  static String _priorityText(int priority) {
    switch (priority) {
      case 3:
        return 'High';
      case 2:
        return 'Medium';
      case 1:
        return 'Low';
      default:
        return 'Low';
    }
  }

  static Color _priorityColor(int priority) {
    switch (priority) {
      case 3:
        return AppColors.error;
      case 2:
        return AppColors.warning;
      case 1:
        return AppColors.success;
      default:
        return AppColors.success;
    }
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color ?? AppColors.textSecondary),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: AppTypography.body.copyWith(color: color),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

class _FocusSessionTile extends StatelessWidget {
  const _FocusSessionTile({required this.session, required this.onTap});

  final FocusSessionRow session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final startedAt = DateTime.fromMillisecondsSinceEpoch(
      session.startedAtMs,
      isUtc: true,
    ).toLocal();
    final statusColor = _statusColor(session.status);
    final durationText = session.actualDurationMs == null
        ? 'In progress'
        : _formatDuration(session.actualDurationMs!);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.small,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
          horizontal: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.mode.name.replaceAll('_', ' '),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${startedAt.year}-${startedAt.month.toString().padLeft(2, '0')}-${startedAt.day.toString().padLeft(2, '0')} '
                          '${startedAt.hour.toString().padLeft(2, '0')}:${startedAt.minute.toString().padLeft(2, '0')}',
                          style: AppTypography.body,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        durationText,
                        style: AppTypography.caption.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(FocusSessionStatus status) {
    switch (status) {
      case FocusSessionStatus.running:
      case FocusSessionStatus.paused:
        return AppColors.primary;
      case FocusSessionStatus.completed:
        return AppColors.success;
      case FocusSessionStatus.interrupted:
      case FocusSessionStatus.cancelled:
        return AppColors.error;
    }
  }

  static String _formatDuration(int milliseconds) {
    final minutes = milliseconds ~/ 60000;
    final seconds = (milliseconds % 60000) ~/ 1000;
    if (minutes == 0) {
      return '${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }
}

class _EmptyFocusHistoryView extends StatelessWidget {
  const _EmptyFocusHistoryView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          const Icon(
            Icons.access_time_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('No focus sessions yet.', style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Start a focus session to track time spent on this task.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _RecurrenceSection extends ConsumerWidget {
  const _RecurrenceSection({required this.taskId, required this.onEdit});

  final String taskId;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ruleState = ref.watch(taskRecurrenceForTaskProvider(taskId));
    return ruleState.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stackTrace) => _RecurrenceLoadError(
        error: error,
        onRetry: () => ref.invalidate(taskRecurrenceForTaskProvider(taskId)),
      ),
      data: (rule) {
        if (rule == null) {
          return const SizedBox.shrink();
        }
        return _buildRule(context, ref, rule);
      },
    );
  }

  Widget _buildRule(
    BuildContext context,
    WidgetRef ref,
    TaskRecurrenceRule rule,
  ) {
    final occurrencesState = ref.watch(taskOccurrencesProvider(rule.id));
    final statusColor = rule.isActive
        ? AppColors.success
        : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: Text('Recurrence', style: AppTypography.title)),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: AppRadius.small,
              ),
              child: Text(
                rule.isActive ? 'Active' : 'Stopped',
                style: AppTypography.caption.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(rule.summary, style: AppTypography.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              label: const Text('Edit schedule'),
            ),
            if (rule.isActive)
              TextButton.icon(
                onPressed: () => _confirmStop(context, ref, rule),
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('Stop recurrence'),
              ),
          ],
        ),
        if (!rule.isActive)
          Text(
            'Future occurrences are stopped. Existing occurrences and '
            'completion history are preserved.',
            style: AppTypography.caption,
          ),
        const SizedBox(height: AppSpacing.sm),
        Text('Occurrences', style: AppTypography.title),
        const SizedBox(height: AppSpacing.xs),
        occurrencesState.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Center(
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (error, stackTrace) => _RecurrenceLoadError(
            error: error,
            onRetry: () => ref.invalidate(taskOccurrencesProvider(rule.id)),
          ),
          data: (occurrences) {
            if (occurrences.isEmpty) {
              return Text(
                'No occurrences generated yet.',
                style: AppTypography.bodySmall,
              );
            }
            const displayLimit = 120;
            final hiddenCount = occurrences.length > displayLimit
                ? occurrences.length - displayLimit
                : 0;
            final visible = hiddenCount == 0
                ? occurrences
                : occurrences.sublist(hiddenCount);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hiddenCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      'Showing the most recent $displayLimit occurrences. '
                      '$hiddenCount earlier occurrence(s) remain stored.',
                      style: AppTypography.caption,
                    ),
                  ),
                for (final occurrence in visible)
                  _OccurrenceTile(
                    occurrence: occurrence,
                    onToggle: (completed) => _setCompleted(
                      context,
                      ref,
                      rule,
                      occurrence,
                      completed,
                    ),
                    onReschedule: () =>
                        _reschedule(context, ref, rule, occurrence),
                    onDelete: () => _delete(context, ref, rule, occurrence),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _confirmStop(
    BuildContext context,
    WidgetRef ref,
    TaskRecurrenceRule rule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stop recurrence?'),
        content: const Text(
          'No new occurrences will be generated. Existing occurrences, '
          'including completed history, will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(recurrenceActionsProvider)
          .stopRecurrence(rule.parentTaskId ?? taskId, rule.id);
    } catch (error) {
      if (context.mounted) {
        _showError(context, 'Could not stop recurrence', error);
      }
    }
  }

  Future<void> _setCompleted(
    BuildContext context,
    WidgetRef ref,
    TaskRecurrenceRule rule,
    TaskOccurrence occurrence,
    bool? completed,
  ) async {
    if (completed == null) {
      return;
    }
    try {
      await ref
          .read(recurrenceActionsProvider)
          .setOccurrenceCompleted(rule.id, occurrence.id, completed);
    } catch (error) {
      if (context.mounted) {
        _showError(context, 'Could not update occurrence', error);
      }
    }
  }

  Future<void> _reschedule(
    BuildContext context,
    WidgetRef ref,
    TaskRecurrenceRule rule,
    TaskOccurrence occurrence,
  ) async {
    final initial = occurrence.dueDate ?? occurrence.occurrenceDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(recurrenceActionsProvider)
          .rescheduleOccurrence(rule.id, occurrence.id, picked);
    } catch (error) {
      if (context.mounted) {
        _showError(context, 'Could not reschedule occurrence', error);
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TaskRecurrenceRule rule,
    TaskOccurrence occurrence,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete occurrence?'),
        content: const Text(
          'This occurrence will be removed from the list and will not be '
          'generated again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(recurrenceActionsProvider)
          .deleteOccurrence(rule.id, occurrence.id);
    } catch (error) {
      if (context.mounted) {
        _showError(context, 'Could not delete occurrence', error);
      }
    }
  }

  void _showError(BuildContext context, String message, Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$message: $error')));
  }
}

class _OccurrenceTile extends StatelessWidget {
  const _OccurrenceTile({
    required this.occurrence,
    required this.onToggle,
    required this.onReschedule,
    required this.onDelete,
  });

  final TaskOccurrence occurrence;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onReschedule;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = occurrence.dueDate ?? occurrence.occurrenceDate;
    final time = _formatTime(occurrence.dueTime);
    final dateLabel = time == null
        ? formatDateOnly(date)
        : '${formatDateOnly(date)} at $time';
    final textStyle = occurrence.completed
        ? AppTypography.body.copyWith(
            color: AppColors.textSecondary,
            decoration: TextDecoration.lineThrough,
          )
        : AppTypography.body;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Checkbox(
            value: occurrence.completed,
            onChanged: onToggle,
            semanticLabel: occurrence.completed
                ? 'Reopen occurrence $dateLabel'
                : 'Complete occurrence $dateLabel',
          ),
          Expanded(
            child: Text(
              dateLabel,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Reschedule occurrence $dateLabel',
            onPressed: onReschedule,
            icon: const Icon(Icons.edit_calendar_outlined),
          ),
          IconButton(
            tooltip: 'Delete occurrence $dateLabel',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  static String? _formatTime(int? seconds) {
    if (seconds == null) {
      return null;
    }
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}

class _RecurrenceLoadError extends StatelessWidget {
  const _RecurrenceLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Could not load recurrence: $error',
            style: AppTypography.caption,
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _TaskErrorView extends StatelessWidget {
  const _TaskErrorView({required this.error, required this.onRetry});

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
              'Could not load this task: $error',
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

class _MissingTaskView extends StatelessWidget {
  const _MissingTaskView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_outlined, size: 56),
            const SizedBox(height: AppSpacing.md),
            Text('Task not found', style: AppTypography.title),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'This task no longer exists. It may have been deleted.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to tasks'),
            ),
          ],
        ),
      ),
    );
  }
}
