import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../../core/database/database.dart';

/// The type of recurrence rule.
enum RecurrenceType { daily, weekly, monthly, custom }

/// Human-readable label for a recurrence type.
String recurrenceTypeLabel(RecurrenceType type) {
  switch (type) {
    case RecurrenceType.daily:
      return 'Daily';
    case RecurrenceType.weekly:
      return 'Weekly';
    case RecurrenceType.monthly:
      return 'Monthly';
    case RecurrenceType.custom:
      return 'Custom interval';
  }
}

/// Sunday is bit 0, Monday bit 1, ... Saturday bit 6.
const int _sundayBit = 1 << 0;
const int _mondayBit = 1 << 1;
const int _tuesdayBit = 1 << 2;
const int _wednesdayBit = 1 << 3;
const int _thursdayBit = 1 << 4;
const int _fridayBit = 1 << 5;
const int _saturdayBit = 1 << 6;

/// All valid weekday bits. The bit order matches [DateTime.weekday] through
/// [weekdayBit].
const int allWeekdayBits =
    _sundayBit |
    _mondayBit |
    _tuesdayBit |
    _wednesdayBit |
    _thursdayBit |
    _fridayBit |
    _saturdayBit;

/// Returns the recurrence bit for a [DateTime.weekday] value (Monday = 1).
int weekdayBit(int weekday) => 1 << (weekday % 7);

/// Converts a weekday bit back to a [DateTime.weekday] value.
int weekdayFromBit(int bitIndex) => bitIndex == 0 ? 7 : bitIndex;

const List<String> _weekdayShortNames = [
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];

/// Human-readable names for the weekdays selected in [mask].
List<String> weekdayLabels(int mask) => [
  for (var bit = 0; bit < 7; bit++)
    if (mask & (1 << bit) != 0) _weekdayShortNames[bit],
];

/// Normalizes a [DateTime] to a date-only value in UTC.
///
/// Recurrence dates are calendar dates, not instants. UTC midnight avoids DST
/// transitions and keeps the stored value stable when the device timezone
/// changes. The local calendar components of [value] are preserved.
DateTime recurrenceDateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

/// Reads a date-only value persisted as milliseconds since the Unix epoch.
DateTime recurrenceDateFromEpochMs(int milliseconds) {
  final stored = DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  return DateTime.utc(stored.year, stored.month, stored.day);
}

/// Persists a date-only value as UTC midnight milliseconds since the epoch.
int recurrenceDateToEpochMs(DateTime value) =>
    recurrenceDateOnly(value).millisecondsSinceEpoch;

/// Adds calendar days without DST effects.
DateTime recurrenceAddDays(DateTime value, int days) {
  final date = recurrenceDateOnly(value);
  return DateTime.utc(date.year, date.month, date.day + days);
}

/// Number of calendar days from [from] to [to].
int recurrenceDaysBetween(DateTime from, DateTime to) =>
    recurrenceDateOnly(to).difference(recurrenceDateOnly(from)).inDays;

/// Stable key for an occurrence date.
String recurrenceDateKey(DateTime value) {
  final date = recurrenceDateOnly(value);
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Stable occurrence identity derived from the rule and calendar date.
String occurrenceIdFor(String ruleId, DateTime occurrenceDate) =>
    'occ:$ruleId:${recurrenceDateKey(occurrenceDate)}';

/// A recurrence rule that defines how occurrences of a parent task are
/// generated over time.
///
/// The rule is attached to a parent/template task. Occurrences are generated
/// from the rule and stored as separate records linked via [id].
class TaskRecurrenceRule {
  const TaskRecurrenceRule({
    required this.id,
    required this.parentTaskId,
    required this.recurrenceType,
    required this.interval,
    this.weekdays,
    required this.startDate,
    this.endDate,
    this.maxOccurrences,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory TaskRecurrenceRule.fromRow(TaskRecurrenceRuleRow row) {
    return TaskRecurrenceRule(
      id: row.id,
      parentTaskId: row.parentTaskId,
      recurrenceType: RecurrenceType.values.firstWhere(
        (type) => type.name == row.recurrenceType,
        orElse: () => RecurrenceType.custom,
      ),
      interval: row.interval,
      weekdays: row.weekdays,
      startDate: recurrenceDateFromEpochMs(row.startDate),
      endDate: row.endDate == null
          ? null
          : recurrenceDateFromEpochMs(row.endDate!),
      maxOccurrences: row.maxOccurrences,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAt,
        isUtc: true,
      ),
      isActive: row.isActive,
    );
  }

  final String id;
  final String? parentTaskId;
  final RecurrenceType recurrenceType;
  final int interval;
  final int? weekdays;
  final DateTime startDate;
  final DateTime? endDate;
  final int? maxOccurrences;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  TaskRecurrenceRulesCompanion toCompanion() {
    return TaskRecurrenceRulesCompanion(
      id: Value(id),
      parentTaskId: Value(parentTaskId),
      recurrenceType: Value(recurrenceType.name),
      interval: Value(interval),
      weekdays: Value(weekdays),
      startDate: Value(recurrenceDateToEpochMs(startDate)),
      endDate: Value(
        endDate == null ? null : recurrenceDateToEpochMs(endDate!),
      ),
      maxOccurrences: Value(maxOccurrences),
      createdAt: Value(createdAt.millisecondsSinceEpoch),
      updatedAt: Value(updatedAt.millisecondsSinceEpoch),
      isActive: Value(isActive),
    );
  }

  /// Validation messages for this rule. An empty list means the rule is valid.
  List<String> validate() {
    final errors = <String>[];
    if (interval < 1) {
      errors.add('Interval must be at least 1.');
    }
    if (interval > 999) {
      errors.add('Interval must be 999 or fewer.');
    }
    if (recurrenceType == RecurrenceType.weekly) {
      final mask = weekdays ?? 0;
      if (mask == 0) {
        errors.add('Select at least one weekday.');
      } else if (mask & ~allWeekdayBits != 0) {
        errors.add('Weekday selection is invalid.');
      }
    }
    if (endDate != null &&
        recurrenceDateOnly(endDate!).isBefore(recurrenceDateOnly(startDate))) {
      errors.add('End date cannot be before the start date.');
    }
    if (maxOccurrences != null && maxOccurrences! < 1) {
      errors.add('Maximum occurrences must be at least 1.');
    }
    if (maxOccurrences != null && maxOccurrences! > 10000) {
      errors.add('Maximum occurrences must be 10000 or fewer.');
    }
    return errors;
  }

  /// First occurrence date on or after [date].
  ///
  /// All calculations use calendar dates in UTC, so DST transitions cannot
  /// skip or duplicate a day.
  DateTime firstOccurrenceOnOrAfter(DateTime date) {
    final start = recurrenceDateOnly(startDate);
    final requested = recurrenceDateOnly(date);
    final from = requested.isAfter(start) ? requested : start;

    switch (recurrenceType) {
      case RecurrenceType.daily:
      case RecurrenceType.custom:
        final difference = recurrenceDaysBetween(start, from);
        final steps = (difference / interval).ceil();
        return recurrenceAddDays(start, steps * interval);
      case RecurrenceType.weekly:
        final selected = weekdays ?? 0;
        final startWeek = _weekStart(start);
        var candidate = from;
        // A full interval plus one week is enough to find the next selected
        // weekday. The guard also protects against corrupt weekday masks.
        final limit = 7 * interval + 7;
        for (var index = 0; index < limit; index++) {
          final bit = weekdayBit(candidate.weekday);
          final weekOffset = recurrenceDaysBetween(startWeek, candidate) ~/ 7;
          if ((selected & bit) != 0 && weekOffset % interval == 0) {
            return candidate;
          }
          candidate = recurrenceAddDays(candidate, 1);
        }
        return candidate;
      case RecurrenceType.monthly:
        final months =
            (from.year - start.year) * 12 + (from.month - start.month);
        var step = months <= 0 ? 0 : (months / interval).floor();
        var candidate = _monthOccurrence(start, step * interval);
        if (candidate.isBefore(from)) {
          step++;
          candidate = _monthOccurrence(start, step * interval);
        }
        return candidate;
    }
  }

  /// First occurrence strictly after [date].
  DateTime nextOccurrenceAfter(DateTime date) =>
      firstOccurrenceOnOrAfter(recurrenceAddDays(date, 1));

  /// Whether [date] is an occurrence date for this rule.
  bool occursOn(DateTime date) {
    final normalized = recurrenceDateOnly(date);
    if (normalized.isBefore(recurrenceDateOnly(startDate))) {
      return false;
    }
    if (endDate != null && normalized.isAfter(recurrenceDateOnly(endDate!))) {
      return false;
    }
    return firstOccurrenceOnOrAfter(normalized) == normalized;
  }

  /// A concise, user-facing description of the recurrence configuration.
  String get summary {
    final buffer = StringBuffer();
    switch (recurrenceType) {
      case RecurrenceType.daily:
        buffer.write(interval == 1 ? 'Daily' : 'Every $interval days');
      case RecurrenceType.custom:
        buffer.write(interval == 1 ? 'Every day' : 'Every $interval days');
      case RecurrenceType.weekly:
        final labels = weekdayLabels(weekdays ?? 0);
        final days = labels.isEmpty ? '' : ' on ${labels.join(', ')}';
        buffer.write(
          interval == 1 ? 'Weekly$days' : 'Every $interval weeks$days',
        );
      case RecurrenceType.monthly:
        final anchor = recurrenceDateOnly(startDate).day;
        final day = anchor > 28 ? 'day $anchor or last day' : 'day $anchor';
        buffer.write(
          interval == 1 ? 'Monthly on $day' : 'Every $interval months on $day',
        );
    }
    buffer.write(' • Starts ${recurrenceDateKey(startDate)}');
    if (endDate != null) {
      buffer.write(' • Ends ${recurrenceDateKey(endDate!)}');
    }
    if (maxOccurrences != null) {
      final noun = maxOccurrences == 1 ? 'occurrence' : 'occurrences';
      buffer.write(' • ${maxOccurrences!} $noun');
    }
    if (!isActive) {
      buffer.write(' • Stopped');
    }
    return buffer.toString();
  }

  /// The initial weekday selection for a new weekly rule.
  int get weeklyWeekdayMask => weekdays ?? weekdayBit(startDate.weekday);

  TaskRecurrenceRule copyWith({
    String? id,
    Object? parentTaskId = _unset,
    RecurrenceType? recurrenceType,
    int? interval,
    Object? weekdays = _unset,
    DateTime? startDate,
    Object? endDate = _unset,
    Object? maxOccurrences = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return TaskRecurrenceRule(
      id: id ?? this.id,
      parentTaskId: parentTaskId == _unset
          ? this.parentTaskId
          : parentTaskId as String?,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      interval: interval ?? this.interval,
      weekdays: weekdays == _unset ? this.weekdays : weekdays as int?,
      startDate: startDate ?? this.startDate,
      endDate: endDate == _unset ? this.endDate : endDate as DateTime?,
      maxOccurrences: maxOccurrences == _unset
          ? this.maxOccurrences
          : maxOccurrences as int?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  static DateTime _weekStart(DateTime date) {
    final normalized = recurrenceDateOnly(date);
    return recurrenceAddDays(normalized, -(normalized.weekday % 7));
  }

  static DateTime _monthOccurrence(DateTime start, int monthsToAdd) {
    final totalMonths = start.month - 1 + monthsToAdd;
    final year = start.year + (totalMonths ~/ 12);
    final month = (totalMonths % 12) + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    return DateTime.utc(year, month, math.min(start.day, lastDay));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TaskRecurrenceRule &&
            id == other.id &&
            parentTaskId == other.parentTaskId &&
            recurrenceType == other.recurrenceType &&
            interval == other.interval &&
            weekdays == other.weekdays &&
            startDate == other.startDate &&
            endDate == other.endDate &&
            maxOccurrences == other.maxOccurrences &&
            isActive == other.isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      parentTaskId,
      recurrenceType,
      interval,
      weekdays,
      startDate,
      endDate,
      maxOccurrences,
      isActive,
    );
  }
}

const Object _unset = Object();

/// Editable recurrence configuration used by the task create/edit flow.
class RecurrenceDraft {
  RecurrenceDraft({
    required this.recurrenceType,
    this.interval = 1,
    this.weekdays,
    required DateTime startDate,
    DateTime? endDate,
    this.maxOccurrences,
  }) : startDate = recurrenceDateOnly(startDate),
       endDate = endDate == null ? null : recurrenceDateOnly(endDate);

  factory RecurrenceDraft.fromRule(TaskRecurrenceRule rule) {
    return RecurrenceDraft(
      recurrenceType: rule.recurrenceType,
      interval: rule.interval,
      weekdays: rule.weekdays,
      startDate: rule.startDate,
      endDate: rule.endDate,
      maxOccurrences: rule.maxOccurrences,
    );
  }

  final RecurrenceType recurrenceType;
  final int interval;
  final int? weekdays;
  final DateTime startDate;
  final DateTime? endDate;
  final int? maxOccurrences;

  /// Validation messages for this draft. An empty list means it is valid.
  List<String> validate() {
    final rule = toRule(
      id: 'draft',
      parentTaskId: null,
      createdAt: DateTime.utc(1970),
      updatedAt: DateTime.utc(1970),
    );
    return rule.validate();
  }

  TaskRecurrenceRule toRule({
    required String id,
    required String? parentTaskId,
    required DateTime createdAt,
    required DateTime updatedAt,
    bool isActive = true,
  }) {
    return TaskRecurrenceRule(
      id: id,
      parentTaskId: parentTaskId,
      recurrenceType: recurrenceType,
      interval: interval,
      weekdays: recurrenceType == RecurrenceType.weekly
          ? (weekdays ?? weekdayBit(startDate.weekday))
          : null,
      startDate: recurrenceDateOnly(startDate),
      endDate: endDate == null ? null : recurrenceDateOnly(endDate!),
      maxOccurrences: maxOccurrences,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isActive: isActive,
    );
  }

  String get summary => toRule(
    id: 'draft',
    parentTaskId: null,
    createdAt: DateTime.utc(1970),
    updatedAt: DateTime.utc(1970),
  ).summary;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RecurrenceDraft &&
            recurrenceType == other.recurrenceType &&
            interval == other.interval &&
            weekdays == other.weekdays &&
            startDate == other.startDate &&
            endDate == other.endDate &&
            maxOccurrences == other.maxOccurrences;
  }

  @override
  int get hashCode => Object.hash(
    recurrenceType,
    interval,
    weekdays,
    startDate,
    endDate,
    maxOccurrences,
  );
}

/// A single generated occurrence of a recurring task.
class TaskOccurrence {
  const TaskOccurrence({
    required this.id,
    required this.ruleId,
    required this.occurrenceDate,
    this.dueDate,
    this.dueTime,
    this.dueTimezone,
    this.completed = false,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskOccurrence.fromRow(TaskOccurrenceRow row) {
    return TaskOccurrence(
      id: row.id,
      ruleId: row.ruleId,
      occurrenceDate: recurrenceDateFromEpochMs(row.occurrenceDate),
      dueDate: row.dueDate == null
          ? null
          : recurrenceDateFromEpochMs(row.dueDate!),
      dueTime: row.dueTime,
      dueTimezone: row.dueTimezone,
      completed: row.completed,
      isDeleted: row.isDeleted,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAt,
        isUtc: true,
      ),
    );
  }

  final String id;
  final String? ruleId;
  final DateTime occurrenceDate;
  final DateTime? dueDate;
  final int? dueTime;
  final String? dueTimezone;
  final bool completed;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskOccurrencesCompanion toCompanion() {
    return TaskOccurrencesCompanion(
      id: Value(id),
      ruleId: Value(ruleId),
      occurrenceDate: Value(recurrenceDateToEpochMs(occurrenceDate)),
      dueDate: Value(
        dueDate == null ? null : recurrenceDateToEpochMs(dueDate!),
      ),
      dueTime: Value(dueTime),
      dueTimezone: Value(dueTimezone),
      completed: Value(completed),
      isDeleted: Value(isDeleted),
      createdAt: Value(createdAt.millisecondsSinceEpoch),
      updatedAt: Value(updatedAt.millisecondsSinceEpoch),
    );
  }

  TaskOccurrence copyWith({
    String? id,
    Object? ruleId = _unset,
    DateTime? occurrenceDate,
    Object? dueDate = _unset,
    Object? dueTime = _unset,
    Object? dueTimezone = _unset,
    bool? completed,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskOccurrence(
      id: id ?? this.id,
      ruleId: ruleId == _unset ? this.ruleId : ruleId as String?,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      dueDate: dueDate == _unset ? this.dueDate : dueDate as DateTime?,
      dueTime: dueTime == _unset ? this.dueTime : dueTime as int?,
      dueTimezone: dueTimezone == _unset
          ? this.dueTimezone
          : dueTimezone as String?,
      completed: completed ?? this.completed,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TaskOccurrence &&
            id == other.id &&
            ruleId == other.ruleId &&
            occurrenceDate == other.occurrenceDate &&
            dueDate == other.dueDate &&
            dueTime == other.dueTime &&
            dueTimezone == other.dueTimezone &&
            completed == other.completed &&
            isDeleted == other.isDeleted;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      ruleId,
      occurrenceDate,
      dueDate,
      dueTime,
      dueTimezone,
      completed,
      isDeleted,
    );
  }
}
