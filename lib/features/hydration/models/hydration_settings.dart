import '../../../core/database/database.dart';

class HydrationSettings {
  const HydrationSettings({
    required this.id,
    required this.hydrationEnabled,
    required this.dailyTargetMl,
  });

  factory HydrationSettings.fromRow(HydrationSettingsRow row) {
    return HydrationSettings(
      id: row.id,
      hydrationEnabled: row.hydrationEnabled,
      dailyTargetMl: row.dailyTargetMl,
    );
  }

  HydrationSettingsRow toCompanion() {
    return HydrationSettingsRow(
      id: id,
      hydrationEnabled: hydrationEnabled,
      dailyTargetMl: dailyTargetMl,
    );
  }

  final String id;
  final bool hydrationEnabled;
  final int dailyTargetMl;

  HydrationSettings copyWith({bool? hydrationEnabled, int? dailyTargetMl}) {
    return HydrationSettings(
      id: id,
      hydrationEnabled: hydrationEnabled ?? this.hydrationEnabled,
      dailyTargetMl: dailyTargetMl ?? this.dailyTargetMl,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HydrationSettings &&
            hydrationEnabled == other.hydrationEnabled &&
            dailyTargetMl == other.dailyTargetMl;
  }

  @override
  int get hashCode => Object.hash(hydrationEnabled, dailyTargetMl);
}
