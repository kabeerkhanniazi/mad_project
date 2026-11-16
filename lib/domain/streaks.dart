/// Streak rules. Pure functions, unit tested in test/streaks_test.dart.
library;

import '../core/dates.dart';
import 'models.dart';

/// Consecutive scheduled days on which [habit] was completed, counting back
/// from [today].
///
/// - A missed scheduled day ends the streak.
/// - Unscheduled days are skipped.
/// - Today does not end the streak while it is still open.
int habitStreak(Habit habit, Set<String> doneDates, String today) {
  var streak = 0;
  var day = today;
  // Ten years is far beyond any real streak and guards against bad data.
  for (var i = 0; i < 3660; i++) {
    if (day.compareTo(habit.startDate) < 0) break;
    if (habit.isScheduledOn(day)) {
      if (doneDates.contains(day)) {
        streak++;
      } else if (day != today) {
        break;
      }
    }
    day = addDays(day, -1);
  }
  return streak;
}

/// Consecutive calendar days on which the step goal was reached.
///
/// Today counts once the goal is reached and is otherwise pending. A day with
/// no record ends the streak, because an untracked day is not an achievement.
int stepStreak(Map<String, StepDay> days, String today) {
  var streak = 0;
  var day = today;
  if (days[day]?.goalMet ?? false) streak++;
  day = addDays(day, -1);
  while (days[day]?.goalMet ?? false) {
    streak++;
    day = addDays(day, -1);
  }
  return streak;
}

/// Dates on which [habitId] was completed.
Set<String> doneDatesFor(String habitId, Iterable<HabitCompletion> all) =>
    {for (final c in all) if (c.habitId == habitId) c.date};
