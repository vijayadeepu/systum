import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../tasks/providers/task_provider.dart';
import '../providers/goal_provider.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_delete_dialog.dart';
import '../widgets/goal_form_dialog.dart';

class GoalListPage extends ConsumerWidget {
  const GoalListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewsState = ref.watch(goalOverviewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createGoal(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create goal'),
      ),
      body: overviewsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _GoalErrorView(error: error, onRetry: () => _refresh(context, ref)),
        data: (overviews) {
          if (overviews.isEmpty) {
            return _EmptyGoalsView(onCreate: () => _createGoal(context, ref));
          }

          return RefreshIndicator(
            onRefresh: () => _refresh(context, ref),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 96),
              itemCount: overviews.length,
              itemBuilder: (context, index) {
                final overview = overviews[index];
                return GoalCard(
                  overview: overview,
                  onTap: () => context.push('/goal/${overview.goal.id}'),
                  onEdit: () => _editGoal(context, ref, overview.goal),
                  onDelete: () => _deleteGoal(context, ref, overview.goal),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    await Future.wait([
      ref.read(goalProvider.notifier).refresh(),
      ref.read(taskProvider.notifier).refresh(),
    ]);
  }

  Future<void> _createGoal(BuildContext context, WidgetRef ref) async {
    final goal = await showDialog<GoalRow>(
      context: context,
      builder: (_) => const GoalFormDialog(),
    );

    if (goal == null || !context.mounted) {
      return;
    }

    try {
      await ref.read(goalProvider.notifier).createGoal(goal);
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, 'Could not create goal', error);
      }
    }
  }

  Future<void> _editGoal(
    BuildContext context,
    WidgetRef ref,
    GoalRow goal,
  ) async {
    final updatedGoal = await showDialog<GoalRow>(
      context: context,
      builder: (_) => GoalFormDialog(goal: goal),
    );

    if (updatedGoal == null || !context.mounted) {
      return;
    }

    try {
      await ref.read(goalProvider.notifier).updateGoal(updatedGoal);
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, 'Could not save goal', error);
      }
    }
  }

  Future<void> _deleteGoal(
    BuildContext context,
    WidgetRef ref,
    GoalRow goal,
  ) async {
    final confirmed = await confirmGoalDeletion(context, goal);
    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await ref.read(goalProvider.notifier).deleteGoal(goal.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal deleted. Its tasks remain in your task list.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, 'Could not delete goal', error);
      }
    }
  }

  void _showMutationError(BuildContext context, String message, Object error) {
    final content = switch (error) {
      GoalMutationReloadException(:final cause) =>
        'Goal change succeeded, but the goal list could not be refreshed: '
            '$cause',
      _ => '$message: $error',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(content)));
  }
}

class _EmptyGoalsView extends StatelessWidget {
  const _EmptyGoalsView({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_outlined, size: 56),
            const SizedBox(height: AppSpacing.md),
            Text('No goals yet', style: AppTypography.title),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Create your first goal to give your work direction.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create goal'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalErrorView extends StatelessWidget {
  const _GoalErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('Could not load goals: $error', textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
