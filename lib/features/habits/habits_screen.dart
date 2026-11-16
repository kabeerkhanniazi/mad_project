/// S07 Habits: tick off scheduled habits and see each habit's streak.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../providers.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  /// Days before today being shown. 0 is today.
  var _daysBack = 0;

  Future<void> _toggle(Habit habit, String date, bool done) async {
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    await ref
        .read(backendProvider)
        .habits
        .setCompleted(uid, habit.id, date, done);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        actions: const [SettingsAction()],
      ),
      body: ListView(
        padding: pagePadding,
        children: switch (data) {
          AsyncData(:final value) => _content(context, value),
          AsyncError() => [
              MessageView(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load habits',
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

  List<Widget> _content(BuildContext context, AppData data) {
    final theme = Theme.of(context);
    final date = addDays(data.today, -_daysBack);
    final due = data.habitsDueOn(date);
    final done = due.where((h) => data.isDone(h, date)).length;

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous day',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _daysBack++),
          ),
          SizedBox(
            width: 140,
            child: Text(formatDay(date, data.today),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
          ),
          IconButton(
            tooltip: 'Next day',
            icon: const Icon(Icons.chevron_right),
            // Habits cannot be ticked for days that have not happened.
            onPressed:
                _daysBack == 0 ? null : () => setState(() => _daysBack--),
          ),
        ],
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        key: const Key('add-habit'),
        icon: const Icon(Icons.add),
        label: const Text('Add habit'),
        onPressed: () => context.push('/habits/edit'),
      ),
      const SizedBox(height: 16),
      if (data.activeHabits.isEmpty)
        const MessageView(
          icon: Icons.check_circle_outline,
          title: 'No habits yet',
          message: 'Add a habit to start a streak. '
              'You can write your own or pick a fitness template.',
        )
      else if (due.isEmpty)
        const MessageView(
          title: 'Nothing scheduled for this day',
          message: 'Days without a scheduled habit do not affect streaks.',
        )
      else ...[
        for (final h in due)
          Card(
            key: ValueKey(h.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    key: Key('habit-check-${h.name}'),
                    value: data.isDone(h, date),
                    onChanged: (v) => _toggle(h, date, v ?? false),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.name, style: theme.textTheme.titleMedium),
                        Text(
                          '${data.streakOf(h)}-day streak | ${h.scheduleLabel}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/habits/edit?id=${h.id}'),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text('$done of ${due.length} scheduled habits complete',
            style: theme.textTheme.bodyMedium),
      ],
      if (data.activeHabits.length > due.length && due.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Not scheduled for this day', style: theme.textTheme.titleSmall),
      ],
      if (data.activeHabits.length > due.length)
        for (final h in data.activeHabits)
          if (!h.isScheduledOn(date))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(h.name),
              subtitle: Text(h.scheduleLabel),
              trailing: TextButton(
                onPressed: () => context.push('/habits/edit?id=${h.id}'),
                child: const Text('Edit'),
              ),
            ),
    ];
  }
}
