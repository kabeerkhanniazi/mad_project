/// S04 Workout log: record a live session, enter a past workout, or edit a
/// saved one.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../data/local_store.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import 'workout_log_controller.dart';

class WorkoutLogScreen extends ConsumerStatefulWidget {
  const WorkoutLogScreen({super.key, this.mode, this.workoutId});

  /// 'live' or 'past' for a new workout.
  final String? mode;

  /// Set when editing a saved workout.
  final String? workoutId;

  @override
  ConsumerState<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends ConsumerState<WorkoutLogScreen> {
  final _title = TextEditingController();
  Timer? _ticker;
  var _opened = false;
  var _saving = false;

  /// Changes when rows are added or removed, so the text fields rebuild
  /// from the data instead of keeping the text of a row that moved.
  var _layoutVersion = 0;

  WorkoutLogController get _controller =>
      ref.read(workoutLogProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Providers must not change while the first frame is being built.
    Future.microtask(() {
      if (!mounted) return;
      _controller.open(mode: widget.mode, workoutId: widget.workoutId);
      _title.text = ref.read(workoutLogProvider)?.workout.title ?? '';
      setState(() => _opened = true);
    });
    // Redraws the elapsed time once a second.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (ref.read(workoutLogProvider)?.isRunning ?? false)) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _title.dispose();
    super.dispose();
  }

  void _relayout(VoidCallback change) {
    change();
    setState(() => _layoutVersion++);
  }

  Future<void> _addExercise() async {
    final picked = await context.push<WorkoutExercise>('/exercises');
    if (picked != null) _relayout(() => _controller.addExercise(picked));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await _controller.save();
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      showSnack(context, error);
      return;
    }
    showSnack(context, 'Workout saved');
    context.go('/workouts');
  }

  Future<void> _discard() async {
    final ok = await confirm(
      context,
      title: 'Discard draft?',
      message: 'Everything entered for this workout will be removed.',
      action: 'Discard',
    );
    if (!ok || !mounted) return;
    await _controller.discard();
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete workout?',
      message: 'This removes the workout from your history, charts and '
          'weekly totals.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    await _controller.delete();
    if (!mounted) return;
    showSnack(context, 'Workout deleted');
    context.pop();
  }

  /// Leaving keeps a new draft. Unsaved edits to a saved workout need a
  /// confirmation, because they are not kept.
  Future<void> _onBack() async {
    if (_controller.hasUnsavedEdits) {
      final ok = await confirm(
        context,
        title: 'Leave without saving?',
        message: 'Your changes to this workout will be lost.',
        action: 'Leave',
      );
      if (!ok) return;
    }
    if (mounted) context.pop();
  }

  Future<void> _pickDate(Workout w) async {
    final now = ref.read(clockProvider)();
    final date = await showDatePicker(
      context: context,
      initialDate: w.startedAt,
      firstDate: DateTime(now.year - 5),
      lastDate: now, // A workout cannot be logged in the future.
    );
    if (date == null) return;
    _controller.setStart(DateTime(date.year, date.month, date.day,
        w.startedAt.hour, w.startedAt.minute));
  }

  Future<void> _pickTime(Workout w) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(w.startedAt),
    );
    if (time == null) return;
    final s = w.startedAt;
    _controller
        .setStart(DateTime(s.year, s.month, s.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(workoutLogProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workout log'),
          actions: [
            if (draft != null && draft.mode == LogMode.edit)
              IconButton(
                tooltip: 'Delete workout',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              )
            else if (draft != null)
              IconButton(
                tooltip: 'Discard draft',
                icon: const Icon(Icons.delete_outline),
                onPressed: _discard,
              ),
          ],
        ),
        body: !_opened
            ? const Center(child: CircularProgressIndicator())
            : draft == null
                ? const Padding(
                    padding: pagePadding,
                    child: MessageView(
                      title: 'Workout not found',
                      message: 'It may have been deleted.',
                    ),
                  )
                : _form(context, draft),
      ),
    );
  }

  Widget _form(BuildContext context, WorkoutDraft draft) {
    final theme = Theme.of(context);
    final w = draft.workout;
    final today = ref.watch(todayProvider);
    final now = ref.read(clockProvider)();

    return ListView(
      padding: pagePadding,
      children: [
        if (_controller.restoredDraft)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Continuing your saved draft.',
                style: theme.textTheme.bodySmall),
          ),
        if (draft.mode != LogMode.edit) ...[
          SegmentedButton<LogMode>(
            segments: const [
              ButtonSegment(value: LogMode.live, label: Text('Live session')),
              ButtonSegment(value: LogMode.past, label: Text('Past workout')),
            ],
            selected: {draft.mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) =>
                _relayout(() => _controller.setMode(s.first)),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          key: const Key('workout-title'),
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              labelText: 'Workout title', hintText: 'Full-body workout'),
          onChanged: _controller.setTitle,
        ),
        const SizedBox(height: 12),
        SegmentedButton<WorkoutType>(
          segments: const [
            ButtonSegment(
                value: WorkoutType.strength, label: Text('Exercises and sets')),
            ButtonSegment(
                value: WorkoutType.timed, label: Text('Timed activity')),
          ],
          selected: {w.type},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              _relayout(() => _controller.setType(s.first)),
        ),
        const SizedBox(height: 16),
        if (draft.mode == LogMode.live) ...[
          Text(
            'Today | ${formatClock(draft.elapsedSeconds(now))} elapsed',
            key: const Key('workout-elapsed'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: Icon(draft.isRunning ? Icons.pause : Icons.play_arrow),
            label: Text(draft.isRunning ? 'Pause' : 'Resume'),
            onPressed: () => setState(
                draft.isRunning ? _controller.pause : _controller.resume),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(formatDay(w.date, today)),
                  onPressed: () => _pickDate(w),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(formatTime(w.startedAt)),
                  onPressed: () => _pickTime(w),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('duration-$_layoutVersion'),
            initialValue: w.minutes == 0 ? '' : '${w.minutes}',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              labelText: w.type == WorkoutType.timed
                  ? 'Duration (minutes)'
                  : 'Duration (minutes, optional)',
            ),
            onChanged: (v) =>
                _controller.setDurationMinutes(int.tryParse(v) ?? 0),
          ),
        ],
        const SizedBox(height: 20),
        if (w.type == WorkoutType.strength) ...[
          for (var i = 0; i < w.exercises.length; i++)
            _ExerciseEditor(
              key: ValueKey('exercise-$i-$_layoutVersion'),
              exercise: w.exercises[i],
              onRemove: () => _relayout(() => _controller.removeExercise(i)),
              onAddSet: () => _relayout(() => _controller.addSet(i)),
              onRemoveSet: (s) =>
                  _relayout(() => _controller.removeSet(i, s)),
              onChanged: (s, value) => _controller.updateSet(i, s, value),
            ),
          OutlinedButton.icon(
            key: const Key('add-exercise'),
            icon: const Icon(Icons.add),
            label: const Text('Add exercise'),
            onPressed: _addExercise,
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(
          key: const Key('save-workout'),
          onPressed: _saving ? null : _save,
          child: Text(draft.mode == LogMode.edit
              ? 'Save changes'
              : 'Finish and save'),
        ),
        const SizedBox(height: 12),
        Text(
          draft.mode == LogMode.edit
              ? 'Changes update your charts and weekly totals.'
              : 'Leaving this screen keeps your draft.',
          style: theme.textTheme.bodySmall,
        ),
        if (w.pendingSync)
          Text('Pending sync', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// One exercise with its rows of sets.
class _ExerciseEditor extends StatelessWidget {
  const _ExerciseEditor({
    super.key,
    required this.exercise,
    required this.onRemove,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onChanged,
  });

  final WorkoutExercise exercise;
  final VoidCallback onRemove;
  final VoidCallback onAddSet;
  final void Function(int set) onRemoveSet;
  final void Function(int set, ExerciseSet value) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final decimal = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(exercise.name,
                      style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Remove exercise',
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 32, child: Text('Set')),
                const Expanded(child: Text('Reps')),
                const SizedBox(width: 8),
                const Expanded(child: Text('kg (optional)')),
                const SizedBox(width: 48, child: Text('Done')),
                const SizedBox(width: 40),
              ].map((w) => DefaultTextStyle.merge(
                  style: theme.textTheme.labelMedium, child: w)).toList(),
            ),
            const SizedBox(height: 4),
            for (var s = 0; s < exercise.sets.length; s++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 32, child: Text('${s + 1}')),
                    Expanded(
                      child: TextFormField(
                        key: Key('reps-$s'),
                        initialValue: exercise.sets[s].reps == 0
                            ? ''
                            : '${exercise.sets[s].reps}',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          ...digits,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: const InputDecoration(isDense: true),
                        onChanged: (v) => onChanged(
                            s,
                            exercise.sets[s]
                                .copyWith(reps: int.tryParse(v) ?? 0)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        key: Key('kg-$s'),
                        initialValue: _weightText(exercise.sets[s].weightKg),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          ...decimal,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(isDense: true),
                        onChanged: (v) => onChanged(
                            s,
                            exercise.sets[s].withWeight(
                                double.tryParse(v.replaceAll(',', '.')))),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Checkbox(
                        key: Key('done-$s'),
                        value: exercise.sets[s].done,
                        onChanged: (v) => onChanged(
                            s, exercise.sets[s].copyWith(done: v ?? false)),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: exercise.sets.length > 1
                          ? IconButton(
                              tooltip: 'Remove set',
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 20),
                              onPressed: () => onRemoveSet(s),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add set'),
              onPressed: onAddSet,
            ),
          ],
        ),
      ),
    );
  }

  static String _weightText(double? kg) {
    if (kg == null) return '';
    return kg == kg.roundToDouble() ? '${kg.round()}' : '$kg';
  }
}
