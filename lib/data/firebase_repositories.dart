/// Firebase implementations: Authentication for accounts, Cloud Firestore
/// for records. See docs/architecture.md for the document layout.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import '../domain/models.dart';
import 'repositories.dart';

/// Builds the Firebase backend. Call after `Firebase.initializeApp`.
Backend createFirebaseBackend() {
  final store = FirestoreStore(FirebaseFirestore.instance);
  return Backend(
    auth: FirebaseAuthRepository(fb.FirebaseAuth.instance),
    profiles: store,
    workouts: store,
    habits: store,
    steps: store,
    isDemo: false,
  );
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);
  final fb.FirebaseAuth _auth;

  static AuthUser? _map(fb.User? u) =>
      u == null ? null : AuthUser(uid: u.uid, email: u.email ?? '');

  @override
  Stream<AuthUser?> authState() => _auth.authStateChanges().map(_map);

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<void> signIn(String email, String password) => _run(() =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<AuthUser> signUp(String email, String password) async {
    final cred = await _run(() => _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password));
    return _map(cred.user)!;
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _run(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('You are signed out.');
    await _run(() => user.reauthenticateWithCredential(
        fb.EmailAuthProvider.credential(
            email: user.email ?? '', password: password)));
  }

  @override
  Future<void> deleteUser() async {
    final user = _auth.currentUser;
    if (user != null) await _run(user.delete);
  }

  /// Runs a Firebase call and turns its error codes into plain messages.
  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(authMessage(e.code));
    }
  }

  static String authMessage(String code) => switch (code) {
        'invalid-email' => 'That email address is not valid.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' =>
          'Email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for this email.',
        'weak-password' => 'Choose a password with at least 6 characters.',
        'network-request-failed' =>
          'No connection. Check your internet and try again.',
        'too-many-requests' =>
          'Too many attempts. Wait a moment and try again.',
        'requires-recent-login' => 'Sign in again, then retry.',
        _ => 'Something went wrong ($code). Try again.',
      };
}

/// All Firestore access. One class, because every record lives under
/// `users/{uid}`.
class FirestoreStore
    implements
        ProfileRepository,
        WorkoutRepository,
        HabitRepository,
        StepRepository {
  FirestoreStore(this._db);
  final FirebaseFirestore _db;

  /// How far back completions and step days are loaded.
  static const _historyDays = 400;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _col(String uid, String name) =>
      _user(uid).collection(name);

  String get _historyStart => addDays(dateKey(DateTime.now()), -_historyDays);

  /// Starts a write without waiting for the server.
  ///
  /// Firestore applies every write to its local cache immediately and sends
  /// it when a connection exists. Awaiting the server would freeze the UI
  /// while offline, so the returned future completes straight away.
  Future<void> _queue(Future<void> write) {
    unawaited(write.catchError((Object e) {
      debugPrint('Firestore write failed: $e');
    }));
    return Future.value();
  }

  // ------------------------------------------------------------- profile

  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      _user(uid).snapshots().map((doc) {
        final data = doc.data();
        return data == null ? null : UserProfile.fromMap(uid, data);
      });

  @override
  Future<void> saveProfile(UserProfile profile) => _queue(
      _user(profile.uid).set(profile.toMap(), SetOptions(merge: true)));

  @override
  Future<void> deleteAllData(String uid) async {
    for (final name in const ['workouts', 'habits', 'completions', 'steps']) {
      final docs = (await _col(uid, name).get()).docs;
      // A batch holds at most 500 writes.
      for (var i = 0; i < docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    await _user(uid).delete();
  }

  // ------------------------------------------------------------- workouts

  @override
  Stream<List<Workout>> watchWorkouts(String uid) => _col(uid, 'workouts')
      .orderBy('startedAt', descending: true)
      .limit(500)
      .snapshots(includeMetadataChanges: true)
      .map((snap) => [
            for (final d in snap.docs)
              Workout.fromMap(d.id, d.data(),
                  pendingSync: d.metadata.hasPendingWrites),
          ]);

  @override
  String newId(String uid) => _col(uid, 'workouts').doc().id;

  @override
  Future<void> saveWorkout(String uid, Workout workout) =>
      _queue(_col(uid, 'workouts').doc(workout.id).set(workout.toMap()));

  @override
  Future<void> deleteWorkout(String uid, String workoutId) =>
      _queue(_col(uid, 'workouts').doc(workoutId).delete());

  // ------------------------------------------------------------- habits

  @override
  Stream<List<Habit>> watchHabits(String uid) =>
      _col(uid, 'habits').orderBy('startDate').snapshots().map((snap) =>
          [for (final d in snap.docs) Habit.fromMap(d.id, d.data())]);

  @override
  Stream<List<HabitCompletion>> watchCompletions(String uid) =>
      _col(uid, 'completions')
          .where('date', isGreaterThanOrEqualTo: _historyStart)
          .snapshots()
          .map((snap) =>
              [for (final d in snap.docs) HabitCompletion.fromMap(d.data())]);

  @override
  Future<void> saveHabit(String uid, Habit habit) =>
      _queue(_col(uid, 'habits').doc(habit.id).set(habit.toMap()));

  @override
  Future<void> setCompleted(
      String uid, String habitId, String date, bool completed) {
    final entry = HabitCompletion(habitId: habitId, date: date);
    final doc = _col(uid, 'completions').doc(entry.id);
    return _queue(completed ? doc.set(entry.toMap()) : doc.delete());
  }

  // ------------------------------------------------------------- steps

  @override
  Stream<List<StepDay>> watchDays(String uid) => _col(uid, 'steps')
      .where('date', isGreaterThanOrEqualTo: _historyStart)
      .snapshots()
      .map((snap) => [for (final d in snap.docs) StepDay.fromMap(d.data())]);

  @override
  Future<void> saveDay(String uid, StepDay day) =>
      _queue(_col(uid, 'steps').doc(day.date).set(day.toMap()));
}
