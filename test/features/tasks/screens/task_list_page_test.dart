import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
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

  Future<void> openCreateDialog(WidgetTester tester) async {
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();
  }

  testWidgets('create action opens the existing task dialog', (tester) async {
    await pumpTaskList(tester);

    await openCreateDialog(tester);

    expect(find.text('Create Task'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
  });

  testWidgets('blank title is rejected and does not save a task', (
    tester,
  ) async {
    await pumpTaskList(tester);
    await openCreateDialog(tester);
    await tester.enterText(find.byType(TextFormField).first, '   ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Title is required'), findsOneWidget);
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(await TaskRepository(database).getAll(), isEmpty);
  });

  testWidgets('successful creation is persisted and displayed', (tester) async {
    await pumpTaskList(tester);
    await openCreateDialog(tester);
    await tester.enterText(
      find.byType(TextFormField).first,
      '  Finish milestone  ',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '  Task creation flow  ',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Finish milestone'), findsOneWidget);
    expect(find.text('No tasks yet'), findsNothing);

    final savedTasks = await TaskRepository(database).getAll();
    expect(savedTasks, hasLength(1));
    expect(savedTasks.single.title, 'Finish milestone');
    expect(savedTasks.single.description, 'Task creation flow');
    expect(savedTasks.single.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
  });

  testWidgets('cancelling creation leaves the list unchanged', (tester) async {
    await pumpTaskList(tester);
    await openCreateDialog(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('No tasks yet'), findsOneWidget);
    expect(await TaskRepository(database).getAll(), isEmpty);
  });

  testWidgets('priority labels follow the established numeric convention', (
    tester,
  ) async {
    final repository = TaskRepository(database);
    for (final priority in [3, 2, 1, 4]) {
      final now = DateTime(2026, 8, 1);
      await repository.insert(
        Task(
          id: 'task-$priority',
          title: 'Priority $priority',
          createdAt: now,
          updatedAt: now,
          priority: priority,
        ),
      );
    }

    await pumpTaskList(tester);

    expect(find.text('High'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Low'), findsNWidgets(2));
    expect((await repository.getAll()).map((task) => task.priority), [
      4,
      3,
      2,
      1,
    ]);
  });
}
