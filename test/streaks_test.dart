import 'package:fithabit/core/dates.dart';
import 'package:fithabit/domain/models.dart';
import 'package:fithabit/domain/streaks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-11-18 is a Wednesday.
  const today = '2026-11-18';

  group('dates', () {
    test('week starts on Monday', () {
      expect(weekdayOf(today), 3);
      expect(weekStartOf(today), '2026-11-16');
      expect(weekStartOf('2026-11-16'), '2026-11-16');
      expect(weekStartOf('2026-11-22'), '2026-11-16');
    });

    test('addDays crosses months and years', () {
      expect(addDays('2026-11-30', 1), '2026-12-01');
      expect(addDays('2027-01-01', -1), '2026-12-31');
      expect(daysBetween('2026-11-16', today), 2);
    });
  });

  group('habitStreak', () {
    const daily = Habit(id: 'h', name: 'Read', startDate: '2026-11-01');
    const monWedFri =
        Habit(id: 'h', name: 'Stretch', weekdays: {1, 3, 5}, startDate: '2026-11-01');

    test('counts consecutive completed days including today', () {
      expect(
          habitStreak(daily, {'2026-11-16', '2026-11-17', today}, today), 3);
    });

    test('today not done yet does not break the streak', () {
      expect(habitStreak(daily, {'2026-11-16', '2026-11-17'}, today), 2);
    });

    test('a missed scheduled day resets the streak', () {
      // The 16th was missed.
      expect(habitStreak(daily, {'2026-11-15', '2026-11-17', today}, today), 2);
    });

    test('unscheduled days are neutral', () {
      // Mon 16, Fri 13 and Wed 11 done; Tue, Thu and the weekend are rest days.
      expect(
          habitStreak(
              monWedFri, {'2026-11-11', '2026-11-13', '2026-11-16', today}, today),
          4);
    });

    test('no completions gives zero', () {
      expect(habitStreak(daily, {}, today), 0);
    });

    test('days before the habit started are ignored', () {
      const fresh = Habit(id: 'h', name: 'New', startDate: today);
      expect(habitStreak(fresh, {today}, today), 1);
    });

    test('removing a completion recalculates the streak', () {
      final done = {'2026-11-16', '2026-11-17', today};
      expect(habitStreak(daily, done, today), 3);
      done.remove('2026-11-17');
      expect(habitStreak(daily, done, today), 1);
    });
  });

  group('stepStreak', () {
    StepDay day(String date, int steps, {int goal = 8000}) =>
        StepDay(date: date, steps: steps, goal: goal);

    test('today is pending until the goal is reached', () {
      final days = {
        '2026-11-16': day('2026-11-16', 9000),
        '2026-11-17': day('2026-11-17', 8000),
        today: day(today, 1200),
      };
      expect(stepStreak(days, today), 2);
    });

    test('today counts once the goal is reached', () {
      final days = {
        '2026-11-17': day('2026-11-17', 8500),
        today: day(today, 8001),
      };
      expect(stepStreak(days, today), 2);
    });

    test('an untracked day ends the streak', () {
      final days = {
        '2026-11-15': day('2026-11-15', 9000),
        // The 16th has no record at all.
        '2026-11-17': day('2026-11-17', 9000),
      };
      expect(stepStreak(days, today), 1);
    });

    test('each day is judged against its own goal', () {
      final days = {
        '2026-11-16': day('2026-11-16', 5000, goal: 5000),
        '2026-11-17': day('2026-11-17', 7000, goal: 8000),
      };
      expect(stepStreak(days, today), 0);
      expect(stepStreak(days, '2026-11-17'), 1);
    });
  });
}
