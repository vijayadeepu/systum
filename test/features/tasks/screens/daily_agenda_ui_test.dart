import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/app/router.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';
import 'package:systum/features/tasks/screens/daily_agenda_page.dart';
import 'package:systum/features/tasks/screens/task_detail_page.dart';
import 'package:systum/shared/providers/database_provider.dart';
import 'package:systum/shared/utils/date_format.dart';
import 'package:systum/features/tasks/models/task_recurrence.dart';

void main() {
  late SystumDatabase database;

  setUp(() {
    database = SystumDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpAgenda(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.pumpAndSettle();
    appRouter.go(DailyAgendaPage.route);
    await tester.pumpAndSettle();
  }

  testWidgets('renders an empty state when there is nothing planned', (
    tester,
  ) async {
    await pumpAgenda(tester);

    expect(find.text('Nothing planned'), findsOneWidget);
    expect(find.text('There are no tasks for this day.'), findsOneWidget);
  });

  testWidgets('shows overdue tasks and tasks due on the selected day', (
    tester,
  ) async {
    final repository = TaskRepository(database);
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    await repository.insert(
      Task(
        id: 'overdue-1',
        title: 'Late task',
        createdAt: today,
        updatedAt: today,
        dueDate: yesterday,
      ),
    );
    await repository.insert(
      Task(
        id: 'due-1',
        title: 'Due today',
        createdAt: today,
        updatedAt: today,
        dueDate: today,
      ),
    );

    await pumpAgenda(tester);

    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Late task'), findsOneWidget);
    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('Due on ${formatDateOnly(today)}'), findsOneWidget);
  });

  testWidgets('toggling a checkbox completes and reopens a task', (
    tester,
  ) async {
    final repository = TaskRepository(database);
    final today = DateTime.now();
    await repository.insert(
      Task(
        id: 'toggle-1',
        title: 'Toggle me',
        createdAt: today,
        updatedAt: today,
        dueDate: today,
      ),
    );

    await pumpAgenda(tester);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect((await repository.getById('toggle-1'))?.completed, isTrue);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect((await repository.getById('toggle-1'))?.completed, isFalse);
  });

  testWidgets('previous day, today and next day navigate the agenda', (
    tester,
  ) async {
    await pumpAgenda(tester);

    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();
    expect(find.textContaining(formatDateOnly(yesterday)), findsOneWidget);

    await tester.tap(find.byIcon(Icons.today_rounded).first);
    await tester.pumpAndSettle();
    expect(find.textContaining(formatDateOnly(today)), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await tester.pumpAndSettle();
    expect(find.textContaining(formatDateOnly(tomorrow)), findsOneWidget);
  });

  testWidgets('selecting a date opens the date picker', (tester) async {
    await pumpAgenda(tester);

    await tester.tap(find.byIcon(Icons.calendar_month_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('creating a task pre-fills the selected due date', (
    tester,
  ) async {
    final repository = TaskRepository(database);
    final today = DateTime.now();

    await pumpAgenda(tester);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Create Task'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Buy milk');
    await tester.tap(find.text('Create').last);
    await tester.pumpAndSettle();

    expect(find.text('Buy milk'), findsOneWidget);
    final created = (await repository.getAll()).singleWhere(
      (task) => task.title == 'Buy milk',
    );
    expect(created.dueDate, isNotNull);
    expect(recurrenceDateOnly(created.dueDate!), recurrenceDateOnly(today));
  });

  testWidgets('tapping calendar opens the calendar page', (tester) async {
    await pumpAgenda(tester);

    await tester.tap(find.byIcon(Icons.calendar_today_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byType(MonthCalendarPage), findsOneWidget);
  });

  testWidgets('tapping a task opens the task detail page', (tester) async {
    final repository = TaskRepository(database);
    final today = DateTime.now();
    await repository.insert(
      Task(
        id: 'open-1',
        title: 'Open me',
        createdAt: today,
        updatedAt: today,
        dueDate: today,
      ),
    );

    await pumpAgenda(tester);

    await tester.tap(find.text('Open me').first);
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailPage), findsOneWidget);
  });
}
