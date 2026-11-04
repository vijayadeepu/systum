import 'package:flutter_test/flutter_test.dart';
import 'package:systum/features/tasks/models/task_recurrence.dart';

void main() {
  group('recurrence date helpers', () {
    test('normalizes to UTC midnight while preserving local components', () {
      final date = recurrenceDateOnly(DateTime(2026, 3, 29, 23, 45));

      expect(date.isUtc, isTrue);
      expect(date, DateTime.utc(2026, 3, 29));
    });

    test('round-trips date-only values through epoch milliseconds', () {
      final date = DateTime.utc(2028, 2, 29);

      expect(recurrenceDateFromEpochMs(recurrenceDateToEpochMs(date)), date);
    });

    test('adds calendar days without time-of-day or DST drift', () {
      expect(
        recurrenceAddDays(DateTime.utc(2026, 3, 29), 1),
        DateTime.utc(2026, 3, 30),
      );
      expect(
        recurrenceDaysBetween(
          DateTime.utc(2026, 12, 31),
          DateTime.utc(2027, 1, 1),
        ),
        1,
      );
    });

    test('builds a stable occurrence identity', () {
      final ruleId = 'rule-1';

      expect(
        occurrenceIdFor(ruleId, DateTime.utc(2026, 1, 2)),
        'occ:rule-1:2026-01-02',
      );
      expect(
        occurrenceIdFor(ruleId, DateTime(2026, 1, 2, 23, 59)),
        'occ:rule-1:2026-01-02',
      );
    });
  });

  group('TaskRecurrenceRule scheduling', () {
    TaskRecurrenceRule rule({
      RecurrenceType type = RecurrenceType.daily,
      int interval = 1,
      int? weekdays,
      DateTime? start,
      DateTime? end,
      int? maxOccurrences,
      bool isActive = true,
    }) {
      final startDate = start ?? DateTime.utc(2026, 1, 1);
      return TaskRecurrenceRule(
        id: 'rule-1',
        parentTaskId: 'task-1',
        recurrenceType: type,
        interval: interval,
        weekdays: weekdays,
        startDate: startDate,
        endDate: end,
        maxOccurrences: maxOccurrences,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        isActive: isActive,
      );
    }

    test('daily interval advances by calendar days', () {
      final daily = rule(interval: 3, start: DateTime.utc(2026, 1, 1));

      expect(daily.occursOn(DateTime.utc(2026, 1, 1)), isTrue);
      expect(daily.occursOn(DateTime.utc(2026, 1, 3)), isFalse);
      expect(daily.occursOn(DateTime.utc(2026, 1, 4)), isTrue);
      expect(
        daily.firstOccurrenceOnOrAfter(DateTime.utc(2026, 1, 5)),
        DateTime.utc(2026, 1, 7),
      );
    });

    test('legacy custom type behaves as every N days', () {
      final custom = rule(
        type: RecurrenceType.custom,
        interval: 2,
        start: DateTime.utc(2026, 1, 1),
      );

      expect(
        custom.nextOccurrenceAfter(DateTime.utc(2026, 1, 1)),
        DateTime.utc(2026, 1, 3),
      );
    });

    test('weekly interval respects selected weekdays and week offsets', () {
      // 2026-01-05 is a Monday.
      final weekly = rule(
        type: RecurrenceType.weekly,
        interval: 2,
        start: DateTime.utc(2026, 1, 5),
        weekdays: weekdayBit(DateTime.monday) | weekdayBit(DateTime.wednesday),
      );

      expect(weekly.occursOn(DateTime.utc(2026, 1, 5)), isTrue);
      expect(weekly.occursOn(DateTime.utc(2026, 1, 7)), isTrue);
      expect(weekly.occursOn(DateTime.utc(2026, 1, 12)), isFalse);
      expect(weekly.occursOn(DateTime.utc(2026, 1, 19)), isTrue);
      expect(
        weekly.nextOccurrenceAfter(DateTime.utc(2026, 1, 7)),
        DateTime.utc(2026, 1, 19),
      );
    });

    test('weekly handles a start date later in the first selected week', () {
      // Start on Wednesday but only Monday is selected; the first occurrence is
      // the following Monday.
      final weekly = rule(
        type: RecurrenceType.weekly,
        start: DateTime.utc(2026, 1, 7),
        weekdays: weekdayBit(DateTime.monday),
      );

      expect(
        weekly.firstOccurrenceOnOrAfter(weekly.startDate),
        DateTime.utc(2026, 1, 12),
      );
    });

    test('monthly clamps to the last day of shorter months', () {
      final monthly = rule(
        type: RecurrenceType.monthly,
        start: DateTime.utc(2027, 1, 31),
      );

      expect(monthly.occursOn(DateTime.utc(2027, 1, 31)), isTrue);
      expect(monthly.occursOn(DateTime.utc(2027, 2, 28)), isTrue);
      expect(monthly.occursOn(DateTime.utc(2027, 3, 31)), isTrue);
      expect(monthly.occursOn(DateTime.utc(2027, 4, 30)), isTrue);
      expect(monthly.occursOn(DateTime.utc(2027, 4, 29)), isFalse);
    });

    test('monthly handles leap years and year boundaries', () {
      final monthly = rule(
        type: RecurrenceType.monthly,
        start: DateTime.utc(2028, 1, 31),
      );

      expect(monthly.occursOn(DateTime.utc(2028, 2, 29)), isTrue);
      expect(
        monthly.firstOccurrenceOnOrAfter(DateTime.utc(2028, 3, 1)),
        DateTime.utc(2028, 3, 31),
      );
      expect(
        monthly.firstOccurrenceOnOrAfter(DateTime.utc(2029, 1, 1)),
        DateTime.utc(2029, 1, 31),
      );
    });

    test('monthly interval skips intermediate months', () {
      final monthly = rule(
        type: RecurrenceType.monthly,
        interval: 2,
        start: DateTime.utc(2026, 1, 15),
      );

      expect(monthly.occursOn(DateTime.utc(2026, 1, 15)), isTrue);
      expect(monthly.occursOn(DateTime.utc(2026, 2, 15)), isFalse);
      expect(monthly.occursOn(DateTime.utc(2026, 3, 15)), isTrue);
    });

    test('respects the inclusive end date', () {
      final bounded = rule(
        start: DateTime.utc(2026, 1, 1),
        end: DateTime.utc(2026, 1, 3),
      );

      expect(bounded.occursOn(DateTime.utc(2026, 1, 3)), isTrue);
      expect(bounded.occursOn(DateTime.utc(2026, 1, 4)), isFalse);
    });

    test('reports a readable summary including limits', () {
      final summary = rule(
        type: RecurrenceType.weekly,
        start: DateTime.utc(2026, 1, 5),
        weekdays: weekdayBit(DateTime.monday) | weekdayBit(DateTime.friday),
        end: DateTime.utc(2026, 3, 1),
        maxOccurrences: 12,
      ).summary;

      expect(summary, contains('Weekly on Mon, Fri'));
      expect(summary, contains('Starts 2026-01-05'));
      expect(summary, contains('Ends 2026-03-01'));
      expect(summary, contains('12 occurrences'));
    });

    test('summary marks a stopped rule', () {
      expect(rule(isActive: false).summary, contains('Stopped'));
    });
  });

  group('recurrence validation', () {
    TaskRecurrenceRule rule({
      RecurrenceType type = RecurrenceType.daily,
      int interval = 1,
      int? weekdays,
      DateTime? start,
      DateTime? end,
      int? maxOccurrences,
    }) {
      return TaskRecurrenceRule(
        id: 'rule-1',
        parentTaskId: 'task-1',
        recurrenceType: type,
        interval: interval,
        weekdays: weekdays,
        startDate: start ?? DateTime.utc(2026, 1, 1),
        endDate: end,
        maxOccurrences: maxOccurrences,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
    }

    test('accepts a valid weekly rule', () {
      expect(
        rule(
          type: RecurrenceType.weekly,
          weekdays: weekdayBit(DateTime.monday),
        ).validate(),
        isEmpty,
      );
    });

    test('rejects interval outside supported bounds', () {
      expect(rule(interval: 0).validate(), isNotEmpty);
      expect(rule(interval: 1000).validate(), isNotEmpty);
    });

    test('rejects weekly rules without selected weekdays', () {
      expect(rule(type: RecurrenceType.weekly).validate(), isNotEmpty);
      expect(
        rule(type: RecurrenceType.weekly, weekdays: 0).validate(),
        isNotEmpty,
      );
      expect(
        rule(type: RecurrenceType.weekly, weekdays: 1 << 8).validate(),
        isNotEmpty,
      );
    });

    test('rejects an end date before the start date', () {
      expect(
        rule(
          start: DateTime.utc(2026, 2, 1),
          end: DateTime.utc(2026, 1, 31),
        ).validate(),
        isNotEmpty,
      );
    });

    test('rejects invalid maximum occurrence counts', () {
      expect(rule(maxOccurrences: 0).validate(), isNotEmpty);
      expect(rule(maxOccurrences: 10001).validate(), isNotEmpty);
    });

    test(
      'draft validates and defaults weekly weekdays from the start date',
      () {
        final draft = RecurrenceDraft(
          recurrenceType: RecurrenceType.weekly,
          startDate: DateTime.utc(2026, 1, 5),
        );

        expect(draft.validate(), isEmpty);
        final rule = draft.toRule(
          id: 'draft',
          parentTaskId: null,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        expect(rule.weekdays, weekdayBit(DateTime.monday));
      },
    );

    test('draft normalizes start and end dates to date-only UTC values', () {
      final draft = RecurrenceDraft(
        recurrenceType: RecurrenceType.daily,
        startDate: DateTime(2026, 1, 1, 22),
        endDate: DateTime(2026, 1, 3, 5),
      );

      expect(draft.startDate, DateTime.utc(2026, 1, 1));
      expect(draft.endDate, DateTime.utc(2026, 1, 3));
    });
  });
}
