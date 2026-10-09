const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];
const weekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

DateTime? parseDate(dynamic value) {
  if (value == null || value == false) return null;
  return DateTime.tryParse(value.toString());
}

/// "2026-10-09" -> "9 Oct 2026"
String fmtDate(dynamic value, {bool year = true}) {
  final d = parseDate(value);
  if (d == null) return '-';
  return year ? '${d.day} ${_months[d.month - 1]} ${d.year}' : '${d.day} ${_months[d.month - 1]}';
}

/// UTC "2026-10-09T10:23:03Z" -> local "9 Oct, 15:53"
String fmtDateTime(dynamic value) {
  final d = parseDate(value)?.toLocal();
  if (d == null) return '-';
  return '${d.day} ${_months[d.month - 1]}, ${_two(d.hour)}:${_two(d.minute)}';
}

String fmtMonth(DateTime d) => '${_monthsLong[d.month - 1]} ${d.year}';

String isoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

String _two(int n) => n.toString().padLeft(2, '0');

/// {"amount": 17000.0, "symbol": "₹"} -> "₹17,000"
String fmtMoney(dynamic money) {
  if (money is! Map) return '-';
  final amount = (money['amount'] ?? 0) as num;
  final symbol = (money['symbol'] ?? '').toString();
  return '$symbol${groupThousands(amount)}';
}

String groupThousands(num amount) {
  final negative = amount < 0;
  final rounded = amount.abs();
  final whole = rounded.truncate();
  final decimals = ((rounded - whole) * 100).round();
  final digits = whole.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final text = decimals > 0 ? '$buffer.${decimals.toString().padLeft(2, '0')}' : buffer.toString();
  return negative ? '-$text' : text;
}

String fmtNum(dynamic value) {
  if (value == null) return '-';
  final n = value as num;
  return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String nameOf(dynamic ref) => ref is Map ? (ref['name'] ?? '').toString() : '';
