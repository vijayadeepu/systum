import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/models/task_recurrence.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SystumDatabase database;
  late TaskRepository repository;

  setUp(() {
    database = SystumDatabase.test(NativeDatabase.memory());
    repository = TaskRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'createTaskWithRecurrence persists task, rule and first occurrences',
    () async {
      final today = recurrenceDateOnly(DateTime.now());
      final task = _task(
        id: 'parent',
        title: 'Water plants',
        dueTime: 3600,
        dueTimezone: 'America/New_York',
      );
      final draft = RecurrenceDraft(
        recurrenceType: RecurrenceType.daily,
        startDate: today,
        endDate: recurrenceAddDays(today, 2),
      );

      await repository.createTaskWithRecurrence(task, draft);

      final storedTask = await repository.getById('parent');
      expect(storedTask?.dueTime, 3600);
      expect(storedTask?.dueTimezone, 'America/New_York');

      final rule = await repository.getRecurrenceRuleForParent('parent');
      expect(rule, isNotNull);
      expect(rule!.recurrenceType, RecurrenceType.daily);
      expect(rule.startDate, today);
      expect(rule.endDate, recurrenceAddDays(today, 2));

      final occurrences = await repository.getOccurrencesForRule(rule.id);
      expect(occurrences.map((occurrence) => occurrence.occurrenceDate), [
        today,
        recurrenceAddDays(today, 1),
        recurrenceAddDays(today, 2),
      ]);
      for (final occurrence in occurrences) {
        expect(
          occurrence.id,
          occurrenceIdFor(rule.id, occurrence.occurrenceDate),
        );
        expect(occurrence.dueDate, occurrence.occurrenceDate);
        expect(occurrence.dueTime, 3600);
        expect(occurrence.dueTimezone, 'America/New_York');
      }
    },
  );

  test('createTaskWithRecurrence rolls back on an invalid draft', () async {
    final task = _task(id: 'parent');
    final invalid = RecurrenceDraft(
      recurrenceType: RecurrenceType.weekly,
      startDate: DateTime.utc(2026, 1, 1),
      weekdays: 0,
    );

    await expectLater(
      repository.createTaskWithRecurrence(task, invalid),
      throwsA(isA<TaskRecurrenceValidationException>()),
    );

    expect(await repository.getById('parent'), isNull);
    expect(await repository.getAllRecurrenceRules(), isEmpty);
  });

  test(
    'createTaskWithRecurrence rolls back when the goal is missing',
    () async {
      final task = _task(id: 'parent');
      final draft = RecurrenceDraft(
        recurrenceType: RecurrenceType.daily,
        startDate: recurrenceDateOnly(DateTime.now()),
      );

      await expectLater(
        repository.createTaskWithRecurrence(
          task,
          draft,
          goalId: 'missing-goal',
        ),
        throwsA(isA<TaskRelationshipException>()),
      );

      expect(await repository.getById('parent'), isNull);
      expect(await repository.getAllRecurrenceRules(), isEmpty);
    },
  );

  test('daily generation is bounded and resumable after a long gap', () async {
    await repository.insert(_task(id: 'parent'));
    final rule = _rule(
      id: 'rule',
      parentTaskId: 'parent',
      startDate: DateTime.utc(2020, 1, 1),
    );
    await repository.createRecurrenceRule(rule);

    final first = await repository.generateOccurrences(
      rule.id,
      horizonDays: 36500,
      maxPerRun: 10,
    );
    expect(first, 10);

    final second = await repository.generateOccurrences(
      rule.id,
      horizonDays: 36500,
      maxPerRun: 10,
    );
    expect(second, 10);

    final occurrences = await repository.getOccurrencesForRule(rule.id);
    expect(occurrences, hasLength(20));
    expect(occurrences.first.occurrenceDate, DateTime.utc(2020, 1, 1));
    expect(occurrences.last.occurrenceDate, DateTime.utc(2020, 1, 20));
  });

  test('generation is idempotent and does not duplicate dates', () async {
    await repository.insert(_task(id: 'parent'));
    final rule = _rule(
      id: 'rule',
      parentTaskId: 'parent',
      startDate: recurrenceDateOnly(DateTime.now()),
    );
    await repository.createRecurrenceRule(rule);

    final first = await repository.generateOccurrences(rule.id);
    final second = await repository.generateOccurrences(rule.id);

    expect(first, greaterThan(0));
    expect(second, 0);
    expect(await repository.getOccurrencesForRule(rule.id), hasLength(first));
    expect(
      await repository.getOccurrencesForRule(rule.id, includeDeleted: true),
      hasLength(first),
    );
  });

  test('weekly generation honours selected weekdays and interval', () async {
    await repository.insert(_task(id: 'parent'));
    final rule = _rule(
      id: 'rule',
      parentTaskId: 'parent',
      type: RecurrenceType.weekly,
      interval: 2,
      startDate: DateTime.utc(2026, 1, 5),
      weekdays: weekdayBit(DateTime.monday) | weekdayBit(DateTime.wednesday),
      endDate: DateTime.utc(2026, 1, 21),
    );
    await repository.createRecurrenceRule(rule);

    await repository.generateOccurrences(rule.id, horizonDays: 20);

    expect(
      (await repository.getOccurrencesForRule(
        rule.id,
      )).map((occurrence) => occurrence.occurrenceDate),
      [
        DateTime.utc(2026, 1, 5),
        DateTime.utc(2026, 1, 7),
        DateTime.utc(2026, 1, 19),
        DateTime.utc(2026, 1, 21),
      ],
    );
  });

  test('monthly generation clamps month-end and handles leap years', () async {
    await repository.insert(_task(id: 'parent'));
    final rule = _rule(
      id: 'rule',
      parentTaskId: 'parent',
      type: RecurrenceType.monthly,
      startDate: DateTime.utc(2028, 1, 31),
      endDate: DateTime.utc(2028, 4, 30),
    );
    await repository.createRecurrenceRule(rule);

    await repository.generateOccurrences(rule.id, horizonDays: 3650);

    expect(
      (await repository.getOccurrencesForRule(
        rule.id,
      )).map((occurrence) => occurrence.occurrenceDate),
      [
        DateTime.utc(2028, 1, 31),
        DateTime.utc(2028, 2, 29),
        DateTime.utc(2028, 3, 31),
        DateTime.utc(2028, 4, 30),
      ],
    );
  });

  test('custom legacy recurrence behaves as an every-N-days rule', () async {
    await repository.insert(_task(id: 'parent'));
    final rule = _rule(
      id: 'rule',
      parentTaskId: 'parent',
      type: RecurrenceType.custom,
      interval: 2,
      startDate: DateTime.utc(2026, 1, 1),
      endDate: DateTime.utc(2026, 1, 7),
    );
    await repository.createRecurrenceRule(rule);

    await repository.generateOccurrences(rule.id, horizonDays: 6);

    expect(
      (await repository.getOccurrencesForRule(
        rule.id,
      )).map((occurrence) => occurrence.occurrenceDate),
      [
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 1, 3),
        DateTime.utc(2026, 1, 5),
        DateTime.utc(2026, 1, 7),
      ],
    );
  });

  test('end date and maximum occurrence count are enforced', () async {
    await repository.insert(_task(id: 'parent'));
    final rule = _rule(
      id: 'rule',
      parentTaskId: 'parent',
      startDate: DateTime.utc(2026, 1, 1),
      endDate: DateTime.utc(2026, 1, 10),
      maxOccurrences: 3,
    );
    await repository.createRecurrenceRule(rule);

    await repository.generateOccurrences(rule.id, horizonDays: 100);

    expect(
      (await repository.getOccurrencesForRule(
        rule.id,
      )).map((occurrence) => occurrence.occurrenceDate),
      [
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 1, 2),
        DateTime.utc(2026, 1, 3),
      ],
    );
  });

  test('stop preserves history and prevents further generation', () async {
    final today = recurrenceDateOnly(DateTime.now());
    await repository.insert(_task(id: 'parent'));
    final rule = _rule(
      id: 'rule',
      parentTaskId: 'parent',
      startDate: today,
      endDate: recurrenceAddDays(today, 5),
    );
    await repository.createRecurrenceRule(rule);
    await repository.generateOccurrences(rule.id);
    final before = await repository.getOccurrencesForRule(rule.id);

    await repository.stopRecurrence(rule.id);

    final stopped = await repository.getRecurrenceRule(rule.id);
    expect(stopped?.isActive, isFalse);
    expect(await repository.generateOccurrences(rule.id), 0);
    expect(
      await repository.getOccurrencesForRule(rule.id),
      hasLength(before.length),
    );
  });

  test(
    'resume continues after the latest occurrence without backfilling',
    () async {
      final today = recurrenceDateOnly(DateTime.now());
      await repository.insert(_task(id: 'parent'));
      final rule = _rule(
        id: 'rule',
        parentTaskId: 'parent',
        startDate: today,
        endDate: recurrenceAddDays(today, 5),
      );
      await repository.createRecurrenceRule(rule);
      expect(await repository.generateOccurrences(rule.id, horizonDays: 0), 1);
      await repository.stopRecurrence(rule.id);
      await repository.resumeRecurrence(rule.id);

      expect(await repository.generateOccurrences(rule.id, horizonDays: 5), 5);
      expect(
        (await repository.getOccurrencesForRule(
          rule.id,
        )).map((occurrence) => occurrence.occurrenceDate),
        [for (var day = 0; day <= 5; day++) recurrenceAddDays(today, day)],
      );
    },
  );

  test('deleted occurrences are retained and never regenerated', () async {
    final today = recurrenceDateOnly(DateTime.now());
    await repository.insert(_task(id: 'parent'));
    final rule = _rule(
      id: 'rule',
      parentTaskId: 'parent',
      startDate: today,
      endDate: recurrenceAddDays(today, 3),
    );
    await repository.createRecurrenceRule(rule);
    await repository.generateOccurrences(rule.id);
    final occurrences = await repository.getOccurrencesForRule(rule.id);
    final deleted = occurrences[1];

    await repository.deleteOccurrence(deleted.id);

    expect(await repository.getOccurrencesForRule(rule.id), hasLength(3));
    expect(
      await repository.getOccurrencesForRule(rule.id, includeDeleted: true),
      hasLength(4),
    );
    expect(await repository.generateOccurrences(rule.id), 0);
    expect((await repository.getOccurrence(deleted.id))?.isDeleted, isTrue);
  });

  test('completion and rescheduling affect only one occurrence', () async {
    final today = recurrenceDateOnly(DateTime.now());
    await repository.insert(_task(id: 'parent'));
    final rule = _rule(
      id: 'rule',
      parentTaskId: 'parent',
      startDate: today,
      endDate: recurrenceAddDays(today, 2),
    );
    await repository.createRecurrenceRule(rule);
    await repository.generateOccurrences(rule.id);
    final occurrences = await repository.getOccurrencesForRule(rule.id);

    await repository.setOccurrenceCompleted(occurrences[0].id, true);
    await repository.rescheduleOccurrence(
      occurrences[1].id,
      recurrenceAddDays(today, 8),
    );

    final updated = await repository.getOccurrencesForRule(rule.id);
    expect(updated[0].completed, isTrue);
    expect(updated[1].completed, isFalse);
    expect(updated[1].dueDate, recurrenceAddDays(today, 8));
    expect(updated[1].occurrenceDate, occurrences[1].occurrenceDate);
    expect(updated[2].dueDate, occurrences[2].occurrenceDate);
    expect(await repository.generateOccurrences(rule.id), 0);
    expect(
      (await repository.getOccurrence(occurrences[0].id))?.completed,
      isTrue,
    );
  });

  test('updateTaskWithRecurrence is atomic and preserves history', () async {
    final today = recurrenceDateOnly(DateTime.now());
    final task = _task(id: 'parent', title: 'Original');
    await repository.createTaskWithRecurrence(
      task,
      RecurrenceDraft(
        recurrenceType: RecurrenceType.daily,
        startDate: today,
        endDate: recurrenceAddDays(today, 2),
      ),
    );
    final rule = (await repository.getRecurrenceRuleForParent('parent'))!;
    final before = await repository.getOccurrencesForRule(rule.id);

    final updatedTask = task.copyWith(
      title: 'Updated',
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    await repository.updateTaskWithRecurrence(
      updatedTask,
      RecurrenceDraft(
        recurrenceType: RecurrenceType.daily,
        startDate: today,
        endDate: recurrenceAddDays(today, 4),
      ),
    );

    expect((await repository.getById('parent'))?.title, 'Updated');
    final after = await repository.getOccurrencesForRule(rule.id);
    expect(after.length, greaterThanOrEqualTo(before.length));
    expect(
      after.take(before.length).map((occurrence) => occurrence.id),
      before.map((occurrence) => occurrence.id),
    );
  });

  test('update with an invalid draft leaves task and rule unchanged', () async {
    final today = recurrenceDateOnly(DateTime.now());
    final task = _task(id: 'parent', title: 'Original');
    await repository.createTaskWithRecurrence(
      task,
      RecurrenceDraft(recurrenceType: RecurrenceType.daily, startDate: today),
    );
    final rule = (await repository.getRecurrenceRuleForParent('parent'))!;

    await expectLater(
      repository.updateTaskWithRecurrence(
        task.copyWith(title: 'Should not persist'),
        RecurrenceDraft(
          recurrenceType: RecurrenceType.weekly,
          startDate: today,
          weekdays: 0,
        ),
      ),
      throwsA(isA<TaskRecurrenceValidationException>()),
    );

    expect((await repository.getById('parent'))?.title, 'Original');
    expect((await repository.getRecurrenceRule(rule.id))?.isActive, isTrue);
  });

  test(
    'updating with a null draft stops recurrence but keeps history',
    () async {
      final today = recurrenceDateOnly(DateTime.now());
      final task = _task(id: 'parent');
      await repository.createTaskWithRecurrence(
        task,
        RecurrenceDraft(
          recurrenceType: RecurrenceType.daily,
          startDate: today,
          endDate: recurrenceAddDays(today, 2),
        ),
      );
      final rule = (await repository.getRecurrenceRuleForParent('parent'))!;
      final before = await repository.getOccurrencesForRule(rule.id);

      await repository.updateTaskWithRecurrence(task, null);

      expect((await repository.getRecurrenceRule(rule.id))?.isActive, isFalse);
      expect(
        await repository.getOccurrencesForRule(rule.id),
        hasLength(before.length),
      );
      expect(await repository.generateOccurrences(rule.id), 0);
    },
  );

  test('deleting the parent task cascades to rule and occurrences', () async {
    final today = recurrenceDateOnly(DateTime.now());
    await repository.createTaskWithRecurrence(
      _task(id: 'parent'),
      RecurrenceDraft(
        recurrenceType: RecurrenceType.daily,
        startDate: today,
        endDate: recurrenceAddDays(today, 2),
      ),
    );
    final rule = (await repository.getRecurrenceRuleForParent('parent'))!;

    await repository.delete('parent');

    expect(await repository.getRecurrenceRule(rule.id), isNull);
    expect(
      await repository.getOccurrencesForRule(rule.id, includeDeleted: true),
      isEmpty,
    );
  });

  test('a task cannot have two recurrence rules', () async {
    await repository.insert(_task(id: 'parent'));
    final first = _rule(id: 'rule-1', parentTaskId: 'parent');
    final second = _rule(id: 'rule-2', parentTaskId: 'parent');

    await repository.createRecurrenceRule(first);
    await expectLater(
      repository.createRecurrenceRule(second),
      throwsA(anything),
    );

    final rules = await repository.getRecurrenceRulesForParent('parent');
    expect(rules.map((rule) => rule.id), ['rule-1']);
  });

  test(
    'occurrence date range queries are inclusive and hide deleted rows',
    () async {
      final today = recurrenceDateOnly(DateTime.now());
      await repository.insert(_task(id: 'parent'));
      final rule = _rule(
        id: 'rule',
        parentTaskId: 'parent',
        startDate: today,
        endDate: recurrenceAddDays(today, 4),
      );
      await repository.createRecurrenceRule(rule);
      await repository.generateOccurrences(rule.id);
      final occurrences = await repository.getOccurrencesForRule(rule.id);
      await repository.deleteOccurrence(occurrences.first.id);

      final inRange = await repository.getOccurrencesForDateRange(
        today,
        recurrenceAddDays(today, 2),
      );

      expect(inRange.map((occurrence) => occurrence.occurrenceDate), [
        recurrenceAddDays(today, 1),
        recurrenceAddDays(today, 2),
      ]);
    },
  );

  test('invalid rules are rejected before persistence', () async {
    await repository.insert(_task(id: 'parent'));

    await expectLater(
      repository.createRecurrenceRule(
        _rule(
          id: 'rule',
          parentTaskId: 'parent',
          type: RecurrenceType.weekly,
          weekdays: 0,
        ),
      ),
      throwsA(isA<TaskRecurrenceValidationException>()),
    );

    expect(await repository.getAllRecurrenceRules(), isEmpty);
  });
}

Task _task({
  required String id,
  String title = 'Recurring task',
  int? dueTime,
  String? dueTimezone,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Task(
    id: id,
    title: title,
    createdAt: now,
    updatedAt: now,
    dueTime: dueTime,
    dueTimezone: dueTimezone,
  );
}

TaskRecurrenceRule _rule({
  required String id,
  required String parentTaskId,
  RecurrenceType type = RecurrenceType.daily,
  int interval = 1,
  int? weekdays,
  DateTime? startDate,
  DateTime? endDate,
  int? maxOccurrences,
  bool isActive = true,
}) {
  return TaskRecurrenceRule(
    id: id,
    parentTaskId: parentTaskId,
    recurrenceType: type,
    interval: interval,
    weekdays: weekdays,
    startDate: startDate ?? DateTime.utc(2026, 1, 1),
    endDate: endDate,
    maxOccurrences: maxOccurrences,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    isActive: isActive,
  );
}
