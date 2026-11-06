import 'package:flutter_test/flutter_test.dart';
import 'package:systum/features/reminders/notifications/reminder_notification_ids.dart';

void main() {
  group('reminderNotificationId', () {
    test('is stable for the same persisted reminder identity', () {
      expect(
        reminderNotificationId('reminder-1'),
        reminderNotificationId('reminder-1'),
      );
    });

    test('differs for different reminder identities', () {
      expect(
        reminderNotificationId('reminder-1'),
        isNot(reminderNotificationId('reminder-2')),
      );
    });

    test('is a deterministic positive signed int in range', () {
      final id = reminderNotificationId('reminder-1');
      expect(id, greaterThan(0));
      expect(id, lessThanOrEqualTo(0x7fffffff));
    });
  });
}
