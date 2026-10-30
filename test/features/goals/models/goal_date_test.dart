import 'package:flutter_test/flutter_test.dart';
import 'package:systum/features/goals/models/goal_date.dart';

void main() {
  group('GoalDate', () {
    test('stores calendar components without a time or timezone', () {
      final local = GoalDate.fromDateTime(DateTime(2026, 9, 15, 23, 45));
      final utc = GoalDate.fromDateTime(DateTime.utc(2026, 9, 15, 0, 5));

      expect(local, utc);
      expect(local.toDateTime().year, 2026);
      expect(local.toDateTime().month, 9);
      expect(local.toDateTime().day, 15);
    });

    test('formats canonical calendar components without local conversion', () {
      final date = GoalDate.fromDateTime(DateTime.utc(2026, 1, 2, 23, 59));

      expect(date.toIso8601String(), '2026-01-02');
    });

    test('supports dates before the Unix epoch', () {
      final date = GoalDate.fromDateTime(DateTime(1969, 12, 31, 18));

      expect(date.toIso8601String(), '1969-12-31');
      expect(date.epochDay, -1);
    });
  });
}
