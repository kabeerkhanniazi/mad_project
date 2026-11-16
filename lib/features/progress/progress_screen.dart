/// S10 Progress: steps, workouts and habit completion for the week or month.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../providers.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  var _month = false;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: const [SettingsAction()],
      ),
      body: ListView(
        padding: pagePadding,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('This week')),
              ButtonSegment(value: true, label: Text('This month')),
            ],
            selected: {_month},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _month = s.first),
          ),
          const SizedBox(height: 16),
          ...switch (data) {
            AsyncData(:final value) => _content(context, value),
            AsyncError() => [
                MessageView(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load progress',
                  message: 'Check your connection and try again.',
                  actions: [
                    FilledButton(
                      onPressed: () => reloadAppData(ref),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ],
            _ => const [SkeletonCard(), SkeletonCard(), SkeletonCard()],
          },
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, AppData data) {
    final theme = Theme.of(context);
    final days = _month ? data.monthDays : weekDays(data.thisWeek);
    final summary = _month ? data.monthSummary : data.summaryFor(data.thisWeek);
    final period = _month ? 'this month' : 'this week';
    final percent = summary.habitPercent;

    return [
      Text('Step history', style: theme.textTheme.titleMedium),
      const SizedBox(height: 12),
      if (summary.trackedDays == 0)
        MessageView(
          icon: Icons.directions_walk,
          title: 'No steps recorded $period',
          message: 'Turn on step tracking to fill this chart.',
          actions: [
            OutlinedButton(
              onPressed: () => context.push('/steps'),
              child: const Text('Set up step tracking'),
            ),
          ],
        )
      else ...[
        SizedBox(
          height: 180,
          child: StepChart(
            days: days,
            stepDays: data.stepDays,
            goal: data.profile.stepGoal,
            today: data.today,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${formatCount(summary.steps)} steps on '
          '${plural(summary.trackedDays, 'tracked day')}. '
          'Days without recording are left empty.',
          style: theme.textTheme.bodySmall,
        ),
      ],
      const SizedBox(height: 16),
      InfoCard(
        title: _month
            ? 'Workouts: ${summary.workouts}'
            : 'Workouts: ${summary.workouts} / ${summary.workoutTarget}',
        subtitle: '${plural(summary.minutes, 'minute')} logged $period',
        onTap: () => context.go('/workouts'),
      ),
      InfoCard(
        title: summary.habitsDue == 0
            ? 'Habits: none due yet'
            : 'Habits: ${summary.habitsDone} / ${summary.habitsDue} due',
        subtitle: percent == null
            ? 'Scheduled habits will be counted here'
            : '$percent% of scheduled entries completed',
        onTap: () => context.go('/habits'),
      ),
      const SizedBox(height: 4),
      FilledButton(
        onPressed: () => context.push('/summary'),
        child: const Text('Open weekly summary'),
      ),
    ];
  }
}

/// A bar per day. A day with no recording has no bar at all, so "not
/// tracked" is never drawn as zero steps.
class StepChart extends StatelessWidget {
  const StepChart({
    super.key,
    required this.days,
    required this.stepDays,
    required this.goal,
    required this.today,
  });

  final List<String> days;
  final Map<String, StepDay> stepDays;
  final int goal;
  final String today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    final weekly = days.length <= 7;

    var highest = goal;
    for (final day in days) {
      final steps = stepDays[day]?.steps ?? 0;
      if (steps > highest) highest = steps;
    }

    return BarChart(
      BarChartData(
        maxY: highest * 1.15,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        // The dashed line marks the current daily goal.
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(
            y: goal.toDouble(),
            color: scheme.outline,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ]),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                final dayOfMonth = parseDateKey(days[i]).day;
                // A month has too many days to label each one.
                if (!weekly && dayOfMonth != 1 && dayOfMonth % 5 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    weekly
                        ? weekdayLetters[weekdayOf(days[i]) - 1]
                        : '$dayOfMonth',
                    style: labelStyle,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${formatDay(days[group.x], today)}\n'
              '${formatCount(rod.toY.round())} steps',
              labelStyle ?? const TextStyle(),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                if (stepDays[days[i]] case final day?)
                  BarChartRodData(
                    toY: day.steps.toDouble(),
                    width: weekly ? 18 : 6,
                    borderRadius: BorderRadius.circular(3),
                    color: day.goalMet ? scheme.primary : scheme.secondary
                        .withValues(alpha: 0.55),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
