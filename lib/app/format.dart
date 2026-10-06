import 'package:intl/intl.dart';

final _whole = NumberFormat.decimalPattern();

/// "1,240"
String fmtKcal(num v) => _whole.format(v.isFinite ? v.round() : 0);

/// "62 g"
String fmtGrams(num v) => '${v.isFinite ? v.round() : 0} g';

/// "1", "1.5", "0.25"
String fmtAmount(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  final s = v.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

/// "Today", "Yesterday", or "Tuesday, Oct 6".
String dayLabel(DateTime day, DateTime today) {
  final d = DateTime(day.year, day.month, day.day);
  final t = DateTime(today.year, today.month, today.day);
  final diff = t.difference(d).inHours.round() ~/ 24;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEEE, MMM d').format(d);
}

String longDate(DateTime d) => DateFormat('EEEE, MMMM d').format(d);
String shortDate(DateTime d) => DateFormat('MMM d').format(d);
String timeLabel(DateTime t) => DateFormat.jm().format(t);
String dateTimeLabel(DateTime t) => '${DateFormat('EEE, MMM d').format(t)} · ${timeLabel(t)}';
String weekdayInitial(DateTime d) => DateFormat('EEEEE').format(d);
