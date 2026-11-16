/// Weekly totals and the comparison with the week before.
/// Calculated from saved records only; there is no AI involved.
library;

import '../core/dates.dart';
import 'models.dart';

class WeeklySummary {
  const WeeklySummary({
    required this.weekStart,
    required this.workouts,
    required this.workoutTarget,
    required this.minutes,
    required this.steps,
    required this.trackedDays,
    required this.goalMetDays,
    required this.habitsDone,
    required this.habitsDue,
  });

  final String weekStart;
  final int workouts;
  final int workoutTarget;
  final int minutes;

  /// Steps recorded on tracked days. Untracked days add nothing.
  final int steps;
  final int trackedDays;
  final int goalMetDays;
  final int habitsDone;
  final int habitsDue;

  String get weekEnd => addDays(weekStart, 6);
  bool get targetMet => workoutTarget > 0 && workouts >= workoutTarget;

  /// Null when no habit was due, so the screen never shows a made-up 0%.
  int? get habitPercent =>
      habitsDue == 0 ? null : (habitsDone * 100 / habitsDue).round();

  int? get averageSteps => trackedDays == 0 ? null : steps ~/ trackedDays;

  bool get isEmpty => workouts == 0 && trackedDays == 0 && habitsDue == 0;
}

/// Builds the summary for the week starting on [weekStart] (a Monday).
///
/// When [today] falls inside the week, habit entries after today are not yet
/// due and are left out.
WeeklySummary buildWeeklySummary({
  required String weekStart,
  required Iterable<Workout> workouts,
  required Iterable<Habit> habits,
  required Iterable<HabitCompletion> completions,
  required Iterable<StepDay> stepDays,
  required int workoutTarget,
  required String today,
}) =>
    summariseDays(
      days: weekDays(weekStart),
      workouts: workouts,
      habits: habits,
      completions: completions,
      stepDays: stepDays,
      workoutTarget: workoutTarget,
      today: today,
    );

/// The same totals for any run of consecutive [days], such as a month.
WeeklySummary summariseDays({
  required List<String> days,
  required Iterable<Workout> workouts,
  required Iterable<Habit> habits,
  required Iterable<HabitCompletion> completions,
  required Iterable<StepDay> stepDays,
  required int workoutTarget,
  required String today,
}) {
  final inPeriod = days.toSet();

  final done =
      workouts.where((w) => inPeriod.contains(w.date) && w.isComplete);
  final completed = {for (final c in completions) c.id};

  var habitsDue = 0;
  var habitsDone = 0;
  for (final day in days) {
    if (day.compareTo(today) > 0) break;
    for (final h in habits) {
      if (!h.isScheduledOn(day)) continue;
      habitsDue++;
      if (completed.contains(HabitCompletion(habitId: h.id, date: day).id)) {
        habitsDone++;
      }
    }
  }

  final tracked = stepDays.where((d) => inPeriod.contains(d.date)).toList();

  return WeeklySummary(
    weekStart: days.first,
    workouts: done.length,
    workoutTarget: workoutTarget,
    minutes: done.fold(0, (n, w) => n + w.minutes),
    steps: tracked.fold(0, (n, d) => n + d.steps),
    trackedDays: tracked.length,
    goalMetDays: tracked.where((d) => d.goalMet).length,
    habitsDone: habitsDone,
    habitsDue: habitsDue,
  );
}

const comparisonUnavailable = 'Comparison not available yet.';

/// Plain sentences comparing [current] with [previous].
List<String> compareWeeks(WeeklySummary current, WeeklySummary? previous) {
  if (previous == null || previous.isEmpty) return [comparisonUnavailable];

  final lines = <String>[];

  final w = current.workouts - previous.workouts;
  if (w == 0) {
    lines.add('Same number of workouts as the week before.');
  } else {
    final n = w.abs();
    final noun = n == 1 ? 'workout' : 'workouts';
    lines.add(w > 0
        ? '$n more $noun completed.'
        : '$n fewer $noun completed.');
  }

  final hc = current.habitPercent;
  final hp = previous.habitPercent;
  if (hc != null && hp != null) {
    final diff = hc - hp;
    if (diff == 0) {
      lines.add('Habit completion stayed at $hc%.');
    } else {
      final n = diff.abs();
      final unit = n == 1 ? 'percentage point' : 'percentage points';
      lines.add(diff > 0
          ? 'Habit completion increased by $n $unit.'
          : 'Habit completion decreased by $n $unit.');
    }
  }

  final sc = current.averageSteps;
  final sp = previous.averageSteps;
  if (sc != null && sp != null) {
    final diff = sc - sp;
    if (diff == 0) {
      lines.add('Average steps per tracked day stayed the same.');
    } else {
      lines.add(diff > 0
          ? 'Average steps per tracked day went up by ${diff.abs()}.'
          : 'Average steps per tracked day went down by ${diff.abs()}.');
    }
  }

  return lines;
}
