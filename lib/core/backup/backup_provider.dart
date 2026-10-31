import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/focus/providers/pomodoro_provider.dart';
import '../../shared/providers/database_provider.dart';
import 'backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(databaseProvider),
    ref.watch(pomodoroSettingsStoreProvider),
  );
});

/// Startup gate for interrupted restore reconciliation.
final backupRecoveryProvider = FutureProvider<void>((ref) {
  return ref.read(backupServiceProvider).reconcilePendingRestore();
});
