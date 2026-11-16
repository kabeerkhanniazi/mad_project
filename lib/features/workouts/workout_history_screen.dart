/// S03 Workout history: past sessions, and the two ways to add one.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../providers.dart';

class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        actions: const [SettingsAction()],
      ),
      body: ListView(
        padding: pagePadding,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => context.push('/workouts/log?mode=live'),
                  child: const Text('Start workout'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/workouts/log?mode=past'),
                  child: const Text('Log past workout'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...switch (data) {
            AsyncData(:final value) => _content(context, value),
            AsyncError() => [
                MessageView(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load workouts',
                  message: 'Check your connection and try again.',
                  actions: [
                    FilledButton(
                      onPressed: () => reloadAppData(ref),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ],
            _ => const [SkeletonCard(), SkeletonCard()],
          },
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, AppData data) => [
        InfoCard(
          title: 'Weekly target: ${data.workoutsThisWeek} / '
              '${data.profile.weeklyWorkoutTarget}',
          subtitle: 'Manage target in Settings',
          onTap: () => context.push('/settings'),
        ),
        const SizedBox(height: 8),
        Text('History', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (data.workouts.isEmpty)
          const MessageView(
            icon: Icons.fitness_center_outlined,
            title: 'No workouts yet',
            message: 'Start a workout or log a past one. It will appear here.',
          )
        else ...[
          for (final w in data.workouts)
            InfoCard(
              key: ValueKey(w.id),
              title: w.displayTitle,
              subtitle: _describe(w, data.today),
              onTap: () => context.push('/workouts/log?id=${w.id}'),
            ),
          Text('Tap a workout to view or edit.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ];

  String _describe(Workout w, String today) => [
        formatDay(w.date, today),
        if (w.minutes > 0) '${w.minutes} min',
        w.type == WorkoutType.timed
            ? 'Timed activity'
            : plural(w.exercises.length, 'exercise'),
        if (w.pendingSync) 'Pending sync',
      ].join(' | ');
}
