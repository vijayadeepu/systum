import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/focus/providers/pomodoro_provider.dart';
import '../../shared/providers/database_provider.dart';
import 'database_diagnostics.dart';

final diagnosticsServiceProvider = Provider<DatabaseDiagnosticsService>((ref) {
  return DatabaseDiagnosticsService(
    ref.watch(databaseProvider),
    settingsStore: ref.watch(pomodoroSettingsStoreProvider),
  );
});

final diagnosticsProvider = FutureProvider<DiagnosticReport>((ref) {
  return ref.read(diagnosticsServiceProvider).run();
});
