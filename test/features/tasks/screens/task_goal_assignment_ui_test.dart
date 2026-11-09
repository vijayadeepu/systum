import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/goals/providers/goal_provider.dart';
import 'package:systum/features/goals/repository/goal_repository.dart';
import 'package:systum/features/goals/screens/goal_detail_page.dart';
import 'package:systum/features/goals/screens/goal_list_page.dart';
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
    GoalRepository? goalRepository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          if (repository != null)
            taskRepositoryProvider.overrideWithValue(repository),
          if (goalRepository != null)
            goalRepositoryProvider.overrideWithValue(goalRepository),
        ],
        child: const MaterialApp(home: TaskListPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('task rows show the goal, including inherited goals', (
    tester,
  ) async {
    final goal = await _insertGoal(database, id: 'goal-1', title: 'Goal One');
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'parent', title: 'Parent'));
    await tasks.assignToGoal('parent', goal.id);
    await tasks.createSubtask(_task(id: 'child', title: 'Child'), 'parent');
    await pumpTaskList(tester);

    expect(find.text('Goal One'), findsNWidgets(2));
    expect(find.byTooltip('Goal actions for Parent'), findsOneWidget);
    expect(find.byTooltip('Goal actions for Child'), findsNothing);
  });

  testWidgets('assigns a standalone task to a goal from the task list', (
    tester,
  ) async {
    final goal = await _insertGoal(database, id: 'goal-1', title: 'Goal One');
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'task-1', title: 'Standalone'));
    await pumpTaskList(tester);

    await tester.tap(find.byTooltip('Goal actions for Standalone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign to goal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goal One'));
    await tester.pumpAndSettle();

    expect(find.text('Goal One'), findsOneWidget);
    expect((await tasks.getById('task-1'))?.goalId, goal.id);
  });

  testWidgets('reassigns a standalone task from one goal to another', (
    tester,
  ) async {
    final firstGoal = await _insertGoal(
      database,
      id: 'goal-1',
      title: 'First goal',
    );
    final secondGoal = await _insertGoal(
      database,
      id: 'goal-2',
      title: 'Second goal',
    );
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'task-1', title: 'Standalone'));
    await tasks.assignToGoal('task-1', firstGoal.id);
    await pumpTaskList(tester);

    await tester.tap(find.byTooltip('Goal actions for Standalone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second goal'));
    await tester.pumpAndSettle();

    expect(find.text('First goal'), findsNothing);
    expect(find.text('Second goal'), findsOneWidget);
    expect((await tasks.getById('task-1'))?.goalId, secondGoal.id);
  });

  testWidgets('cancelling goal selection leaves the task unassigned', (
    tester,
  ) async {
    await _insertGoal(database, id: 'goal-1', title: 'Goal One');
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'task-1', title: 'Standalone'));
    await pumpTaskList(tester);

    await tester.tap(find.byTooltip('Goal actions for Standalone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign to goal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect((await tasks.getById('task-1'))?.goalId, isNull);
  });

  testWidgets('goal picker scrolls long titles on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (var index = 0; index < 9; index++) {
      await _insertGoal(database, id: 'goal-$index', title: 'Goal $index');
    }
    const longTitle =
        'A very long goal title that should remain readable when the picker '
        'is displayed on a narrow phone screen';
    final longGoal = await _insertGoal(
      database,
      id: 'goal-long',
      title: longTitle,
    );
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'task-1', title: 'Standalone'));
    await pumpTaskList(tester);

    await tester.tap(find.byTooltip('Goal actions for Standalone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign to goal').last);
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    final listView = find.descendant(
      of: dialog,
      matching: find.byType(ListView),
    );
    final scrollable = find.descendant(
      of: listView,
      matching: find.byType(Scrollable),
    );
    final goalTile = find.ancestor(
      of: find.text(longTitle),
      matching: find.byType(ListTile),
    );
    await tester.scrollUntilVisible(goalTile, 120, scrollable: scrollable);
    await tester.drag(listView, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(goalTile);
    await tester.pumpAndSettle();

    expect((await tasks.getById('task-1'))?.goalId, longGoal.id);
  });

  testWidgets('removes a task from its goal from the task list', (
    tester,
  ) async {
    final goal = await _insertGoal(database, id: 'goal-1', title: 'Goal One');
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'task-1', title: 'Assigned'));
    await tasks.assignToGoal('task-1', goal.id);
    await pumpTaskList(tester);

    await tester.tap(find.byTooltip('Goal actions for Assigned'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from goal'));
    await tester.pumpAndSettle();

    expect(find.text('Goal One'), findsNothing);
    expect((await tasks.getById('task-1'))?.goalId, isNull);
  });

  testWidgets('parent reassignment moves the parent and its child together', (
    tester,
  ) async {
    final firstGoal = await _insertGoal(
      database,
      id: 'goal-1',
      title: 'First goal',
    );
    await _insertGoal(database, id: 'goal-2', title: 'Second goal');
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'parent', title: 'Parent'));
    await tasks.assignToGoal('parent', firstGoal.id);
    await tasks.createSubtask(_task(id: 'child', title: 'Child'), 'parent');
    await pumpTaskList(tester);

    await tester.tap(find.byTooltip('Goal actions for Parent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second goal'));
    await tester.pumpAndSettle();

    expect(find.text('First goal'), findsNothing);
    expect(find.text('Second goal'), findsNWidgets(2));
    expect((await tasks.getById('parent'))?.goalId, 'goal-2');
    expect((await tasks.getById('child'))?.goalId, 'goal-2');
  });

  testWidgets('failed assignment is visible and leaves the task unassigned', (
    tester,
  ) async {
    await _insertGoal(database, id: 'goal-1', title: 'Goal One');
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'task-1', title: 'Standalone'));
    await pumpTaskList(
      tester,
      repository: _FailingAssignmentRepository(database),
    );

    await tester.tap(find.byTooltip('Goal actions for Standalone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign to goal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goal One'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not assign task to goal'),
      findsOneWidget,
    );
    expect((await tasks.getById('task-1'))?.goalId, isNull);
  });

  testWidgets('goal load failure is visible and can be retried', (
    tester,
  ) async {
    final goal = await _insertGoal(database, id: 'goal-1', title: 'Goal One');
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'task-1', title: 'Standalone'));
    await pumpTaskList(
      tester,
      goalRepository: _FailingOnceGoalLoadRepository(database),
    );

    await tester.tap(find.byTooltip('Goal actions for Standalone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign to goal').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load goals'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.text('No goals yet. Create a goal before assigning tasks to one.'),
      findsNothing,
    );
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Goal actions for Standalone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign to goal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goal One'));
    await tester.pumpAndSettle();

    expect((await tasks.getById('task-1'))?.goalId, goal.id);
  });

  testWidgets('goals action opens the dedicated goal screen', (tester) async {
    await _insertGoal(database, id: 'goal-1', title: 'Goal One');
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TaskListPage()),
        GoRoute(path: '/goals', builder: (_, _) => const GoalListPage()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();

    expect(find.text('Goal One'), findsOneWidget);
    expect(find.byType(GoalListPage), findsOneWidget);
  });

  testWidgets('tapping a task goal navigates to the goal detail', (
    tester,
  ) async {
    final goal = await _insertGoal(database, id: 'goal-1', title: 'Goal One');
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'task-1', title: 'Assigned'));
    await tasks.assignToGoal('task-1', goal.id);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TaskListPage()),
        GoRoute(
          path: '/goal/:goalId',
          builder: (_, state) =>
              GoalDetailPage(goalId: state.pathParameters['goalId']!),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Goal One'));
    await tester.pumpAndSettle();

    expect(find.byType(GoalDetailPage), findsOneWidget);
    expect(find.text('Assigned'), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);
  });
}

Future<GoalRow> _insertGoal(
  SystumDatabase database, {
  required String id,
  required String title,
}) async {
  final now = DateTime(2026, 8, 1);
  final goal = GoalRow(id: id, title: title, createdAt: now, updatedAt: now);
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

class _FailingAssignmentRepository extends TaskRepository {
  _FailingAssignmentRepository(super._database);

  @override
  Future<void> assignToGoal(String taskId, String goalId) async {
    throw StateError('simulated assignment failure');
  }
}

class _FailingOnceGoalLoadRepository extends GoalRepository {
  _FailingOnceGoalLoadRepository(super._database);

  bool _failed = false;

  @override
  Future<List<GoalRow>> getAll() async {
    if (!_failed) {
      _failed = true;
      throw StateError('simulated goal load failure');
    }
    return super.getAll();
  }
}
