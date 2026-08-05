import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, required this.onToggle});

  final TaskRow task;
  final ValueChanged<bool?> onToggle;

  @override
  Widget build(BuildContext context) {
    final dueDate = task.dueDate?.toLocal();
    final dueDateText = dueDate == null
        ? null
        : 'Due ${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.medium),
      child: CheckboxListTile(
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        value: task.completed,
        onChanged: onToggle,
        title: Text(
          task.title,
          style: AppTypography.body,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: dueDateText == null
            ? null
            : Text(dueDateText, style: AppTypography.caption),
      ),
    );
  }
}
