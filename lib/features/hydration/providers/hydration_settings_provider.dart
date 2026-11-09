import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../shared/providers/database_provider.dart';
import '../models/hydration_settings.dart';

/// Provides hydration settings from the database.
final hydrationSettingsProvider = FutureProvider<HydrationSettings>((ref) {
  final database = ref.watch(databaseProvider);
  return HydrationSettingsRepository(database).getSettings();
});

/// Repository for hydration settings (CRUD operations for hydration settings).
class HydrationSettingsRepository {
  HydrationSettingsRepository(this._database);

  final SystumDatabase _database;

  /// Get the current hydration settings, or create default if none exist.
  Future<HydrationSettings> getSettings() async {
    final rows = await _database.select(_database.hydrationSettingsTable).get();
    if (rows.isNotEmpty) {
      return HydrationSettings.fromRow(rows.first);
    }

    // Create default settings
    final defaultSettings = HydrationSettings(
      id: 'hydration-settings',
      hydrationEnabled: true,
      dailyTargetMl: 2500,
    );
    await _database
        .into(_database.hydrationSettingsTable)
        .insert(defaultSettings.toCompanion());
    return defaultSettings;
  }

  /// Update hydration settings.
  Future<void> updateSettings(HydrationSettings settings) async {
    await _database
        .into(_database.hydrationSettingsTable)
        .insert(settings.toCompanion(), mode: InsertMode.replace);
  }
}

/// Provider for the hydration settings repository.
final hydrationSettingsRepositoryProvider =
    Provider<HydrationSettingsRepository>((ref) {
      return HydrationSettingsRepository(ref.watch(databaseProvider));
    });
