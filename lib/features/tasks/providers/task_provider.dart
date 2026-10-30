import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../shared/providers/database_provider.dart';
import '../models/task.dart';
import '../models/task_hierarchy.dart';
import '../repository/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return TaskRepository(database);
});

/// The canonical task state is a flat collection.
///
/// Subtasks carry their `parentTaskId`, so a single list stays consistent with
/// the database and can be grouped for display without maintaining a second,
/// independently refreshable hierarchy. [taskHierarchyProvider] is a pure
/// projection of this state.
final taskProvider = AsyncNotifierProvider<TaskNotifier, List<TaskRow>>(
  TaskNotifier.new,
);

final taskHierarchyProvider = Provider<TaskHierarchy>((ref) {
  final tasks = ref.watch(taskProvider).value;
  return TaskHierarchy.fromRows(tasks ?? const []);
});

class TaskNotifier extends AsyncNotifier<List<TaskRow>> {
  late final TaskRepository _repository = ref.read(taskRepositoryProvider);
  int _stateRevision = 0;

  @override
  Future<List<TaskRow>> build() async {
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

  Future<void> loadTasks() {
    return refresh();
  }

  Future<void> addTask(Task task) {
    return _mutate(() => _repository.insert(task));
  }

  Future<void> updateTask(Task task) {
    return _mutate(() => _repository.update(task));
  }

  Future<void> createSubtask(Task subtask, String parentTaskId) {
    return _mutate(() => _repository.createSubtask(subtask, parentTaskId));
  }

  /// Deletes a task. Direct subtasks of a parent are promoted to standalone
  /// tasks by the repository and the refreshed state reflects the promotion.
  Future<void> deleteTask(String id) {
    return _mutate(() => _repository.delete(id));
  }

  Future<void> setCompleted(String id, bool completed) async {
    await _mutate(() => _repository.setCompleted(id, completed));
  }

  Future<void> refresh() async {
    final revision = ++_stateRevision;
    state = const AsyncLoading<List<TaskRow>>();
    final result = await AsyncValue.guard(_repository.getAll);
    if (revision == _stateRevision) {
      state = result;
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    await action();
    final revision = ++_stateRevision;

    try {
      final tasks = await _repository.getAll();
      if (revision == _stateRevision) {
        state = AsyncData(tasks);
      }
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(TaskMutationReloadException(error), stackTrace);
    }
  }
}

class TaskMutationReloadException implements Exception {
  const TaskMutationReloadException(this.cause);

  final Object cause;
}
