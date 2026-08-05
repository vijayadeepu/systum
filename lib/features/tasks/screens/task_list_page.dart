import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../providers/task_provider.dart';
import '../widgets/task_tile.dart';

class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(taskProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: tasksState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: AppSpacing.md),
                const Text('Unable to load tasks'),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () => ref.read(taskProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
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
                    Text('Your tasks will appear here once created.'),
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
              return TaskTile(task: task, onToggle: (_) {});
            },
          );
        },
      ),
    );
  }
}
