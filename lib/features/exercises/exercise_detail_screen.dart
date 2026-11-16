/// S06 Exercise detail: read about an exercise before adding it.
library;

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets.dart';
import '../../domain/models.dart';

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});
  final Exercise exercise;

  Future<void> _openSource(BuildContext context) async {
    final opened = await launchUrl(Uri.parse(exercise.sourceUrl),
        mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showSnack(context, 'Could not open the page.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = exercise;
    final attribution = [
      'Source: wger.de',
      if (e.author.isNotEmpty) 'Author: ${e.author}',
      if (e.license.isNotEmpty) 'Licence: ${e.license}',
    ].join('. ');

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise detail')),
      body: ListView(
        padding: pagePadding,
        children: [
          Text(e.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: e.imageUrl == null
                  ? const _ImagePlaceholder('No image for this exercise')
                  : Image.network(
                      e.imageUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const _ImagePlaceholder('Loading image...'),
                      errorBuilder: (_, _, _) =>
                          const _ImagePlaceholder('Image unavailable'),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _Fact('Category', e.category),
          _Fact('Muscles', e.muscles.join(', ')),
          _Fact('Equipment', e.equipment.join(', ')),
          const SizedBox(height: 12),
          Text(
            e.description.isEmpty
                ? 'No description is provided for this exercise.'
                : e.description,
          ),
          const SizedBox(height: 16),
          Text(attribution, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('add-to-workout'),
            onPressed: () => context.pop(e),
            child: const Text('Add to workout'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _openSource(context),
            child: const Text('View source'),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: value.isEmpty ? 'Not listed' : value),
        ])),
      );
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, color: scheme.outline, size: 36),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: scheme.outline)),
          ],
        ),
      ),
    );
  }
}
