/// Calendar-day helpers.
///
/// A day is identified by a `yyyy-MM-dd` string ("date key") in the phone's
/// timezone. Keys sort correctly as plain strings.
library;

String dateKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

DateTime parseDateKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Moves a date key by [days]. Uses calendar arithmetic, so daylight-saving
/// changes cannot skip or repeat a day.
String addDays(String key, int days) {
  final d = parseDateKey(key);
  return dateKey(DateTime(d.year, d.month, d.day + days));
}

/// 1 = Monday ... 7 = Sunday.
int weekdayOf(String key) => parseDateKey(key).weekday;

/// The Monday on or before [key].
String weekStartOf(String key) => addDays(key, 1 - weekdayOf(key));

/// The seven date keys of the week that starts on [weekStart].
List<String> weekDays(String weekStart) =>
    [for (var i = 0; i < 7; i++) addDays(weekStart, i)];

/// Whole days from [from] to [to]; negative when [to] is earlier.
int daysBetween(String from, String to) {
  final a = parseDateKey(from);
  final b = parseDateKey(to);
  return DateTime.utc(b.year, b.month, b.day)
      .difference(DateTime.utc(a.year, a.month, a.day))
      .inDays;
}

const weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
