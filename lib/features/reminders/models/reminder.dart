import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../tasks/models/task_recurrence.dart';

const Object _unset = Object();

/// How a persisted reminder repeats.
enum ReminderScheduleType { once, daily, weekly, monthly, custom }

/// Whether a reminder is currently intended to fire.
enum ReminderStatus { scheduled, cancelled }

/// Why a reminder stopped being scheduled.
enum ReminderCancellationReason {
  /// The user cancelled the reminder explicitly.
  user,

  /// The linked task was completed. Reopening the task reactivates it.
  taskCompleted,
}

/// A task reminder's persisted scheduling intent.
///
/// One-time reminders store an absolute UTC instant. Recurring reminders store
/// a local wall-clock time plus an IANA timezone (or null for the device-local
/// timezone) and the same calendar-weekday semantics as task recurrence, so a
/// later scheduler can resolve DST transitions without changing the user's
/// intended local time.
class Reminder {
  const Reminder({
    required this.id,
    required this.taskId,
    required this.scheduleType,
    this.timezoneId,
    this.scheduledAtUtc,
    this.localTimeSeconds,
    this.interval = 1,
    this.weekdays,
    this.startDate,
    this.endDate,
    this.maxOccurrences,
    this.status = ReminderStatus.scheduled,
    this.cancellationReason,
    this.cancelledAtUtc,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Reminder.fromRow(ReminderRow row) {
    return Reminder(
      id: row.id,
      taskId: row.taskId,
      scheduleType: ReminderScheduleType.values.firstWhere(
        (type) => type.name == row.scheduleType,
      ),
      timezoneId: row.timezoneId,
      scheduledAtUtc: row.scheduledAtUtcMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              row.scheduledAtUtcMs!,
              isUtc: true,
            ),
      localTimeSeconds: row.localTimeSeconds,
      interval: row.interval,
      weekdays: row.weekdays,
      startDate: row.startDate == null
          ? null
          : recurrenceDateFromEpochMs(row.startDate!),
      endDate: row.endDate == null
          ? null
          : recurrenceDateFromEpochMs(row.endDate!),
      maxOccurrences: row.maxOccurrences,
      status: ReminderStatus.values.firstWhere(
        (status) => status.name == row.status,
      ),
      cancellationReason: row.cancellationReason == null
          ? null
          : ReminderCancellationReason.values.firstWhere(
              (reason) => reason.name == row.cancellationReason,
            ),
      cancelledAtUtc: row.cancelledAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              row.cancelledAtMs!,
              isUtc: true,
            ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAtMs,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAtMs,
        isUtc: true,
      ),
    );
  }

  final String id;
  final String taskId;
  final ReminderScheduleType scheduleType;
  final String? timezoneId;
  final DateTime? scheduledAtUtc;
  final int? localTimeSeconds;
  final int interval;
  final int? weekdays;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? maxOccurrences;
  final ReminderStatus status;
  final ReminderCancellationReason? cancellationReason;
  final DateTime? cancelledAtUtc;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isScheduled => status == ReminderStatus.scheduled;

  bool get isRecurring => scheduleType != ReminderScheduleType.once;

  int? get localHour =>
      localTimeSeconds == null ? null : localTimeSeconds! ~/ 3600;

  int? get localMinute =>
      localTimeSeconds == null ? null : (localTimeSeconds! % 3600) ~/ 60;

  RemindersCompanion toCompanion() {
    return RemindersCompanion(
      id: Value(id),
      taskId: Value(taskId),
      scheduleType: Value(scheduleType.name),
      timezoneId: Value(timezoneId),
      scheduledAtUtcMs: Value(scheduledAtUtc?.toUtc().millisecondsSinceEpoch),
      localTimeSeconds: Value(localTimeSeconds),
      interval: Value(interval),
      weekdays: Value(weekdays),
      startDate: Value(
        startDate == null ? null : recurrenceDateToEpochMs(startDate!),
      ),
      endDate: Value(
        endDate == null ? null : recurrenceDateToEpochMs(endDate!),
      ),
      maxOccurrences: Value(maxOccurrences),
      status: Value(status.name),
      cancellationReason: Value(cancellationReason?.name),
      cancelledAtMs: Value(cancelledAtUtc?.toUtc().millisecondsSinceEpoch),
      createdAtMs: Value(createdAt.toUtc().millisecondsSinceEpoch),
      updatedAtMs: Value(updatedAt.toUtc().millisecondsSinceEpoch),
    );
  }

  /// Validation messages for this reminder. An empty list means it is valid.
  List<String> validate() {
    final errors = <String>[];
    if (id.isEmpty) errors.add('Reminder ID is required.');
    if (taskId.isEmpty) errors.add('A reminder must belong to a task.');
    if (timezoneId != null && timezoneId!.trim().isEmpty) {
      errors.add('Timezone identifier cannot be blank.');
    }
    if (createdAt.isAfter(updatedAt)) {
      errors.add('Updated timestamp cannot be before the created timestamp.');
    }

    if (scheduleType == ReminderScheduleType.once) {
      if (scheduledAtUtc == null) {
        errors.add('A one-time reminder requires an absolute trigger time.');
      }
      if (localTimeSeconds != null) {
        errors.add('A one-time reminder cannot store a recurring local time.');
      }
      if (interval != 1 || weekdays != null) {
        errors.add('A one-time reminder cannot define recurrence.');
      }
      if (startDate != null || endDate != null || maxOccurrences != null) {
        errors.add('A one-time reminder cannot define recurrence dates.');
      }
    } else {
      if (scheduledAtUtc != null) {
        errors.add(
          'A recurring reminder cannot store an absolute trigger time.',
        );
      }
      final time = localTimeSeconds;
      if (time == null || time < 0 || time > 86399) {
        errors.add('Recurring local time must be between 00:00 and 23:59:59.');
      }
      if (startDate == null) {
        errors.add('A recurring reminder requires a start date.');
      }
      if (interval < 1 || interval > 999) {
        errors.add('Recurrence interval must be between 1 and 999.');
      }
      if (scheduleType == ReminderScheduleType.weekly) {
        final mask = weekdays ?? 0;
        if (mask == 0) {
          errors.add('Select at least one weekday.');
        } else if (mask & ~allWeekdayBits != 0) {
          errors.add('Weekday selection is invalid.');
        }
      } else if (weekdays != null) {
        errors.add('Only weekly reminders may select weekdays.');
      }
      if (startDate != null &&
          endDate != null &&
          recurrenceDateOnly(
            endDate!,
          ).isBefore(recurrenceDateOnly(startDate!))) {
        errors.add('End date cannot be before the start date.');
      }
      if (maxOccurrences != null &&
          (maxOccurrences! < 1 || maxOccurrences! > 10000)) {
        errors.add('Maximum occurrences must be between 1 and 10000.');
      }
    }

    if (status == ReminderStatus.cancelled) {
      if (cancellationReason == null) {
        errors.add('A cancelled reminder requires a cancellation reason.');
      }
      if (cancelledAtUtc == null) {
        errors.add('A cancelled reminder requires a cancellation time.');
      }
    } else {
      if (cancellationReason != null) {
        errors.add('A scheduled reminder cannot have a cancellation reason.');
      }
      if (cancelledAtUtc != null) {
        errors.add('A scheduled reminder cannot have a cancellation time.');
      }
    }
    return errors;
  }

  Reminder copyWith({
    String? id,
    String? taskId,
    ReminderScheduleType? scheduleType,
    Object? timezoneId = _unset,
    Object? scheduledAtUtc = _unset,
    Object? localTimeSeconds = _unset,
    int? interval,
    Object? weekdays = _unset,
    Object? startDate = _unset,
    Object? endDate = _unset,
    Object? maxOccurrences = _unset,
    ReminderStatus? status,
    Object? cancellationReason = _unset,
    Object? cancelledAtUtc = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      scheduleType: scheduleType ?? this.scheduleType,
      timezoneId: timezoneId == _unset
          ? this.timezoneId
          : timezoneId as String?,
      scheduledAtUtc: scheduledAtUtc == _unset
          ? this.scheduledAtUtc
          : scheduledAtUtc as DateTime?,
      localTimeSeconds: localTimeSeconds == _unset
          ? this.localTimeSeconds
          : localTimeSeconds as int?,
      interval: interval ?? this.interval,
      weekdays: weekdays == _unset ? this.weekdays : weekdays as int?,
      startDate: startDate == _unset ? this.startDate : startDate as DateTime?,
      endDate: endDate == _unset ? this.endDate : endDate as DateTime?,
      maxOccurrences: maxOccurrences == _unset
          ? this.maxOccurrences
          : maxOccurrences as int?,
      status: status ?? this.status,
      cancellationReason: cancellationReason == _unset
          ? this.cancellationReason
          : cancellationReason as ReminderCancellationReason?,
      cancelledAtUtc: cancelledAtUtc == _unset
          ? this.cancelledAtUtc
          : cancelledAtUtc as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Reminder &&
            id == other.id &&
            taskId == other.taskId &&
            scheduleType == other.scheduleType &&
            timezoneId == other.timezoneId &&
            scheduledAtUtc == other.scheduledAtUtc &&
            localTimeSeconds == other.localTimeSeconds &&
            interval == other.interval &&
            weekdays == other.weekdays &&
            startDate == other.startDate &&
            endDate == other.endDate &&
            maxOccurrences == other.maxOccurrences &&
            status == other.status &&
            cancellationReason == other.cancellationReason &&
            cancelledAtUtc == other.cancelledAtUtc &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      taskId,
      scheduleType,
      timezoneId,
      scheduledAtUtc,
      localTimeSeconds,
      interval,
      weekdays,
      startDate,
      endDate,
      maxOccurrences,
      status,
      cancellationReason,
      cancelledAtUtc,
      createdAt,
      updatedAt,
    ]);
  }
}
