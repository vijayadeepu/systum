import 'package:flutter_test/flutter_test.dart';
import 'package:systum/features/reminders/models/reminder.dart';
import 'package:systum/features/reminders/notifications/reminder_notification_ids.dart';
import 'package:systum/features/reminders/notifications/reminder_notification_plan.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
  });

  late ReminderNotificationPlanner planner;

  setUp(() {
    planner = const ReminderNotificationPlanner();
  });

  Reminder recurring({
    String id = 'reminder-1',
    ReminderScheduleType scheduleType = ReminderScheduleType.daily,
    String? timezoneId,
    int interval = 1,
    int? weekdays,
    int localTimeSeconds = 3600,
    DateTime? startDate,
    DateTime? endDate,
    int? maxOccurrences,
    ReminderStatus status = ReminderStatus.scheduled,
  }) {
    final now = DateTime.utc(2026, 6, 1, 12);
    return Reminder(
      id: id,
      taskId: 'task-1',
      scheduleType: scheduleType,
      timezoneId: timezoneId,
      interval: interval,
      weekdays: weekdays,
      localTimeSeconds: localTimeSeconds,
      startDate: startDate ?? DateTime.utc(2026, 1, 1),
      endDate: endDate,
      maxOccurrences: maxOccurrences,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('plans a one-time reminder at its absolute UTC instant', () {
    final plan = planner.plan(
      Reminder(
        id: 'reminder-1',
        taskId: 'task-1',
        scheduleType: ReminderScheduleType.once,
        scheduledAtUtc: DateTime.utc(2026, 6, 20, 9),
        createdAt: DateTime.utc(2026, 6, 1, 12),
        updatedAt: DateTime.utc(2026, 6, 1, 12),
      ),
      nowUtc: DateTime.utc(2026, 6, 1, 12),
    );

    expect(plan, isNotNull);
    expect(plan!.taskId, 'task-1');
    expect(plan.notificationId, reminderNotificationId('reminder-1'));
    expect(plan.repeatComponent, isNull);
    expect(
      plan.scheduledAt.toUtc().millisecondsSinceEpoch,
      DateTime.utc(2026, 6, 20, 9).millisecondsSinceEpoch,
    );
  });

  test('returns no plan for a one-time reminder in the past', () {
    final plan = planner.plan(
      Reminder(
        id: 'reminder-1',
        taskId: 'task-1',
        scheduleType: ReminderScheduleType.once,
        scheduledAtUtc: DateTime.utc(2026, 6, 1, 9),
        createdAt: DateTime.utc(2026, 6, 1, 12),
        updatedAt: DateTime.utc(2026, 6, 1, 12),
      ),
      nowUtc: DateTime.utc(2026, 6, 1, 12),
    );

    expect(plan, isNull);
  });

  test('plans a recurring daily reminder as an exact local-time repeat', () {
    final plan = planner.plan(
      recurring(),
      nowUtc: DateTime.utc(2026, 6, 15, 12),
    );

    expect(plan, isNotNull);
    expect(plan!.repeatComponent, ReminderRepeatComponent.time);
    expect(
      plan.scheduledAt.toUtc().millisecondsSinceEpoch,
      DateTime.utc(2026, 6, 16, 1).millisecondsSinceEpoch,
    );
  });

  test('plans a single-weekday weekly reminder as a weekly repeat', () {
    final plan = planner.plan(
      recurring(
        scheduleType: ReminderScheduleType.weekly,
        weekdays: 2, // Monday
        localTimeSeconds: 7200,
        startDate: DateTime.utc(2026, 6, 1),
      ),
      nowUtc: DateTime.utc(2026, 6, 15, 12),
    );

    expect(plan, isNotNull);
    expect(plan!.repeatComponent, ReminderRepeatComponent.dayOfWeekAndTime);
    expect(
      plan.scheduledAt.toUtc().millisecondsSinceEpoch,
      DateTime.utc(2026, 6, 22, 2).millisecondsSinceEpoch,
    );
  });

  test(
    'falls back to a one-shot next occurrence for multi-weekday weekly or custom interval schedules',
    () {
      final multiWeekday = planner.plan(
        recurring(
          scheduleType: ReminderScheduleType.weekly,
          weekdays: 3, // Sunday and Monday
          localTimeSeconds: 3600,
          startDate: DateTime.utc(2026, 6, 1),
        ),
        nowUtc: DateTime.utc(2026, 6, 1, 12),
      );
      expect(multiWeekday!.repeatComponent, isNull);

      final customInterval = planner.plan(
        recurring(
          scheduleType: ReminderScheduleType.custom,
          interval: 2,
          localTimeSeconds: 3600,
          startDate: DateTime.utc(2026, 1, 1),
        ),
        nowUtc: DateTime.utc(2026, 6, 1, 12),
      );
      expect(customInterval!.repeatComponent, isNull);
      expect(
        customInterval.scheduledAt.toUtc().millisecondsSinceEpoch,
        greaterThan(DateTime.utc(2026, 6, 1, 12).millisecondsSinceEpoch),
      );
    },
  );

  test('recomputes recurring occurrences for a different device timezone', () {
    final inNewYork = planner.plan(
      recurring(),
      nowUtc: DateTime.utc(2026, 6, 15, 12),
      deviceLocation: tz.getLocation('America/New_York'),
    );
    final inBerlin = planner.plan(
      recurring(),
      nowUtc: DateTime.utc(2026, 6, 15, 12),
      deviceLocation: tz.getLocation('Europe/Berlin'),
    );

    expect(inNewYork, isNotNull);
    expect(inBerlin, isNotNull);
    expect(
      inNewYork!.scheduledAt.toUtc().millisecondsSinceEpoch,
      isNot(inBerlin!.scheduledAt.toUtc().millisecondsSinceEpoch),
    );
  });

  test('throws for an unknown IANA timezone identifier', () {
    expect(
      () => planner.plan(
        recurring(timezoneId: 'Not/AZone'),
        nowUtc: DateTime.utc(2026, 6, 1, 12),
      ),
      throwsA(isA<ReminderScheduleException>()),
    );
  });

  test('returns no plan for cancelled reminders', () {
    final plan = planner.plan(
      recurring(
        status: ReminderStatus.cancelled,
        startDate: DateTime.utc(2026, 1, 1),
      ),
    );
    expect(plan, isNull);
  });

  test('throws for an invalid one-time reminder without an instant', () {
    expect(
      () => planner.plan(
        Reminder(
          id: 'reminder-1',
          taskId: 'task-1',
          scheduleType: ReminderScheduleType.once,
          createdAt: DateTime.utc(2026, 6, 1, 12),
          updatedAt: DateTime.utc(2026, 6, 1, 12),
        ),
        nowUtc: DateTime.utc(2026, 6, 1, 12),
      ),
      throwsA(isA<ReminderScheduleException>()),
    );
  });
}
