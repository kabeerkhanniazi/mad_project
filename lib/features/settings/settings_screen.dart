/// S12 Settings and profile: targets, reminders, permissions, account.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../data/repositories.dart';
import '../../providers.dart';
import '../../services/step_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  var _target = 3;
  var _reminder = false;
  var _reminderMinutes = 19 * 60;
  var _loaded = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Copies the saved profile into the form once it has arrived.
  void _loadOnce() {
    final profile = ref.read(profileProvider).value;
    if (_loaded || profile == null) return;
    _loaded = true;
    _name.text = profile.displayName;
    _target = profile.weeklyWorkoutTarget.clamp(1, 14);
    _reminder = profile.dailyReminderEnabled;
    _reminderMinutes = profile.dailyReminderMinutes;
  }

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
    final profile = ref.read(profileProvider).value;
    if (profile == null) return;
    final notifications = ref.read(notificationServiceProvider);

    // The reminder needs notification access. If it is refused the switch
    // goes back off and everything else is still saved.
    var refused = false;
    if (_reminder && !await notifications.requestPermission()) {
      refused = true;
      setState(() => _reminder = false);
    }
    try {
      if (_reminder) {
        await notifications.scheduleDailyReminder(_reminderMinutes);
      } else {
        await notifications.cancelDailyReminder();
      }
    } catch (_) {
      // A scheduling problem must not block saving preferences.
    }

    await ref.read(backendProvider).profiles.saveProfile(profile.copyWith(
          displayName: _name.text.trim(),
          weeklyWorkoutTarget: _target,
          dailyReminderEnabled: _reminder,
          dailyReminderMinutes: _reminderMinutes,
        ));
    if (!mounted) return;
    showSnack(
      context,
      refused
          ? 'Saved. The reminder is off because notifications are not '
              'allowed for this app.'
          : 'Preferences saved',
    );
  }

  Future<void> _signOut() async {
    await ref.read(stepControllerProvider.notifier).flush();
    try {
      // Reminders belong to the account, so they stop at sign-out.
      await ref.read(notificationServiceProvider).cancelAll();
    } catch (_) {}
    await ref.read(backendProvider).auth.signOut();
  }

  Future<void> _deleteAccount() async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _DeleteAccountDialog(),
    );
    if (password == null || !mounted) return;

    final backend = ref.read(backendProvider);
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    try {
      // Checked first, so a wrong password deletes nothing.
      await backend.auth.reauthenticate(password);
      await backend.profiles.deleteAllData(uid);
      await ref.read(localStoreProvider).clearUser(uid);
      try {
        await ref.read(notificationServiceProvider).cancelAll();
      } catch (_) {}
      await backend.auth.deleteUser();
    } on AuthFailure catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (_) {
      if (mounted) {
        showSnack(context,
            'Could not delete the account. Check your connection and retry.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider);
    final steps = ref.watch(stepControllerProvider);
    final email = ref.watch(authStateProvider).value?.email ?? '';
    _loadOnce();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & profile')),
      body: !profile.hasValue
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: pagePadding,
              children: [
                if (email.isNotEmpty) ...[
                  Text('Signed in as $email',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                ],
                TextField(
                  key: const Key('settings-name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: 'Display name'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  key: const Key('settings-target'),
                  initialValue: _target,
                  decoration: const InputDecoration(
                      labelText: 'Weekly workout target'),
                  items: [
                    for (var n = 1; n <= 14; n++)
                      DropdownMenuItem(
                          value: n, child: Text(plural(n, 'session'))),
                  ],
                  onChanged: (v) => setState(() => _target = v ?? _target),
                ),
                const SizedBox(height: 16),
                const Text('Week begins: Monday'),
                const SizedBox(height: 6),
                Text('Timezone: ${DateTime.now().timeZoneName} (from this phone)'),
                const SizedBox(height: 6),
                const Text('Units: kg'),
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const Key('settings-reminder'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Daily reminder'),
                  subtitle: const Text(
                      'A notification to check your steps and habits'),
                  value: _reminder,
                  onChanged: (v) => setState(() => _reminder = v),
                ),
                if (_reminder)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(
                        'Reminder time: ${formatMinutes(_reminderMinutes)}'),
                    onPressed: _pickTime,
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('settings-save'),
                  onPressed: _save,
                  child: const Text('Save preferences'),
                ),
                const SizedBox(height: 24),
                Text('Permissions and privacy',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                InfoCard(
                  title: 'Step tracking: ${_stepLabel(steps.status)}',
                  subtitle: 'Uses the activity permission. '
                      'Refusing it never blocks workouts or habits.',
                  onTap: () => context.push('/steps'),
                ),
                OutlinedButton(
                  onPressed:
                      ref.read(stepControllerProvider.notifier).openSettings,
                  child: const Text('Open system settings for this app'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your records are private to your account. '
                  'Exercise information comes from wger (wger.de) under the '
                  'CC-BY-SA licence.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                const DisclaimerText(),
                const SizedBox(height: 16),
                const Divider(),
                TextButton(
                  key: const Key('sign-out'),
                  onPressed: _signOut,
                  child: const Text('Sign out'),
                ),
                TextButton(
                  onPressed: _deleteAccount,
                  style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error),
                  child: const Text('Delete account and data'),
                ),
              ],
            ),
    );
  }

  static String _stepLabel(StepStatus status) => switch (status) {
        StepStatus.tracking => 'on',
        StepStatus.unavailable => 'not available on this device',
        StepStatus.denied ||
        StepStatus.permanentlyDenied =>
          'off (access not allowed)',
        _ => 'off',
      };
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Delete account and data?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently removes your account, workouts, habits, '
              'step history and settings. It cannot be undone.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('delete-password'),
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Enter your password to confirm'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              if (_password.text.isNotEmpty) {
                Navigator.pop(context, _password.text);
              }
            },
            child: const Text('Delete everything'),
          ),
        ],
      );
}
