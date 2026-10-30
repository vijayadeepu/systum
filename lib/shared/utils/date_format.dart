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
