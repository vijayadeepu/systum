/// The Android notification ID reserved for one persisted reminder.
///
/// The value is derived from the reminder's stable persisted identity using
/// FNV-1a. Unlike [Object.hashCode], this is deterministic across isolates,
/// app restarts and Dart releases, so scheduling, rescheduling and
/// cancellation always address the same Android notification/job.
int reminderNotificationId(String reminderId) {
  var hash = 0x811c9dc5;
  for (final codeUnit in reminderId.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }

  // Android notification IDs are signed 32-bit values. Keep the value
  // positive and non-zero so it also stays usable for foreground APIs.
  final positive = hash & 0x7fffffff;
  return positive == 0 ? 1 : positive;
}
