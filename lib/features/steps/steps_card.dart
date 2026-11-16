/// The steps card on Home. It is the only part of Home that changes when
/// activity access is denied.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../providers.dart';
import '../../services/step_service.dart';

class StepsCard extends ConsumerWidget {
  const StepsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(stepControllerProvider);
    final goal = ref.watch(profileProvider).value?.stepGoal ?? 8000;
    void open() => context.push('/steps');

    return switch (view.status) {
      StepStatus.starting => const SkeletonCard(),
      StepStatus.tracking => InfoCard(
          title: 'Steps: ${formatCount(view.steps)} / ${formatCount(goal)}',
          subtitle: view.steps >= goal
              ? 'Daily goal reached'
              : 'Open steps and daily goal',
          onTap: open,
          child: LinearProgressIndicator(
            value: (view.steps / goal).clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      StepStatus.off => InfoCard(
          title: 'Step tracking is off',
          subtitle: 'Set up step tracking',
          onTap: open,
        ),
      StepStatus.denied || StepStatus.permanentlyDenied => InfoCard(
          title: 'Step tracking is off',
          subtitle: 'Activity access was not allowed. '
              'Workouts and habits still work.',
          onTap: open,
        ),
      StepStatus.unavailable => InfoCard(
          title: 'Step counting is unavailable on this device',
          subtitle: 'Workouts and habits still work.',
          onTap: open,
        ),
    };
  }
}
