import 'package:flutter/material.dart';

import '../../../core/database/database.dart';

/// Confirms task deletion and explains child promotion.
Future<bool> confirmTaskDeletion(
  BuildContext context,
  TaskRow task, {
  int subtaskCount = 0,
}) async {
  final confirmationMessage = subtaskCount == 0
      ? 'Delete "${task.title}"? This cannot be undone.'
      : 'Delete "${task.title}"? Its '
            '${subtaskCount == 1 ? 'subtask' : '$subtaskCount subtasks'} '
            'will become standalone ${subtaskCount == 1 ? 'task' : 'tasks'}.';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete task?'),
      content: Text(confirmationMessage),
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
