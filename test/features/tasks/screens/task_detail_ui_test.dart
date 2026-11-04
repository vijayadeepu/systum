import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/models/task_recurrence.dart';
import 'package:systum/features/tasks/providers/task_provider.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';
import 'package:systum/features/tasks/screens/task_detail_page.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  late SystumDatabase database;

  setUp(() {
    database = SystumDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpDetailPage(
    WidgetTester tester, {
    required String taskId,
    TaskRepository? repository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          if (repository != null)
            taskRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: TaskDetailPage(taskId: 'task-1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> insertTask() async {
    final repository = TaskRepository(database);
    await repository.insert(
      Task(
        id: 'task-1',
        title: 'Test task',
        description: 'A test description',
        completed: false,
        createdAt: DateTime(2026, 8, 10, 8),
        updatedAt: DateTime(2026, 8, 10, 9),
        dueDate: DateTime(2026, 8, 12),
        priority: 3,
        category: 'Work',
      ),
    );
  }

  testWidgets('displays task title, description, and metadata', (tester) async {
    await insertTask();
    await pumpDetailPage(tester, taskId: 'task-1');

    expect(find.text('Test task'), findsOneWidget);
    expect(find.text('A test description'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Due 2026-08-12'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
    expect(find.text('Last updated'), findsOneWidget);
  });

  testWidgets('edit button opens create task dialog', (tester) async {
    await insertTask();
    await pumpDetailPage(tester, taskId: 'task-1');

    // Tap edit button (pencil icon in app bar)
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();

    expect(find.text('Edit Task'), findsOneWidget);
    // The dialog's title field contains the task title
    expect(find.text('Test task').at(1), findsOneWidget);
  });

  testWidgets('delete button shows confirmation dialog', (tester) async {
    await insertTask();
    await pumpDetailPage(tester, taskId: 'task-1');

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();

    expect(find.text('Delete task?'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('shows error for nonexistent task', (tester) async {
    await pumpDetailPage(tester, taskId: 'nonexistent');

    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load this task'), findsOneWidget);
  });

  testWidgets('shows the recurring occurrence list and stop action', (
    tester,
  ) async {
    final repository = TaskRepository(database);
    final task = Task(
      id: 'task-1',
      title: 'Test task',
      createdAt: DateTime(2026, 8, 10, 8),
      updatedAt: DateTime(2026, 8, 10, 9),
      dueDate: DateTime(2026, 8, 12),
      priority: 3,
    );
    final draft = RecurrenceDraft(
      recurrenceType: RecurrenceType.daily,
      startDate: DateTime(2026, 8, 12),
      endDate: DateTime(2026, 8, 14),
    );
    await repository.createTaskWithRecurrence(task, draft);

    await pumpDetailPage(tester, taskId: 'task-1');

    expect(find.text('Recurrence'), findsOneWidget);
    expect(find.text('Occurrences'), findsOneWidget);
    expect(find.text('Stop recurrence'), findsOneWidget);
    expect(find.textContaining('Starts'), findsWidgets);

    await tester.tap(find.text('Stop recurrence'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop').last);
    await tester.pumpAndSettle();

    final rule = await repository.getRecurrenceRuleForParent('task-1');
    expect(rule, isNotNull);
    expect(rule!.isActive, isFalse);
    expect((await repository.getOccurrencesForRule(rule.id)).length, 3);
  });
}
