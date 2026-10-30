import 'package:drift/drift.dart';

/// A calendar date stored as days since 1970-01-01, independent of timezone.
final class GoalDate {
  const GoalDate(this.epochDay);

  factory GoalDate.fromDateTime(DateTime date) {
    final utcDay = DateTime.utc(date.year, date.month, date.day);
    return GoalDate(utcDay.difference(_unixEpoch).inDays);
  }

  final int epochDay;

  int get year => _asUtcDate.year;
  int get month => _asUtcDate.month;
  int get day => _asUtcDate.day;

  DateTime get _asUtcDate => _unixEpoch.add(Duration(days: epochDay));

  /// Produces a local date for APIs such as Flutter's date picker.
  DateTime toDateTime() => DateTime(year, month, day);

  String toIso8601String() =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GoalDate && epochDay == other.epochDay;

  @override
  int get hashCode => epochDay.hashCode;

  @override
  String toString() => 'GoalDate($epochDay)';
}

class GoalDateConverter extends TypeConverter<GoalDate, int> {
  const GoalDateConverter();

  @override
  GoalDate fromSql(int fromDb) => GoalDate(fromDb);

  @override
  int toSql(GoalDate value) => value.epochDay;
}

final DateTime _unixEpoch = DateTime.utc(1970, 1, 1);
