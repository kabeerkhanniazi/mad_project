/// Turns raw sensor readings into a daily step total.
///
/// The phone's step counter reports steps since the last restart, not steps
/// today. [StepTracker] remembers the previous reading and adds the
/// difference to today's total. Pure Dart, tested in
/// test/step_tracker_test.dart.
library;

import '../core/dates.dart';
import 'models.dart';

class StepState {
  const StepState({
    required this.date,
    this.steps = 0,
    this.lastRaw,
    this.trackedFrom,
    this.source = StepSource.sensor,
    this.goalNotified = false,
  });

  final String date;
  final int steps;

  /// The previous counter reading, or null when the next reading should only
  /// set a new baseline.
  final int? lastRaw;
  final DateTime? trackedFrom;
  final StepSource source;

  /// True once the goal-reached notification was shown for [date].
  final bool goalNotified;

  StepState copyWith({
    int? steps,
    StepSource? source,
    bool? goalNotified,
  }) =>
      StepState(
        date: date,
        steps: steps ?? this.steps,
        lastRaw: lastRaw,
        trackedFrom: trackedFrom,
        source: source ?? this.source,
        goalNotified: goalNotified ?? this.goalNotified,
      );

  /// Forgets the last reading. Used when tracking stops, so steps taken
  /// while it is off are not added when it starts again.
  StepState withoutBaseline() => StepState(
        date: date,
        steps: steps,
        trackedFrom: trackedFrom,
        source: source,
        goalNotified: goalNotified,
      );

  Map<String, dynamic> toMap() => {
        'date': date,
        'steps': steps,
        'lastRaw': lastRaw,
        'trackedFrom': trackedFrom?.toIso8601String(),
        'source': source.name,
        'goalNotified': goalNotified,
      };

  factory StepState.fromMap(Map<String, dynamic> m) => StepState(
        date: m['date'] as String? ?? '',
        steps: (m['steps'] as num?)?.toInt() ?? 0,
        lastRaw: (m['lastRaw'] as num?)?.toInt(),
        trackedFrom: DateTime.tryParse(m['trackedFrom'] as String? ?? ''),
        source: m['source'] == 'accelerometer'
            ? StepSource.accelerometer
            : StepSource.sensor,
        goalNotified: m['goalNotified'] as bool? ?? false,
      );
}

abstract final class StepTracker {
  /// Applies a counter reading ([raw] = steps since the phone restarted).
  ///
  /// - First reading of a day: becomes the baseline; nothing is added,
  ///   because steps since the previous reading may belong to yesterday.
  /// - Later readings: the difference is added.
  /// - Reading lower than the last one: the phone restarted, so the counter
  ///   began again at zero and the whole reading is new.
  static StepState applyRaw(StepState? state, int raw, DateTime now) {
    final today = dateKey(now);
    if (state == null || state.date != today) {
      return StepState(date: today, lastRaw: raw, trackedFrom: now);
    }
    final last = state.lastRaw;
    final added = last == null ? 0 : (raw >= last ? raw - last : raw);
    return StepState(
      date: today,
      steps: state.steps + added,
      lastRaw: raw,
      trackedFrom: state.trackedFrom ?? now,
      source: StepSource.sensor,
      goalNotified: state.goalNotified,
    );
  }

  /// Adds steps counted by the app itself (accelerometer fallback).
  static StepState addSteps(StepState? state, int count, DateTime now) {
    final today = dateKey(now);
    if (state == null || state.date != today) {
      return StepState(
        date: today,
        steps: count,
        trackedFrom: now,
        source: StepSource.accelerometer,
      );
    }
    return StepState(
      date: today,
      steps: state.steps + count,
      trackedFrom: state.trackedFrom ?? now,
      source: StepSource.accelerometer,
      goalNotified: state.goalNotified,
    );
  }
}
