/// Build-time switches.
library;

abstract final class AppConfig {
  static const appName = 'Fitness and Habit Tracker';

  /// Build with `--dart-define=DEMO=true` to run without Firebase.
  static const forceDemo = bool.fromEnvironment('DEMO');

  static const disclaimer = 'For fitness tracking and motivation only. '
      'This app does not provide medical advice.';
}
