import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reminder_repository_provider.dart';
import 'reminder_delivery_provider.dart';
import 'reminder_reconciliation.dart';

/// Idempotent reconciliation of persisted reminders into Android schedules.
final reminderReconciliationProvider = Provider<ReminderReconciliation>((ref) {
  return ReminderReconciliation(
    repository: ref.watch(reminderRepositoryProvider),
    delivery: ref.watch(reminderDeliveryProvider),
  );
});

/// Runs a full persisted-reminder reconciliation at application start.
///
/// The result is observed but never gates app startup, so a transient database
/// read failure cannot block the user from using the app.
final reminderStartupReconciliationProvider = FutureProvider<void>((ref) async {
  final reconciliation = ref.read(reminderReconciliationProvider);
  return reconciliation.reconcileAll();
});
