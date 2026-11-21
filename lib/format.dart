// Formatting helpers in Bahasa Melayu. Kept local (no intl package) so the
// app needs no locale data to start.

const monthsMs = [
  'Januari', 'Februari', 'Mac', 'April', 'Mei', 'Jun',
  'Julai', 'Ogos', 'September', 'Oktober', 'November', 'Disember',
];
const daysMs = ['Isnin', 'Selasa', 'Rabu', 'Khamis', 'Jumaat', 'Sabtu', 'Ahad'];

String two(int n) => n.toString().padLeft(2, '0');

/// yyyy-mm-dd
String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// yyyy-mm
String ym(DateTime d) => '${d.year}-${two(d.month)}';

String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

DateTime parseYmd(String s) => DateTime.parse(s);

String fmtDate(String? s) {
  if (s == null || s.isEmpty) return '—';
  final d = parseYmd(s);
  return '${d.day} ${monthsMs[d.month - 1].substring(0, 3)} ${d.year}';
}

String fmtShort(String? s) {
  if (s == null || s.isEmpty) return '—';
  final d = parseYmd(s);
  return '${d.day} ${monthsMs[d.month - 1].substring(0, 3)}';
}

String longDate(DateTime d) =>
    '${daysMs[d.weekday - 1]}, ${d.day} ${monthsMs[d.month - 1]} ${d.year}';

String monthLabel(String ymKey) {
  final p = ymKey.split('-');
  return '${monthsMs[int.parse(p[1]) - 1]} ${p[0]}';
}

String addMonths(String ymKey, int n) {
  final p = ymKey.split('-');
  final d = DateTime(int.parse(p[0]), int.parse(p[1]) + n, 1);
  return ym(d);
}

/// RM 1,234.50
String rm(num v) {
  final neg = v < 0;
  final fixed = v.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final buf = StringBuffer();
  final s = parts[0];
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${neg ? '−' : ''}RM ${buf.toString()}.${parts[1]}';
}

String daysLabel(double d) =>
    d == d.roundToDouble() ? '${d.toInt()} hari' : '${d.toStringAsFixed(1)} hari';

double hoursBetween(String? a, String? b) {
  if (a == null || b == null) return 0;
  int m(String t) {
    final p = t.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  final diff = (m(b) - m(a)) / 60;
  return diff < 0 ? 0 : diff;
}

String ago(DateTime t) {
  final d = DateTime.now().difference(t).inDays;
  if (d <= 0) return 'hari ini';
  if (d == 1) return 'semalam';
  return '$d hari lalu';
}

String tenure(DateTime join) {
  final now = DateTime.now();
  var months = (now.year - join.year) * 12 + now.month - join.month;
  if (months < 0) return 'Belum mula';
  final y = months ~/ 12;
  months %= 12;
  final parts = [if (y > 0) '$y thn', if (months > 0) '$months bln'];
  return parts.isEmpty ? 'Baru' : parts.join(' ');
}

/// 485 -> "8j 05m", 42 -> "42m".
String fmtMinutes(int m) {
  if (m < 60) return '${m}m';
  return '${m ~/ 60}j ${two(m % 60)}m';
}
