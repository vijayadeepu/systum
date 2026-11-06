import 'package:flutter_test/flutter_test.dart';
import 'package:systum/features/reminders/models/reminder.dart';
import 'package:systum/features/tasks/models/task_recurrence.dart';

void main() {
  const unset = Object();
  final createdAt = DateTime.utc(2026, 1, 1, 12);

  Reminder once({
    String id = 'reminder-1',
    String taskId = 'task-1',
    Object? scheduledAt = unset,
    int? localTimeSeconds,
    ReminderStatus status = ReminderStatus.scheduled,
    ReminderCancellationReason? reason,
    DateTime? cancelledAt,
  }) {
    return Reminder(
      id: id,
      taskId: taskId,
      scheduleType: ReminderScheduleType.once,
      timezoneId: 'America/New_York',
      scheduledAtUtc: identical(scheduledAt, unset)
          ? DateTime.utc(2026, 1, 2, 9, 30)
          : scheduledAt as DateTime?,
      localTimeSeconds: localTimeSeconds,
      status: status,
      cancellationReason: reason,
      cancelledAtUtc: cancelledAt,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  Reminder recurring({
    ReminderScheduleType type = ReminderScheduleType.daily,
    Object? localTimeSeconds = unset,
    int interval = 1,
    Object? weekdays = unset,
    DateTime? startDate,
    DateTime? endDate,
    int? maxOccurrences,
    String? timezoneId = 'America/New_York',
  }) {
    return Reminder(
      id: 'rec-1',
      taskId: 'task-1',
      scheduleType: type,
      timezoneId: timezoneId,
      localTimeSeconds: identical(localTimeSeconds, unset)
          ? 9 * 3600
          : localTimeSeconds as int?,
      interval: interval,
      weekdays: identical(weekdays, unset)
          ? (type == ReminderScheduleType.weekly ? 1 << DateTime.monday : null)
          : weekdays as int?,
      startDate: startDate ?? DateTime.utc(2026, 1, 1),
      endDate: endDate,
      maxOccurrences: maxOccurrences,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  group('Reminder validation', () {
    test('accepts a one-time reminder with an absolute UTC instant', () {
      final reminder = once();

      expect(reminder.validate(), isEmpty);
      expect(reminder.isRecurring, isFalse);
      expect(reminder.scheduledAtUtc, DateTime.utc(2026, 1, 2, 9, 30));
    });

    test('rejects a one-time reminder without an absolute trigger', () {
      final reminder = once(scheduledAt: null);

      expect(
        reminder.validate(),
        contains('A one-time reminder requires an absolute trigger time.'),
      );
    });

    test('rejects recurrence fields on a one-time reminder', () {
      final reminder = once(localTimeSeconds: 3600);

      expect(
        reminder.validate(),
        contains('A one-time reminder cannot store a recurring local time.'),
      );
    });

    test('accepts recurring local-time schedules with an IANA timezone', () {
      final reminder = recurring(
        type: ReminderScheduleType.weekly,
        localTimeSeconds: 8 * 3600 + 15 * 60,
        interval: 2,
        endDate: DateTime.utc(2026, 6, 1),
        maxOccurrences: 10,
      );

      expect(reminder.validate(), isEmpty);
      expect(reminder.isRecurring, isTrue);
      expect(reminder.timezoneId, 'America/New_York');
      expect(reminder.localHour, 8);
      expect(reminder.localMinute, 15);
    });

    test('allows device-local recurring schedules when no zone is stored', () {
      expect(recurring(timezoneId: null).validate(), isEmpty);
    });

    test('rejects invalid local times', () {
      expect(
        recurring(localTimeSeconds: null).validate(),
        contains('Recurring local time must be between 00:00 and 23:59:59.'),
      );
      expect(
        recurring(localTimeSeconds: 86400).validate(),
        contains('Recurring local time must be between 00:00 and 23:59:59.'),
      );
    });

    test('rejects invalid weekly weekday masks', () {
      expect(
        recurring(type: ReminderScheduleType.weekly, weekdays: 0).validate(),
        contains('Select at least one weekday.'),
      );
      expect(
        recurring(
          type: ReminderScheduleType.weekly,
          weekdays: allWeekdayBits | 128,
        ).validate(),
        contains('Weekday selection is invalid.'),
      );
      expect(
        recurring(
          type: ReminderScheduleType.daily,
          weekdays: weekdayBit(DateTime.monday),
        ).validate(),
        contains('Only weekly reminders may select weekdays.'),
      );
    });

    test('rejects end dates before start, bad intervals and caps', () {
      expect(
        recurring(
          startDate: DateTime.utc(2026, 5, 1),
          endDate: DateTime.utc(2026, 4, 1),
        ).validate(),
        contains('End date cannot be before the start date.'),
      );
      expect(
        recurring(interval: 0).validate(),
        contains('Recurrence interval must be between 1 and 999.'),
      );
      expect(
        recurring(maxOccurrences: 0).validate(),
        contains('Maximum occurrences must be between 1 and 10000.'),
      );
    });

    test('requires cancellation metadata only for cancelled reminders', () {
      final cancelled = once(
        status: ReminderStatus.cancelled,
        reason: ReminderCancellationReason.user,
        cancelledAt: DateTime.utc(2026, 1, 1, 13),
      );
      expect(cancelled.validate(), isEmpty);

      expect(
        once(status: ReminderStatus.cancelled).validate(),
        contains('A cancelled reminder requires a cancellation reason.'),
      );
      expect(
        once(
          reason: ReminderCancellationReason.user,
          cancelledAt: DateTime.utc(2026, 1, 1, 13),
        ).validate(),
        contains('A scheduled reminder cannot have a cancellation reason.'),
      );
    });

    test('rejects blank identifiers', () {
      expect(
        once(id: '', taskId: '').validate(),
        containsAll([
          'Reminder ID is required.',
          'A reminder must belong to a task.',
        ]),
      );
    });
  });

  group('Reminder copyWith', () {
    test('can clear nullable schedule and cancellation fields', () {
      final reminder = once(
        status: ReminderStatus.cancelled,
        reason: ReminderCancellationReason.user,
        cancelledAt: DateTime.utc(2026, 1, 1, 13),
      );

      final cleared = reminder.copyWith(
        status: ReminderStatus.scheduled,
        cancellationReason: null,
        cancelledAtUtc: null,
      );

      expect(cleared.cancellationReason, isNull);
      expect(cleared.cancelledAtUtc, isNull);
      expect(cleared.status, ReminderStatus.scheduled);
      expect(cleared.validate(), isEmpty);
    });
  });
}
