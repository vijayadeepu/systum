import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/database_provider.dart';
import '../models/hydration_entry.dart';
import '../repository/hydration_repository.dart';
import 'hydration_settings_provider.dart';

/// Provides a [HydrationRepository] backed by the app database.
final hydrationRepositoryProvider = Provider<HydrationRepository>((ref) {
  return HydrationRepository(ref.watch(databaseProvider));
});

/// Current daily hydration target in milliliters. Defaults to 2500 ml (2.5 L).
final hydrationTargetMsProvider = Provider<int>((ref) {
  return ref
      .watch(hydrationSettingsProvider)
      .maybeWhen(
        data: (settings) => settings.dailyTargetMl,
        orElse: () => 2500,
      );
});

/// Hydration entries for a specific date.
final hydrationEntriesProvider =
    FutureProvider.family<List<HydrationEntry>, DateTime>((ref, date) async {
      final repository = ref.watch(hydrationRepositoryProvider);
      return repository.getEntriesForDate(date);
    });

/// Total hydration intake in milliliters for a specific date.
final hydrationTotalMsProvider = FutureProvider.family<int, DateTime>((
  ref,
  date,
) async {
  final repository = ref.watch(hydrationRepositoryProvider);
  return repository.getDailyTotalMs(date);
});

/// Whether the daily hydration target has been met for [date].
final hydrationTargetMetProvider = FutureProvider.family<bool, DateTime>((
  ref,
  date,
) async {
  final repository = ref.watch(hydrationRepositoryProvider);
  final target = ref.watch(hydrationTargetMsProvider);
  return repository.isTargetMet(date, target);
});
