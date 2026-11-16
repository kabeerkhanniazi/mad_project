/// Interfaces between the app and its storage.
///
/// Two implementations exist: Firebase (firebase_repositories.dart) and
/// in-memory (memory_repositories.dart) for demo mode and tests.
library;

import '../domain/models.dart';

class AuthUser {
  const AuthUser({required this.uid, required this.email});
  final String uid;
  final String email;
}

/// A sign-in problem with a message that can be shown to the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  /// Emits the signed-in user, or null when signed out.
  Stream<AuthUser?> authState();
  AuthUser? get currentUser;

  Future<void> signIn(String email, String password);
  Future<AuthUser> signUp(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();

  /// Confirms the password again. Required before deleting the account.
  Future<void> reauthenticate(String password);
  Future<void> deleteUser();
}

abstract interface class ProfileRepository {
  /// Emits null until a profile has been saved.
  Stream<UserProfile?> watchProfile(String uid);
  Future<void> saveProfile(UserProfile profile);

  /// Removes the profile and every record stored under it.
  Future<void> deleteAllData(String uid);
}

abstract interface class WorkoutRepository {
  /// Newest first.
  Stream<List<Workout>> watchWorkouts(String uid);
  String newId(String uid);
  Future<void> saveWorkout(String uid, Workout workout);
  Future<void> deleteWorkout(String uid, String workoutId);
}

abstract interface class HabitRepository {
  Stream<List<Habit>> watchHabits(String uid);
  Stream<List<HabitCompletion>> watchCompletions(String uid);
  String newId(String uid);
  Future<void> saveHabit(String uid, Habit habit);
  Future<void> setCompleted(
      String uid, String habitId, String date, bool completed);
}

abstract interface class StepRepository {
  Stream<List<StepDay>> watchDays(String uid);
  Future<void> saveDay(String uid, StepDay day);
}

/// Everything the app needs from a backend, chosen once at start-up.
class Backend {
  const Backend({
    required this.auth,
    required this.profiles,
    required this.workouts,
    required this.habits,
    required this.steps,
    required this.isDemo,
  });

  final AuthRepository auth;
  final ProfileRepository profiles;
  final WorkoutRepository workouts;
  final HabitRepository habits;
  final StepRepository steps;

  /// True when data lives in memory only.
  final bool isDemo;
}
