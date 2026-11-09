import '../../../core/database/database.dart';

/// A single hydration entry recording water intake.
class HydrationEntry {
  const HydrationEntry({
    required this.id,
    required this.amountMs,
    required this.loggedAtMs,
  });

  factory HydrationEntry.fromRow(HydrationEntryRow row) {
    return HydrationEntry(
      id: row.id,
      amountMs: row.amountMs,
      loggedAtMs: row.loggedAtMs,
    );
  }

  HydrationEntryRow toCompanion() {
    return HydrationEntryRow(
      id: id,
      amountMs: amountMs,
      loggedAtMs: loggedAtMs,
    );
  }

  final String id;
  final int amountMs;
  final int loggedAtMs;

  /// Amount in liters.
  double get liters => amountMs / 1000.0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HydrationEntry &&
            id == other.id &&
            amountMs == other.amountMs &&
            loggedAtMs == other.loggedAtMs;
  }

  @override
  int get hashCode => Object.hash(id, amountMs, loggedAtMs);
}
