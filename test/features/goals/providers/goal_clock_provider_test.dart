import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/goals/models/goal_date.dart';
import 'package:systum/features/goals/models/goal_lifecycle.dart';
import 'package:systum/features/goals/providers/goal_clock_provider.dart';
import 'package:systum/features/goals/providers/goal_provider.dart';
import 'package:systum/features/goals/repository/goal_repository.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/providers/task_provider.dart';
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

  testWidgets('goal lifecycle refreshes across midnight without mutations', (
    tester,
  ) async {
    var now = DateTime(2026, 8, 10, 23, 59);
    final container = await _createContainer(database, () => now);
    addTearDown(container.dispose);
    final subscription = container.listen(goalOverviewsProvider, (_, _) {});
    addTearDown(subscription.close);
    await _loadProviders(container);

    expect(
      container
          .read(goalOverviewsProvider)
          .requireValue
          .single
          .status
          .lifecycle,
      GoalLifecycle.active,
    );

    now = DateTime(2026, 8, 11, 0, 1);
    await tester.pump(const Duration(minutes: 2));

    final lifecycle = container
        .read(goalOverviewsProvider)
        .requireValue
        .single
        .status
        .lifecycle;
    subscription.close();
    container.dispose();
    expect(lifecycle, GoalLifecycle.overdue);
  });

  testWidgets('goal lifecycle refreshes when the app resumes', (tester) async {
    var now = DateTime(2026, 8, 10, 12);
    final container = await _createContainer(database, () => now);
    addTearDown(container.dispose);
    final subscription = container.listen(goalOverviewsProvider, (_, _) {});
    addTearDown(subscription.close);
    await _loadProviders(container);

    expect(
      container
          .read(goalOverviewsProvider)
          .requireValue
          .single
          .status
          .lifecycle,
      GoalLifecycle.active,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 8, 11, 12);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    final lifecycle = container
        .read(goalOverviewsProvider)
        .requireValue
        .single
        .status
        .lifecycle;
    subscription.close();
    container.dispose();
    expect(lifecycle, GoalLifecycle.overdue);
  });
}

Future<ProviderContainer> _createContainer(
  SystumDatabase database,
  DateTime Function() now,
) async {
  final goal = GoalRow(
    id: 'goal-1',
    title: 'Finish this goal',
    targetDate: GoalDate.fromDateTime(DateTime(2026, 8, 10)),
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );
  await GoalRepository(database).create(goal);
  final taskRepository = TaskRepository(database);
  final taskNow = DateTime(2026, 8, 1);
  await taskRepository.insert(
    Task(
      id: 'task-1',
      title: 'Do the work',
      createdAt: taskNow,
      updatedAt: taskNow,
    ),
  );
  await taskRepository.assignToGoal('task-1', goal.id);

  return ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      goalSystemClockProvider.overrideWithValue(now),
    ],
  );
}

Future<void> _loadProviders(ProviderContainer container) async {
  await container.read(goalProvider.future);
  await container.read(taskProvider.future);
}
