import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/goals/models/goal_date.dart';
import 'package:systum/features/goals/repository/goal_repository.dart';
import 'package:systum/features/goals/screens/goal_detail_page.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  late SystumDatabase database;

  setUp(() {
    database = SystumDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpDetail(
    WidgetTester tester, {
    String goalId = 'goal-1',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(home: GoalDetailPage(goalId: goalId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('a goal with no tasks remains useful', (tester) async {
    await _insertGoal(
      database,
      id: 'goal-1',
      title: 'Launch a side project',
      description: 'Ship a small useful thing',
      targetDate: DateTime(2027, 5, 1),
    );

    await pumpDetail(tester);

    expect(find.text('Launch a side project'), findsOneWidget);
    expect(find.text('Ship a small useful thing'), findsOneWidget);
    expect(find.textContaining('Target 2027-05-01'), findsOneWidget);
    expect(find.text('None assigned'), findsOneWidget);
    expect(
      find.textContaining('A goal with no tasks stays open'),
      findsOneWidget,
    );
    expect(find.textContaining('No tasks in this goal yet.'), findsOneWidget);
    expect(find.text('Add task'), findsOneWidget);
    expect(find.text('Assign existing task'), findsOneWidget);
  });

  testWidgets('detail shows nested subtasks and leaf-only progress', (
    tester,
  ) async {
    final goal = await _insertGoal(database, id: 'goal-1', title: 'Nested');
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'parent', title: 'Parent heading'));
    await tasks.assignToGoal('parent', goal.id);
    await tasks.createSubtask(
      _task(id: 'child-1', title: 'First child'),
      'parent',
    );
    await tasks.createSubtask(
      _task(id: 'child-2', title: 'Second child', completed: true),
      'parent',
    );

    await pumpDetail(tester);

    expect(find.text('Parent heading'), findsOneWidget);
    expect(find.text('First child'), findsOneWidget);
    expect(find.text('Second child'), findsOneWidget);
    expect(find.text('3 assigned'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Remaining'), findsOneWidget);
  });

  testWidgets('completing and reopening a task updates goal progress', (
    tester,
  ) async {
    final goal = await _insertGoal(database, id: 'goal-1', title: 'Progress');
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'task-1', title: 'Only task'));
    await tasks.assignToGoal('task-1', goal.id);
    await pumpDetail(tester);

    expect(find.text('0%'), findsOneWidget);

    await tapVisible(tester, find.byType(Checkbox).first);

    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    expect((await tasks.getById('task-1'))?.completed, isTrue);

    await tapVisible(tester, find.byType(Checkbox).first);

    expect(find.text('0%'), findsOneWidget);
    expect((await tasks.getById('task-1'))?.completed, isFalse);
  });

  testWidgets('creates a task directly in the goal', (tester) async {
    final goal = await _insertGoal(database, id: 'goal-1', title: 'Create in');
    await pumpDetail(tester);

    await tapVisible(tester, find.text('Add task'));
    await tester.enterText(find.byType(TextFormField).first, 'Goal task');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Goal task'), findsOneWidget);
    final stored = await TaskRepository(database).getByGoalId(goal.id);
    expect(stored.single.title, 'Goal task');
  });

  testWidgets('assigns an existing standalone task', (tester) async {
    final goal = await _insertGoal(database, id: 'goal-1', title: 'Assign in');
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'standalone', title: 'Standalone task'));
    await pumpDetail(tester);

    await tapVisible(tester, find.text('Assign existing task'));
    await tester.tap(find.text('Standalone task'));
    await tester.pumpAndSettle();

    expect(find.text('Standalone task'), findsOneWidget);
    expect(find.text('None assigned'), findsNothing);
    expect((await tasks.getById('standalone'))?.goalId, goal.id);
  });

  testWidgets('removes a parent and its inherited subtask from the goal', (
    tester,
  ) async {
    final goal = await _insertGoal(
      database,
      id: 'goal-1',
      title: 'Remove from',
    );
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'parent', title: 'Parent'));
    await tasks.assignToGoal('parent', goal.id);
    await tasks.createSubtask(_task(id: 'child', title: 'Child'), 'parent');
    await pumpDetail(tester);

    await tapVisible(tester, find.byTooltip('Actions for Parent'));
    await tester.tap(find.text('Remove from goal'));
    await tester.pumpAndSettle();

    expect(find.text('Parent'), findsNothing);
    expect(find.text('Child'), findsNothing);
    expect((await tasks.getById('parent'))?.goalId, isNull);
    expect((await tasks.getById('child'))?.goalId, isNull);
    expect(find.textContaining('Task removed from goal'), findsOneWidget);
  });

  testWidgets('subtasks do not offer independent goal removal', (tester) async {
    final goal = await _insertGoal(
      database,
      id: 'goal-1',
      title: 'Locked child',
    );
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'parent', title: 'Parent'));
    await tasks.assignToGoal('parent', goal.id);
    await tasks.createSubtask(_task(id: 'child', title: 'Child'), 'parent');
    await pumpDetail(tester);

    await tapVisible(tester, find.byTooltip('Actions for Child'));

    expect(find.text('Remove from goal'), findsNothing);
    expect(find.text('Add subtask'), findsNothing);
    expect(find.text('Open task'), findsOneWidget);
    expect(find.text('Delete task'), findsOneWidget);
  });

  testWidgets('edits the goal without losing its tasks', (tester) async {
    final goal = await _insertGoal(database, id: 'goal-1', title: 'Old title');
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'task-1'));
    await tasks.assignToGoal('task-1', goal.id);
    await pumpDetail(tester);

    await tester.tap(find.byTooltip('Edit goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'New title');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('New title'), findsOneWidget);
    expect(find.text('Task task-1'), findsOneWidget);
    expect((await tasks.getById('task-1'))?.goalId, goal.id);
  });

  testWidgets('missing goal shows a safe recovery state', (tester) async {
    await pumpDetail(tester, goalId: 'missing-goal');

    expect(find.text('Goal not found'), findsOneWidget);
    expect(
      find.textContaining('Its tasks are still available'),
      findsOneWidget,
    );
  });

  testWidgets('deleting from detail preserves the goal tasks', (tester) async {
    final goal = await _insertGoal(
      database,
      id: 'goal-1',
      title: 'Delete goal',
    );
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'task-1', title: 'Preserved task'));
    await tasks.assignToGoal('task-1', goal.id);
    await pumpDetail(tester);

    await tester.tap(find.byTooltip('Delete goal'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Its tasks will stay in your task list.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await GoalRepository(database).getById(goal.id), isNull);
    final kept = await tasks.getById('task-1');
    expect(kept, isNotNull);
    expect(kept?.goalId, isNull);
  });

  testWidgets('long content renders without overflow on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final goal = await _insertGoal(
      database,
      id: 'goal-1',
      title:
          'A deliberately long goal title that should wrap instead of '
          'overflowing on a narrow phone',
      description:
          'A long description that needs to wrap across several lines so the '
          'goal detail screen remains readable without clipping any content.',
      targetDate: DateTime(2027, 5, 1),
    );
    final tasks = TaskRepository(database);
    await tasks.insert(
      _task(
        id: 'task-1',
        title: 'A long task title that also needs to wrap cleanly',
      ),
    );
    await tasks.assignToGoal('task-1', goal.id);

    await pumpDetail(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('deliberately long goal title'), findsOneWidget);
  });
}

Future<GoalRow> _insertGoal(
  SystumDatabase database, {
  required String id,
  required String title,
  String? description,
  DateTime? targetDate,
}) async {
  final now = DateTime(2026, 8, 1);
  final goal = GoalRow(
    id: id,
    title: title,
    description: description,
    targetDate: targetDate == null ? null : GoalDate.fromDateTime(targetDate),
    createdAt: now,
    updatedAt: now,
  );
  await GoalRepository(database).create(goal);
  return goal;
}

Task _task({required String id, String? title, bool completed = false}) {
  final now = DateTime(2026, 8, 1);
  return Task(
    id: id,
    title: title ?? 'Task $id',
    completed: completed,
    createdAt: now,
    updatedAt: now,
  );
}
