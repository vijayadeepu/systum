import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/focus/providers/pomodoro_provider.dart';
import '../../shared/providers/database_provider.dart';
import 'automatic_backup.dart';
import 'backup_service.dart';
import 'export_service.dart';
import 'selective_portability.dart';

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

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(ref.watch(backupServiceProvider));
});

/// Startup reconciliation for interrupted export staging and publication.
final exportRecoveryProvider = FutureProvider<void>((ref) {
  return ref.read(exportServiceProvider).reconcilePendingExport();
});

final automaticBackupStoreProvider = Provider<AutomaticBackupStore>((ref) {
  return LocalAutomaticBackupStore();
});

final automaticBackupStatusStoreProvider = Provider<AutomaticBackupStatusStore>(
  (ref) {
    return SharedPreferencesAutomaticBackupStatusStore();
  },
);

final automaticBackupServiceProvider = Provider<AutomaticBackupService>((ref) {
  return AutomaticBackupService(
    ref.watch(backupServiceProvider),
    store: ref.watch(automaticBackupStoreProvider),
    statusStore: ref.watch(automaticBackupStatusStoreProvider),
  );
});

/// Runs lifecycle-driven automatic backups without blocking application use.
///
/// Failures are persisted in [AutomaticBackupStatus] and shown on the Backup
/// screen rather than preventing startup.
final automaticBackupProvider = FutureProvider<AutomaticBackupStatus>((
  ref,
) async {
  final service = ref.watch(automaticBackupServiceProvider);
  try {
    await service.reconcileInterruptedWrites();
  } on Object {
    // A later attempt will retry cleanup; never block startup for a stale
    // temporary file.
  }
  return service.runIfDue();
});

final automaticBackupCatalogueProvider =
    FutureProvider<List<AutomaticBackupEntry>>((ref) {
      return ref.watch(automaticBackupServiceProvider).catalogue();
    });

final selectivePortabilityServiceProvider =
    Provider<SelectivePortabilityService>((ref) {
      return SelectivePortabilityService(
        ref.watch(databaseProvider),
        ref.watch(backupServiceProvider),
      );
    });
