/// In-memory backend for demo mode and tests. Nothing leaves the device and
/// everything is lost when the app closes.
library;

import 'dart:async';

import '../domain/models.dart';
import 'repositories.dart';

/// A value that can be watched: new listeners get the current value first.
class _Live<T> {
  _Live(this._value);
  T _value;
  final _changes = StreamController<T>.broadcast();

  T get value => _value;
  set value(T v) {
    _value = v;
    _changes.add(v);
  }

  Stream<T> watch() async* {
    yield _value;
    yield* _changes.stream;
  }
}

class _UserData {
  final profile = _Live<UserProfile?>(null);
  final workouts = _Live<List<Workout>>(const []);
  final habits = _Live<List<Habit>>(const []);
  final completions = _Live<List<HabitCompletion>>(const []);
  final steps = _Live<List<StepDay>>(const []);
}

class MemoryBackend
    implements
        AuthRepository,
        ProfileRepository,
        WorkoutRepository,
        HabitRepository,
        StepRepository {
  final _accounts = <String, ({String uid, String password})>{};
  final _data = <String, _UserData>{};
  final _auth = _Live<AuthUser?>(null);
  var _nextId = 1;

  /// Test hook: when true, record streams fail like a lost connection with
  /// no cached data.
  bool failLoads = false;

  /// Test hook: when true, saving a workout fails.
  bool failSaves = false;

  Backend asBackend() => Backend(
        auth: this,
        profiles: this,
        workouts: this,
        habits: this,
        steps: this,
        isDemo: true,
      );

  _UserData _of(String uid) => _data.putIfAbsent(uid, _UserData.new);

  Stream<T> _guard<T>(Stream<T> source) =>
      failLoads ? Stream<T>.error(StateError('Could not reach the server')) : source;

  // ------------------------------------------------------------- auth

  @override
  Stream<AuthUser?> authState() => _auth.watch();

  @override
  AuthUser? get currentUser => _auth.value;

  @override
  Future<void> signIn(String email, String password) async {
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null || account.password != password) {
      throw const AuthFailure('Email or password is incorrect.');
    }
    _auth.value = AuthUser(uid: account.uid, email: email.trim());
  }

  @override
  Future<AuthUser> signUp(String email, String password) async {
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      throw const AuthFailure('An account already exists for this email.');
    }
    final uid = 'demo-${_nextId++}';
    _accounts[key] = (uid: uid, password: password);
    final user = AuthUser(uid: uid, email: email.trim());
    _auth.value = user;
    return user;
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async => _auth.value = null;

  @override
  Future<void> reauthenticate(String password) async {
    final user = _auth.value;
    final account = user == null ? null : _accounts[user.email.toLowerCase()];
    if (account == null || account.password != password) {
      throw const AuthFailure('Password is incorrect.');
    }
  }

  @override
  Future<void> deleteUser() async {
    final user = _auth.value;
    if (user != null) _accounts.remove(user.email.toLowerCase());
    _auth.value = null;
  }

  // ------------------------------------------------------------- profile

  @override
  Stream<UserProfile?> watchProfile(String uid) => _guard(_of(uid).profile.watch());

  @override
  Future<void> saveProfile(UserProfile profile) async =>
      _of(profile.uid).profile.value = profile;

  @override
  Future<void> deleteAllData(String uid) async => _data.remove(uid);

  // ------------------------------------------------------------- workouts

  @override
  Stream<List<Workout>> watchWorkouts(String uid) =>
      _guard(_of(uid).workouts.watch());

  @override
  String newId(String uid) => 'id-${_nextId++}';

  @override
  Future<void> saveWorkout(String uid, Workout workout) async {
    if (failSaves) throw StateError('Could not save');
    final live = _of(uid).workouts;
    final list = [
      for (final w in live.value)
        if (w.id != workout.id) w,
      workout,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    live.value = list;
  }

  @override
  Future<void> deleteWorkout(String uid, String workoutId) async {
    final live = _of(uid).workouts;
    live.value = [
      for (final w in live.value)
        if (w.id != workoutId) w,
    ];
  }

  // ------------------------------------------------------------- habits

  @override
  Stream<List<Habit>> watchHabits(String uid) =>
      _guard(_of(uid).habits.watch());

  @override
  Stream<List<HabitCompletion>> watchCompletions(String uid) =>
      _guard(_of(uid).completions.watch());

  @override
  Future<void> saveHabit(String uid, Habit habit) async {
    final live = _of(uid).habits;
    final exists = live.value.any((h) => h.id == habit.id);
    live.value = exists
        ? [for (final h in live.value) h.id == habit.id ? habit : h]
        : [...live.value, habit];
  }

  @override
  Future<void> setCompleted(
      String uid, String habitId, String date, bool completed) async {
    final live = _of(uid).completions;
    final entry = HabitCompletion(habitId: habitId, date: date);
    live.value = [
      for (final c in live.value)
        if (c.id != entry.id) c,
      if (completed) entry,
    ];
  }

  // ------------------------------------------------------------- steps

  @override
  Stream<List<StepDay>> watchDays(String uid) => _guard(_of(uid).steps.watch());

  @override
  Future<void> saveDay(String uid, StepDay day) async {
    final live = _of(uid).steps;
    live.value = [
      for (final d in live.value)
        if (d.date != day.date) d,
      day,
    ]..sort((a, b) => a.date.compareTo(b.date));
  }
}
