/// S05 Exercise catalogue: search the wger REST API and pick an exercise.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../data/wger_api.dart';
import '../../domain/models.dart';
import '../../providers.dart';

class CatalogueState {
  const CatalogueState({
    this.query = const ExerciseQuery(),
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = false,
    this.fromCache = false,
    this.error,
  });

  final ExerciseQuery query;
  final List<Exercise> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final bool fromCache;
  final String? error;
}

class CatalogueController extends Notifier<CatalogueState> {
  /// Number of the latest request. An answer to an older request is ignored,
  /// so a slow response cannot overwrite a newer search.
  var _request = 0;

  /// How many API rows have been read; the next page starts here.
  var _offset = 0;

  @override
  CatalogueState build() {
    Future.microtask(() => search(const ExerciseQuery()));
    return const CatalogueState();
  }

  Future<void> search(ExerciseQuery query) async {
    final request = ++_request;
    _offset = 0;
    state = CatalogueState(query: query);
    try {
      final page = await ref.read(wgerApiProvider).fetchExercises(query);
      if (request != _request || !ref.mounted) return;
      _offset = WgerApi.pageSize;
      state = CatalogueState(
        query: query,
        items: page.items,
        loading: false,
        hasMore: page.hasMore,
        fromCache: page.fromCache,
      );
    } on WgerException catch (e) {
      if (request != _request || !ref.mounted) return;
      state = CatalogueState(query: query, loading: false, error: e.message);
    }
  }

  Future<void> retry() => search(state.query);

  Future<void> loadMore() async {
    final current = state;
    if (current.loading || current.loadingMore || !current.hasMore) return;
    final request = ++_request;
    state = CatalogueState(
      query: current.query,
      items: current.items,
      loading: false,
      loadingMore: true,
      hasMore: true,
      fromCache: current.fromCache,
    );
    try {
      final page = await ref
          .read(wgerApiProvider)
          .fetchExercises(current.query, offset: _offset);
      if (request != _request || !ref.mounted) return;
      _offset += WgerApi.pageSize;
      state = CatalogueState(
        query: current.query,
        items: [...current.items, ...page.items],
        loading: false,
        hasMore: page.hasMore,
        fromCache: current.fromCache || page.fromCache,
      );
    } on WgerException catch (e) {
      if (request != _request || !ref.mounted) return;
      state = CatalogueState(
        query: current.query,
        items: current.items,
        loading: false,
        hasMore: true,
        fromCache: current.fromCache,
        error: e.message,
      );
    }
  }
}

final catalogueProvider =
    NotifierProvider.autoDispose<CatalogueController, CatalogueState>(
        CatalogueController.new);

final exerciseCategoriesProvider = FutureProvider<List<WgerOption>>(
    (ref) => ref.watch(wgerApiProvider).fetchCategories());

final exerciseEquipmentProvider = FutureProvider<List<WgerOption>>((ref) async {
  final options = await ref.watch(wgerApiProvider).fetchEquipment();
  return [
    for (final o in options) WgerOption(o.id, WgerApi.equipmentLabel(o.name)),
  ];
});

class ExerciseCatalogueScreen extends ConsumerStatefulWidget {
  const ExerciseCatalogueScreen({super.key});

  @override
  ConsumerState<ExerciseCatalogueScreen> createState() =>
      _ExerciseCatalogueScreenState();
}

class _ExerciseCatalogueScreenState
    extends ConsumerState<ExerciseCatalogueScreen> {
  Timer? _debounce;

  CatalogueController get _controller => ref.read(catalogueProvider.notifier);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Waits until typing pauses, so each letter does not send a request.
  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _controller.search(ref.read(catalogueProvider).query.copyWith(search: text));
    });
  }

  void _choose(WorkoutExercise exercise) => context.pop(exercise);

  Future<void> _openDetail(Exercise exercise) async {
    final added =
        await context.push<Exercise>('/exercises/detail', extra: exercise);
    if (added != null && mounted) {
      _choose(WorkoutExercise(
        exerciseId: added.id,
        name: added.name,
        category: added.category,
      ));
    }
  }

  Future<void> _addManual() async {
    final controller = TextEditingController(
        text: ref.read(catalogueProvider).query.search.trim());
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual exercise'),
        content: TextField(
          key: const Key('manual-exercise-name'),
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Exercise name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add to workout'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && mounted) {
      _choose(WorkoutExercise(name: name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogueProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Find an exercise')),
      body: ListView(
        padding: pagePadding,
        children: [
          TextField(
            key: const Key('exercise-search'),
            decoration: const InputDecoration(
              labelText: 'Search',
              hintText: 'Exercise name',
              prefixIcon: Icon(Icons.search),
            ),
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FilterMenu(
                  label: 'Equipment',
                  options: ref.watch(exerciseEquipmentProvider).value,
                  selected: state.query.equipmentId,
                  onSelected: (id) =>
                      _controller.search(state.query.withEquipment(id)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FilterMenu(
                  label: 'Category',
                  options: ref.watch(exerciseCategoriesProvider).value,
                  selected: state.query.categoryId,
                  onSelected: (id) =>
                      _controller.search(state.query.withCategory(id)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Exercise catalogue', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (state.fromCache)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Offline: showing saved results.',
                  style: theme.textTheme.bodySmall),
            ),
          if (state.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null && state.items.isEmpty)
            MessageView(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load exercises',
              message: state.error,
              actions: [
                FilledButton(
                  onPressed: _controller.retry,
                  child: const Text('Try again'),
                ),
              ],
            )
          else if (state.items.isEmpty && !state.hasMore)
            const MessageView(
              icon: Icons.search_off,
              title: 'No exercises found',
              message: 'Try another name or filter, '
                  'or add the exercise by hand.',
            )
          else ...[
            for (final e in state.items)
              InfoCard(
                key: ValueKey(e.id),
                title: e.name,
                subtitle: e.subtitle,
                onTap: () => _openDetail(e),
              ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(state.error!,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            if (state.loadingMore)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.hasMore)
              OutlinedButton(
                onPressed: _controller.loadMore,
                child: const Text('Load more'),
              ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('manual-exercise'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Add a manual exercise'),
            onPressed: _addManual,
          ),
          const SizedBox(height: 8),
          Text('Exercise data: wger (wger.de), licensed CC-BY-SA.',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// A button that opens a list of filter options. "Any" clears the filter.
class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<WgerOption>? options;
  final int? selected;
  final void Function(int? id) onSelected;

  @override
  Widget build(BuildContext context) {
    var current = 'Any';
    for (final o in options ?? const <WgerOption>[]) {
      if (o.id == selected) current = o.name;
    }
    return PopupMenuButton<int>(
      enabled: options != null,
      // 0 stands for "Any"; wger IDs start at 1.
      onSelected: (id) => onSelected(id == 0 ? null : id),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0, child: Text('Any')),
        for (final o in options!)
          PopupMenuItem(value: o.id, child: Text(o.name)),
      ],
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: Text(current, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
