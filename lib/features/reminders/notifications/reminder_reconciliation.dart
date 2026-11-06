import '../models/reminder.dart';
import '../repository/reminder_repository.dart';
import 'reminder_delivery.dart';

/// Idempotent reconciliation of persisted reminders into Android schedules.
///
/// SQLite remains authoritative. For every persisted reminder the desired
/// Android state is derived from the persisted row through the D3 planner and
/// applied through the scheduler:
///
/// - scheduled + schedulable -> ensure a schedule exists
/// - cancelled -> ensure the notification is cancelled
/// - task lifecycle state -> follow persisted status (completion stays
///   cancelled, reopen becomes scheduled, task delete cascades away the row)
///
/// Re-running this reconciliation is safe: deterministic notification IDs make
/// cancel-and-replace idempotent, so no duplicate notification jobs are created.
class ReminderReconciliation {
  ReminderReconciliation({required this.repository, required this.delivery});

  final ReminderRepository repository;
  final ReminderDelivery delivery;

  /// Reconciles every persisted reminder.
  Future<void> reconcileAll() async {
    final reminders = await repository.getAll();
    await _reconcile(reminders);
  }

  /// Reconciles every reminder linked to a task.
  Future<void> reconcileTask(String taskId) async {
    final reminders = await repository.getForTask(taskId);
    await _reconcile(reminders);
  }

  Future<void> _reconcile(List<Reminder> reminders) async {
    for (final reminder in reminders) {
      try {
        await delivery.ensureScheduled(reminder);
      } catch (error, stackTrace) {
        delivery.logReconciliationFailure(reminder, error, stackTrace);
      }
    }
  }
}
