import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../models/reminder.dart';

/// Persistence for reminder scheduling intent.
///
/// SQLite is authoritative. This repository never talks to Android
/// notifications; delivery adapters consume the rows written here.
class ReminderRepository {
  const ReminderRepository(this._database);

  final SystumDatabase _database;

  /// Returns every reminder, scheduled rows first, then newest first.
  Future<List<Reminder>> getAll() async {
    final rows = await _ordered(_database.select(_database.reminders)).get();
    return rows.map(Reminder.fromRow).toList(growable: false);
  }

  /// Returns every reminder for [taskId], scheduled rows first.
  Future<List<Reminder>> getForTask(String taskId) async {
    final query = _database.select(_database.reminders)
      ..where((reminder) => reminder.taskId.equals(taskId));
    final rows = await _ordered(query).get();
    return rows.map(Reminder.fromRow).toList(growable: false);
  }

  Future<Reminder?> getById(String id) async {
    final row = await (_database.select(
      _database.reminders,
    )..where((reminder) => reminder.id.equals(id))).getSingleOrNull();
    return row == null ? null : Reminder.fromRow(row);
  }

  /// Creates [reminder] for an existing, incomplete task.
  ///
  /// The task check and insert share a transaction so a concurrent task
  /// completion or deletion cannot leave a scheduled reminder behind.
  Future<void> create(Reminder reminder) async {
    _ensureValid(reminder);
    await _database.transaction(() async {
      final task = await _taskFor(reminder.taskId);
      if (task == null) {
        throw ReminderRelationshipException(
          'Task "${reminder.taskId}" does not exist.',
        );
      }
      if (task.completed) {
        throw ReminderRelationshipException(
          'Task "${reminder.taskId}" is completed; reopen it before adding a '
          'reminder.',
        );
      }
      await _database.into(_database.reminders).insert(reminder.toCompanion());
    });
  }

  /// Replaces an existing reminder's persisted scheduling intent.
  ///
  /// A reminder cannot be rescheduled as active for a completed task. The
  /// existence check and write share a transaction.
  Future<void> update(Reminder reminder) async {
    _ensureValid(reminder);
    await _database.transaction(() async {
      final existing = await getById(reminder.id);
      if (existing == null) {
        throw ReminderRelationshipException(
          'Reminder "${reminder.id}" does not exist.',
        );
      }
      final task = await _taskFor(reminder.taskId);
      if (task == null) {
        throw ReminderRelationshipException(
          'Task "${reminder.taskId}" does not exist.',
        );
      }
      if (reminder.isScheduled && task.completed) {
        throw ReminderRelationshipException(
          'Task "${reminder.taskId}" is completed; reopen it before scheduling '
          'a reminder.',
        );
      }
      final updated = await _database
          .update(_database.reminders)
          .replace(reminder.toCompanion());
      if (!updated) {
        throw ReminderRelationshipException(
          'Reminder "${reminder.id}" no longer exists.',
        );
      }
    });
  }

  /// Cancels a reminder while retaining the row for history and diagnostics.
  ///
  /// Cancelling an already-cancelled reminder is a no-op so retries are safe.
  Future<void> cancel(
    String id, {
    ReminderCancellationReason reason = ReminderCancellationReason.user,
    DateTime? at,
  }) async {
    await _database.transaction(() async {
      final existing = await getById(id);
      if (existing == null) {
        throw ReminderRelationshipException('Reminder "$id" does not exist.');
      }
      if (existing.status == ReminderStatus.cancelled) {
        return;
      }
      final cancelledAt = (at ?? DateTime.now()).toUtc();
      final updated =
          await (_database.update(
            _database.reminders,
          )..where((reminder) => reminder.id.equals(id))).write(
            RemindersCompanion(
              status: Value(ReminderStatus.cancelled.name),
              cancellationReason: Value(reason.name),
              cancelledAtMs: Value(cancelledAt.millisecondsSinceEpoch),
              updatedAtMs: Value(cancelledAt.millisecondsSinceEpoch),
            ),
          );
      if (updated == 0) {
        throw ReminderRelationshipException('Reminder "$id" no longer exists.');
      }
    });
  }

  /// Permanently deletes a reminder. Missing IDs are a no-op.
  Future<void> delete(String id) async {
    await (_database.delete(
      _database.reminders,
    )..where((reminder) => reminder.id.equals(id))).go();
  }

  Future<TaskRow?> _taskFor(String taskId) {
    return (_database.select(
      _database.tasks,
    )..where((task) => task.id.equals(taskId))).getSingleOrNull();
  }

  SimpleSelectStatement<$RemindersTable, ReminderRow> _ordered(
    SimpleSelectStatement<$RemindersTable, ReminderRow> query,
  ) {
    return query..orderBy([
      (reminder) => OrderingTerm(
        expression: reminder.status.equals(ReminderStatus.scheduled.name),
        mode: OrderingMode.desc,
      ),
      (reminder) => OrderingTerm.desc(reminder.createdAtMs),
      (reminder) => OrderingTerm.asc(reminder.id),
    ]);
  }

  void _ensureValid(Reminder reminder) {
    final errors = reminder.validate();
    if (errors.isNotEmpty) {
      throw ReminderValidationException(errors);
    }
  }
}

class ReminderValidationException implements Exception {
  const ReminderValidationException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'ReminderValidationException: ${errors.join(' ')}';
}

class ReminderRelationshipException implements Exception {
  const ReminderRelationshipException(this.message);

  final String message;

  @override
  String toString() => 'ReminderRelationshipException: $message';
}
