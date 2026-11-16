// Widget tests that drive the whole app on the in-memory backend.

import 'package:fithabit/core/app_config.dart';
import 'package:fithabit/data/memory_repositories.dart';
import 'package:fithabit/domain/models.dart';
import 'package:fithabit/services/step_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  group('S01 Account access', () {
    testWidgets('shows the health disclaimer and validates the form',
        (tester) async {
      await pumpApp(tester);
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text(AppConfig.disclaimer), findsOneWidget);

      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });

    testWidgets('a wrong password keeps the form and shows an error',
        (tester) async {
      await pumpApp(tester);
      await tester.enterText(
          find.byKey(const Key('auth-email')), 'nobody@example.com');
      await tester.enterText(find.byKey(const Key('auth-password')), 'wrong-pw');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(find.text('nobody@example.com'), findsOneWidget);
    });

    testWidgets('create account, sign out, sign in again', (tester) async {
      await pumpApp(tester);
      await signUp(tester);
      expect(find.text('Your first day starts here'), findsOneWidget);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text(AppConfig.disclaimer), findsOneWidget);
      await tester.tap(find.byKey(const Key('sign-out')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('auth-email')), 'kabeer@example.com');
      await tester.enterText(find.byKey(const Key('auth-password')), 'secret1');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
    });
  });

  group('S02 Home states', () {
    testWidgets('empty: invites a first habit and workout', (tester) async {
      await pumpApp(tester);
      await signUp(tester);
      expect(find.text('No workouts or habits yet.'), findsOneWidget);
      expect(find.text('Add your first habit'), findsOneWidget);
      expect(find.text('Log your first workout'), findsOneWidget);
      expect(find.text('Step tracking is off'), findsOneWidget);
    });

    testWidgets('error: offers a retry that recovers', (tester) async {
      final backend = MemoryBackend();
      await pumpApp(tester, backend: backend);
      backend.failLoads = true;
      await signUp(tester);
      expect(find.text('Could not load progress'), findsOneWidget);

      backend.failLoads = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load progress'), findsNothing);
      expect(find.text('Your first day starts here'), findsOneWidget);
    });

    testWidgets('with data: shows habits, workouts and actions',
        (tester) async {
      final app = await pumpApp(tester);
      await signUp(tester);
      final uid = app.backend.currentUser!.uid;
      await app.backend.saveHabit(
          uid, const Habit(id: 'h1', name: 'Read', startDate: '2026-11-01'));
      await app.backend.setCompleted(uid, 'h1', '2026-11-17', true);
      await app.backend.setCompleted(uid, 'h1', '2026-11-18', true);
      await tester.pumpAndSettle();

      expect(find.text('Your progress today'), findsOneWidget);
      expect(find.text('Habits: 1 of 1 complete'), findsOneWidget);
      expect(find.text('Read: 2-day streak'), findsOneWidget);
      expect(find.text('Workouts this week: 0 / 3'), findsOneWidget);
      expect(find.text('3 sessions left to reach your target'), findsOneWidget);
      expect(find.text('Start workout'), findsOneWidget);
    });
  });

  group('workouts', () {
    testWidgets('log a past workout with a manual exercise', (tester) async {
      await pumpApp(tester, wgerOnline: false);
      await signUp(tester);
      await openTab(tester, 'Workouts');
      expect(find.text('No workouts yet'), findsOneWidget);

      await tester.tap(find.text('Log past workout'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('workout-title')), 'Morning session');

      // The catalogue is offline; a manual exercise keeps logging usable.
      await tester.tap(find.byKey(const Key('add-exercise')));
      await tester.pumpAndSettle();
      expect(find.text('Could not load exercises'), findsOneWidget);
      await tester.tap(find.byKey(const Key('manual-exercise')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('manual-exercise-name')), 'Push-up');
      await tester.tap(find.text('Add to workout'));
      await tester.pumpAndSettle();
      expect(find.text('Push-up'), findsOneWidget);

      // Nothing ticked yet: the workout is not complete.
      await tester.tap(find.byKey(const Key('save-workout')));
      await tester.pumpAndSettle();
      expect(find.text('Tick at least one completed set before saving.'),
          findsOneWidget);

      await tester.enterText(find.byKey(const Key('reps-0')), '12');
      await tester.tap(find.byKey(const Key('done-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-workout')));
      await tester.pumpAndSettle();

      expect(find.text('Morning session'), findsOneWidget);
      expect(find.text('Today | 1 exercise'), findsOneWidget);
      expect(find.text('Weekly target: 1 / 3'), findsOneWidget);
    });

    testWidgets('pick an exercise from the wger catalogue', (tester) async {
      final app = await pumpApp(tester);
      await signUp(tester);
      await openTab(tester, 'Workouts');
      await tester.tap(find.text('Start workout'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('workout-elapsed')), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-exercise')));
      await tester.pumpAndSettle();
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Chest | Barbell, Bench'), findsWidgets);

      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();
      expect(find.text('Exercise detail'), findsOneWidget);
      expect(find.textContaining('Licence: CC-BY-SA'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-to-workout')));
      await tester.pumpAndSettle();

      expect(find.text('Workout log'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);

      // The live timer runs on the clock: 25 minutes later it shows 25:00.
      app.now = app.now.add(const Duration(minutes: 25));
      await tester.tap(find.byKey(const Key('done-0')));
      await tester.pumpAndSettle();
      expect(find.text('Today | 00:25:00 elapsed'), findsOneWidget);

      await tester.tap(find.byKey(const Key('save-workout')));
      await tester.pumpAndSettle();
      expect(find.text('Today | 25 min | 1 exercise'), findsOneWidget);
    });

    testWidgets('a draft survives leaving the screen', (tester) async {
      await pumpApp(tester);
      await signUp(tester);
      await openTab(tester, 'Workouts');
      await tester.tap(find.text('Log past workout'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('workout-title')), 'Half-finished');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('No workouts yet'), findsOneWidget);

      await tester.tap(find.text('Start workout'));
      await tester.pumpAndSettle();
      expect(find.text('Continuing your saved draft.'), findsOneWidget);
      expect(find.text('Half-finished'), findsOneWidget);
    });

    testWidgets('a failed save keeps the input and a retry does not duplicate',
        (tester) async {
      final app = await pumpApp(tester);
      await signUp(tester);
      await openTab(tester, 'Workouts');
      await tester.tap(find.text('Log past workout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timed activity'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('workout-title')), 'Walk');
      await tester.enterText(find.byType(TextFormField).first, '35');

      app.backend.failSaves = true;
      await tester.tap(find.byKey(const Key('save-workout')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not save'), findsOneWidget);
      expect(find.text('Walk'), findsOneWidget);

      app.backend.failSaves = false;
      await tester.tap(find.byKey(const Key('save-workout')));
      await tester.pumpAndSettle();
      expect(find.text('Today | 35 min | Timed activity'), findsOneWidget);
      expect(find.text('Walk'), findsOneWidget);
    });
  });

  group('habits', () {
    testWidgets('create a habit from a template and tick it', (tester) async {
      final app = await pumpApp(tester);
      await signUp(tester);
      await openTab(tester, 'Habits');
      expect(find.text('No habits yet'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-habit')));
      await tester.pumpAndSettle();
      // An empty name is refused.
      await tester.tap(find.byKey(const Key('save-habit')));
      await tester.pumpAndSettle();
      expect(find.text('Give the habit a name'), findsOneWidget);

      await tester.tap(find.text('Fitness template'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Walk outside'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remind me'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-habit')));
      await tester.pumpAndSettle();

      expect(find.text('Walk outside'), findsOneWidget);
      expect(find.text('0-day streak | Every day'), findsOneWidget);
      expect(find.text('0 of 1 scheduled habits complete'), findsOneWidget);
      expect(app.notifications.log.last, endsWith(':true'));

      await tester.tap(find.byKey(const Key('habit-check-Walk outside')));
      await tester.pumpAndSettle();
      expect(find.text('1-day streak | Every day'), findsOneWidget);
      expect(find.text('1 of 1 scheduled habits complete'), findsOneWidget);

      // Unticking recalculates the streak.
      await tester.tap(find.byKey(const Key('habit-check-Walk outside')));
      await tester.pumpAndSettle();
      expect(find.text('0-day streak | Every day'), findsOneWidget);
    });

    testWidgets('denied notifications still save the habit', (tester) async {
      final app = await pumpApp(tester, notificationsAllowed: false);
      await signUp(tester);
      await openTab(tester, 'Habits');
      await tester.tap(find.byKey(const Key('add-habit')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('habit-name')), 'Read');
      await tester.tap(find.text('Remind me'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-habit')));
      await tester.pumpAndSettle();

      expect(find.text('Read'), findsOneWidget);
      expect(find.textContaining('saved without a reminder'), findsOneWidget);
      expect(app.notifications.log.last, endsWith(':false'));
    });
  });

  group('steps', () {
    Future<void> openSteps(WidgetTester tester) async {
      await tester.tap(find.text('Step tracking is off'));
      await tester.pumpAndSettle();
    }

    testWidgets('denied permission is handled without blocking the app',
        (tester) async {
      final steps = FakeStepPlatform(permission: PermissionResult.denied);
      await pumpApp(tester, steps: steps);
      await signUp(tester);
      await openSteps(tester);

      await tester.tap(find.byKey(const Key('enable-steps')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steps-off')), findsOneWidget);
      expect(find.text('Activity access was not allowed'), findsOneWidget);

      // Continue without tracking: Home changes only its steps card.
      await tester.tap(find.text('Continue without tracking'));
      await tester.pumpAndSettle();
      expect(find.text('Step tracking is off'), findsOneWidget);
      expect(find.text('Add your first habit'), findsOneWidget);

      // The rest of the app still works.
      await openTab(tester, 'Workouts');
      expect(find.text('Start workout'), findsOneWidget);
      await openTab(tester, 'Habits');
      expect(find.byKey(const Key('add-habit')), findsOneWidget);
    });

    testWidgets('a blocked permission offers the system settings',
        (tester) async {
      final steps =
          FakeStepPlatform(permission: PermissionResult.permanentlyDenied);
      await pumpApp(tester, steps: steps);
      await signUp(tester);
      await openSteps(tester);
      await tester.tap(find.byKey(const Key('enable-steps')));
      await tester.pumpAndSettle();

      expect(find.text('Activity access is blocked'), findsOneWidget);
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      expect(steps.settingsOpened, 1);
    });

    testWidgets('a device without sensors says so', (tester) async {
      await pumpApp(tester, steps: FakeStepPlatform(isSupported: false));
      await signUp(tester);
      await openSteps(tester);
      await tester.tap(find.byKey(const Key('enable-steps')));
      await tester.pumpAndSettle();
      expect(find.text('Step counting is unavailable on this device'),
          findsOneWidget);
    });

    testWidgets('counts steps, saves the day and notifies at the goal',
        (tester) async {
      final steps = FakeStepPlatform();
      final app = await pumpApp(tester, steps: steps);
      await signUp(tester);
      await openSteps(tester);

      // A goal outside the allowed range is refused.
      await tester.enterText(find.byKey(const Key('step-goal')), '50');
      await tester.tap(find.text('Save goal'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter a goal between'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('step-goal')), '2000');
      await tester.tap(find.text('Save goal'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('enable-steps')));
      await tester.pumpAndSettle();
      expect(find.text('Tracking: on'), findsOneWidget);

      steps.counts.add(40000); // baseline
      steps.counts.add(41500);
      await tester.pumpAndSettle();
      expect(find.text('1,500 / 2,000'), findsOneWidget);
      expect(find.text('Today is still in progress.'), findsOneWidget);
      expect(app.notifications.log.where((l) => l.startsWith('goal:')), isEmpty);

      steps.counts.add(42100);
      await tester.pumpAndSettle();
      expect(find.text('2,100 / 2,000'), findsOneWidget);
      expect(find.text('Goal reached today.'), findsOneWidget);
      expect(app.notifications.log, contains('goal:2100/2000'));

      // More steps do not notify a second time.
      steps.counts.add(42500);
      await tester.pumpAndSettle();
      expect(app.notifications.log.where((l) => l.startsWith('goal:')),
          hasLength(1));

      // The total is written after a short delay, then appears as a streak.
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(find.text('1-day goal streak'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Steps: 2,500 / 2,000'), findsOneWidget);
    });

    testWidgets('falls back to the accelerometer without a step sensor',
        (tester) async {
      final steps = FakeStepPlatform(hasStepSensor: false);
      await pumpApp(tester, steps: steps);
      await signUp(tester);
      await openSteps(tester);
      await tester.tap(find.byKey(const Key('enable-steps')));
      await tester.pumpAndSettle();
      expect(find.textContaining('counts steps itself while it is open'),
          findsOneWidget);

      // Three clear bounces, each followed by rest.
      var t = 0;
      void sample(double z) => steps.samples.add(AccelSample(0, 0, z, t += 100));
      for (var i = 0; i < 20; i++) {
        sample(9.81);
      }
      for (var step = 0; step < 3; step++) {
        sample(14);
        for (var i = 0; i < 5; i++) {
          sample(9.81);
        }
      }
      await tester.pumpAndSettle();
      expect(find.text('3 / 8,000'), findsOneWidget);
    });
  });

  group('progress and summary', () {
    testWidgets('weekly summary totals and comparison', (tester) async {
      final app = await pumpApp(tester);
      await signUp(tester);
      final uid = app.backend.currentUser!.uid;

      Workout workout(String id, String date, int minutes) => Workout(
            id: id,
            date: date,
            startedAt: DateTime.parse('${date}T08:00:00'),
            durationSeconds: minutes * 60,
            exercises: const [
              WorkoutExercise(
                  name: 'Squat', sets: [ExerciseSet(reps: 10, done: true)]),
            ],
          );

      // Last completed week: 9-15 Nov. The week before: 2-8 Nov.
      await app.backend.saveWorkout(uid, workout('a', '2026-11-03', 30));
      await app.backend.saveWorkout(uid, workout('b', '2026-11-09', 40));
      await app.backend.saveWorkout(uid, workout('c', '2026-11-11', 35));
      await app.backend.saveWorkout(uid, workout('d', '2026-11-14', 30));
      await app.backend.saveDay(uid,
          const StepDay(date: '2026-11-10', steps: 9000, goal: 8000));
      await app.backend.saveDay(uid,
          const StepDay(date: '2026-11-12', steps: 6500, goal: 8000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View weekly summary'));
      await tester.pumpAndSettle();
      expect(find.text('Last completed week'), findsOneWidget);
      expect(find.text('Workouts: 3 / 3'), findsOneWidget);
      expect(find.text('105 minutes | Target achieved'), findsOneWidget);
      expect(find.text('Steps: 15,500 recorded'), findsOneWidget);
      expect(find.text('Goal met on 1 of 2 tracked days | 5 days not tracked'),
          findsOneWidget);
      expect(find.text('Habits: none due'), findsOneWidget);
      expect(find.text('2 more workouts completed.'), findsOneWidget);

      // The earliest week has nothing to compare with.
      await tester.tap(find.byTooltip('Earlier week'));
      await tester.pumpAndSettle();
      expect(find.text('2 Nov - 8 Nov'), findsOneWidget);
      expect(find.text('Comparison not available yet.'), findsOneWidget);
    });

    testWidgets('progress shows week and month figures', (tester) async {
      final app = await pumpApp(tester);
      await signUp(tester);
      final uid = app.backend.currentUser!.uid;
      await app.backend.saveHabit(
          uid, const Habit(id: 'h1', name: 'Read', startDate: '2026-11-16'));
      await app.backend.setCompleted(uid, 'h1', '2026-11-16', true);
      await app.backend.saveDay(uid,
          const StepDay(date: '2026-11-17', steps: 8200, goal: 8000));
      await tester.pumpAndSettle();

      await openTab(tester, 'Progress');
      expect(find.text('Step history'), findsOneWidget);
      expect(find.textContaining('8,200 steps on 1 tracked day'), findsOneWidget);
      expect(find.text('Workouts: 0 / 3'), findsOneWidget);
      // Due Mon, Tue and today; done once.
      expect(find.text('Habits: 1 / 3 due'), findsOneWidget);
      expect(find.text('33% of scheduled entries completed'), findsOneWidget);

      await tester.tap(find.text('This month'));
      await tester.pumpAndSettle();
      expect(find.text('0 minutes logged this month'), findsOneWidget);
    });
  });

  group('S12 Settings', () {
    testWidgets('saves the weekly target and schedules the reminder',
        (tester) async {
      final app = await pumpApp(tester);
      await signUp(tester);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings-reminder')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-save')));
      await tester.pumpAndSettle();
      expect(find.text('Preferences saved'), findsOneWidget);
      expect(app.notifications.log, contains('daily:1140'));
    });

    testWidgets('deleting the account needs the right password',
        (tester) async {
      final app = await pumpApp(tester);
      await signUp(tester);
      final uid = app.backend.currentUser!.uid;
      await app.backend.saveHabit(
          uid, const Habit(id: 'h1', name: 'Read', startDate: '2026-11-16'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete account and data'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('delete-password')), 'wrong');
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();
      expect(find.text('Password is incorrect.'), findsOneWidget);
      expect(app.backend.currentUser, isNotNull);

      await tester.tap(find.text('Delete account and data'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('delete-password')), 'secret1');
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsOneWidget);
      expect(app.backend.currentUser, isNull);
    });
  });
}
