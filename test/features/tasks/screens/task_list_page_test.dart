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

  testWidgets('navigation drawer opens and lists destinations', (tester) async {
    tester.view.physicalSize = const Size(560, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpTaskList(tester);
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Hydration').last, findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Focus History'), findsOneWidget);
    expect(find.text('Backup & Restore'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('filter row shows All Today Upcoming Overdue labels', (
    tester,
  ) async {
    await pumpTaskList(tester);

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
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

  testWidgets('title longer than the database limit is rejected', (
    tester,
  ) async {
    await pumpTaskList(tester);
    await openCreateDialog(tester);
    await tester.enterText(find.byType(TextFormField).first, 'a' * 121);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Title must be 120 characters or fewer'), findsOneWidget);
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

  testWidgets('completing a task persists and updates the checkbox', (
    tester,
  ) async {
    final repository = TaskRepository(database);
    await repository.insert(_task(id: 'complete-me'));
    await pumpTaskList(tester);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect((await repository.getById('complete-me'))?.completed, isTrue);
  });

  testWidgets('reopening a task persists and updates the checkbox', (
    tester,
  ) async {
    final repository = TaskRepository(database);
    await repository.insert(_task(id: 'reopen-me', completed: true));
    await pumpTaskList(tester);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect((await repository.getById('reopen-me'))?.completed, isFalse);
  });

  testWidgets('refresh retains the persisted completion state', (tester) async {
    final repository = TaskRepository(database);
    await repository.insert(_task(id: 'refresh-me'));
    await pumpTaskList(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TaskListPage)),
    );
    await container.read(taskProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect((await repository.getById('refresh-me'))?.completed, isTrue);
  });

  testWidgets('completion write failure is visible and retains the task', (
    tester,
  ) async {
    final repository = _FailingTaskRepository(database);
    await TaskRepository(database).insert(_task(id: 'failure-me'));
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

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Task failure-me'), findsOneWidget);
    expect(find.textContaining('Could not update task'), findsOneWidget);
    expect(
      (await TaskRepository(database).getById('failure-me'))?.completed,
      isFalse,
    );
  });
}

Task _task({required String id, bool completed = false}) {
  final now = DateTime(2026, 8, 1, 8);
  return Task(
    id: id,
    title: 'Task $id',
    completed: completed,
    createdAt: now,
    updatedAt: now,
  );
}

class _FailingTaskRepository extends TaskRepository {
  _FailingTaskRepository(super._database);

  @override
  Future<void> setCompleted(String id, bool completed) async {
    throw StateError('simulated write failure');
  }
}
