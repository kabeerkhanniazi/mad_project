import 'dart:math' as math;

import 'package:fithabit/domain/models.dart';
import 'package:fithabit/domain/step_detector.dart';
import 'package:fithabit/domain/step_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final morning = DateTime(2026, 11, 18, 9);
  final noon = DateTime(2026, 11, 18, 12);
  final evening = DateTime(2026, 11, 18, 19);
  final nextDay = DateTime(2026, 11, 19, 8);

  group('StepTracker.applyRaw', () {
    test('the first reading sets a baseline and adds nothing', () {
      final s = StepTracker.applyRaw(null, 52000, morning);
      expect(s.steps, 0);
      expect(s.lastRaw, 52000);
      expect(s.date, '2026-11-18');
      expect(s.trackedFrom, morning);
    });

    test('later readings add the difference', () {
      var s = StepTracker.applyRaw(null, 52000, morning);
      s = StepTracker.applyRaw(s, 52300, noon);
      s = StepTracker.applyRaw(s, 53100, evening);
      expect(s.steps, 1100);
      expect(s.trackedFrom, morning);
    });

    test('steps taken while the app was closed are added on reopening', () {
      // The state is stored; the next reading arrives hours later.
      final stored = StepState.fromMap(
          StepTracker.applyRaw(null, 100, morning).toMap());
      expect(StepTracker.applyRaw(stored, 4100, evening).steps, 4000);
    });

    test('a phone restart resets the counter without losing the total', () {
      var s = StepTracker.applyRaw(null, 52000, morning);
      s = StepTracker.applyRaw(s, 53000, noon);
      // After the restart the sensor starts again from zero.
      s = StepTracker.applyRaw(s, 250, evening);
      expect(s.steps, 1250);
    });

    test('a new day starts from zero with a new baseline', () {
      var s = StepTracker.applyRaw(null, 52000, morning);
      s = StepTracker.applyRaw(s, 58000, evening);
      s = StepTracker.applyRaw(s, 59500, nextDay);
      expect(s.date, '2026-11-19');
      // Steps since last evening may belong to yesterday, so none are added.
      expect(s.steps, 0);
      expect(s.goalNotified, isFalse);
      expect(StepTracker.applyRaw(s, 59800, nextDay).steps, 300);
    });

    test('turning tracking off drops the baseline', () {
      var s = StepTracker.applyRaw(null, 1000, morning);
      s = StepTracker.applyRaw(s, 1500, noon).withoutBaseline();
      // 2,000 steps were taken while tracking was off.
      s = StepTracker.applyRaw(s, 3500, evening);
      expect(s.steps, 500);
      expect(StepTracker.applyRaw(s, 3600, evening).steps, 600);
    });

    test('goalNotified survives further readings on the same day', () {
      var s = StepTracker.applyRaw(null, 0, morning).copyWith(goalNotified: true);
      s = StepTracker.applyRaw(s, 10, noon);
      expect(s.goalNotified, isTrue);
    });
  });

  test('addSteps counts app-detected steps and marks the source', () {
    var s = StepTracker.addSteps(null, 1, morning);
    s = StepTracker.addSteps(s, 1, noon);
    expect(s.steps, 2);
    expect(s.source, StepSource.accelerometer);
    expect(StepTracker.addSteps(s, 1, nextDay).steps, 1);
  });

  group('StepDetector', () {
    /// Feeds [seconds] of samples at 50 Hz. Walking is modelled as gravity
    /// plus a bounce of [amplitude] m/s² at [stepsPerSecond].
    int count(double seconds, {double amplitude = 0, double stepsPerSecond = 2}) {
      final detector = StepDetector();
      var steps = 0;
      for (var i = 0; i < seconds * 50; i++) {
        final t = i / 50;
        final z =
            9.81 + amplitude * math.sin(2 * math.pi * stepsPerSecond * t);
        if (detector.addSample(0.2, 0.1, z, (t * 1000).round())) steps++;
      }
      return steps;
    }

    test('a phone lying still counts nothing', () {
      expect(count(30), 0);
    });

    test('small vibration counts nothing', () {
      expect(count(30, amplitude: 0.4, stepsPerSecond: 9), 0);
    });

    test('walking at two steps a second is counted closely', () {
      expect(count(30, amplitude: 3), inInclusiveRange(56, 61));
    });

    test('fast shaking is limited by the minimum step interval', () {
      // 10 peaks a second cannot all be steps.
      expect(count(10, amplitude: 4, stepsPerSecond: 10), lessThanOrEqualTo(36));
    });
  });
}
