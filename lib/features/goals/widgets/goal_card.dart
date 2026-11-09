import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/goal_view.dart';
import 'goal_status_chip.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.overview,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final GoalOverview overview;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final goal = overview.goal;
    final progress = overview.progress;
    final status = overview.status;

    return Semantics(
      label:
          '${goal.title}, ${status.isCompleted
              ? 'completed'
              : status.isOverdue
              ? 'overdue'
              : 'active'}, ${progress.completedLeaves} of ${progress.totalLeaves} actionable tasks complete',
      button: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        goal.title,
                        style: AppTypography.title.copyWith(fontSize: 18),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    GoalStatusChip(status: status),
                    PopupMenuButton<_GoalCardAction>(
                      tooltip: 'Actions for ${goal.title}',
                      onSelected: (action) {
                        switch (action) {
                          case _GoalCardAction.edit:
                            onEdit();
                          case _GoalCardAction.delete:
                            onDelete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _GoalCardAction.edit,
                          child: Text('Edit goal'),
                        ),
                        PopupMenuItem(
                          value: _GoalCardAction.delete,
                          child: Text('Delete goal'),
                        ),
                      ],
                    ),
                  ],
                ),
                if (goal.description != null &&
                    goal.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    goal.description!,
                    style: AppTypography.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (goal.targetDate != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 16,
                        color: status.isOverdue
                            ? Theme.of(context).colorScheme.error
                            : AppColors.secondary,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        'Target ${goal.targetDate!.toIso8601String()}',
                        style: AppTypography.caption.copyWith(
                          color: status.isOverdue
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        progress.hasActionableTasks
                            ? '${progress.completedLeaves} of '
                                  '${progress.totalLeaves} actionable tasks complete'
                            : 'No actionable tasks yet',
                        style: AppTypography.caption,
                      ),
                    ),
                    if (progress.hasActionableTasks)
                      Text(
                        '${progress.percentage}%',
                        style: AppTypography.caption.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
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
                      minHeight: 6,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _GoalCardAction { edit, delete }
