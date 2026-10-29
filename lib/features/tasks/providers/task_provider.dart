import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../shared/providers/database_provider.dart';
import '../models/task.dart';
import '../repository/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return TaskRepository(database);
});

final taskProvider = AsyncNotifierProvider<TaskNotifier, List<TaskRow>>(
  TaskNotifier.new,
);

class TaskNotifier extends AsyncNotifier<List<TaskRow>> {
  late final TaskRepository _repository = ref.read(taskRepositoryProvider);
  int _stateRevision = 0;

  @override
  FutureOr<List<TaskRow>> build() {
    return _repository.getAll();
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
