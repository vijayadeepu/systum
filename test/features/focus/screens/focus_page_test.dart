import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/focus/models/focus_session.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/models/focus_session_status.dart';
import 'package:systum/features/focus/providers/focus_clock_provider.dart';
import 'package:systum/features/focus/providers/focus_provider.dart';
import 'package:systum/features/focus/repository/focus_repository.dart';
import 'package:systum/features/focus/screens/focus_page.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FocusPage', () {
    late SystumDatabase database;
    late DateTime now;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      database = SystumDatabase.test(NativeDatabase.memory());
      now = DateTime.utc(2026, 10, 31, 8);
    });

    tearDown(() async {
      await database.close();
    });

    Widget createApp({String initialLocation = '/focus'}) {
      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home route')),
          ),
          GoRoute(
            path: '/focus',
            builder: (_, state) =>
                FocusPage(initialTaskId: state.uri.queryParameters['taskId']),
          ),
        ],
      );
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          focusSystemClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('shows standalone untimed session setup by default', (
      tester,
    ) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      expect(find.text('Set up a focus session'), findsOneWidget);
      expect(find.text('Standard session — untimed'), findsOneWidget);
      expect(find.text('No task — focus on anything'), findsOneWidget);
      expect(find.byKey(const ValueKey('focus-duration')), findsNothing);
    });

    testWidgets('selects a task and starts a task-linked session', (
      tester,
    ) async {
      await _insertTask(database, id: 'task-1', title: 'Write the report');
      await tester.pumpWidget(
        createApp(initialLocation: '/focus?taskId=task-1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Write the report'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('start-focus-session')));
      await tester.pumpAndSettle();

      expect(find.text('Write the report'), findsOneWidget);
      expect(find.text('Standard focus'), findsOneWidget);
      expect(find.text('Standalone focus session'), findsNothing);
      final active = await FocusRepository(database).getUnresolvedSession();
      expect(active?.session.taskIdSnapshot, 'task-1');
      expect(active?.session.taskTitleSnapshot, 'Write the report');
    });

    testWidgets('selecting Pomodoro shows default timed duration', (
      tester,
    ) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      await _selectMode(tester, 'Pomodoro');
      expect(find.byKey(const ValueKey('focus-duration')), findsOneWidget);
      expect(
        find.text('This session is timed. You can complete it early.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('focus-duration')))
            .controller
            ?.text,
        '25',
      );
    });

    testWidgets('break session does not require or offer task selection', (
      tester,
    ) async {
      await _insertTask(database, id: 'task-1', title: 'Task title');
      await tester.pumpWidget(
        createApp(initialLocation: '/focus?taskId=task-1'),
      );
      await tester.pumpAndSettle();

      await _selectMode(tester, 'Short break');

      expect(find.byKey(const ValueKey('focus-task')), findsNothing);
      expect(find.text('Break session — no task required'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('start-focus-session')));
      await tester.pumpAndSettle();

      final active = await FocusRepository(database).getUnresolvedSession();
      expect(active?.session.mode, FocusSessionMode.shortBreak);
      expect(active?.session.taskId, isNull);
    });

    testWidgets('custom duration validation prevents invalid session start', (
      tester,
    ) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();
      await _selectMode(tester, 'Custom');

      await tester.enterText(find.byKey(const ValueKey('focus-duration')), '0');
      await tester.tap(find.byKey(const ValueKey('start-focus-session')));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a duration from 1 to 1440 minutes.'),
        findsOneWidget,
      );
      expect(await FocusRepository(database).getHistory(), isEmpty);
    });

    testWidgets('custom timed session starts and displays remaining time', (
      tester,
    ) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();
      await _selectMode(tester, 'Custom');
      await tester.enterText(find.byKey(const ValueKey('focus-duration')), '2');
      await tester.tap(find.byKey(const ValueKey('start-focus-session')));
      await tester.pumpAndSettle();

      expect(find.text('Custom focus'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
      expect(find.byKey(const ValueKey('focus-timer')), findsOneWidget);
      expect(
        (await FocusRepository(
          database,
        ).getUnresolvedSession())?.session.plannedDurationMs,
        const Duration(minutes: 2).inMilliseconds,
      );
    });

    testWidgets('cycle explicitly progresses to a separate break session', (
      tester,
    ) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('start-pomodoro-cycle')));
      await tester.pumpAndSettle();
      // The focus title and the mode selector both display "Focus".
      expect(find.text('Focus'), findsNWidgets(2));
      expect(find.text('Round 1 of 4'), findsOneWidget);
      expect(find.text('Next after focus: Short break'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('complete-focus-session')));
      await tester.pumpAndSettle();
      expect(find.text('Focus complete'), findsOneWidget);
      expect(find.text('Next: Short break after round 1.'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('start-next-pomodoro-segment')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Short break'), findsOneWidget);
      expect(find.text('Round 1 of 4'), findsOneWidget);
      expect(find.text('Break session — no task required'), findsNothing);
      expect(
        (await FocusRepository(
          database,
        ).getUnresolvedSession())?.session.cycleId,
        isNotNull,
      );

      final exitCycle = find.byKey(
        const ValueKey('exit-active-pomodoro-cycle'),
      );
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(exitCycle);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel segment and exit'));
      await tester.pumpAndSettle();

      final history = await FocusRepository(database).getHistory();
      expect(history, hasLength(2));
      final breakSession = history.singleWhere(
        (entry) => entry.session.mode == FocusSessionMode.shortBreak,
      );
      final focusSession = history.singleWhere(
        (entry) => entry.session.mode == FocusSessionMode.pomodoro,
      );
      expect(breakSession.session.status, FocusSessionStatus.cancelled);
      expect(focusSession.session.status, FocusSessionStatus.completed);
      expect(breakSession.session.taskId, isNull);
    });

    testWidgets('Pomodoro settings can be edited and affect cycle duration', (
      tester,
    ) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-pomodoro-settings')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('pomodoro-focus-minutes')),
        '30',
      );
      await tester.tap(find.byKey(const ValueKey('save-pomodoro-settings')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('start-pomodoro-cycle')));
      await tester.pumpAndSettle();
      expect(
        (await FocusRepository(
          database,
        ).getUnresolvedSession())?.session.plannedDurationMs,
        const Duration(minutes: 30).inMilliseconds,
      );
    });

    testWidgets('pause, resume and early completion use persisted state', (
      tester,
    ) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();
      await _selectMode(tester, 'Pomodoro');
      await tester.tap(find.byKey(const ValueKey('start-focus-session')));
      await tester.pumpAndSettle();

      now = now.add(const Duration(seconds: 10));
      await tester.tap(find.byKey(const ValueKey('pause-focus-session')));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('resume-focus-session')),
        findsOneWidget,
      );

      now = now.add(const Duration(minutes: 3));
      await tester.tap(find.byKey(const ValueKey('resume-focus-session')));
      await tester.pumpAndSettle();
      expect(find.text('Running'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('complete-focus-session')));
      await tester.pumpAndSettle();
      expect(find.text('Set up a focus session'), findsOneWidget);
      final history = await FocusRepository(database).getHistory();
      expect(history.single.session.status, FocusSessionStatus.completed);
      expect(history.single.session.actualDurationMs, 10_000);
    });

    testWidgets('cancellation asks for confirmation before ending session', (
      tester,
    ) async {
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start-focus-session')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('cancel-focus-session')));
      await tester.pumpAndSettle();
      expect(find.text('Cancel this session?'), findsOneWidget);
      await tester.tap(find.text('Keep session'));
      await tester.pumpAndSettle();
      expect(
        (await FocusRepository(
          database,
        ).getUnresolvedSession())?.session.status,
        FocusSessionStatus.running,
      );

      await tester.tap(find.byKey(const ValueKey('cancel-focus-session')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel session'));
      await tester.pumpAndSettle();
      expect(find.text('Set up a focus session'), findsOneWidget);
      expect(
        (await FocusRepository(database).getHistory()).single.session.status,
        FocusSessionStatus.cancelled,
      );
    });

    testWidgets('restores persisted session and allows explicit interruption', (
      tester,
    ) async {
      final started = await FocusRepository(database).startSession(
        mode: FocusSessionMode.standard,
        startedAtMs: now.millisecondsSinceEpoch,
      );
      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      expect(find.text('Your session is saved'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('interrupt-focus-session')));
      await tester.pumpAndSettle();

      expect(find.text('Set up a focus session'), findsOneWidget);
      expect(
        (await FocusRepository(
          database,
        ).getById(started.session.id))?.session.status,
        FocusSessionStatus.interrupted,
      );
    });

    testWidgets('repository load failures have a retryable error state', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            focusSystemClockProvider.overrideWithValue(() => now),
            focusRepositoryProvider.overrideWithValue(
              _FailingLoadRepository(database),
            ),
          ],
          child: const MaterialApp(home: FocusPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load your focus session.'), findsOneWidget);
      expect(find.textContaining('Database unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a slow start cannot be submitted twice', (tester) async {
      final repository = _BlockingStartRepository(database);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            focusSystemClockProvider.overrideWithValue(() => now),
            focusRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: FocusPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('start-focus-session')));
      await repository.startStarted.future;
      await tester.pump();
      expect(find.byKey(const ValueKey('start-focus-session')), findsNothing);
      expect(repository.startCalls, 1);

      repository.releaseStart.complete();
      await tester.pumpAndSettle();
      expect(await FocusRepository(database).getHistory(), hasLength(1));
    });

    testWidgets('back navigation returns to the previous route', (
      tester,
    ) async {
      await tester.pumpWidget(createApp(initialLocation: '/'));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Home route'));
      GoRouter.of(context).push('/focus');
      await tester.pumpAndSettle();
      expect(find.text('Set up a focus session'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Home route'), findsOneWidget);
    });
  });
}

class _FailingLoadRepository extends FocusRepository {
  _FailingLoadRepository(super.database);

  @override
  Future<FocusSessionTransition?> getUnresolvedSession() {
    throw StateError('Database unavailable.');
  }
}

class _BlockingStartRepository extends FocusRepository {
  _BlockingStartRepository(super.database);

  final startStarted = Completer<void>();
  final releaseStart = Completer<void>();
  var startCalls = 0;

  @override
  Future<FocusSessionTransition> startSession({
    String? taskId,
    String? taskIdSnapshot,
    String? taskTitleSnapshot,
    required FocusSessionMode mode,
    required int startedAtMs,
    int? plannedDurationMs,
    String? cycleId,
    int? cycleRound,
  }) async {
    startCalls++;
    startStarted.complete();
    await releaseStart.future;
    return super.startSession(
      taskId: taskId,
      taskIdSnapshot: taskIdSnapshot,
      taskTitleSnapshot: taskTitleSnapshot,
      mode: mode,
      startedAtMs: startedAtMs,
      plannedDurationMs: plannedDurationMs,
      cycleId: cycleId,
      cycleRound: cycleRound,
    );
  }
}

Future<void> _selectMode(WidgetTester tester, String mode) async {
  await tester.tap(find.byKey(const ValueKey('focus-mode')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(mode).last);
  await tester.pumpAndSettle();
}

Future<void> _insertTask(
  SystumDatabase database, {
  required String id,
  required String title,
}) {
  final now = DateTime.utc(2026, 10, 1);
  return TaskRepository(
    database,
  ).insert(Task(id: id, title: title, createdAt: now, updatedAt: now));
}
