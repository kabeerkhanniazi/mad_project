/// Shared Riverpod providers. Screens read these; nothing else is global.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'core/dates.dart';
import 'data/local_store.dart';
import 'data/repositories.dart';
import 'data/wger_api.dart';
import 'domain/models.dart';
import 'domain/streaks.dart';
import 'domain/weekly_summary.dart';
import 'services/notification_service.dart';
import 'services/step_platform.dart';

// ------------------------------------------------------------ infrastructure
// The first two are overridden in main.dart once start-up has finished.

final backendProvider = Provider<Backend>(
    (ref) => throw UnimplementedError('backendProvider must be overridden'));

final localStoreProvider = Provider<LocalStore>(
    (ref) => throw UnimplementedError('localStoreProvider must be overridden'));

final notificationServiceProvider =
    Provider<NotificationService>((ref) => FakeNotificationService());

final stepPlatformProvider =
    Provider<StepPlatform>((ref) => DeviceStepPlatform());

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final wgerApiProvider = Provider<WgerApi>((ref) =>
    WgerApi(ref.watch(httpClientProvider), ref.watch(localStoreProvider)));

/// The current time. Tests override this to fix the date.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Today's date key. Updates itself at midnight.
class TodayNotifier extends Notifier<String> {
  @override
  String build() {
    final now = ref.watch(clockProvider)();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final timer = Timer(
        midnight.difference(now) + const Duration(seconds: 1),
        ref.invalidateSelf);
    ref.onDispose(timer.cancel);
    return dateKey(now);
  }

  /// Called when the app returns to the foreground.
  void refresh() {
    if (dateKey(ref.read(clockProvider)()) != state) ref.invalidateSelf();
  }
}

final todayProvider =
    NotifierProvider<TodayNotifier, String>(TodayNotifier.new);

// ------------------------------------------------------------ account

final authStateProvider = StreamProvider<AuthUser?>(
    (ref) => ref.watch(backendProvider).auth.authState());

final uidProvider =
    Provider<String?>((ref) => ref.watch(authStateProvider).value?.uid);

// ------------------------------------------------------------ live records
// Each stream follows the signed-in user and stays empty when signed out.

final profileProvider = StreamProvider<UserProfile>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref
      .watch(backendProvider)
      .profiles
      .watchProfile(uid)
      .map((p) => p ?? UserProfile(uid: uid));
});

final workoutsProvider = StreamProvider<List<Workout>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(backendProvider).workouts.watchWorkouts(uid);
});

final habitsProvider = StreamProvider<List<Habit>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(backendProvider).habits.watchHabits(uid);
});

final completionsProvider = StreamProvider<List<HabitCompletion>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(backendProvider).habits.watchCompletions(uid);
});

final stepDaysProvider = StreamProvider<List<StepDay>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(backendProvider).steps.watchDays(uid);
});

// ------------------------------------------------------------ combined view

/// Every record the signed-in user has, with the questions screens ask.
class AppData {
  AppData({
    required this.profile,
    required this.workouts,
    required this.habits,
    required this.completions,
    required List<StepDay> stepDays,
    required this.today,
  }) : stepDays = {for (final d in stepDays) d.date: d};

  final UserProfile profile;
  final List<Workout> workouts;
  final List<Habit> habits;
  final List<HabitCompletion> completions;
  final Map<String, StepDay> stepDays;
  final String today;

  late final Set<String> _completionIds = {for (final c in completions) c.id};

  bool get isEmpty => workouts.isEmpty && habits.isEmpty;

  List<Habit> get activeHabits => [
        for (final h in habits)
          if (!h.archived) h,
      ];

  List<Habit> habitsDueOn(String date) => [
        for (final h in habits)
          if (h.isScheduledOn(date)) h,
      ];

  bool isDone(Habit habit, String date) =>
      _completionIds.contains(HabitCompletion(habitId: habit.id, date: date).id);

  int streakOf(Habit habit) =>
      habitStreak(habit, doneDatesFor(habit.id, completions), today);

  int get currentStepStreak => stepStreak(stepDays, today);

  String get thisWeek => weekStartOf(today);

  int get workoutsThisWeek => summaryFor(thisWeek).workouts;

  WeeklySummary summaryFor(String weekStart) => buildWeeklySummary(
        weekStart: weekStart,
        workouts: workouts,
        habits: habits,
        completions: completions,
        stepDays: stepDays.values,
        workoutTarget: profile.weeklyWorkoutTarget,
        today: today,
      );

  /// Totals for the calendar month that contains today.
  WeeklySummary get monthSummary => summariseDays(
        days: monthDays,
        workouts: workouts,
        habits: habits,
        completions: completions,
        stepDays: stepDays.values,
        workoutTarget: profile.weeklyWorkoutTarget,
        today: today,
      );

  /// Every day of the current month, including days still to come.
  List<String> get monthDays {
    final d = parseDateKey(today);
    final count = DateTime(d.year, d.month + 1, 0).day;
    return [
      for (var i = 1; i <= count; i++) dateKey(DateTime(d.year, d.month, i)),
    ];
  }

  /// The earliest day with any record; weeks before it have nothing to show.
  String get firstRecordDate {
    var first = today;
    void consider(String date) {
      if (date.compareTo(first) < 0) first = date;
    }

    for (final w in workouts) {
      consider(w.date);
    }
    for (final h in habits) {
      consider(h.startDate);
    }
    stepDays.keys.forEach(consider);
    return first;
  }
}

/// Combines the five record streams. Loading until all have arrived; an
/// error only when a stream failed and has no earlier data to show.
final appDataProvider = Provider<AsyncValue<AppData>>((ref) {
  final profile = ref.watch(profileProvider);
  final workouts = ref.watch(workoutsProvider);
  final habits = ref.watch(habitsProvider);
  final completions = ref.watch(completionsProvider);
  final stepDays = ref.watch(stepDaysProvider);
  final today = ref.watch(todayProvider);

  final all = <AsyncValue<Object?>>[
    profile,
    workouts,
    habits,
    completions,
    stepDays,
  ];
  for (final value in all) {
    if (value.hasError && !value.hasValue) {
      return AsyncError(value.error!, value.stackTrace ?? StackTrace.current);
    }
  }
  if (all.any((value) => !value.hasValue)) return const AsyncLoading();

  return AsyncData(AppData(
    profile: profile.requireValue,
    workouts: workouts.requireValue,
    habits: habits.requireValue,
    completions: completions.requireValue,
    stepDays: stepDays.requireValue,
    today: today,
  ));
});

/// Reloads every record stream. Used by "Try again".
void reloadAppData(WidgetRef ref) {
  ref.invalidate(profileProvider);
  ref.invalidate(workoutsProvider);
  ref.invalidate(habitsProvider);
  ref.invalidate(completionsProvider);
  ref.invalidate(stepDaysProvider);
}
