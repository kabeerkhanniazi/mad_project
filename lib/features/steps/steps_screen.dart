/// S09 Steps and daily goal: today's recorded steps, the daily target, and
/// every state of activity access.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import '../../services/step_service.dart';

const minStepGoal = 1000;
const maxStepGoal = 100000;

class StepsScreen extends ConsumerStatefulWidget {
  const StepsScreen({super.key});

  @override
  ConsumerState<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends ConsumerState<StepsScreen> {
  final _goal = TextEditingController();
  String? _goalError;

  @override
  void initState() {
    super.initState();
    _goal.text = '${ref.read(profileProvider).value?.stepGoal ?? 8000}';
  }

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  StepController get _steps => ref.read(stepControllerProvider.notifier);

  Future<void> _saveGoal() async {
    final goal = int.tryParse(_goal.text);
    if (goal == null || goal < minStepGoal || goal > maxStepGoal) {
      setState(() => _goalError = 'Enter a goal between '
          '${formatCount(minStepGoal)} and ${formatCount(maxStepGoal)}');
      return;
    }
    setState(() => _goalError = null);
    final profile = ref.read(profileProvider).value;
    final uid = ref.read(uidProvider);
    if (profile == null || uid == null) return;
    final backend = ref.read(backendProvider);
    await backend.profiles.saveProfile(profile.copyWith(stepGoal: goal));

    // The new goal applies from today. Earlier days keep the goal they had.
    final today = ref.read(todayProvider);
    final days = ref.read(stepDaysProvider).value ?? const <StepDay>[];
    for (final day in days) {
      if (day.date == today) {
        await backend.steps.saveDay(
            uid,
            StepDay(
              date: day.date,
              steps: day.steps,
              goal: goal,
              source: day.source,
              trackedFrom: day.trackedFrom,
            ));
      }
    }
    if (mounted) showSnack(context, 'Daily goal saved');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final view = ref.watch(stepControllerProvider);
    final goal = ref.watch(profileProvider).value?.stepGoal ?? 8000;
    final streak = ref.watch(appDataProvider).value?.currentStepStreak ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Steps & goal')),
      body: ListView(
        padding: pagePadding,
        children: [
          Text('Today', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (view.isTracking) ...[
            Text(
              '${formatCount(view.steps)} / ${formatCount(goal)}',
              key: const Key('steps-today'),
              style: theme.textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (view.steps / goal).clamp(0.0, 1.0),
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 12),
            Text(
              streak == 0
                  ? 'No goal streak yet'
                  : '$streak-day goal streak',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(view.steps >= goal
                ? 'Goal reached today.'
                : 'Today is still in progress.'),
          ] else
            Text(
              view.status == StepStatus.unavailable
                  ? 'Step counting is unavailable on this device'
                  : 'Step tracking is off',
              key: const Key('steps-off'),
              style: theme.textTheme.headlineSmall,
            ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('step-goal'),
            controller: _goal,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: 'Daily step goal',
              errorText: _goalError,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _saveGoal,
            child: const Text('Save goal'),
          ),
          const SizedBox(height: 20),
          ..._trackingSection(context, view),
          const SizedBox(height: 12),
          Text('Counts may be incomplete if tracking stops.',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  List<Widget> _trackingSection(BuildContext context, StepView view) {
    Widget continueWithout() => TextButton(
          onPressed: () => context.pop(),
          child: const Text('Continue without tracking'),
        );

    switch (view.status) {
      case StepStatus.starting:
        return const [SkeletonCard()];

      case StepStatus.tracking:
        final since = view.trackedFrom;
        return [
          InfoCard(
            title: 'Tracking: on',
            subtitle: [
              if (since != null) 'Recording since ${formatTime(since)} today.',
              view.source == StepSource.accelerometer
                  ? 'This phone has no step sensor, so the app counts steps '
                      'itself while it is open.'
                  : 'Steps taken while the app is closed are added when '
                      'you open it again.',
            ].join(' '),
            trailing: const SizedBox.shrink(),
          ),
          OutlinedButton(
            onPressed: _steps.disable,
            child: const Text('Turn off step tracking'),
          ),
        ];

      case StepStatus.off:
        return [
          const InfoCard(
            title: 'Tracking: off',
            subtitle: 'To count steps, the app needs access to your physical '
                'activity. It is used only for your step total.',
            trailing: SizedBox.shrink(),
          ),
          FilledButton(
            key: const Key('enable-steps'),
            onPressed: _steps.enable,
            child: const Text('Enable step tracking'),
          ),
          continueWithout(),
        ];

      case StepStatus.denied:
        return [
          const InfoCard(
            title: 'Activity access was not allowed',
            subtitle: 'Steps cannot be counted without it. Workouts, habits '
                'and summaries keep working.',
            trailing: SizedBox.shrink(),
          ),
          FilledButton(
            key: const Key('enable-steps'),
            onPressed: _steps.enable,
            child: const Text('Enable step tracking'),
          ),
          continueWithout(),
        ];

      case StepStatus.permanentlyDenied:
        return [
          const InfoCard(
            title: 'Activity access is blocked',
            subtitle: 'Allow "Physical activity" for this app in the system '
                'settings to count steps. Workouts, habits and summaries '
                'keep working.',
            trailing: SizedBox.shrink(),
          ),
          FilledButton(
            key: const Key('open-settings'),
            onPressed: _steps.openSettings,
            child: const Text('Open settings'),
          ),
          continueWithout(),
        ];

      case StepStatus.unavailable:
        return [
          const InfoCard(
            title: 'No step sensor found',
            subtitle: 'This device cannot count steps. Workouts, habits and '
                'summaries keep working.',
            trailing: SizedBox.shrink(),
          ),
          continueWithout(),
        ];
    }
  }
}
