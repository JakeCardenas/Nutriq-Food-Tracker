/// "Logical day" helpers so people who eat after midnight (late nights,
/// night shifts) can choose when their day rolls over.
///
/// Field arithmetic (rather than subtracting a Duration) keeps this correct
/// across daylight-saving changes.
library;

/// The calendar date a moment counts toward when the day starts at
/// [startHour] (0 = midnight, 4 = 4 AM, …).
DateTime logicalDay(DateTime t, int startHour) {
  final shifted = DateTime(t.year, t.month, t.day, t.hour - startHour, t.minute);
  return DateTime(shifted.year, shifted.month, shifted.day);
}

/// The half-open range `[start, end)` covered by logical [day].
({DateTime start, DateTime end}) dayRange(DateTime day, int startHour) => (
  start: DateTime(day.year, day.month, day.day, startHour),
  end: DateTime(day.year, day.month, day.day + 1, startHour),
);

DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);
