import 'package:drift/drift.dart';

/// Hydration entries table: records each water intake event with timestamp
/// and amount in milliliters.
@DataClassName('HydrationEntryRow')
class HydrationEntries extends Table {
  TextColumn get id => text()();

  /// Amount consumed in milliliters.
  IntColumn get amountMs => integer()();

  /// Timestamp when the intake was logged (UTC epoch milliseconds).
  IntColumn get loggedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
