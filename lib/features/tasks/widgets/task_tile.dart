import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/date_format.dart';
import '../providers/countdown_provider.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onStartFocus,
    this.onAddSubtask,
    this.subtaskCount = 0,
    this.isSubtask = false,
    this.goalTitle,
    this.onOpenGoal,
    this.onAssignGoal,
    this.onRemoveFromGoal,
    this.countdown,
    this.recurrenceSummary,
  });

  final TaskRow task;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onStartFocus;
  final VoidCallback? onAddSubtask;
  final int subtaskCount;
  final bool isSubtask;

  /// Name of the goal this task belongs to, when it has one.
  final String? goalTitle;
  final VoidCallback? onOpenGoal;

  /// Present only for top-level tasks, which are the only tasks allowed to
  /// change their goal assignment.
  final VoidCallback? onAssignGoal;
  final VoidCallback? onRemoveFromGoal;

  /// Optional countdown result for this task, used to display a live
  /// countdown to the deadline.
  final CountdownResult? countdown;

  /// Human-readable recurrence summary for a parent/template task.
  final String? recurrenceSummary;

  @override
  Widget build(BuildContext context) {
    final dueDateText = _formatDueDate(task.dueDate);
    final priorityText = _priorityText(task.priority);
    final priorityColor = _priorityColor(task.priority);
    final semanticsLabel =
        '${task.title}${task.completed ? ', completed' : ', not completed'}${dueDateText != null ? ', $dueDateText' : ''}${countdown != null ? ', ${_countdownSubtitle(countdown)}' : ''}';

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Card(
        margin: EdgeInsets.only(
          left: isSubtask ? AppSpacing.xl : AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.xs,
          bottom: AppSpacing.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.medium),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Keep the title usable on narrow phones by dropping the optional
              // priority badge before the action buttons are squeezed.
              final showPriority = constraints.maxWidth >= 380;

              return Row(
                children: [
                  Checkbox(value: task.completed, onChanged: onToggle),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: AppTypography.body.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (dueDateText != null)
                          Text(dueDateText, style: AppTypography.caption),
                        if (recurrenceSummary != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xxs),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.repeat_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.xxs),
                                Flexible(
                                  child: Text(
                                    recurrenceSummary!,
                                    style: AppTypography.caption,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (countdown != null) _buildCountdownText(countdown),
                        if (subtaskCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xxs),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.account_tree_outlined,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.xxs),
                                Flexible(
                                  child: Text(
                                    subtaskCount == 1
                                        ? '1 subtask'
                                        : '$subtaskCount subtasks',
                                    style: AppTypography.caption,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (goalTitle != null)
                          _GoalLink(title: goalTitle!, onTap: onOpenGoal)
                        else if (onAssignGoal != null)
                          _GoalLink(
                            title: 'Assign to goal',
                            onTap: onAssignGoal,
                            isAction: true,
                          ),
                      ],
                    ),
                  ),
                  if (showPriority) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.12),
                        borderRadius: AppRadius.small,
                      ),
                      child: Text(
                        priorityText,
                        style: AppTypography.caption.copyWith(
                          color: priorityColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  PopupMenuButton<_TaskTileAction>(
                    tooltip: onAssignGoal != null || onRemoveFromGoal != null
                        ? 'Goal actions for ${task.title}'
                        : 'Task actions for ${task.title}',
                    onSelected: (action) {
                      switch (action) {
                        case _TaskTileAction.edit:
                          onEdit();
                        case _TaskTileAction.delete:
                          onDelete();
                        case _TaskTileAction.addSubtask:
                          onAddSubtask?.call();
                        case _TaskTileAction.assign:
                          onAssignGoal?.call();
                        case _TaskTileAction.open:
                          onOpenGoal?.call();
                        case _TaskTileAction.remove:
                          onRemoveFromGoal?.call();
                        case _TaskTileAction.focus:
                          onStartFocus?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _TaskTileAction.edit,
                        child: Text('Edit task'),
                      ),
                      const PopupMenuItem(
                        value: _TaskTileAction.delete,
                        child: Text('Delete task'),
                      ),
                      if (onAddSubtask != null)
                        const PopupMenuItem(
                          value: _TaskTileAction.addSubtask,
                          child: Text('Add subtask'),
                        ),
                      if (onStartFocus != null)
                        const PopupMenuItem(
                          value: _TaskTileAction.focus,
                          child: Text('Start focus'),
                        ),
                      if (onAssignGoal != null)
                        PopupMenuItem(
                          value: _TaskTileAction.assign,
                          child: Text(
                            goalTitle == null
                                ? 'Assign to goal'
                                : 'Change goal',
                          ),
                        ),
                      if (goalTitle != null && onOpenGoal != null)
                        const PopupMenuItem(
                          value: _TaskTileAction.open,
                          child: Text('Open goal'),
                        ),
                      if (onRemoveFromGoal != null)
                        const PopupMenuItem(
                          value: _TaskTileAction.remove,
                          child: Text('Remove from goal'),
                        ),
                    ],
                    icon: const Icon(Icons.more_vert_rounded),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String? _formatDueDate(DateTime? dueDate) {
    if (dueDate == null) {
      return null;
    }

    return 'Due ${formatDate(dueDate)}';
  }

  Widget _buildCountdownText(CountdownResult? countdown) {
    if (countdown == null) return const SizedBox.shrink();

    final remaining = countdown.remaining ?? Duration.zero;
    final hms = formatCountdownHMS(remaining.abs());

    if (countdown.isDueNow) {
      return Text(
        '⏱ 0000:00:00',
        style: AppTypography.caption.copyWith(
          color: AppColors.warning,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      );
    }
    if (countdown.isOverdue) {
      return Text(
        '🔴 OVERDUE $hms',
        style: AppTypography.caption.copyWith(
          color: AppColors.error,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      );
    }
    return Text(
      '⏱ $hms',
      style: AppTypography.caption.copyWith(
        color: AppColors.textSecondary,
        fontFamily: 'monospace',
      ),
    );
  }

  /// Accessibility subtitle for the countdown, used in the tile's semantics
  /// label so TalkBack users understand time remaining at a glance.
  String _countdownSubtitle(CountdownResult? countdown) {
    if (countdown == null) return '';
    if (countdown.isDueNow) return ', countdown 0000:00:00';
    if (countdown.isOverdue) {
      return ', overdue ${formatCountdownHMS(countdown.remaining!.abs())}';
    }
    return ', countdown ${formatCountdownHMS(countdown.remaining!)}';
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

enum _TaskTileAction { edit, delete, addSubtask, assign, open, remove, focus }

class _GoalLink extends StatelessWidget {
  const _GoalLink({
    required this.title,
    required this.onTap,
    this.isAction = false,
  });

  final String title;
  final VoidCallback? onTap;
  final bool isAction;

  @override
  Widget build(BuildContext context) {
    final color = isAction ? AppColors.primary : AppColors.secondary;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Semantics(
        label: isAction ? 'Assign to goal' : 'Goal $title',
        button: onTap != null,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.small,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAction ? Icons.add_rounded : Icons.flag_outlined,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Flexible(
                    child: Text(
                      title,
                      style: AppTypography.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
