import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/app/router.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';
import 'package:systum/features/tasks/screens/daily_agenda_page.dart';
import 'package:systum/shared/providers/database_provider.dart';
import 'package:systum/shared/utils/date_format.dart';

void main() {
  late SystumDatabase database;

  setUp(() {
    database = SystumDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpCalendar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.pumpAndSettle();
    appRouter.go(MonthCalendarPage.route);
    await tester.pumpAndSettle();
  }

  testWidgets('renders the current month grid', (tester) async {
    await pumpCalendar(tester);

    final now = DateTime.now();
    expect(
      find.textContaining('${_monthName(now.month)} ${now.year}'),
      findsOneWidget,
    );
  });

  testWidgets('navigates between months', (tester) async {
    await pumpCalendar(tester);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded).last);
    await tester.pumpAndSettle();

    final next = DateTime.now().add(const Duration(days: 35));
    expect(
      find.textContaining('${_monthName(next.month)} ${next.year}'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(
      find.textContaining('${_monthName(now.month)} ${now.year}'),
      findsOneWidget,
    );
  });

  testWidgets('today shortcut selects today', (tester) async {
    await pumpCalendar(tester);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.today_rounded).first);
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(
      find.textContaining('${_monthName(now.month)} ${now.year}'),
      findsOneWidget,
    );
  });

  testWidgets('marks dates that have tasks due on them', (tester) async {
    final repository = TaskRepository(database);
    final today = DateTime.now();
    await repository.insert(
      Task(
        id: 'cal-1',
        title: 'Calendar task',
        createdAt: today,
        updatedAt: today,
        dueDate: today,
      ),
    );

    await pumpCalendar(tester);

    // A date with tasks shows a task indicator dot on its cell.
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return decoration.color == const Color(0xFFB3261E);
      }),
      findsOneWidget,
    );
  });

  testWidgets('selecting a date opens the daily agenda', (tester) async {
    await pumpCalendar(tester);

    final today = DateTime.now();
    await tester.tap(find.text(today.day.toString()).first);
    await tester.pumpAndSettle();

    expect(find.byType(DailyAgendaPage), findsOneWidget);
    expect(find.textContaining(formatDateOnly(today)), findsOneWidget);
  });

  testWidgets('tapping back returns to the home screen', (tester) async {
    await pumpCalendar(tester);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byType(DailyAgendaPage), findsNothing);
  });
}

String _monthName(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[month - 1];
}
