/// Small pieces of state kept on the phone with SharedPreferences:
/// the workout draft, the step tracker's last reading and the wger cache.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import '../domain/step_tracker.dart';

enum LogMode { live, past, edit }

/// A workout being entered, plus the state of the live timer.
class WorkoutDraft {
  const WorkoutDraft({
    required this.workout,
    required this.mode,
    this.accumulatedSeconds = 0,
    this.runningSince,
  });

  final Workout workout;
  final LogMode mode;

  /// Seconds counted before the current run of the timer.
  final int accumulatedSeconds;

  /// When the timer was last started, or null while paused. Stored as a
  /// time, so the timer stays correct if the app is closed and reopened.
  final DateTime? runningSince;

  bool get isRunning => runningSince != null;

  int elapsedSeconds(DateTime now) =>
      accumulatedSeconds +
      (runningSince == null ? 0 : now.difference(runningSince!).inSeconds);

  WorkoutDraft copyWith({Workout? workout, LogMode? mode}) => WorkoutDraft(
        workout: workout ?? this.workout,
        mode: mode ?? this.mode,
        accumulatedSeconds: accumulatedSeconds,
        runningSince: runningSince,
      );

  WorkoutDraft paused(DateTime now) => WorkoutDraft(
        workout: workout,
        mode: mode,
        accumulatedSeconds: elapsedSeconds(now),
      );

  WorkoutDraft resumed(DateTime now) => WorkoutDraft(
        workout: workout,
        mode: mode,
        accumulatedSeconds: accumulatedSeconds,
        runningSince: now,
      );

  Map<String, dynamic> toMap() => {
        'id': workout.id,
        'workout': workout.toMap(),
        'mode': mode.name,
        'accumulatedSeconds': accumulatedSeconds,
        'runningSince': runningSince?.toIso8601String(),
      };

  factory WorkoutDraft.fromMap(Map<String, dynamic> m) => WorkoutDraft(
        workout: Workout.fromMap(
          m['id'] as String,
          Map<String, dynamic>.from(m['workout'] as Map),
        ),
        mode: LogMode.values.byName(m['mode'] as String? ?? 'live'),
        accumulatedSeconds: (m['accumulatedSeconds'] as num?)?.toInt() ?? 0,
        runningSince: DateTime.tryParse(m['runningSince'] as String? ?? ''),
      );
}

class LocalStore {
  LocalStore(this._prefs);
  final SharedPreferences _prefs;

  static String _draftKey(String uid) => 'draft.$uid';
  static String _stepKey(String uid) => 'steps.$uid';
  static String _cacheKey(String key) => 'cache.$key';

  WorkoutDraft? loadDraft(String uid) {
    final raw = _prefs.getString(_draftKey(uid));
    if (raw == null) return null;
    try {
      return WorkoutDraft.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // A damaged draft is dropped rather than crashing.
    }
  }

  Future<void> saveDraft(String uid, WorkoutDraft draft) =>
      _prefs.setString(_draftKey(uid), jsonEncode(draft.toMap()));

  Future<void> clearDraft(String uid) => _prefs.remove(_draftKey(uid));

  StepState? loadStepState(String uid) {
    final raw = _prefs.getString(_stepKey(uid));
    if (raw == null) return null;
    try {
      return StepState.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveStepState(String uid, StepState state) =>
      _prefs.setString(_stepKey(uid), jsonEncode(state.toMap()));

  String? cacheGet(String key) => _prefs.getString(_cacheKey(key));

  Future<void> cachePut(String key, String value) =>
      _prefs.setString(_cacheKey(key), value);

  /// Removes everything stored for [uid]. The wger cache is public data and
  /// is kept.
  Future<void> clearUser(String uid) async {
    await _prefs.remove(_draftKey(uid));
    await _prefs.remove(_stepKey(uid));
  }
}
