/// Formats an ISO8601 timestamp string (as saved by DateTime.now().toIso8601String())
/// into a readable local date + time string, e.g. "31 Jul 2026, 2:23 PM".
String formatDateTime(String isoString) {
  final dt = DateTime.parse(isoString).toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final day = dt.day.toString().padLeft(2, '0');
  final month = months[dt.month - 1];
  final year = dt.year;
  final hour24 = dt.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = hour24 < 12 ? 'AM' : 'PM';
  return '$day $month $year, $hour12:$minute $ampm';
}
