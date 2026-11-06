import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tasks/providers/task_provider.dart';
import '../models/reminder.dart';
import '../notifications/reminder_delivery.dart';
import '../notifications/reminder_delivery_provider.dart';
import '../repository/reminder_repository.dart';
import 'reminder_repository_provider.dart';

/// Every persisted reminder, scheduled rows first.
final remindersProvider = FutureProvider<List<Reminder>>((ref) async {
  // Task completion and deletion mutate reminder rows transactionally, so
  // refresh this collection whenever the task list state changes.
  await ref.watch(taskProvider.future);
  final repository = ref.watch(reminderRepositoryProvider);
  return repository.getAll();
});

/// Reminders for one task. Kept in sync with task lifecycle mutations because
/// completion and reopening change reminder status in the same transaction as
/// the task write.
final taskRemindersProvider = FutureProvider.family<List<Reminder>, String>((
  ref,
  taskId,
) async {
  // Wait for the task list to settle before reading reminders. Watching the
  // raw state would rebuild this provider while its first query is still in
  // flight, orphaning the future callers are awaiting.
  await ref.watch(taskProvider.future);
  final repository = ref.watch(reminderRepositoryProvider);
  return repository.getForTask(taskId);
});

/// Coordinates reminder mutations and provider invalidation.
///
/// Widgets and future delivery adapters call these methods instead of reading
/// repositories directly.
final reminderActionsProvider = Provider<ReminderActions>((ref) {
  return ReminderActions(ref);
});

class ReminderActions {
  ReminderActions(this._ref);

  final Ref _ref;

  ReminderRepository get _repository => _ref.read(reminderRepositoryProvider);

  ReminderDelivery get _delivery => _ref.read(reminderDeliveryProvider);

  Future<void> create(Reminder reminder) async {
    await _repository.create(reminder);
    await _delivery.syncReminder(reminder);
    _invalidate();
  }

  Future<void> update(Reminder reminder) async {
    await _repository.update(reminder);
    await _delivery.syncReminder(reminder);
    _invalidate();
  }

  Future<void> cancel(
    String id, {
    ReminderCancellationReason reason = ReminderCancellationReason.user,
    DateTime? at,
  }) async {
    await _repository.cancel(id, reason: reason, at: at);
    await _delivery.cancelReminder(id);
    _invalidate();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await _delivery.cancelReminder(id);
    _invalidate();
  }

  void _invalidate() {
    _ref.invalidate(remindersProvider);
    _ref.invalidate(taskRemindersProvider);
  }
}
