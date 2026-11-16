/// S01 Account access: sign in, create an account, reset a password.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_config.dart';
import '../../core/widgets.dart';
import '../../data/repositories.dart';
import '../../domain/models.dart';
import '../../providers.dart';

String? validateEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) return 'Enter your email';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address';
  }
  return null;
}

String? validatePassword(String? value) {
  if ((value ?? '').isEmpty) return 'Enter your password';
  if (value!.length < 6) return 'Use at least 6 characters';
  return null;
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  var _creating = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final backend = ref.read(backendProvider);
    try {
      if (_creating) {
        final user = await backend.auth.signUp(_email.text, _password.text);
        await backend.profiles.saveProfile(
            UserProfile(uid: user.uid, displayName: _name.text.trim()));
      } else {
        await backend.auth.signIn(_email.text, _password.text);
      }
      // The router moves to Home when the sign-in state changes.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text.trim());
    final formKey = GlobalKey<FormState>();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: validateEmail,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Send reset link'),
          ),
        ],
      ),
    );
    if (email == null || !mounted) return;
    try {
      await ref.read(backendProvider).auth.sendPasswordReset(email);
      if (mounted) {
        showSnack(context, 'If an account exists, a reset link was sent.');
      }
    } on AuthFailure catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDemo = ref.watch(backendProvider).isDemo;

    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: pagePadding,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(AppConfig.appName, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                const Text('Track effort. Build consistency.'),
                if (isDemo) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Demo mode: create any account to look around. '
                    'Nothing is saved to the cloud.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 20),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Sign in')),
                    ButtonSegment(value: true, label: Text('Create account')),
                  ],
                  selected: {_creating},
                  showSelectedIcon: false,
                  onSelectionChanged: _busy
                      ? null
                      : (s) => setState(() {
                            _creating = s.first;
                            _error = null;
                          }),
                ),
                const SizedBox(height: 20),
                if (_creating) ...[
                  TextFormField(
                    key: const Key('auth-name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(labelText: 'Display name'),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Enter a name to show in the app'
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  key: const Key('auth-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                      labelText: 'Email', hintText: 'you@example.com'),
                  validator: validateEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('auth-password'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: validatePassword,
                ),
                if (_creating) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('auth-confirm'),
                    controller: _confirm,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Confirm password'),
                    validator: (v) =>
                        v != _password.text ? 'Passwords do not match' : null,
                  ),
                ] else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _busy ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('auth-submit'),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_creating ? 'Create account' : 'Sign in'),
                ),
                const SizedBox(height: 24),
                const DisclaimerText(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
