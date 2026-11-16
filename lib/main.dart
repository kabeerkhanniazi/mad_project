import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'data/firebase_repositories.dart';
import 'data/local_store.dart';
import 'data/memory_repositories.dart';
import 'data/repositories.dart';
import 'firebase_options.dart';
import 'providers.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = LocalStore(await SharedPreferences.getInstance());
  final backend = await _createBackend();

  // Phone notifications exist only on Android and iOS.
  final onPhone = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  final NotificationService notifications =
      onPhone ? LocalNotificationService() : FakeNotificationService();

  runApp(ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(store),
      backendProvider.overrideWithValue(backend),
      notificationServiceProvider.overrideWithValue(notifications),
    ],
    child: const FitHabitApp(),
  ));
}

/// Firebase when it is configured, otherwise the in-memory demo backend.
Future<Backend> _createBackend() async {
  if (AppConfig.forceDemo || !DefaultFirebaseOptions.isConfigured) {
    return MemoryBackend().asBackend();
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  return createFirebaseBackend();
}
