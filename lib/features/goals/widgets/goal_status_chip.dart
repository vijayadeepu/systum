import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/goal_lifecycle.dart';

/// Small, non-interactive lifecycle badge.
///
/// Active goals deliberately carry no badge; the absence of a badge is the
/// quiet default. Completed and overdue states are the ones that need to stand
/// out.
class GoalStatusChip extends StatelessWidget {
  const GoalStatusChip({super.key, required this.status});

  final GoalStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.isActive) {
      return const SizedBox.shrink();
    }

    final color = status.isCompleted ? AppColors.success : AppColors.error;
    final icon = status.isCompleted
        ? Icons.check_circle_outline_rounded
        : Icons.schedule_rounded;
    final label = status.isCompleted
        ? 'Completed'
        : _overdueLabel(status.daysUntilTarget);

    return Semantics(
      label: 'Goal status $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.small,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _overdueLabel(int? daysUntilTarget) {
    if (daysUntilTarget == null || daysUntilTarget >= 0) {
      return 'Overdue';
    }
    final days = -daysUntilTarget;
    return days == 1 ? 'Overdue by 1 day' : 'Overdue by $days days';
  }
}
