/// S02 Home: today's activity and the next action.
/// Shows four states: loading, error, empty and with data.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../providers.dart';
import '../steps/steps_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: const [SettingsAction()],
      ),
      body: ListView(
        padding: pagePadding,
        children: switch (data) {
          AsyncData(:final value) =>
            value.isEmpty ? _empty(context) : _withData(context, value),
          AsyncError() => _error(context, ref),
          _ => _loading(context),
        },
      ),
    );
  }

  List<Widget> _loading(BuildContext context) => [
        Text('Loading your progress...',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        const SkeletonCard(),
        const SkeletonCard(),
        const SkeletonCard(),
      ];

  List<Widget> _error(BuildContext context, WidgetRef ref) => [
        MessageView(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load progress',
          message: 'Check your connection and try again. '
              'Saved workout drafts are available.',
          actions: [
            FilledButton(
              onPressed: () => reloadAppData(ref),
              child: const Text('Try again'),
            ),
            OutlinedButton(
              onPressed: () => context.push('/workouts/log'),
              child: const Text('Open saved workouts'),
            ),
          ],
        ),
      ];

  List<Widget> _empty(BuildContext context) => [
        Text('Your first day starts here',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('No workouts or habits yet.'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.push('/habits/edit'),
          child: const Text('Add your first habit'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.push('/workouts/log?mode=past'),
          child: const Text('Log your first workout'),
        ),
        const SizedBox(height: 16),
        const StepsCard(),
      ];

  List<Widget> _withData(BuildContext context, AppData data) {
    final due = data.habitsDueOn(data.today);
    final done = due.where((h) => data.isDone(h, data.today)).length;
    final streaks = [
      for (final h in data.activeHabits)
        if (data.streakOf(h) > 0) '${h.name}: ${data.streakOf(h)}-day streak',
    ];

    final target = data.profile.weeklyWorkoutTarget;
    final workouts = data.workoutsThisWeek;
    final left = target - workouts;
    final pending = data.workouts.any((w) => w.pendingSync);

    return [
      Text('Your progress today',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      const StepsCard(),
      InfoCard(
        title: due.isEmpty
            ? 'Habits: none scheduled today'
            : 'Habits: $done of ${due.length} complete',
        subtitle: streaks.isEmpty
            ? 'Tick a habit to start a streak'
            : streaks.take(2).join(' | '),
        onTap: () => context.go('/habits'),
      ),
      InfoCard(
        title: 'Workouts this week: $workouts / $target',
        subtitle: left <= 0
            ? 'Weekly target reached'
            : '${plural(left, 'session')} left to reach your target',
        onTap: () => context.go('/workouts'),
      ),
      const SizedBox(height: 4),
      FilledButton(
        onPressed: () => context.push('/workouts/log?mode=live'),
        child: const Text('Start workout'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => context.push('/workouts/log?mode=past'),
        child: const Text('Log a past workout'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => context.push('/summary'),
        child: const Text('View weekly summary'),
      ),
      if (pending)
        Text('Some changes are waiting to sync.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center),
    ];
  }
}
