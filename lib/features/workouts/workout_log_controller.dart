/// State of the workout being entered on S04.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../data/local_store.dart';
import '../../domain/models.dart';
import '../../providers.dart';

class WorkoutLogController extends Notifier<WorkoutDraft?> {
  /// True when [open] found a saved draft and continued it.
  bool restoredDraft = false;

  /// True once an existing workout has been changed and not yet saved.
  bool hasUnsavedEdits = false;

  @override
  WorkoutDraft? build() => null;

  DateTime get _now => ref.read(clockProvider)();
  String? get _uid => ref.read(uidProvider);
  LocalStore get _store => ref.read(localStoreProvider);

  /// Prepares the draft for the screen: an existing workout to edit, the
  /// saved draft if there is one, or a new workout.
  void open({String? mode, String? workoutId}) {
    final uid = _uid;
    if (uid == null) return;
    restoredDraft = false;
    hasUnsavedEdits = false;

    if (workoutId != null) {
      final workouts = ref.read(workoutsProvider).value ?? const [];
      for (final w in workouts) {
        if (w.id == workoutId) {
          state = WorkoutDraft(workout: w, mode: LogMode.edit);
          return;
        }
      }
      state = null;
      return;
    }

    final saved = _store.loadDraft(uid);
    if (saved != null) {
      restoredDraft = true;
      state = saved;
      return;
    }

    final now = _now;
    final live = mode != 'past';
    _set(WorkoutDraft(
      workout: Workout(
        // The ID is fixed now, so saving twice writes the same document.
        id: ref.read(backendProvider).workouts.newId(uid),
        date: dateKey(now),
        startedAt: now,
      ),
      mode: live ? LogMode.live : LogMode.past,
      runningSince: live ? now : null,
    ));
  }

  void _set(WorkoutDraft draft) {
    state = draft;
    final uid = _uid;
    if (uid == null) return;
    if (draft.mode == LogMode.edit) {
      hasUnsavedEdits = true;
    } else {
      // Saved on every change, so the draft survives closing the app.
      unawaited(_store.saveDraft(uid, draft));
    }
  }

  void _setWorkout(Workout Function(Workout w) change) {
    final draft = state;
    if (draft != null) _set(draft.copyWith(workout: change(draft.workout)));
  }

  // ------------------------------------------------------------ fields

  void setTitle(String title) => _setWorkout((w) => w.copyWith(title: title));

  void setType(WorkoutType type) => _setWorkout((w) => w.copyWith(type: type));

  /// Switches between a live session and a past workout.
  void setMode(LogMode mode) {
    final draft = state;
    if (draft == null || draft.mode == LogMode.edit || draft.mode == mode) {
      return;
    }
    final now = _now;
    if (mode == LogMode.past) {
      final paused = draft.paused(now);
      _set(paused.copyWith(
        mode: LogMode.past,
        workout: paused.workout
            .copyWith(durationSeconds: paused.accumulatedSeconds),
      ));
    } else {
      _set(WorkoutDraft(
        workout: draft.workout.copyWith(date: dateKey(now), startedAt: now),
        mode: LogMode.live,
        runningSince: now,
      ));
    }
  }

  void pause() {
    final draft = state;
    if (draft != null && draft.isRunning) _set(draft.paused(_now));
  }

  void resume() {
    final draft = state;
    if (draft != null && !draft.isRunning) _set(draft.resumed(_now));
  }

  /// Sets the day and start time of a past workout.
  void setStart(DateTime start) => _setWorkout(
      (w) => w.copyWith(date: dateKey(start), startedAt: start));

  void setDurationMinutes(int minutes) =>
      _setWorkout((w) => w.copyWith(durationSeconds: minutes * 60));

  // ------------------------------------------------------------ exercises

  void addExercise(WorkoutExercise exercise) =>
      _setWorkout((w) => w.copyWith(exercises: [...w.exercises, exercise]));

  void removeExercise(int index) => _setWorkout(
      (w) => w.copyWith(exercises: [...w.exercises]..removeAt(index)));

  void _setSets(int exercise,
          List<ExerciseSet> Function(List<ExerciseSet> sets) change) =>
      _setWorkout((w) => w.copyWith(exercises: [
            for (var i = 0; i < w.exercises.length; i++)
              i == exercise
                  ? w.exercises[i].copyWith(sets: change(w.exercises[i].sets))
                  : w.exercises[i],
          ]));

  /// Adds a set that starts with the values of the one before it.
  void addSet(int exercise) => _setSets(exercise, (sets) {
        final last = sets.isEmpty ? const ExerciseSet() : sets.last;
        return [...sets, ExerciseSet(reps: last.reps, weightKg: last.weightKg)];
      });

  void removeSet(int exercise, int set) =>
      _setSets(exercise, (sets) => [...sets]..removeAt(set));

  void updateSet(int exercise, int set, ExerciseSet value) =>
      _setSets(exercise, (sets) => [...sets]..[set] = value);

  // ------------------------------------------------------------ finishing

  /// Saves the workout. Returns null on success, or a message to show.
  /// On failure the draft is untouched, so nothing typed is lost.
  Future<String?> save() async {
    final draft = state;
    final uid = _uid;
    if (draft == null || uid == null) return 'Nothing to save.';

    var workout = draft.workout;
    if (draft.mode == LogMode.live) {
      workout = workout.copyWith(durationSeconds: draft.elapsedSeconds(_now));
    }
    if (!workout.isComplete) {
      return workout.type == WorkoutType.timed
          ? 'Record a duration above zero before saving.'
          : 'Tick at least one completed set before saving.';
    }

    try {
      await ref.read(backendProvider).workouts.saveWorkout(uid, workout);
    } catch (_) {
      return 'Could not save. Your entries are kept, so you can try again.';
    }
    if (draft.mode != LogMode.edit) await _store.clearDraft(uid);
    hasUnsavedEdits = false;
    state = null;
    return null;
  }

  /// Throws the draft away.
  Future<void> discard() async {
    final uid = _uid;
    if (uid != null && state?.mode != LogMode.edit) {
      await _store.clearDraft(uid);
    }
    hasUnsavedEdits = false;
    state = null;
  }

  /// Deletes the saved workout being edited.
  Future<void> delete() async {
    final draft = state;
    final uid = _uid;
    if (draft == null || uid == null) return;
    await ref.read(backendProvider).workouts.deleteWorkout(uid, draft.workout.id);
    hasUnsavedEdits = false;
    state = null;
  }
}

final workoutLogProvider =
    NotifierProvider<WorkoutLogController, WorkoutDraft?>(
        WorkoutLogController.new);
