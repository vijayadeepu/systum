import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/focus/providers/focus_clock_provider.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/repository/focus_repository.dart';
import 'package:systum/features/focus/screens/focus_page.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';
import 'package:systum/features/tasks/screens/task_list_page.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('task focus action opens setup with task preselected', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final database = SystumDatabase.test(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.utc(2026, 10, 31, 8);
    await TaskRepository(database).insert(
      Task(
        id: 'navigate-task',
        title: 'Review design',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TaskListPage()),
        GoRoute(
          path: '/focus',
          builder: (_, state) =>
              FocusPage(initialTaskId: state.uri.queryParameters['taskId']),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          focusSystemClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Goal actions for Review design'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start focus'));
    await tester.pumpAndSettle();

    expect(find.text('Set up a focus session'), findsOneWidget);
    expect(find.text('Review design'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Tasks'), findsOneWidget);
  });

  testWidgets('task list exposes Focus navigation entry', (tester) async {
    final database = SystumDatabase.test(NativeDatabase.memory());
    addTearDown(database.close);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TaskListPage()),
        GoRoute(path: '/focus', builder: (_, _) => const Text('Focus route')),
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
    await tester.tap(find.text('Focus'));
    await tester.pumpAndSettle();
    expect(find.text('Focus route'), findsOneWidget);
  });

  testWidgets('home exposes recovery entry for a persisted session', (
    tester,
  ) async {
    final database = SystumDatabase.test(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.utc(2026, 10, 31, 8);
    await FocusRepository(database).startSession(
      mode: FocusSessionMode.standard,
      startedAtMs: now.millisecondsSinceEpoch,
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TaskListPage()),
        GoRoute(
          path: '/focus',
          builder: (_, _) => const Text('Recovered focus route'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          focusSystemClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Focus'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered focus route'), findsOneWidget);
  });
}
