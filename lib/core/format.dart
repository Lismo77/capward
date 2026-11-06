/// Small display formatters. No `intl` dependency: the app has no currency
/// setting yet, so money is shown as a plain number.
library;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Fri 6 Nov"
String weekdayDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

/// The calendar day of [d], at midnight local time.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "2026-11-06"
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// "Today", "Yesterday", "3 Nov", or "3 Nov 2025" for another year.
String friendlyDate(DateTime d, {required DateTime today}) {
  final day = dateOnly(d);
  final t = dateOnly(today);
  if (day == t) return 'Today';
  if (day == DateTime(t.year, t.month, t.day - 1)) return 'Yesterday';
  final base = '${d.day} ${_months[d.month - 1]}';
  return d.year == t.year ? base : '$base ${d.year}';
}

/// [friendlyDate] for the middle of a sentence: "today", "yesterday",
/// "3 Nov".
String inlineDate(DateTime d, {required DateTime today}) {
  final s = friendlyDate(d, today: today);
  return s.contains(' ') ? s : s.toLowerCase();
}

/// 1240 -> "12.40"
String formatCents(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${_two(abs % 100)}';
}

String _two(int n) => n.toString().padLeft(2, '0');
