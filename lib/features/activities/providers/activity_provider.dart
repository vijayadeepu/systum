import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/database_provider.dart';
import '../models/activity.dart';
import '../repository/activity_repository.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) => ActivityRepository(ref.watch(databaseProvider)));
final activitiesProvider = FutureProvider<List<Activity>>((ref) => ref.watch(activityRepositoryProvider).getAll());
final activeActivitiesProvider = FutureProvider<List<Activity>>((ref) async => (await ref.watch(activitiesProvider.future)).where((a) => a.status != ActivityStatus.archived).toList());
final dueActivitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final now = DateTime.now();
  return (await ref.watch(activeActivitiesProvider.future)).where((a) => !a.nextDue.isAfter(now)).toList();
});

final activityActionsProvider = Provider<ActivityActions>((ref) => ActivityActions(ref));

class ActivityActions {
  ActivityActions(this.ref);
  final Ref ref;
  ActivityRepository get repository => ref.read(activityRepositoryProvider);
  Future<void> create(Activity value) async { await repository.create(value); _refresh(); }
  Future<void> update(Activity value) async { await repository.update(value); _refresh(); }
  Future<void> complete(String id) async { await repository.complete(id); _refresh(); }
  Future<void> setStatus(String id, ActivityStatus status) async { await repository.setStatus(id, status); _refresh(); }
  void _refresh() { ref.invalidate(activitiesProvider); ref.invalidate(activeActivitiesProvider); ref.invalidate(dueActivitiesProvider); }
}
