import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/date_format.dart';

/// Task row used inside a goal. Goal assignment is inherited from the goal
/// context, so the only goal action offered here is removing a top-level task
/// from the goal.
class GoalTaskTile extends StatelessWidget {
  const GoalTaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onOpen,
    required this.onDelete,
    this.onAddSubtask,
    this.onRemoveFromGoal,
    this.subtaskCount = 0,
    this.isSubtask = false,
  });

  final TaskRow task;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback? onAddSubtask;
  final VoidCallback? onRemoveFromGoal;
  final int subtaskCount;
  final bool isSubtask;

  @override
  Widget build(BuildContext context) {
    final dueDate = task.dueDate;
    final semanticsLabel =
        '${task.title}${task.completed ? ', completed' : ', not completed'}${dueDate != null ? ', due $dueDate' : ''}';

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Card(
        margin: EdgeInsets.only(
          left: isSubtask ? AppSpacing.xl : AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.xxs,
          bottom: AppSpacing.xxs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.medium),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Checkbox(
              value: task.completed,
              onChanged: onToggle,
              semanticLabel: task.completed
                  ? 'Reopen ${task.title}'
                  : 'Complete ${task.title}',
            ),
            Expanded(
              child: InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xs,
                    horizontal: AppSpacing.xxs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: AppTypography.body.copyWith(
                          decoration: task.completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.completed
                              ? AppColors.textSecondary
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dueDate != null)
                        Text(
                          'Due ${formatDate(dueDate)}',
                          style: AppTypography.caption,
                        ),
                      if (subtaskCount > 0)
                        Text(
                          subtaskCount == 1
                              ? '1 subtask'
                              : '$subtaskCount subtasks',
                          style: AppTypography.caption,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuButton<_GoalTaskAction>(
              tooltip: 'Actions for ${task.title}',
              onSelected: (action) {
                switch (action) {
                  case _GoalTaskAction.open:
                    onOpen();
                  case _GoalTaskAction.addSubtask:
                    onAddSubtask?.call();
                  case _GoalTaskAction.removeFromGoal:
                    onRemoveFromGoal?.call();
                  case _GoalTaskAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _GoalTaskAction.open,
                  child: Text('Open task'),
                ),
                if (onAddSubtask != null)
                  const PopupMenuItem(
                    value: _GoalTaskAction.addSubtask,
                    child: Text('Add subtask'),
                  ),
                if (onRemoveFromGoal != null)
                  const PopupMenuItem(
                    value: _GoalTaskAction.removeFromGoal,
                    child: Text('Remove from goal'),
                  ),
                const PopupMenuItem(
                  value: _GoalTaskAction.delete,
                  child: Text('Delete task'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _GoalTaskAction { open, addSubtask, removeFromGoal, delete }
