import 'day_boundary.dart';

/// Consecutive logical days with at least one meal, ending today — or ending
/// yesterday when today has nothing logged yet (the day isn't over).
int loggingStreak(Set<DateTime> loggedDays, DateTime today) {
  final days = loggedDays.map(dateOnly).toSet();
  var day = dateOnly(today);
  if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}
