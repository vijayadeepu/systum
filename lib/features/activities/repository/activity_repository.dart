import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../shared/utils/id_generator.dart';
import '../models/activity.dart';

class ActivityRepository {
  const ActivityRepository(this.database);
  final SystumDatabase database;

  Future<List<Activity>> getAll({bool includeArchived = true}) async {
    final query = database.select(database.activities)
      ..orderBy([(a) => OrderingTerm.asc(a.status), (a) => OrderingTerm.asc(a.name)]);
    if (!includeArchived) query.where((a) => a.status.isNotIn(['archived']));
    return (await query.get()).map(Activity.fromRow).toList();
  }

  Future<Activity?> getById(String id) async {
    final row = await (database.select(database.activities)..where((a) => a.id.equals(id))).getSingleOrNull();
    return row == null ? null : Activity.fromRow(row);
  }

  Future<void> create(Activity activity) async {
    _validate(activity);
    await database.into(database.activities).insert(activity.toCompanion());
  }

  Future<void> update(Activity activity) async {
    _validate(activity);
    if (!await database.update(database.activities).replace(activity.toCompanion())) throw StateError('Activity no longer exists.');
  }

  Future<void> setStatus(String id, ActivityStatus status) async {
    final activity = await getById(id);
    if (activity == null) throw StateError('Activity does not exist.');
    final now = DateTime.now().toUtc();
    await update(Activity(
      id: activity.id, name: activity.name, description: activity.description, targetName: activity.targetName,
      targetType: activity.targetType, accountIdentifier: activity.accountIdentifier, cadence: activity.cadence,
      interval: activity.interval, weekdays: activity.weekdays, startDate: activity.startDate,
      localTimeSeconds: activity.localTimeSeconds, timezoneId: activity.timezoneId, lastCompletedAt: activity.lastCompletedAt,
      status: status, notificationEnabled: status == ActivityStatus.archived ? false : activity.notificationEnabled,
      createdAt: activity.createdAt, updatedAt: now,
    ));
  }

  Future<Activity> complete(String id, {String? note}) async {
    final activity = await getById(id);
    if (activity == null) throw StateError('Activity does not exist.');
    if (activity.status == ActivityStatus.archived) throw StateError('Archived activities cannot be completed.');
    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      await database.into(database.activityCompletions).insert(ActivityCompletionsCompanion.insert(
        id: generateId(), activityId: activity.id, completedAtMs: now.millisecondsSinceEpoch,
        previousDueAtMs: Value(activity.nextDue.toUtc().millisecondsSinceEpoch), note: Value(note),
      ));
      await (database.update(database.activities)..where((a) => a.id.equals(id))).write(
        ActivitiesCompanion(lastCompletedAtMs: Value(now.millisecondsSinceEpoch), updatedAtMs: Value(now.millisecondsSinceEpoch)),
      );
    });
    return (await getById(id))!;
  }

  Future<List<ActivityCompletion>> history(String activityId) async {
    final rows = await (database.select(database.activityCompletions)
          ..where((c) => c.activityId.equals(activityId))
          ..orderBy([(c) => OrderingTerm.desc(c.completedAtMs)])).get();
    return rows.map(ActivityCompletion.fromRow).toList();
  }

  void _validate(Activity activity) {
    final errors = activity.validate();
    if (errors.isNotEmpty) throw ArgumentError(errors.join(' '));
  }
}
