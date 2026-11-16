import 'package:fithabit/domain/models.dart';
import 'package:fithabit/domain/weekly_summary.dart';
import 'package:flutter_test/flutter_test.dart';

Workout strength(String id, String date, {int minutes = 30, bool done = true}) =>
    Workout(
      id: id,
      date: date,
      startedAt: DateTime.parse('${date}T10:00:00'),
      durationSeconds: minutes * 60,
      exercises: [
        WorkoutExercise(name: 'Squat', sets: [ExerciseSet(reps: 10, done: done)]),
      ],
    );

void main() {
  const week = '2026-11-09'; // Monday
  const today = '2026-11-18'; // the Wednesday after

  const read = Habit(id: 'read', name: 'Read', startDate: '2026-11-01');
  const stretch =
      Habit(id: 'stretch', name: 'Stretch', weekdays: {1, 3, 5}, startDate: '2026-11-01');

  WeeklySummary build({
    String weekStart = week,
    List<Workout> workouts = const [],
    List<Habit> habits = const [],
    List<HabitCompletion> completions = const [],
    List<StepDay> stepDays = const [],
    String now = today,
  }) =>
      buildWeeklySummary(
        weekStart: weekStart,
        workouts: workouts,
        habits: habits,
        completions: completions,
        stepDays: stepDays,
        workoutTarget: 3,
        today: now,
      );

  test('workout rules: strength needs a done set, timed needs a duration', () {
    expect(strength('a', week).isComplete, isTrue);
    expect(strength('a', week, done: false).isComplete, isFalse);
    final walk = Workout(
        id: 'w',
        type: WorkoutType.timed,
        date: week,
        startedAt: DateTime(2026, 11, 9));
    expect(walk.isComplete, isFalse);
    expect(walk.copyWith(durationSeconds: 60).isComplete, isTrue);
  });

  test('counts only complete workouts inside the week', () {
    final s = build(workouts: [
      strength('a', '2026-11-09', minutes: 40),
      strength('b', '2026-11-15', minutes: 35),
      strength('c', '2026-11-16'), // next week
      strength('d', '2026-11-10', done: false), // nothing ticked
    ]);
    expect(s.workouts, 2);
    expect(s.minutes, 75);
    expect(s.targetMet, isFalse);
  });

  test('habit entries: due follows the schedule', () {
    final s = build(
      habits: const [read, stretch],
      completions: const [
        HabitCompletion(habitId: 'read', date: '2026-11-09'),
        HabitCompletion(habitId: 'read', date: '2026-11-10'),
        HabitCompletion(habitId: 'stretch', date: '2026-11-09'),
        // Ticked on a day it was not scheduled: not counted.
        HabitCompletion(habitId: 'stretch', date: '2026-11-10'),
      ],
    );
    expect(s.habitsDue, 7 + 3);
    expect(s.habitsDone, 3);
    expect(s.habitPercent, 30);
  });

  test('in the current week, days after today are not due yet', () {
    final s = build(weekStart: '2026-11-16', habits: const [read]);
    expect(s.habitsDue, 3); // Mon, Tue, Wed
  });

  test('an archived habit stops being due from its archive date', () {
    final archived = read.copyWith(archivedDate: '2026-11-12');
    expect(build(habits: [archived]).habitsDue, 3); // 9th, 10th, 11th
  });

  test('untracked step days add nothing and are not counted as tracked', () {
    final s = build(stepDays: const [
      StepDay(date: '2026-11-09', steps: 9000, goal: 8000),
      StepDay(date: '2026-11-11', steps: 4000, goal: 8000),
    ]);
    expect(s.steps, 13000);
    expect(s.trackedDays, 2);
    expect(s.goalMetDays, 1);
    expect(s.averageSteps, 6500);
  });

  test('a week with no habits has no percentage, not 0%', () {
    expect(build().habitPercent, isNull);
    expect(build().isEmpty, isTrue);
  });

  group('compareWeeks', () {
    test('no previous week', () {
      expect(compareWeeks(build(), null), [comparisonUnavailable]);
      expect(compareWeeks(build(), build()), [comparisonUnavailable]);
    });

    test('describes changes in plain sentences', () {
      final previous = build(
        weekStart: '2026-11-02',
        workouts: [strength('a', '2026-11-03')],
        habits: const [read],
        completions: const [
          HabitCompletion(habitId: 'read', date: '2026-11-02'),
          HabitCompletion(habitId: 'read', date: '2026-11-03'),
        ],
        stepDays: const [StepDay(date: '2026-11-02', steps: 5000, goal: 8000)],
      );
      final current = build(
        workouts: [strength('b', '2026-11-09'), strength('c', '2026-11-10')],
        habits: const [read],
        completions: const [
          HabitCompletion(habitId: 'read', date: '2026-11-09'),
          HabitCompletion(habitId: 'read', date: '2026-11-10'),
          HabitCompletion(habitId: 'read', date: '2026-11-11'),
        ],
        stepDays: const [StepDay(date: '2026-11-09', steps: 6200, goal: 8000)],
      );
      expect(compareWeeks(current, previous), [
        '1 more workout completed.',
        'Habit completion increased by 14 percentage points.',
        'Average steps per tracked day went up by 1200.',
      ]);
    });

    test('steps are left out when a week was not tracked', () {
      final previous = build(
          weekStart: '2026-11-02', workouts: [strength('a', '2026-11-03')]);
      final current = build(workouts: [strength('b', '2026-11-09')]);
      expect(compareWeeks(current, previous),
          ['Same number of workouts as the week before.']);
    });
  });
}
