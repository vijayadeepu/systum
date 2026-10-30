import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Selects a goal for an existing top-level task.
class GoalPickerDialog extends StatelessWidget {
  const GoalPickerDialog({
    super.key,
    required this.goals,
    required this.taskTitle,
  });

  final List<GoalRow> goals;
  final String taskTitle;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign to goal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose a goal for "$taskTitle".',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (goals.isEmpty)
            const Text(
              'No goals yet. Create a goal before assigning tasks to one.',
            )
          else
            SizedBox(
              width: double.maxFinite,
              height: _pickerListHeight(context, goals.length),
              child: ListView.builder(
                itemCount: goals.length,
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(
                      goal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: goal.targetDate == null
                        ? null
                        : const Text('Has a target date'),
                    onTap: () => Navigator.of(context).pop(goal.id),
                  );
                },
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Selects a standalone top-level task to add to a goal.
class TaskPickerDialog extends StatelessWidget {
  const TaskPickerDialog({super.key, required this.standaloneTasks});

  final List<TaskRow> standaloneTasks;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign existing task'),
      content: standaloneTasks.isEmpty
          ? const Text(
              'There are no standalone tasks to assign. Create a task from '
              'the Tasks screen first.',
            )
          : SizedBox(
              width: double.maxFinite,
              height: _pickerListHeight(context, standaloneTasks.length),
              child: ListView.builder(
                itemCount: standaloneTasks.length,
                itemBuilder: (context, index) {
                  final task = standaloneTasks[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_box_outline_blank_rounded),
                    title: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      task.completed ? 'Completed' : 'Not started',
                      style: AppTypography.caption,
                    ),
                    onTap: () => Navigator.of(context).pop(task.id),
                  );
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

double _pickerListHeight(BuildContext context, int itemCount) {
  final preferredHeight = itemCount * 88.0;
  final availableHeight = MediaQuery.sizeOf(context).height * 0.32;
  return preferredHeight < availableHeight ? preferredHeight : availableHeight;
}
