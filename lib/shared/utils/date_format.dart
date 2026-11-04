/// Formats a date as an unambiguous local ISO-like calendar date.
///
/// Only the local calendar day is shown. Callers that persist dates should
/// still store the full [DateTime]; presentation should not decide semantics.
String formatDate(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

/// Formats the calendar components of [date] without converting timezone.
///
/// Use this for date-only values stored as UTC midnight so the displayed date
/// cannot shift when the device timezone changes.
String formatDateOnly(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
