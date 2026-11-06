import 'package:timezone/timezone.dart' as tz;

import '../../tasks/models/task_recurrence.dart';
import '../models/reminder.dart';
import 'reminder_notification_ids.dart';

/// Android's repeating-schedule components that preserve a D2 recurrence.
///
/// Only recurrence shapes that Android can express exactly are mapped. The
/// adapter translates these values to its platform union type so the planner
/// stays free of notification-plugin types.
enum ReminderRepeatComponent { time, dayOfWeekAndTime }

/// A schedule request derived from one persisted reminder.
class ReminderNotificationPlan {
  const ReminderNotificationPlan({
    required this.notificationId,
    required this.taskId,
    required this.scheduledAt,
    required this.repeatComponent,
  });

  final int notificationId;
  final String taskId;
  final tz.TZDateTime scheduledAt;

  /// Null schedules a single occurrence. A non-null value asks Android to
  /// repeat at the same wall-clock time in [scheduledAt]'s timezone.
  final ReminderRepeatComponent? repeatComponent;

  bool get repeats => repeatComponent != null;
}

/// Raised when a persisted reminder cannot be converted into a valid Android
/// schedule (for example an unknown IANA timezone identifier).
class ReminderScheduleException implements Exception {
  const ReminderScheduleException(this.message);

  final String message;

  @override
  String toString() => 'ReminderScheduleException: $message';
}

/// Pure translation from persisted D2 reminder intent to an Android request.
///
/// This deliberately reuses [TaskRecurrenceRule] for calendar occurrence
/// selection instead of defining a second recurrence engine. D2 stays the
/// source of truth; this class only projects it onto Android's capabilities.
class ReminderNotificationPlanner {
  const ReminderNotificationPlanner();

  /// Returns a plan, or null when the reminder has no future occurrence to
  /// schedule (cancelled, past one-time instant, or past recurrence end).
  ///
  /// [deviceLocation] resolves reminders whose persisted `timezoneId` is null.
  /// Pass it in tests; the app initializes `tz.local` from the device zone.
  ReminderNotificationPlan? plan(
    Reminder reminder, {
    DateTime? nowUtc,
    tz.Location? deviceLocation,
  }) {
    if (!reminder.isScheduled) {
      return null;
    }

    final errors = reminder.validate();
    if (errors.isNotEmpty) {
      throw ReminderScheduleException(errors.join(' '));
    }

    final now = (nowUtc ?? DateTime.now()).toUtc();
    if (reminder.scheduleType == ReminderScheduleType.once) {
      final instant = reminder.scheduledAtUtc!.toUtc();
      if (!instant.isAfter(now)) {
        return null;
      }
      return ReminderNotificationPlan(
        notificationId: reminderNotificationId(reminder.id),
        taskId: reminder.taskId,
        scheduledAt: tz.TZDateTime.from(instant, tz.UTC),
        repeatComponent: null,
      );
    }

    final location = _locationFor(reminder, deviceLocation);
    final occurrence = _nextOccurrence(reminder, now, location);
    if (occurrence == null) {
      return null;
    }

    return ReminderNotificationPlan(
      notificationId: reminderNotificationId(reminder.id),
      taskId: reminder.taskId,
      scheduledAt: occurrence,
      repeatComponent: _repeatComponent(reminder),
    );
  }

  tz.Location _locationFor(Reminder reminder, tz.Location? deviceLocation) {
    final timezoneId = reminder.timezoneId;
    if (timezoneId == null) {
      return deviceLocation ?? tz.local;
    }
    try {
      return tz.getLocation(timezoneId);
    } on tz.LocationNotFoundException {
      throw const ReminderScheduleException(
        'Reminder timezone is not a known IANA identifier.',
      );
    }
  }

  tz.TZDateTime? _nextOccurrence(
    Reminder reminder,
    DateTime nowUtc,
    tz.Location location,
  ) {
    final rule = _ruleFor(reminder);
    final now = tz.TZDateTime.from(nowUtc, location);
    final today = DateTime.utc(now.year, now.month, now.day);
    var date = rule.firstOccurrenceOnOrAfter(today);

    for (var attempt = 0; attempt < 1000; attempt++) {
      if (!_withinEndDate(reminder, date)) {
        return null;
      }
      final occurrence = _atLocalTime(
        location,
        date,
        reminder.localTimeSeconds!,
      );
      if (occurrence.isAfter(now)) {
        return occurrence;
      }
      date = rule.nextOccurrenceAfter(date);
    }

    throw const ReminderScheduleException(
      'Could not resolve the next reminder occurrence.',
    );
  }

  bool _withinEndDate(Reminder reminder, DateTime date) {
    final endDate = reminder.endDate;
    return endDate == null || !date.isAfter(recurrenceDateOnly(endDate));
  }

  tz.TZDateTime _atLocalTime(
    tz.Location location,
    DateTime date,
    int secondsSinceMidnight,
  ) {
    return tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
      secondsSinceMidnight ~/ 3600,
      (secondsSinceMidnight % 3600) ~/ 60,
      secondsSinceMidnight % 60,
    );
  }

  TaskRecurrenceRule _ruleFor(Reminder reminder) {
    return TaskRecurrenceRule(
      id: 'reminder:${reminder.id}',
      parentTaskId: reminder.taskId,
      recurrenceType: _recurrenceType(reminder.scheduleType),
      interval: reminder.interval,
      weekdays: reminder.weekdays,
      startDate: reminder.startDate!,
      endDate: reminder.endDate,
      maxOccurrences: reminder.maxOccurrences,
      createdAt: reminder.createdAt,
      updatedAt: reminder.updatedAt,
    );
  }

  RecurrenceType _recurrenceType(ReminderScheduleType type) {
    switch (type) {
      case ReminderScheduleType.once:
        throw const ReminderScheduleException(
          'A one-time reminder has no recurrence rule.',
        );
      case ReminderScheduleType.daily:
        return RecurrenceType.daily;
      case ReminderScheduleType.weekly:
        return RecurrenceType.weekly;
      case ReminderScheduleType.monthly:
        return RecurrenceType.monthly;
      case ReminderScheduleType.custom:
        return RecurrenceType.custom;
    }
  }

  /// Android can repeat exactly for an unbounded daily schedule and for an
  /// unbounded weekly schedule on a single weekday. Every other shape is
  /// scheduled as its next occurrence so D2 semantics are not silently
  /// changed; re-arming later occurrences is D4 reconciliation.
  ReminderRepeatComponent? _repeatComponent(Reminder reminder) {
    if (reminder.endDate != null || reminder.maxOccurrences != null) {
      return null;
    }
    switch (reminder.scheduleType) {
      case ReminderScheduleType.once:
      case ReminderScheduleType.monthly:
      case ReminderScheduleType.custom:
        return null;
      case ReminderScheduleType.daily:
        return reminder.interval == 1 ? ReminderRepeatComponent.time : null;
      case ReminderScheduleType.weekly:
        final weekdays = reminder.weekdays ?? 0;
        final singleWeekday = weekdays != 0 && (weekdays & (weekdays - 1)) == 0;
        return reminder.interval == 1 && singleWeekday
            ? ReminderRepeatComponent.dayOfWeekAndTime
            : null;
    }
  }
}
