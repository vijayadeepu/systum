import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/features/focus/models/focus_session.dart';
import 'package:systum/features/focus/models/focus_session_interval.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/models/focus_session_status.dart';
import 'package:systum/features/focus/providers/focus_provider.dart';
import 'package:systum/features/focus/screens/focus_history_page.dart';
import 'package:systum/shared/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:systum/core/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SystumDatabase database;
  setUp(() => database = SystumDatabase.test(NativeDatabase.memory()));
  tearDown(() => database.close());

  Widget app(Future<List<FocusSessionTransition>> Function() history) {
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        databaseProvider.overrideWithValue(database),
        focusHistoryProvider.overrideWith((ref) => history()),
      ],
      child: const MaterialApp(home: FocusHistoryPage()),
    );
  }

  testWidgets('renders daily summary, snapshots, status, and task totals', (
    tester,
  ) async {
    final start = DateTime(2026, 10, 31, 10).toUtc().millisecondsSinceEpoch;
    await tester.pumpWidget(
      app(
        () async => [
          _transition(
            id: 'deleted',
            title: 'Write report',
            taskId: 'missing-task',
            status: FocusSessionStatus.completed,
            start: start,
            end: start + 90 * 1000,
          ),
          _transition(
            id: 'interrupted',
            title: 'Write report',
            taskId: 'missing-task',
            status: FocusSessionStatus.interrupted,
            start: start + 120 * 1000,
            end: start + 150 * 1000,
          ),
          _transition(
            id: 'break',
            mode: FocusSessionMode.shortBreak,
            status: FocusSessionStatus.completed,
            start: start + 180 * 1000,
            end: start + 300 * 1000,
          ),
          _transition(
            id: 'cancelled',
            title: 'Ignored',
            taskId: 'ignored-task',
            status: FocusSessionStatus.cancelled,
            start: start + 360 * 1000,
            end: start + 600 * 1000,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focused'), findsOneWidget);
    expect(find.text('2m 00s'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Interrupted'), findsWidgets);
    expect(find.text('Write report (deleted task)'), findsWidgets);
    expect(find.textContaining('Short break'), findsOneWidget);
    expect(find.text('Ignored (deleted task)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Task time'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Task time'), findsOneWidget);
    expect(find.text('Write report (deleted task)'), findsWidgets);
  });

  testWidgets('date navigation changes the selected day and opens details', (
    tester,
  ) async {
    final start = DateTime(2026, 10, 31, 10).toUtc().millisecondsSinceEpoch;
    await tester.pumpWidget(
      app(
        () async => [
          _transition(
            id: 'record',
            title: 'Snapshot',
            taskId: 'task',
            status: FocusSessionStatus.completed,
            start: start,
            end: start + 1000,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('31/10/2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous day'));
    await tester.pump();
    expect(find.text('30/10/2026'), findsOneWidget);
    expect(find.text('No sessions on this day.'), findsOneWidget);
  });

  testWidgets('opens a session detail view', (tester) async {
    final start = DateTime(2026, 10, 31, 10).toUtc().millisecondsSinceEpoch;
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          databaseProvider.overrideWithValue(database),
          focusHistoryProvider.overrideWith(
            (ref) async => [
              _transition(
                id: 'record',
                title: 'Snapshot',
                taskId: 'task',
                status: FocusSessionStatus.completed,
                start: start,
                end: start + 1000,
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: FocusHistoryPage(sessionId: 'record')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mode: Focus'), findsOneWidget);
    expect(find.text('Recorded intervals'), findsOneWidget);
    expect(find.text('Actual duration: 1s'), findsOneWidget);
  });

  testWidgets('handles empty and error states', (tester) async {
    await tester.pumpWidget(app(() async => const []));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No focus sessions yet. Start a session to build your history.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      app(
        () => Future<List<FocusSessionTransition>>.error(Exception('offline')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

FocusSessionTransition _transition({
  required String id,
  FocusSessionMode mode = FocusSessionMode.standard,
  required FocusSessionStatus status,
  required int start,
  required int end,
  String? title,
  String? taskId,
}) {
  return FocusSessionTransition(
    session: FocusSession(
      id: id,
      taskId: taskId,
      taskIdSnapshot: taskId,
      taskTitleSnapshot: title,
      mode: mode,
      status: status,
      startedAtMs: start,
      endedAtMs: end,
      actualDurationMs: end - start,
      updatedAtMs: end,
    ),
    intervals: [
      FocusSessionInterval(sessionId: id, startedAtMs: start, endedAtMs: end),
    ],
  );
}
