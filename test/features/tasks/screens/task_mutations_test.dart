import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/providers/task_provider.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';
import 'package:systum/features/tasks/screens/task_list_page.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  late SystumDatabase database;

  setUp(() {
    database = SystumDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpTaskList(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: TaskListPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openEditDialog(WidgetTester tester, String title) async {
    await tester.tap(find.byTooltip('Edit $title'));
    await tester.pumpAndSettle();
  }

  testWidgets('edit form opens with the task values prefilled', (tester) async {
    final dueDate = DateTime(2026, 8, 2);
    await TaskRepository(database).insert(
      _task(
        id: 'edit-prefill',
        title: 'Existing title',
        description: 'Existing description',
        dueDate: dueDate,
        priority: 3,
      ),
    );
    await pumpTaskList(tester);

    await openEditDialog(tester, 'Existing title');

    expect(find.text('Edit Task'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Existing title',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      'Existing description',
    );
    expect(find.text('Due 2026-08-02'), findsNWidgets(2));
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .initialValue,
      3,
    );
  });

  testWidgets('successful edit persists changes and preserves task state', (
    tester,
  ) async {
    final original = _task(
      id: 'edit-success',
      title: 'Original title',
      description: 'Original description',
      completed: true,
      dueDate: DateTime(2026, 8, 2),
      priority: 2,
    );
    final repository = TaskRepository(database);
    await repository.insert(original);
    await pumpTaskList(tester);
    await openEditDialog(tester, original.title);

    await tester.enterText(
      find.byType(TextFormField).first,
      '  Updated title  ',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '  Updated description  ',
    );
    await tester.tap(find.byTooltip('Clear due date'));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Updated title'), findsOneWidget);
    final updated = Task.fromRow((await repository.getById(original.id))!);
    expect(updated.id, original.id);
    expect(updated.createdAt, original.createdAt);
    expect(updated.completed, original.completed);
    expect(updated.updatedAt, isNot(original.updatedAt));
    expect(updated.title, 'Updated title');
    expect(updated.description, 'Updated description');
    expect(updated.dueDate, isNull);
    expect(updated.priority, 3);
  });

  testWidgets('blank edit title is rejected without saving', (tester) async {
    final original = _task(id: 'edit-invalid', title: 'Keep this title');
    final repository = TaskRepository(database);
    await repository.insert(original);
    await pumpTaskList(tester);
    await openEditDialog(tester, original.title);
    await tester.enterText(find.byType(TextFormField).first, '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Title is required'), findsOneWidget);
    expect((await repository.getById(original.id))?.title, original.title);
  });

  testWidgets('cancelling edits leaves the task unchanged', (tester) async {
    final original = _task(id: 'edit-cancel', title: 'Unchanged');
    final repository = TaskRepository(database);
    await repository.insert(original);
    await pumpTaskList(tester);
    await openEditDialog(tester, original.title);
    await tester.enterText(find.byType(TextFormField).first, 'Not saved');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect((await repository.getById(original.id))?.title, original.title);
    expect(find.text('Unchanged'), findsOneWidget);
  });

  testWidgets('cancelling delete confirmation keeps the task', (tester) async {
    final repository = TaskRepository(database);
    await repository.insert(_task(id: 'delete-cancel'));
    await pumpTaskList(tester);

    await tester.tap(find.byTooltip('Delete Task delete-cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Task delete-cancel'), findsOneWidget);
    expect(await repository.getById('delete-cancel'), isNotNull);
  });

  testWidgets('confirmed deletion remains deleted after reloading', (
    tester,
  ) async {
    final repository = TaskRepository(database);
    await repository.insert(_task(id: 'delete-confirm'));
    await pumpTaskList(tester);

    await tester.tap(find.byTooltip('Delete Task delete-confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No tasks yet'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TaskListPage)),
    );
    await container.read(taskProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(await repository.getAll(), isEmpty);
  });

  testWidgets('edit and delete failures are visible without removing task', (
    tester,
  ) async {
    final repository = _FailingMutationTaskRepository(database);
    await TaskRepository(database).insert(_task(id: 'mutation-failure'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          taskRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: TaskListPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit Task mutation-failure'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Changed');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not edit task'), findsOneWidget);
    expect(find.text('Task mutation-failure'), findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.byType(TaskListPage)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete Task mutation-failure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not delete task'), findsOneWidget);
    expect(find.text('Task mutation-failure'), findsOneWidget);
    expect(
      await TaskRepository(database).getById('mutation-failure'),
      isNotNull,
    );
  });

  test(
    'write failure keeps loaded state while the mutation is pending',
    () async {
      final repository = _PendingMutationTaskRepository(database);
      final original = _task(id: 'pending-mutation');
      await TaskRepository(database).insert(original);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          taskRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(taskProvider.future);

      final mutation = container
          .read(taskProvider.notifier)
          .updateTask(_task(id: original.id, title: 'Updated'));

      expect(container.read(taskProvider), isA<AsyncData<List<TaskRow>>>());
      expect(
        container.read(taskProvider).requireValue.single.title,
        original.title,
      );

      repository.updateCompleter.completeError(
        StateError('simulated write failure'),
      );
      await expectLater(mutation, throwsA(isA<StateError>()));

      expect(container.read(taskProvider), isA<AsyncData<List<TaskRow>>>());
      expect(
        container.read(taskProvider).requireValue.single.title,
        original.title,
      );
      expect(
        (await TaskRepository(database).getById(original.id))?.title,
        original.title,
      );
    },
  );

  test('older mutation reload cannot overwrite a newer mutation', () async {
    final repository = _StaleReloadTaskRepository(database);
    final original = _task(id: 'stale-reload');
    await TaskRepository(database).insert(original);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        taskRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(taskProvider.future);
    final notifier = container.read(taskProvider.notifier);

    final olderMutation = notifier.updateTask(
      _task(id: original.id, title: 'Older result'),
    );
    await repository.staleReloadCaptured.future;

    await notifier.updateTask(_task(id: original.id, title: 'Latest result'));
    expect(
      container.read(taskProvider).requireValue.single.title,
      'Latest result',
    );

    repository.releaseStaleReload.complete();
    await olderMutation;

    expect(
      container.read(taskProvider).requireValue.single.title,
      'Latest result',
    );
    expect(
      (await TaskRepository(database).getById(original.id))?.title,
      'Latest result',
    );
  });

  testWidgets('successful write with failed reload is reported distinctly', (
    tester,
  ) async {
    final repository = _FailingReloadTaskRepository(database);
    final original = _task(id: 'reload-failure');
    await TaskRepository(database).insert(original);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          taskRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: TaskListPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit ${original.title}'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Updated');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Task change succeeded, but the task list'),
      findsOneWidget,
    );
    expect(find.textContaining('Could not edit task'), findsNothing);
    expect(find.text(original.title), findsOneWidget);
    expect(
      (await TaskRepository(database).getById(original.id))?.title,
      'Updated',
    );
  });
}

Task _task({
  required String id,
  String? title,
  String? description,
  bool completed = false,
  DateTime? dueDate,
  int priority = 2,
}) {
  final now = DateTime(2026, 8, 1, 8);
  return Task(
    id: id,
    title: title ?? 'Task $id',
    description: description,
    completed: completed,
    createdAt: now,
    updatedAt: now,
    dueDate: dueDate,
    priority: priority,
  );
}

class _FailingMutationTaskRepository extends TaskRepository {
  _FailingMutationTaskRepository(super._database);

  @override
  Future<void> update(Task task) async {
    throw StateError('simulated write failure');
  }

  @override
  Future<void> delete(String id) async {
    throw StateError('simulated delete failure');
  }
}

class _PendingMutationTaskRepository extends TaskRepository {
  _PendingMutationTaskRepository(super._database);

  final updateCompleter = Completer<void>();

  @override
  Future<void> update(Task task) => updateCompleter.future;
}

class _StaleReloadTaskRepository extends TaskRepository {
  _StaleReloadTaskRepository(super._database);

  final staleReloadCaptured = Completer<void>();
  final releaseStaleReload = Completer<void>();
  int _getAllCalls = 0;

  @override
  Future<List<TaskRow>> getAll() async {
    final call = ++_getAllCalls;
    final tasks = await super.getAll();
    if (call == 2) {
      staleReloadCaptured.complete();
      await releaseStaleReload.future;
    }
    return tasks;
  }
}

class _FailingReloadTaskRepository extends TaskRepository {
  _FailingReloadTaskRepository(super._database);

  bool _failNextReload = false;

  @override
  Future<void> update(Task task) async {
    await super.update(task);
    _failNextReload = true;
  }

  @override
  Future<List<TaskRow>> getAll() async {
    if (_failNextReload) {
      _failNextReload = false;
      throw StateError('simulated reload failure');
    }
    return super.getAll();
  }
}
