/// Routes. Paths match the screen list in docs/architecture.md.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models.dart';
import '../features/auth/auth_screen.dart';
import '../features/exercises/exercise_catalogue_screen.dart';
import '../features/exercises/exercise_detail_screen.dart';
import '../features/habits/habit_editor_screen.dart';
import '../features/habits/habits_screen.dart';
import '../features/home/home_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/progress/weekly_summary_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell.dart';
import '../features/steps/steps_screen.dart';
import '../features/workouts/workout_history_screen.dart';
import '../features/workouts/workout_log_screen.dart';
import '../providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-runs the redirect whenever the user signs in or out.
  final authChanged = ValueNotifier(0);
  ref.listen(authStateProvider, (_, _) => authChanged.value++);
  ref.onDispose(authChanged.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: authChanged,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final at = state.matchedLocation;
      if (auth.isLoading && !auth.hasValue) {
        return at == '/splash' ? null : '/splash';
      }
      final signedIn = auth.value != null;
      if (!signedIn) return at == '/auth' ? null : '/auth';
      if (at == '/auth' || at == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/workouts',
                builder: (_, _) => const WorkoutHistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/habits', builder: (_, _) => const HabitsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/progress', builder: (_, _) => const ProgressScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/workouts/log',
        builder: (_, state) => WorkoutLogScreen(
          mode: state.uri.queryParameters['mode'],
          workoutId: state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
          path: '/exercises',
          builder: (_, _) => const ExerciseCatalogueScreen()),
      GoRoute(
        path: '/exercises/detail',
        builder: (_, state) =>
            ExerciseDetailScreen(exercise: state.extra! as Exercise),
      ),
      GoRoute(
        path: '/habits/edit',
        builder: (_, state) =>
            HabitEditorScreen(habitId: state.uri.queryParameters['id']),
      ),
      GoRoute(path: '/steps', builder: (_, _) => const StepsScreen()),
      GoRoute(path: '/summary', builder: (_, _) => const WeeklySummaryScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
});
