import 'package:flutter/material.dart';

import '../../../core/database/database.dart';

/// Confirms destructive goal deletion and explains exactly what happens to
/// the goal's tasks.
Future<bool> confirmGoalDeletion(BuildContext context, GoalRow goal) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete goal?'),
      content: Text(
        'Delete "${goal.title}"?\n\n'
        'Its tasks will stay in your task list. Only their goal assignment '
        'will be cleared. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
