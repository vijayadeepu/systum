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

  Future<void> pumpTaskList(
    WidgetTester tester, {
    TaskRepository? repository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          if (repository != null)
            taskRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: TaskListPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a parent with its subtasks and count', (tester) async {
    final repository = TaskRepository(database);
    await repository.insert(_task(id: 'parent', title: 'Parent task'));
    await repository.createSubtask(
      _task(id: 'child', title: 'Child task'),
      'parent',
    );

    await pumpTaskList(tester);

    expect(find.text('Parent task'), findsOneWidget);
    expect(find.text('Child task'), findsOneWidget);
    expect(find.text('1 subtask'), findsOneWidget);
    expect(find.byTooltip('Add subtask to Parent task'), findsOneWidget);
    expect(find.byTooltip('Add subtask to Child task'), findsNothing);
  });

  testWidgets('adding a subtask persists it under the parent', (tester) async {
    final repository = TaskRepository(database);
    await repository.insert(_task(id: 'parent', title: 'Parent task'));
    await pumpTaskList(tester);

    await tester.tap(find.byTooltip('Add subtask to Parent task'));
    await tester.pumpAndSettle();

    expect(find.text('Add Subtask'), findsOneWidget);
    expect(find.text('Under "Parent task"'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'New child');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('New child'), findsOneWidget);
    expect(find.text('1 subtask'), findsOneWidget);

    final children = await (database.select(
      database.tasks,
    )..where((task) => task.parentTaskId.equals('parent'))).get();
    expect(children.single.title, 'New child');
  });

  testWidgets('a subtask completes and reopens independently', (tester) async {
    final repository = TaskRepository(database);
    await repository.insert(_task(id: 'parent', title: 'Parent task'));
    await repository.createSubtask(
      _task(id: 'child', title: 'Child task'),
      'parent',
    );
    await pumpTaskList(tester);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();

    expect((await repository.getById('child'))?.completed, isTrue);
    expect((await repository.getById('parent'))?.completed, isFalse);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();

    expect((await repository.getById('child'))?.completed, isFalse);
  });

  testWidgets('deleting a subtask leaves the parent intact', (tester) async {
    final repository = TaskRepository(database);
    await repository.insert(_task(id: 'parent', title: 'Parent task'));
    await repository.createSubtask(
      _task(id: 'child', title: 'Child task'),
      'parent',
    );
    await pumpTaskList(tester);

    await tester.tap(find.byTooltip('Delete Child task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Child task'), findsNothing);
    expect(find.text('Parent task'), findsOneWidget);
    expect(await repository.getById('parent'), isNotNull);
    expect(await repository.getById('child'), isNull);
  });

  testWidgets('deleting a parent explains promotion and keeps children', (
    tester,
  ) async {
    final repository = TaskRepository(database);
    await repository.insert(_task(id: 'parent', title: 'Parent task'));
    await repository.createSubtask(
      _task(id: 'child', title: 'Child task'),
      'parent',
    );
    await pumpTaskList(tester);

    await tester.tap(find.byTooltip('Delete Parent task'));
    await tester.pumpAndSettle();

    expect(find.textContaining('will become standalone task'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Parent task'), findsNothing);
    expect(find.text('Child task'), findsOneWidget);
    expect((await repository.getById('child'))?.parentTaskId, isNull);
  });

  testWidgets('shows an error state when loading fails', (tester) async {
    await pumpTaskList(
      tester,
      repository: _FailingLoadTaskRepository(database),
    );

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No tasks yet'), findsNothing);
  });

  testWidgets('a long title remains usable on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = TaskRepository(database);
    await repository.insert(
      _task(
        id: 'long',
        title:
            'A very long task title that should wrap or truncate without '
            'overflowing the available screen width',
      ),
    );

    await pumpTaskList(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('A very long task title'), findsOneWidget);
  });
}

Task _task({required String id, required String title}) {
  final now = DateTime(2026, 8, 1, 8);
  return Task(id: id, title: title, createdAt: now, updatedAt: now);
}

class _FailingLoadTaskRepository extends TaskRepository {
  _FailingLoadTaskRepository(super._database);

  @override
  Future<List<TaskRow>> getAll() async {
    throw StateError('simulated load failure');
  }
}
