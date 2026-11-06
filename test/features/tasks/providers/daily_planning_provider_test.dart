import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/repository/focus_repository.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/models/task_recurrence.dart';
import 'package:systum/features/tasks/providers/daily_planning_provider.dart';
import 'package:systum/features/tasks/providers/task_provider.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  group('selectedDateProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(
            SystumDatabase.test(NativeDatabase.memory()),
          ),
        ],
      );
      addTearDown(() {
        container.dispose();
      });
    });

    test('starts at today', () {
      final today = DateTime.now();
      final selected = container.read(selectedDateProvider);
      expect(selected.year, today.year);
      expect(selected.month, today.month);
      expect(selected.day, today.day);
    });

    test('navigates previous and next day', () {
      final notifier = container.read(selectedDateProvider.notifier);
      final start = DateTime.utc(2026, 6, 15);
      notifier.selectDate(start);
      expect(container.read(selectedDateProvider), start);

      notifier.previousDay();
      expect(container.read(selectedDateProvider), DateTime.utc(2026, 6, 14));

      notifier.nextDay();
      notifier.nextDay();
      expect(container.read(selectedDateProvider), DateTime.utc(2026, 6, 16));

      notifier.today();
      final today = DateTime.now();
      final selected = container.read(selectedDateProvider);
      expect(selected.year, today.year);
      expect(selected.month, today.month);
      expect(selected.day, today.day);
    });
  });

  group('dailyAgendaProvider', () {
    late SystumDatabase database;
    late TaskRepository repository;
    late ProviderContainer container;

    DateTime? now;

    setUp(() async {
      now = DateTime.utc(2026, 6, 10, 12);
      database = SystumDatabase.test(NativeDatabase.memory());
      repository = TaskRepository(database);
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        await database.close();
        container.dispose();
      });
    });

    Task task({
      required String id,
      required String title,
      DateTime? dueDate,
      int? dueTime,
      bool completed = false,
    }) {
      return Task(
        id: id,
        title: title,
        createdAt: now!,
        updatedAt: now!,
        dueDate: dueDate,
        dueTime: dueTime,
        completed: completed,
      );
    }

    Future<void> pumpAgenda(DateTime date) async {
      await container.read(taskProvider.future);
      await container.read(dailyAgendaProvider(date).future);
    }

    DailyAgenda agendaFor(DateTime date) =>
        container.read(dailyAgendaProvider(date)).requireValue;

    test('shows tasks due on the selected date', () async {
      await repository.insert(
        task(id: 't-1', title: 'Due today', dueDate: DateTime.utc(2026, 6, 15)),
      );
      await pumpAgenda(DateTime.utc(2026, 6, 15));

      final agenda = agendaFor(DateTime.utc(2026, 6, 15));
      expect(agenda.due, hasLength(1));
      expect(agenda.due.single.title, 'Due today');
      expect(agenda.overdue, isEmpty);
    });

    test('does not show tasks due on other dates', () async {
      await repository.insert(
        task(id: 't-1', title: 'Due 15th', dueDate: DateTime.utc(2026, 6, 15)),
      );
      await pumpAgenda(DateTime.utc(2026, 6, 16));

      final agenda = agendaFor(DateTime.utc(2026, 6, 16));
      expect(agenda.due, isEmpty);
      expect(agenda.overdue, hasLength(1));
      expect(agenda.overdue.single.title, 'Due 15th');
    });

    test('excludes completed tasks from overdue', () async {
      await repository.insert(
        _task(
          't-1',
          'Done',
          dueDate: DateTime.utc(2026, 6, 14),
          completed: true,
        ),
      );
      await pumpAgenda(DateTime.utc(2026, 6, 15));

      final agenda = agendaFor(DateTime.utc(2026, 6, 15));
      expect(agenda.overdue, isEmpty);
      expect(agenda.due, isEmpty);
    });

    test(
      'classifies tasks without due dates as neither due nor overdue',
      () async {
        await repository.insert(task(id: 't-1', title: 'Undated'));
        await pumpAgenda(DateTime.utc(2026, 6, 15));

        final agenda = agendaFor(DateTime.utc(2026, 6, 15));
        expect(agenda.isEmpty, isTrue);
      },
    );

    test('includes generated recurring occurrences due on the date', () async {
      await repository.insert(
        task(id: 'p-1', title: 'Parent', dueDate: DateTime.utc(2026, 6, 10)),
      );
      final rule = TaskRecurrenceRule(
        id: 'r-1',
        parentTaskId: 'p-1',
        recurrenceType: RecurrenceType.daily,
        interval: 1,
        startDate: DateTime.utc(2026, 6, 10),
        createdAt: now!,
        updatedAt: now!,
      );
      await repository.createRecurrenceRule(rule);
      await repository.createOccurrence(
        TaskOccurrence(
          id: 'occ-1',
          ruleId: 'r-1',
          occurrenceDate: DateTime.utc(2026, 6, 15),
          dueDate: DateTime.utc(2026, 6, 15),
          createdAt: now!,
          updatedAt: now!,
        ),
      );

      await pumpAgenda(DateTime.utc(2026, 6, 15));

      final agenda = agendaFor(DateTime.utc(2026, 6, 15));
      expect(agenda.due, hasLength(1));
      expect(agenda.due.single.isOccurrence, isTrue);
      expect(agenda.due.single.title, 'Parent');
      expect(agenda.due.single.parentTaskId, 'p-1');
      expect(agenda.due.single.ruleId, 'r-1');
    });

    test(
      'shows incomplete occurrences due before the date as overdue',
      () async {
        await repository.insert(task(id: 'p-1', title: 'Parent'));
        final rule = TaskRecurrenceRule(
          id: 'r-1',
          parentTaskId: 'p-1',
          recurrenceType: RecurrenceType.daily,
          interval: 1,
          startDate: DateTime.utc(2026, 6, 10),
          createdAt: now!,
          updatedAt: now!,
        );
        await repository.createRecurrenceRule(rule);
        await repository.createOccurrence(
          TaskOccurrence(
            id: 'occ-1',
            ruleId: 'r-1',
            occurrenceDate: DateTime.utc(2026, 6, 14),
            dueDate: DateTime.utc(2026, 6, 14),
            createdAt: now!,
            updatedAt: now!,
          ),
        );

        await pumpAgenda(DateTime.utc(2026, 6, 15));

        final agenda = agendaFor(DateTime.utc(2026, 6, 15));
        expect(agenda.overdue, hasLength(1));
        expect(agenda.overdue.single.isOccurrence, isTrue);
        expect(agenda.due, isEmpty);
      },
    );

    test('hides soft-deleted occurrences', () async {
      await repository.insert(task(id: 'p-1', title: 'Parent'));
      final rule = TaskRecurrenceRule(
        id: 'r-1',
        parentTaskId: 'p-1',
        recurrenceType: RecurrenceType.daily,
        interval: 1,
        startDate: DateTime.utc(2026, 6, 10),
        createdAt: now!,
        updatedAt: now!,
      );
      await repository.createRecurrenceRule(rule);
      await repository.createOccurrence(
        TaskOccurrence(
          id: 'occ-1',
          ruleId: 'r-1',
          occurrenceDate: DateTime.utc(2026, 6, 15),
          dueDate: DateTime.utc(2026, 6, 15),
          isDeleted: true,
          createdAt: now!,
          updatedAt: now!,
        ),
      );

      await pumpAgenda(DateTime.utc(2026, 6, 15));

      final agenda = agendaFor(DateTime.utc(2026, 6, 15));
      expect(agenda.isEmpty, isTrue);
    });

    test('respects due time when provided', () async {
      await repository.insert(
        task(
          id: 't-1',
          title: 'Timed',
          dueDate: DateTime.utc(2026, 6, 15),
          dueTime: 3660,
        ),
      );
      await pumpAgenda(DateTime.utc(2026, 6, 15));

      final agenda = agendaFor(DateTime.utc(2026, 6, 15));
      expect(agenda.due.single.dueTime, 3660);
    });
  });

  group('task completion and rescheduling through the agenda', () {
    late SystumDatabase database;
    late TaskRepository repository;
    late ProviderContainer container;

    setUp(() async {
      database = SystumDatabase.test(NativeDatabase.memory());
      repository = TaskRepository(database);
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        await database.close();
        container.dispose();
      });
    });

    test('completing a task moves it out of the due list', () async {
      await repository.insert(
        _task('t-1', 'Task', dueDate: DateTime.utc(2026, 6, 15)),
      );
      await container.read(taskProvider.future);

      await container.read(taskProvider.notifier).setCompleted('t-1', true);

      await container.read(
        dailyAgendaProvider(DateTime.utc(2026, 6, 15)).future,
      );
      final agenda = container
          .read(dailyAgendaProvider(DateTime.utc(2026, 6, 15)))
          .requireValue;
      expect(agenda.due.single.completed, isTrue);
      expect((await repository.getById('t-1'))?.completed, isTrue);
    });

    test('reopening a task marks it incomplete again', () async {
      await repository.insert(
        _task(
          't-9',
          'Task',
          dueDate: DateTime.utc(2026, 6, 21),
          completed: true,
        ),
      );
      await container.read(taskProvider.future);

      await container.read(taskProvider.notifier).setCompleted('t-9', false);

      final agenda = await container.read(
        dailyAgendaProvider(DateTime.utc(2026, 6, 21)).future,
      );
      expect(agenda.due.single.completed, isFalse);
    });

    test(
      'completing an occurrence does not touch the rule or siblings',
      () async {
        await repository.insert(_task('p-7', 'Parent'));
        final rule = TaskRecurrenceRule(
          id: 'r-7',
          parentTaskId: 'p-7',
          recurrenceType: RecurrenceType.daily,
          interval: 1,
          startDate: DateTime.utc(2026, 6, 10),
          createdAt: DateTime.utc(2026, 6, 1),
          updatedAt: DateTime.utc(2026, 6, 1),
        );
        await repository.createRecurrenceRule(rule);
        await repository.createOccurrence(
          TaskOccurrence(
            id: 'occ-7',
            ruleId: 'r-7',
            occurrenceDate: DateTime.utc(2026, 6, 22),
            dueDate: DateTime.utc(2026, 6, 22),
            createdAt: DateTime.utc(2026, 6, 1),
            updatedAt: DateTime.utc(2026, 6, 1),
          ),
        );
        await repository.createOccurrence(
          TaskOccurrence(
            id: 'occ-8',
            ruleId: 'r-7',
            occurrenceDate: DateTime.utc(2026, 6, 23),
            dueDate: DateTime.utc(2026, 6, 23),
            createdAt: DateTime.utc(2026, 6, 1),
            updatedAt: DateTime.utc(2026, 6, 1),
          ),
        );
        await container.read(taskProvider.future);

        await container
            .read(taskProvider.notifier)
            .setOccurrenceCompleted('occ-7', true);

        final day22 = await container.read(
          dailyAgendaProvider(DateTime.utc(2026, 6, 22)).future,
        );
        final completedEntry = day22.due.firstWhere(
          (entry) => entry.id == 'occ-7',
        );
        expect(completedEntry.completed, isTrue);
        final day23 = await container.read(
          dailyAgendaProvider(DateTime.utc(2026, 6, 23)).future,
        );
        final openEntry = day23.due.firstWhere((entry) => entry.id == 'occ-8');
        expect(openEntry.completed, isFalse);
        final storedRule = await repository.getRecurrenceRule('r-7');
        expect(storedRule?.isActive, isTrue);
      },
    );

    test('rescheduling a task moves it between days', () async {
      await repository.insert(
        _task('t-8', 'Task', dueDate: DateTime.utc(2026, 6, 15)),
      );
      await container.read(taskProvider.future);

      await container
          .read(taskProvider.notifier)
          .updateTask(_task('t-8', 'Task', dueDate: DateTime.utc(2026, 6, 17)));

      await container.read(
        dailyAgendaProvider(DateTime.utc(2026, 6, 17)).future,
      );
      final agenda17 = await container.read(
        dailyAgendaProvider(DateTime.utc(2026, 6, 17)).future,
      );
      expect(agenda17.due.single.title, 'Task');
      final agenda15 = await container.read(
        dailyAgendaProvider(DateTime.utc(2026, 6, 15)).future,
      );
      expect(agenda15.due, isEmpty);
    });

    test('rescheduling an occurrence moves only that occurrence', () async {
      await repository.insert(_task('p-9', 'Parent'));
      final rule = TaskRecurrenceRule(
        id: 'r-9',
        parentTaskId: 'p-9',
        recurrenceType: RecurrenceType.daily,
        interval: 1,
        startDate: DateTime.utc(2026, 6, 10),
        createdAt: DateTime.utc(2026, 6, 1),
        updatedAt: DateTime.utc(2026, 6, 1),
      );
      await repository.createRecurrenceRule(rule);
      await repository.createOccurrence(
        TaskOccurrence(
          id: 'occ-9',
          ruleId: 'r-9',
          occurrenceDate: DateTime.utc(2026, 6, 15),
          dueDate: DateTime.utc(2026, 6, 15),
          createdAt: DateTime.utc(2026, 6, 1),
          updatedAt: DateTime.utc(2026, 6, 1),
        ),
      );
      await container.read(taskProvider.future);

      await container
          .read(taskProvider.notifier)
          .rescheduleOccurrence('occ-9', DateTime.utc(2026, 6, 20));

      final day15 = await container.read(
        dailyAgendaProvider(DateTime.utc(2026, 6, 15)).future,
      );
      final occurrenceEntry = day15.due.firstWhere(
        (entry) => entry.isOccurrence,
      );
      expect(occurrenceEntry.title, 'Parent');
      expect(occurrenceEntry.dueDate, DateTime.utc(2026, 6, 20));
    });
  });

  group('dayOrderProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(
            SystumDatabase.test(NativeDatabase.memory()),
          ),
        ],
      );
      addTearDown(() => container.dispose());
    });

    test('starts empty, records and reapplies an order', () {
      final notifier = container.read(dayOrderProvider.notifier);
      final date = DateTime.utc(2026, 6, 15);

      expect(notifier.orderedIds(date), isNull);

      notifier.setOrder(date, ['b', 'a', 'c']);
      expect(notifier.orderedIds(date), ['b', 'a', 'c']);

      notifier.move(date, 0, 2);
      expect(notifier.orderedIds(date), ['a', 'c', 'b']);

      notifier.noteEntry(date, 'd');
      expect(notifier.orderedIds(date), ['a', 'c', 'b', 'd']);
      notifier.noteEntry(date, 'a');
      expect(notifier.orderedIds(date), ['a', 'c', 'b', 'd']);
    });
  });

  group('dailySummaryProvider', () {
    late SystumDatabase database;
    late TaskRepository repository;
    late FocusRepository focusRepository;
    late ProviderContainer container;

    setUp(() async {
      database = SystumDatabase.test(NativeDatabase.memory());
      repository = TaskRepository(database);
      focusRepository = FocusRepository(database);
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        await database.close();
        container.dispose();
      });
    });

    test('counts due tasks completed and incomplete', () async {
      await repository.insert(
        _task(
          't-1',
          'Done',
          dueDate: DateTime.utc(2026, 6, 15),
          completed: true,
        ),
      );
      await repository.insert(
        _task('t-2', 'Open', dueDate: DateTime.utc(2026, 6, 15)),
      );
      await repository.insert(
        _task('t-3', 'Old open', dueDate: DateTime.utc(2026, 6, 14)),
      );

      await container.read(
        dailySummaryProvider(DateTime.utc(2026, 6, 15)).future,
      );
      final summary = container
          .read(dailySummaryProvider(DateTime.utc(2026, 6, 15)))
          .requireValue;

      expect(summary.completedTasks, 1);
      expect(summary.incompleteTasks, 1);
      expect(summary.overdueTasks, 1);
    });

    test('derives focus metrics from persisted sessions', () async {
      await repository.insert(
        _task('t-1', 'Task', dueDate: DateTime.utc(2026, 6, 15)),
      );
      final started = DateTime.utc(2026, 6, 15, 9, 0);
      final session = await focusRepository.startSession(
        taskId: 't-1',
        taskIdSnapshot: 't-1',
        taskTitleSnapshot: 'Task',
        mode: FocusSessionMode.standard,
        startedAtMs: started.millisecondsSinceEpoch,
        plannedDurationMs: 1800000,
      );
      await focusRepository.completeSession(
        session.session.id,
        atMs: started.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
      );

      await container.read(
        dailySummaryProvider(DateTime.utc(2026, 6, 15)).future,
      );
      final summary = container
          .read(dailySummaryProvider(DateTime.utc(2026, 6, 15)))
          .requireValue;

      expect(summary.focusSessions, 1);
      expect(summary.focusedTimeMilliseconds, 1800000);
      expect(summary.tasksWorkedOn, ['t-1']);
    });

    test('returns zeros for a date with nothing recorded', () async {
      await container.read(
        dailySummaryProvider(DateTime.utc(2026, 6, 15)).future,
      );
      final summary = container
          .read(dailySummaryProvider(DateTime.utc(2026, 6, 15)))
          .requireValue;

      expect(summary.completedTasks, 0);
      expect(summary.incompleteTasks, 0);
      expect(summary.overdueTasks, 0);
      expect(summary.focusSessions, 0);
      expect(summary.focusedTimeMilliseconds, 0);
      expect(summary.tasksWorkedOn, isEmpty);
    });
  });

  group('monthCalendarProvider', () {
    late SystumDatabase database;
    late TaskRepository repository;
    late ProviderContainer container;

    setUp(() async {
      database = SystumDatabase.test(NativeDatabase.memory());
      repository = TaskRepository(database);
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        await database.close();
        container.dispose();
      });
    });

    test('marks dates that have tasks due on them', () async {
      await repository.insert(
        _task('t-1', 'Mid-month', dueDate: DateTime.utc(2026, 6, 15)),
      );
      await repository.insert(
        _task('t-2', 'Month end', dueDate: DateTime.utc(2026, 6, 30)),
      );
      await container.read(taskProvider.future);

      await container.read(
        monthCalendarProvider(const MonthRange(year: 2026, month: 6)).future,
      );
      final calendar = container
          .read(monthCalendarProvider(const MonthRange(year: 2026, month: 6)))
          .requireValue;

      expect(calendar.hasTasksOn(DateTime.utc(2026, 6, 15)), isTrue);
      expect(calendar.hasTasksOn(DateTime.utc(2026, 6, 30)), isTrue);
      expect(calendar.hasTasksOn(DateTime.utc(2026, 6, 16)), isFalse);
    });

    test('marks dates with recurring occurrences', () async {
      await repository.insert(_task('p-1', 'Parent'));
      final rule = TaskRecurrenceRule(
        id: 'r-1',
        parentTaskId: 'p-1',
        recurrenceType: RecurrenceType.daily,
        interval: 1,
        startDate: DateTime.utc(2026, 6, 1),
        createdAt: DateTime.utc(2026, 6, 1),
        updatedAt: DateTime.utc(2026, 6, 1),
      );
      await repository.createRecurrenceRule(rule);
      await repository.createOccurrence(
        TaskOccurrence(
          id: 'occ-1',
          ruleId: 'r-1',
          occurrenceDate: DateTime.utc(2026, 6, 11),
          dueDate: DateTime.utc(2026, 6, 11),
          createdAt: DateTime.utc(2026, 6, 1),
          updatedAt: DateTime.utc(2026, 6, 1),
        ),
      );
      await container.read(taskProvider.future);

      final calendar = await container.read(
        monthCalendarProvider(const MonthRange(year: 2026, month: 6)).future,
      );
      expect(calendar.hasTasksOn(DateTime.utc(2026, 6, 11)), isTrue);
    });
  });
}

Task _task(
  String id,
  String title, {
  DateTime? dueDate,
  int? dueTime,
  bool completed = false,
}) {
  return Task(
    id: id,
    title: title,
    createdAt: DateTime.utc(2026, 6, 1),
    updatedAt: DateTime.utc(2026, 6, 1),
    dueDate: dueDate,
    dueTime: dueTime,
    completed: completed,
  );
}
