/// Widgets and formatters shared by several screens.
library;

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'app_config.dart';
import 'dates.dart';

final _number = NumberFormat.decimalPattern('en');

/// 6300 -> "6,300".
String formatCount(int n) => _number.format(n);

/// 754 seconds -> "00:12:34".
String formatClock(int seconds) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(seconds ~/ 3600)}:${two(seconds % 3600 ~/ 60)}:${two(seconds % 60)}';
}

/// 1140 -> "19:00".
String formatMinutes(int minutesOfDay) =>
    '${(minutesOfDay ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutesOfDay % 60).toString().padLeft(2, '0')}';

/// "Today", "Yesterday" or "Mon 9 Nov".
String formatDay(String date, String today) {
  if (date == today) return 'Today';
  if (date == addDays(today, -1)) return 'Yesterday';
  return DateFormat('EEE d MMM').format(parseDateKey(date));
}

String formatTime(DateTime t) => DateFormat('HH:mm').format(t);

String plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// A tappable card with a title and a line of detail.
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.child,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: theme.textTheme.bodyMedium),
                    ],
                    if (child != null) ...[
                      const SizedBox(height: 12),
                      child!,
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// A grey block shown in place of a card while data loads.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double widthFactor) => FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [bar(0.5), const SizedBox(height: 10), bar(0.8)],
        ),
      ),
    );
  }
}

/// A message with optional actions, used for empty and error states.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.actions = const [],
  });

  final String title;
  final String? message;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
          ],
          Text(title,
              style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!,
                style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
          if (actions.isNotEmpty) const SizedBox(height: 16),
          for (final action in actions)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: action),
        ],
      ),
    );
  }
}

/// The health disclaimer required by the course brief.
class DisclaimerText extends StatelessWidget {
  const DisclaimerText({super.key});

  @override
  Widget build(BuildContext context) => Text(
        AppConfig.disclaimer,
        style: Theme.of(context).textTheme.bodySmall,
      );
}

/// The Settings button shown on every root tab.
class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Settings',
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => context.push('/settings'),
      );
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Asks the user to confirm something that cannot be undone.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

const pagePadding = EdgeInsets.fromLTRB(16, 8, 16, 24);
