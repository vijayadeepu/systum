import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/create_task_dialog.dart';
import '../widgets/task_tile.dart';

class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(taskProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final task = await showDialog<Task>(
            context: context,
            builder: (_) => const CreateTaskDialog(),
          );

          if (task != null && context.mounted) {
            try {
              await ref.read(taskProvider.notifier).addTask(task);
            } catch (error) {
              if (context.mounted) {
                _showMutationError(context, 'Could not create task', error);
              }
            }
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create task'),
      ),
      body: tasksState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          final message = error.toString();

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: () => ref.read(taskProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.task_alt_outlined, size: 48),
                    SizedBox(height: AppSpacing.md),
                    Text('No tasks yet'),
                    SizedBox(height: AppSpacing.xs),
                    Text('Create your first task to get started.'),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, index) {
              final task = tasks[index];

              return TaskTile(
                task: task,
                onEdit: () => _editTask(context, ref, task),
                onDelete: () => _deleteTask(context, ref, task),
                onToggle: (completed) async {
                  if (completed == null) {
                    return;
                  }

                  try {
                    await ref
                        .read(taskProvider.notifier)
                        .setCompleted(task.id, completed);
                  } catch (error) {
                    if (context.mounted) {
                      _showMutationError(
                        context,
                        'Could not update task',
                        error,
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editTask(
    BuildContext context,
    WidgetRef ref,
    TaskRow taskRow,
  ) async {
    final task = await showDialog<Task>(
      context: context,
      builder: (_) => CreateTaskDialog(task: Task.fromRow(taskRow)),
    );

    if (task == null || !context.mounted) {
      return;
    }

    try {
      await ref.read(taskProvider.notifier).updateTask(task);
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, 'Could not edit task', error);
      }
    }
  }

  Future<void> _deleteTask(
    BuildContext context,
    WidgetRef ref,
    TaskRow task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${task.title}"? This cannot be undone.'),
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

    if (confirmed != true || !context.mounted) {
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
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$message: $error')));
  }
}
