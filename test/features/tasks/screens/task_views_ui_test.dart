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

  Future<void> insertTasks() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    final tasks = TaskRepository(database);
    await tasks.insert(
      Task(
        id: 'task-today',
        title: 'Task due today',
        completed: false,
        createdAt: today,
        updatedAt: today,
        dueDate: today,
      ),
    );
    await tasks.insert(
      Task(
        id: 'task-overdue',
        title: 'Task overdue',
        completed: false,
        createdAt: yesterday,
        updatedAt: yesterday,
        dueDate: yesterday,
      ),
    );
    await tasks.insert(
      Task(
        id: 'task-upcoming',
        title: 'Task upcoming',
        completed: false,
        createdAt: tomorrow,
        updatedAt: tomorrow,
        dueDate: tomorrow,
      ),
    );
    await tasks.insert(
      Task(
        id: 'task-completed',
        title: 'Task completed',
        completed: true,
        createdAt: today,
        updatedAt: today,
        dueDate: today,
      ),
    );
    await tasks.insert(
      Task(
        id: 'task-undated',
        title: 'Task undated',
        completed: false,
        createdAt: today,
        updatedAt: today,
        dueDate: null,
      ),
    );
  }

  testWidgets('view selector chips are visible', (tester) async {
    await insertTasks();
    await pumpTaskList(tester);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('all view shows all tasks', (tester) async {
    await insertTasks();
    await pumpTaskList(tester);

    expect(find.text('Task due today'), findsOneWidget);
    expect(find.text('Task overdue'), findsOneWidget);
    expect(find.text('Task upcoming'), findsOneWidget);
    expect(find.text('Task completed'), findsOneWidget);
    expect(find.text('Task undated'), findsOneWidget);
  });

  testWidgets('today view shows only tasks due today', (tester) async {
    await insertTasks();
    await pumpTaskList(tester);

    await tester.tap(find.text('Today').first);
    await tester.pumpAndSettle();

    expect(find.text('Task due today'), findsOneWidget);
    expect(find.text('Task completed'), findsOneWidget);
    expect(find.text('Task overdue'), findsNothing);
    expect(find.text('Task upcoming'), findsNothing);
    expect(find.text('Task undated'), findsNothing);
  });

  testWidgets('upcoming view shows only upcoming tasks', (tester) async {
    await insertTasks();
    await pumpTaskList(tester);

    await tester.tap(find.text('Upcoming').first);
    await tester.pumpAndSettle();

    expect(find.text('Task upcoming'), findsOneWidget);
    expect(find.text('Task due today'), findsNothing);
    expect(find.text('Task overdue'), findsNothing);
    expect(find.text('Task completed'), findsNothing);
    expect(find.text('Task undated'), findsNothing);
  });

  testWidgets('overdue view shows only overdue tasks', (tester) async {
    await insertTasks();
    await pumpTaskList(tester);

    await tester.tap(find.text('Overdue').first);
    await tester.pumpAndSettle();

    expect(find.text('Task overdue'), findsOneWidget);
    expect(find.text('Task due today'), findsNothing);
    expect(find.text('Task upcoming'), findsNothing);
    expect(find.text('Task completed'), findsNothing);
    expect(find.text('Task undated'), findsNothing);
  });

  testWidgets('completed view shows only completed tasks', (tester) async {
    await insertTasks();
    await pumpTaskList(tester);

    await tester.tap(find.text('Completed').first);
    await tester.pumpAndSettle();

    expect(find.text('Task completed'), findsOneWidget);
    expect(find.text('Task due today'), findsNothing);
    expect(find.text('Task overdue'), findsNothing);
    expect(find.text('Task upcoming'), findsNothing);
    expect(find.text('Task undated'), findsNothing);
  });

  testWidgets('switching views does not clear filters', (tester) async {
    await insertTasks();
    await pumpTaskList(tester);

    // Switch to completed view
    await tester.tap(find.text('Completed').first);
    await tester.pumpAndSettle();
    expect(find.text('Task completed'), findsOneWidget);

    // Switch to today view - completed filter still applies, so no tasks
    // match (completed task due today is filtered out by view=today + no
    // status filter, but wait - view=today shows tasks due today regardless
    // of completion... actually view=today just filters by due date, no
    // status filter is applied)
    await tester.tap(find.text('Today').first);
    await tester.pumpAndSettle();

    expect(find.text('Task due today'), findsOneWidget);
    expect(find.text('Task completed'), findsOneWidget);
  });

  testWidgets('empty state shows for view with no tasks', (tester) async {
    await pumpTaskList(tester);

    await tester.tap(find.text('Overdue').first);
    await tester.pumpAndSettle();

    expect(find.text('No Overdue'), findsOneWidget);
  });

  testWidgets('switching back to all view shows all tasks', (tester) async {
    await insertTasks();
    await pumpTaskList(tester);

    // Switch to overdue view
    await tester.tap(find.text('Overdue').first);
    await tester.pumpAndSettle();
    expect(find.text('Task overdue'), findsOneWidget);
    expect(find.text('Task due today'), findsNothing);

    // Switch back to all view
    await tester.tap(find.text('All tasks').first);
    await tester.pumpAndSettle();

    // Should show all tasks again
    expect(find.text('Task due today'), findsOneWidget);
    expect(find.text('Task overdue'), findsOneWidget);
    expect(find.text('Task upcoming'), findsOneWidget);
    expect(find.text('Task completed'), findsOneWidget);
    expect(find.text('Task undated'), findsOneWidget);
  });

  testWidgets('view persists across search', (tester) async {
    await insertTasks();
    await pumpTaskList(tester);

    // Switch to today view
    await tester.tap(find.text('Today').first);
    await tester.pumpAndSettle();

    expect(find.text('Task due today'), findsOneWidget);
    expect(find.text('Task overdue'), findsNothing);

    // Search should still respect today view
    await tester.tap(find.byTooltip('Search tasks').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'overdue');
    await tester.pumpAndSettle();

    // "overdue" search matches "Task overdue" but view=today excludes it
    expect(find.text('Task overdue'), findsNothing);
  });
}
