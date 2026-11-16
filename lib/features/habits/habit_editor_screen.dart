/// S08 Habit editor: create a custom habit, start from a fitness template,
/// or change or archive an existing habit.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../providers.dart';

class HabitEditorScreen extends ConsumerStatefulWidget {
  const HabitEditorScreen({super.key, this.habitId});

  /// Set when editing an existing habit.
  final String? habitId;

  @override
  ConsumerState<HabitEditorScreen> createState() => _HabitEditorScreenState();
}

class _HabitEditorScreenState extends ConsumerState<HabitEditorScreen> {
  final _name = TextEditingController();
  var _weekdays = <int>{1, 2, 3, 4, 5, 6, 7};
  var _remind = false;
  var _reminderMinutes = 19 * 60;
  var _fromTemplate = false;
  Habit? _existing;
  String? _nameError;
  String? _daysError;

  @override
  void initState() {
    super.initState();
    final habits = ref.read(habitsProvider).value ?? const <Habit>[];
    for (final h in habits) {
      if (h.id == widget.habitId) {
        _existing = h;
        _name.text = h.name;
        _weekdays = {...h.weekdays};
        _remind = h.reminderEnabled;
        _reminderMinutes = h.reminderMinutes;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _useTemplate(({String name, Set<int> weekdays}) template) =>
      setState(() {
        _name.text = template.name;
        _weekdays = {...template.weekdays};
        _nameError = null;
        _daysError = null;
      });

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: _reminderMinutes ~/ 60, minute: _reminderMinutes % 60),
    );
    if (time != null) {
      setState(() => _reminderMinutes = time.hour * 60 + time.minute);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Give the habit a name' : null;
      _daysError = _weekdays.isEmpty ? 'Choose at least one day' : null;
    });
    final uid = ref.read(uidProvider);
    if (_nameError != null || _daysError != null || uid == null) return;

    final repo = ref.read(backendProvider).habits;
    final notifications = ref.read(notificationServiceProvider);

    // A reminder needs notification access. Without it the habit is still
    // saved, only without the reminder.
    var remind = _remind;
    var reminderRefused = false;
    if (remind && !await notifications.requestPermission()) {
      remind = false;
      reminderRefused = true;
    }

    final existing = _existing;
    final habit = existing == null
        ? Habit(
            id: repo.newId(uid),
            name: name,
            weekdays: _weekdays,
            reminderEnabled: remind,
            reminderMinutes: _reminderMinutes,
            startDate: ref.read(todayProvider),
          )
        : existing.copyWith(
            name: name,
            weekdays: _weekdays,
            reminderEnabled: remind,
            reminderMinutes: _reminderMinutes,
          );

    await repo.saveHabit(uid, habit);
    try {
      await notifications.syncHabitReminder(habit);
    } catch (_) {
      // A scheduling problem must not undo the saved habit.
    }
    if (!mounted) return;
    showSnack(
      context,
      reminderRefused
          ? 'Habit saved without a reminder, because notifications are off.'
          : 'Habit saved',
    );
    context.pop();
  }

  Future<void> _archive() async {
    final existing = _existing;
    final uid = ref.read(uidProvider);
    if (existing == null || uid == null) return;
    final ok = await confirm(
      context,
      title: 'Archive habit?',
      message: 'It leaves your list from today. Past completions are kept '
          'in your history and summaries.',
      action: 'Archive',
    );
    if (!ok) return;
    await ref
        .read(backendProvider)
        .habits
        .saveHabit(uid, existing.copyWith(archivedDate: ref.read(todayProvider)));
    try {
      await ref
          .read(notificationServiceProvider)
          .cancelHabitReminder(existing.id);
    } catch (_) {}
    if (!mounted) return;
    showSnack(context, 'Habit archived');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = _existing != null;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit habit' : 'Create habit')),
      body: ListView(
        padding: pagePadding,
        children: [
          if (!editing) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Custom')),
                ButtonSegment(value: true, label: Text('Fitness template')),
              ],
              selected: {_fromTemplate},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  setState(() => _fromTemplate = s.first),
            ),
            const SizedBox(height: 16),
          ],
          if (_fromTemplate && !editing) ...[
            Text('Pick a template, then change anything you like.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in fitnessHabitTemplates)
                  ActionChip(
                    label: Text(t.name),
                    onPressed: () => _useTemplate(t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            key: const Key('habit-name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Habit name',
              hintText: 'Read 10 pages',
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 20),
          Text('Repeat on', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var day = 1; day <= 7; day++)
                _DayToggle(
                  label: weekdayLetters[day - 1],
                  tooltip: weekdayShort[day - 1],
                  selected: _weekdays.contains(day),
                  onTap: () => setState(() {
                    _weekdays.contains(day)
                        ? _weekdays.remove(day)
                        : _weekdays.add(day);
                    _daysError = null;
                  }),
                ),
            ],
          ),
          if (_daysError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_daysError!,
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 12),
          Text('Completion: one check per scheduled day',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Remind me'),
            value: _remind,
            onChanged: (v) => setState(() => _remind = v ?? false),
          ),
          if (_remind)
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule, size: 18),
              label:
                  Text('Reminder time: ${formatMinutes(_reminderMinutes)}'),
              onPressed: _pickTime,
            ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('save-habit'),
            onPressed: _save,
            child: const Text('Save habit'),
          ),
          if (editing) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _archive,
              child: const Text('Archive habit'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 40,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
