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
    final result = await AsyncValue.guard(() async {
      await _repository.setCompleted(id, completed);
      return _repository.getAll();
    });
    state = result;
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<TaskRow>>();
    state = await AsyncValue.guard(_repository.getAll);
  }

  Future<void> _mutate(Future<void> Function() action) async {
    state = const AsyncLoading<List<TaskRow>>();
    state = await AsyncValue.guard(() async {
      await action();
      return _repository.getAll();
    });
  }
}
