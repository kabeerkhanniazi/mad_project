/// The frame around the four root tabs: bottom navigation, the demo-mode
/// banner, and the hooks that run when the app is paused or resumed.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../services/step_service.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  /// The account whose reminders were last put back on this phone.
  String? _remindersSyncedFor;

  /// Reminders are cancelled at sign-out and do not exist on a new phone, so
  /// they are scheduled again the first time an account's records arrive.
  Future<void> _restoreReminders(AppData data) async {
    if (_remindersSyncedFor == data.profile.uid) return;
    _remindersSyncedFor = data.profile.uid;
    final notifications = ref.read(notificationServiceProvider);
    try {
      if (data.profile.dailyReminderEnabled) {
        await notifications
            .scheduleDailyReminder(data.profile.dailyReminderMinutes);
      }
      for (final habit in data.activeHabits) {
        if (habit.reminderEnabled) await notifications.syncHabitReminder(habit);
      }
    } catch (_) {
      // Reminders are a convenience; a failure here must not disturb the app.
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final steps = ref.read(stepControllerProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      // The date or the permission may have changed while the app was away.
      ref.read(todayProvider.notifier).refresh();
      steps.refresh();
    } else if (state == AppLifecycleState.paused) {
      steps.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keeps step tracking alive on every tab, not only where it is shown.
    ref.watch(stepControllerProvider);
    ref.listen(appDataProvider, (_, next) {
      final data = next.value;
      if (data != null) _restoreReminders(data);
    });
    final isDemo = ref.watch(backendProvider).isDemo;

    return Scaffold(
      body: Column(
        children: [
          if (isDemo) const _DemoBanner(),
          Expanded(child: widget.shell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.shell.currentIndex,
        onDestinationSelected: (index) => widget.shell.goBranch(
          index,
          initialLocation: index == widget.shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'Workouts'),
          NavigationDestination(
              icon: Icon(Icons.check_circle_outline),
              selectedIcon: Icon(Icons.check_circle),
              label: 'Habits'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Progress'),
        ],
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            'Demo mode: nothing is saved to the cloud and data is lost '
            'when the app closes.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onTertiaryContainer),
          ),
        ),
      ),
    );
  }
}
