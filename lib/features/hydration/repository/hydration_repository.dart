import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../models/hydration_entry.dart';

/// Repository for hydration entries. Provides CRUD operations and daily
/// aggregation for the hydration tracking feature.
class HydrationRepository {
  HydrationRepository(this._database);

  final SystumDatabase _database;
  int _idCounter = 0;

  /// Logs a hydration entry with [amountMs] milliliters at the given time.
  ///
  /// Returns the stable ID of the created entry.
  Future<String> logEntry(int amountMs, {DateTime? loggedAt}) async {
    final id = _generateId();
    await _database
        .into(_database.hydrationEntries)
        .insert(
          HydrationEntryRow(
            id: id,
            amountMs: amountMs,
            loggedAtMs: (loggedAt ?? DateTime.now())
                .toUtc()
                .millisecondsSinceEpoch,
          ),
        );
    return id;
  }

  /// Returns all hydration entries for [date] (local calendar date).
  Future<List<HydrationEntry>> getEntriesForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final rows =
        await (_database.select(_database.hydrationEntries)
              ..where(
                (entry) =>
                    entry.loggedAtMs.isBiggerOrEqualValue(
                      startOfDay.millisecondsSinceEpoch,
                    ) &
                    entry.loggedAtMs.isSmallerThanValue(
                      endOfDay.millisecondsSinceEpoch,
                    ),
              )
              ..orderBy([(entry) => OrderingTerm.asc(entry.loggedAtMs)]))
            .get();

    return rows.map(HydrationEntry.fromRow).toList(growable: false);
  }

  /// Returns total intake in milliliters for [date].
  Future<int> getDailyTotalMs(DateTime date) async {
    final entries = await getEntriesForDate(date);
    int total = 0;
    for (final entry in entries) {
      total += entry.amountMs;
    }
    return total;
  }

  /// Returns true if the daily target has been met for [date].
  Future<bool> isTargetMet(DateTime date, int targetMs) async {
    return (await getDailyTotalMs(date)) >= targetMs;
  }

  /// Returns entries in [startDate]..[endDate] inclusive range.
  Future<List<HydrationEntry>> getEntriesForRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startEpoch = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    ).millisecondsSinceEpoch;
    final endEpoch = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    final rows =
        await (_database.select(_database.hydrationEntries)
              ..where(
                (entry) =>
                    entry.loggedAtMs.isBiggerOrEqualValue(startEpoch) &
                    entry.loggedAtMs.isSmallerOrEqualValue(endEpoch),
              )
              ..orderBy([(entry) => OrderingTerm.asc(entry.loggedAtMs)]))
            .get();

    return rows.map(HydrationEntry.fromRow).toList(growable: false);
  }

  /// Deletes the entry with [id].
  Future<void> deleteEntry(String id) async {
    await (_database.delete(
      _database.hydrationEntries,
    )..where((entry) => entry.id.equals(id))).go();
  }

  String _generateId() {
    // Stable, unique ID based on current time plus a monotonic counter to
    // avoid collisions when multiple entries are logged in the same
    // millisecond.
    _idCounter++;
    return '${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }
}
