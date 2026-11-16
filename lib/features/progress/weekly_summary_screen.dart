/// S11 Weekly summary: a week's totals and the change from the week before.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/widgets.dart';
import '../../domain/weekly_summary.dart';
import '../../providers.dart';

class WeeklySummaryScreen extends ConsumerStatefulWidget {
  const WeeklySummaryScreen({super.key});

  @override
  ConsumerState<WeeklySummaryScreen> createState() =>
      _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends ConsumerState<WeeklySummaryScreen> {
  /// Weeks before the current one. Starts at 1: the last completed week.
  var _weeksBack = 1;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly summary')),
      body: ListView(
        padding: pagePadding,
        children: switch (data) {
          AsyncData(:final value) => _content(context, value),
          AsyncError() => [
              MessageView(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load the summary',
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
      ),
    );
  }

  String _label(String weekStart) {
    if (_weeksBack == 0) return 'This week so far';
    if (_weeksBack == 1) return 'Last completed week';
    final format = DateFormat('d MMM');
    return '${format.format(parseDateKey(weekStart))} - '
        '${format.format(parseDateKey(addDays(weekStart, 6)))}';
  }

  List<Widget> _content(BuildContext context, AppData data) {
    final theme = Theme.of(context);
    final weekStart = addDays(data.thisWeek, -7 * _weeksBack);
    final summary = data.summaryFor(weekStart);
    final previousStart = addDays(weekStart, -7);
    final firstWeek = weekStartOf(data.firstRecordDate);
    // A week before the first record has nothing to compare with.
    final previous = previousStart.compareTo(firstWeek) < 0
        ? null
        : data.summaryFor(previousStart);
    final canGoBack = weekStart.compareTo(firstWeek) > 0;

    final daysInWeek =
        _weeksBack == 0 ? daysBetween(weekStart, data.today) + 1 : 7;
    final untracked = daysInWeek - summary.trackedDays;
    final percent = summary.habitPercent;

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Earlier week',
            icon: const Icon(Icons.chevron_left),
            onPressed: canGoBack ? () => setState(() => _weeksBack++) : null,
          ),
          SizedBox(
            width: 190,
            child: Text(_label(weekStart),
                key: const Key('summary-week'),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
          ),
          IconButton(
            tooltip: 'Later week',
            icon: const Icon(Icons.chevron_right),
            onPressed:
                _weeksBack == 0 ? null : () => setState(() => _weeksBack--),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (summary.isEmpty)
        const MessageView(
          title: 'Nothing recorded in this week',
          message: 'Workouts, steps and habits you record will be '
              'summarised here.',
        )
      else ...[
        InfoCard(
          title: 'Workouts: ${summary.workouts} / ${summary.workoutTarget}',
          subtitle: '${plural(summary.minutes, 'minute')} | '
              '${summary.targetMet ? 'Target achieved' : 'Target not reached'}',
        ),
        InfoCard(
          title: summary.trackedDays == 0
              ? 'Steps: not tracked'
              : 'Steps: ${formatCount(summary.steps)} recorded',
          subtitle: summary.trackedDays == 0
              ? 'No steps were recorded this week'
              : 'Goal met on ${summary.goalMetDays} of '
                  '${plural(summary.trackedDays, 'tracked day')}'
                  '${untracked > 0 ? ' | ${plural(untracked, 'day')} not tracked' : ''}',
        ),
        InfoCard(
          title: summary.habitsDue == 0
              ? 'Habits: none due'
              : 'Habits: ${summary.habitsDone} / ${summary.habitsDue} due',
          subtitle: percent == null
              ? 'No habits were scheduled this week'
              : '$percent% of scheduled entries completed',
        ),
      ],
      const SizedBox(height: 12),
      Text('Compared with the previous week',
          style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final line in compareWeeks(summary, previous))
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(line),
        ),
      const SizedBox(height: 16),
      Text(
        'Summaries use your recorded activity. Days without step tracking '
        'are labelled, not counted as zero.',
        style: theme.textTheme.bodySmall,
      ),
    ];
  }
}
