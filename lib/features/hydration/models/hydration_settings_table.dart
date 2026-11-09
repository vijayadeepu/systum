import 'package:drift/drift.dart';

/// Hydration settings table: stores user-configurable hydration settings.
@DataClassName('HydrationSettingsRow')
class HydrationSettingsTable extends Table {
  TextColumn get id => text()();

  /// Whether hydration tracking is enabled (shows hydration card on home).
  BoolColumn get hydrationEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Daily hydration target in milliliters. Defaults to 2500 ml (2.5 L).
  IntColumn get dailyTargetMl => integer().withDefault(const Constant(2500))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
