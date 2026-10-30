import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../shared/providers/database_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../models/goal_view.dart';
import '../repository/goal_repository.dart';
import 'goal_clock_provider.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return GoalRepository(database);
});

/// Canonical goal state.
///
/// Task data stays owned by [taskProvider]; goal progress and lifecycle are
/// derived from that single task collection instead of being stored twice.
final goalProvider = AsyncNotifierProvider<GoalNotifier, List<GoalRow>>(
  GoalNotifier.new,
);

/// The goal list with progress and lifecycle derived from the task collection.
final goalOverviewsProvider = Provider<AsyncValue<List<GoalOverview>>>((ref) {
  final goalsState = ref.watch(goalProvider);
  final tasksState = ref.watch(taskProvider);

  if (goalsState case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (tasksState case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (!goalsState.hasValue || !tasksState.hasValue) {
    return const AsyncLoading();
  }

  final goals = goalsState.requireValue;
  final tasks = tasksState.requireValue;
  final now = ref.watch(goalClockProvider);
  return AsyncData([
    for (final goal in goals)
      GoalOverview.fromRows(goal: goal, allTasks: tasks, now: now),
  ]);
});

/// A goal, its assigned tasks and its progress.
///
/// `AsyncData(null)` means both sources loaded and the goal does not exist,
/// which is different from the loading and error states.
final goalDetailProvider = Provider.family<AsyncValue<GoalDetail?>, String>((
  ref,
  goalId,
) {
  final goalsState = ref.watch(goalProvider);
  final tasksState = ref.watch(taskProvider);

  if (goalsState case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (tasksState case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (!goalsState.hasValue || !tasksState.hasValue) {
    return const AsyncLoading();
  }

  GoalRow? goal;
  for (final candidate in goalsState.requireValue) {
    if (candidate.id == goalId) {
      goal = candidate;
      break;
    }
  }
  if (goal == null) {
    return const AsyncData(null);
  }

  return AsyncData(
    GoalDetail.fromRows(
      goal: goal,
      allTasks: tasksState.requireValue,
      now: ref.watch(goalClockProvider),
    ),
  );
});

class GoalNotifier extends AsyncNotifier<List<GoalRow>> {
  late final GoalRepository _repository = ref.read(goalRepositoryProvider);
  int _stateRevision = 0;

  @override
  Future<List<GoalRow>> build() async {
    final revision = _stateRevision;
    final result = await AsyncValue.guard(_repository.getAll);
    if (revision != _stateRevision) {
      final currentState = state;
      if (currentState.hasValue) {
        return currentState.requireValue;
      }
      if (currentState case AsyncError(:final error, :final stackTrace)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
    if (result case AsyncError(:final error, :final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    return result.requireValue;
  }

  Future<void> loadGoals() => refresh();

  Future<void> createGoal(GoalRow goal) {
    return _mutate(() => _repository.create(goal));
  }

  Future<void> updateGoal(GoalRow goal) {
    return _mutate(() => _repository.update(goal));
  }

  /// Deletes the goal, reloads goals, and refreshes tasks because the foreign
  /// key clears their goal assignments. Task rows themselves are never deleted.
  Future<void> deleteGoal(String id) async {
    await _repository.delete(id);
    try {
      await _reloadAfterMutation();
    } finally {
      // Task state must not keep pointing at a goal that no longer exists.
      await ref.read(taskProvider.notifier).refresh();
    }
  }

  Future<void> refresh() async {
    final revision = ++_stateRevision;
    state = const AsyncLoading<List<GoalRow>>();
    final result = await AsyncValue.guard(_repository.getAll);
    if (revision == _stateRevision) {
      state = result;
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    await action();
    await _reloadAfterMutation();
  }

  Future<void> _reloadAfterMutation() async {
    final revision = ++_stateRevision;
    try {
      final goals = await _repository.getAll();
      if (revision == _stateRevision) {
        state = AsyncData(goals);
      }
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(GoalMutationReloadException(error), stackTrace);
    }
  }
}

class GoalMutationReloadException implements Exception {
  const GoalMutationReloadException(this.cause);

  final Object cause;
}
