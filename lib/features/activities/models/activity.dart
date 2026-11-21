import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../tasks/models/task_recurrence.dart';

enum ActivityTargetType { app, service, account, task, general }
enum ActivityCadence { daily, everyNDays, weekly, weekdays }
enum ActivityStatus { active, paused, archived }

class Activity {
  const Activity({
    required this.id,
    required this.name,
    required this.targetName,
    required this.targetType,
    required this.cadence,
    required this.interval,
    required this.startDate,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.accountIdentifier,
    this.weekdays,
    this.localTimeSeconds,
    this.timezoneId,
    this.lastCompletedAt,
    this.status = ActivityStatus.active,
    this.notificationEnabled = false,
  });

  factory Activity.fromRow(ActivityRow row) => Activity(
    id: row.id,
    name: row.name,
    description: row.description,
    targetName: row.targetName,
    targetType: ActivityTargetType.values.byName(row.targetType),
    accountIdentifier: row.accountIdentifier,
    cadence: ActivityCadence.values.byName(row.cadenceType),
    interval: row.interval,
    weekdays: row.weekdays,
    startDate: recurrenceDateFromEpochMs(row.startDateMs),
    localTimeSeconds: row.localTimeSeconds,
    timezoneId: row.timezoneId,
    lastCompletedAt: row.lastCompletedAtMs == null ? null : DateTime.fromMillisecondsSinceEpoch(row.lastCompletedAtMs!, isUtc: true),
    status: ActivityStatus.values.byName(row.status),
    notificationEnabled: row.notificationEnabled,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAtMs, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAtMs, isUtc: true),
  );

  final String id, name, targetName;
  final String? description, accountIdentifier, timezoneId;
  final ActivityTargetType targetType;
  final ActivityCadence cadence;
  final int interval;
  final int? weekdays, localTimeSeconds;
  final DateTime startDate;
  final DateTime? lastCompletedAt;
  final ActivityStatus status;
  final bool notificationEnabled;
  final DateTime createdAt, updatedAt;

  DateTime get nextDue {
    final base = lastCompletedAt?.toLocal() ?? DateTime(startDate.year, startDate.month, startDate.day);
    return _nextAfter(base);
  }

  DateTime _nextAfter(DateTime base) {
    switch (cadence) {
      case ActivityCadence.daily:
        return base.add(Duration(days: interval));
      case ActivityCadence.everyNDays:
        return base.add(Duration(days: interval));
      case ActivityCadence.weekly:
        return base.add(Duration(days: 7 * interval));
      case ActivityCadence.weekdays:
        final mask = weekdays ?? 0;
        for (var i = 1; i <= 7; i++) {
          final candidate = base.add(Duration(days: i));
          if (mask & weekdayBit(candidate.weekday) != 0) return candidate;
        }
        return base.add(const Duration(days: 7));
    }
  }

  List<String> validate() {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('Activity ID is required.');
    if (name.trim().isEmpty || name.length > 120) errors.add('Activity name must be 1–120 characters.');
    if (targetName.trim().isEmpty || targetName.length > 120) errors.add('Target name must be 1–120 characters.');
    if (interval < 1 || interval > 999) errors.add('Cadence interval must be between 1 and 999.');
    if (cadence == ActivityCadence.weekdays && (weekdays == null || weekdays! <= 0 || weekdays! & ~allWeekdayBits != 0)) errors.add('Select at least one valid weekday.');
    if (localTimeSeconds != null && (localTimeSeconds! < 0 || localTimeSeconds! >= 86400)) errors.add('Activity time is invalid.');
    if (status == ActivityStatus.archived && notificationEnabled) errors.add('Archived activities cannot notify.');
    return errors;
  }

  ActivitiesCompanion toCompanion() => ActivitiesCompanion(
    id: Value(id), name: Value(name), description: Value(description), targetName: Value(targetName),
    targetType: Value(targetType.name), accountIdentifier: Value(accountIdentifier), cadenceType: Value(cadence.name),
    interval: Value(interval), weekdays: Value(weekdays), startDateMs: Value(recurrenceDateToEpochMs(startDate)),
    localTimeSeconds: Value(localTimeSeconds), timezoneId: Value(timezoneId),
    lastCompletedAtMs: Value(lastCompletedAt?.toUtc().millisecondsSinceEpoch), status: Value(status.name),
    notificationEnabled: Value(notificationEnabled), createdAtMs: Value(createdAt.toUtc().millisecondsSinceEpoch),
    updatedAtMs: Value(updatedAt.toUtc().millisecondsSinceEpoch),
  );
}

class ActivityCompletion {
  const ActivityCompletion({required this.id, required this.activityId, required this.completedAt, this.previousDueAt, this.note});
  factory ActivityCompletion.fromRow(ActivityCompletionRow row) => ActivityCompletion(
    id: row.id, activityId: row.activityId,
    completedAt: DateTime.fromMillisecondsSinceEpoch(row.completedAtMs, isUtc: true),
    previousDueAt: row.previousDueAtMs == null ? null : DateTime.fromMillisecondsSinceEpoch(row.previousDueAtMs!, isUtc: true),
    note: row.note,
  );
  final String id, activityId;
  final DateTime completedAt;
  final DateTime? previousDueAt;
  final String? note;
}
