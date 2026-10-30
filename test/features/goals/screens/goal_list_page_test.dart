import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/goals/models/goal_date.dart';
import 'package:systum/features/goals/providers/goal_provider.dart';
import 'package:systum/features/goals/repository/goal_repository.dart';
import 'package:systum/features/goals/screens/goal_list_page.dart';
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

  Future<void> pumpGoalList(
    WidgetTester tester, {
    GoalRepository? repository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          if (repository != null)
            goalRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: GoalListPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCreateDialog(WidgetTester tester) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
  }

  testWidgets('empty state offers a clear creation action', (tester) async {
    await pumpGoalList(tester);

    expect(find.text('No goals yet'), findsOneWidget);
    expect(
      find.text('Create your first goal to give your work direction.'),
      findsOneWidget,
    );
    expect(find.text('Create goal'), findsNWidgets(2));
  });

  testWidgets('create action opens the goal dialog', (tester) async {
    await pumpGoalList(tester);

    await openCreateDialog(tester);

    expect(find.text('Create Goal'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Description (optional)'), findsOneWidget);
  });

  testWidgets('blank title is rejected without saving', (tester) async {
    await pumpGoalList(tester);
    await openCreateDialog(tester);
    await tester.enterText(find.byType(TextFormField).first, '   ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Title is required'), findsOneWidget);
    expect(await GoalRepository(database).getAll(), isEmpty);
  });

  testWidgets('successful creation is persisted and displayed', (tester) async {
    await pumpGoalList(tester);
    await openCreateDialog(tester);
    await tester.enterText(find.byType(TextFormField).first, '  Learn Rust  ');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '  Finish the book  ',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Learn Rust'), findsOneWidget);
    expect(find.text('Finish the book'), findsOneWidget);
    expect(find.text('No actionable tasks yet'), findsOneWidget);

    final goals = await GoalRepository(database).getAll();
    expect(goals, hasLength(1));
    expect(goals.single.title, 'Learn Rust');
    expect(goals.single.description, 'Finish the book');
    expect(goals.single.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
  });

  testWidgets('goal cards show progress, target date and completion counts', (
    tester,
  ) async {
    final goal = await _insertGoal(
      database,
      id: 'goal-1',
      title: 'Ship Phase 3',
      targetDate: DateTime(2027, 12, 31),
    );
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'done', completed: true));
    await tasks.insert(_task(id: 'open'));
    await tasks.assignToGoal('done', goal.id);
    await tasks.assignToGoal('open', goal.id);
    await pumpGoalList(tester);

    expect(find.text('Ship Phase 3'), findsOneWidget);
    expect(find.text('1 of 2 actionable tasks complete'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Target 2027-12-31'), findsOneWidget);
  });

  testWidgets('a completed goal shows its completion state', (tester) async {
    final goal = await _insertGoal(
      database,
      id: 'goal-1',
      title: 'Finished goal',
    );
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'done', completed: true));
    await tasks.assignToGoal('done', goal.id);
    await pumpGoalList(tester);

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('1 of 1 actionable tasks complete'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('edit opens prefilled values and preserves the goal identity', (
    tester,
  ) async {
    final goal = await _insertGoal(
      database,
      id: 'goal-1',
      title: 'Original goal',
      description: 'Original description',
    );
    await pumpGoalList(tester);

    await tester.tap(find.byTooltip('Actions for Original goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit goal'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Goal'), findsOneWidget);
    final titleField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(titleField.controller!.text, 'Original goal');

    await tester.enterText(find.byType(TextFormField).first, 'Updated goal');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Updated goal'), findsOneWidget);
    final stored = await GoalRepository(database).getById(goal.id);
    expect(stored?.title, 'Updated goal');
    expect(stored?.description, 'Original description');
    expect(stored?.createdAt, goal.createdAt);
  });

  testWidgets('an incomplete goal past its target shows overdue', (
    tester,
  ) async {
    final now = DateTime.now();
    final target = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 3));
    final goal = await _insertGoal(
      database,
      id: 'goal-1',
      title: 'Late goal',
      targetDate: target,
    );
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'open'));
    await tasks.assignToGoal('open', goal.id);
    await pumpGoalList(tester);

    expect(find.textContaining('Overdue by 3 days'), findsOneWidget);
  });

  testWidgets('edit can clear a target date without touching other fields', (
    tester,
  ) async {
    final goal = await _insertGoal(
      database,
      id: 'goal-1',
      title: 'Dated goal',
      description: 'Keep this',
      targetDate: DateTime(2027, 12, 31),
    );
    await pumpGoalList(tester);
    expect(find.text('Target 2027-12-31'), findsOneWidget);

    await tester.tap(find.byTooltip('Actions for Dated goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear target date'));
    await tester.pumpAndSettle();
    expect(find.text('Target date (optional)'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = await GoalRepository(database).getById(goal.id);
    expect(stored?.targetDate, isNull);
    expect(stored?.description, 'Keep this');
    expect(find.textContaining('Target 2027-12-31'), findsNothing);
  });

  testWidgets('delete confirmation explains that tasks are preserved', (
    tester,
  ) async {
    await _insertGoal(database, id: 'goal-1', title: 'Keep my tasks');
    await pumpGoalList(tester);

    await tester.tap(find.byTooltip('Actions for Keep my tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete goal'));
    await tester.pumpAndSettle();

    expect(find.text('Delete goal?'), findsOneWidget);
    expect(
      find.textContaining('Its tasks will stay in your task list.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Keep my tasks'), findsOneWidget);
    expect(await GoalRepository(database).getAll(), hasLength(1));
  });

  testWidgets('confirmed deletion removes the goal but keeps its tasks', (
    tester,
  ) async {
    final goal = await _insertGoal(database, id: 'goal-1', title: 'Delete me');
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'kept'));
    await tasks.assignToGoal('kept', goal.id);
    await pumpGoalList(tester);

    await tester.tap(find.byTooltip('Actions for Delete me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No goals yet'), findsOneWidget);
    expect(await GoalRepository(database).getById(goal.id), isNull);
    final kept = await tasks.getById('kept');
    expect(kept, isNotNull);
    expect(kept?.goalId, isNull);
    expect(
      find.text('Goal deleted. Its tasks remain in your task list.'),
      findsOneWidget,
    );
  });

  testWidgets('long goal content renders without overflow on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final goal = await _insertGoal(
      database,
      id: 'goal-1',
      title: 'A long goal title that must wrap cleanly on a narrow phone',
      description:
          'A long goal description that should be truncated after two lines '
          'instead of overflowing the card horizontally.',
      targetDate: DateTime(2027, 12, 31),
    );
    final tasks = TaskRepository(database);
    await tasks.insert(_task(id: 'open'));
    await tasks.assignToGoal('open', goal.id);
    await pumpGoalList(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('A long goal title'), findsOneWidget);
  });

  testWidgets('delete failure is visible and keeps the goal', (tester) async {
    await _insertGoal(database, id: 'goal-1', title: 'Stay put');
    await pumpGoalList(
      tester,
      repository: _FailingDeleteGoalRepository(database),
    );

    await tester.tap(find.byTooltip('Actions for Stay put'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not delete goal'), findsOneWidget);
    expect(find.text('Stay put'), findsOneWidget);
    expect(await GoalRepository(database).getAll(), hasLength(1));
  });

  testWidgets('load error is visible and retry recovers', (tester) async {
    await pumpGoalList(
      tester,
      repository: _FailingOnceGoalRepository(database),
    );

    expect(find.textContaining('Could not load goals'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('No goals yet'), findsOneWidget);
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

Task _task({required String id, bool completed = false}) {
  final now = DateTime(2026, 8, 1);
  return Task(
    id: id,
    title: 'Task $id',
    completed: completed,
    createdAt: now,
    updatedAt: now,
  );
}

class _FailingOnceGoalRepository extends GoalRepository {
  _FailingOnceGoalRepository(super._database);

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

class _FailingDeleteGoalRepository extends GoalRepository {
  _FailingDeleteGoalRepository(super._database);

  @override
  Future<void> delete(String id) async {
    throw StateError('simulated goal delete failure');
  }
}
