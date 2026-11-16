import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fithabit/app.dart';
import 'package:fithabit/data/local_store.dart';
import 'package:fithabit/data/memory_repositories.dart';
import 'package:fithabit/providers.dart';
import 'package:fithabit/services/notification_service.dart';
import 'package:fithabit/services/step_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A step sensor and permission dialog controlled by the test.
class FakeStepPlatform implements StepPlatform {
  FakeStepPlatform({
    this.permission = PermissionResult.granted,
    this.hasStepSensor = true,
    this.isSupported = true,
  });

  /// What the system answers when asked for activity access.
  PermissionResult permission;
  bool hasStepSensor;

  @override
  bool isSupported;

  /// Whether the user has been through the permission dialog.
  bool asked = false;
  int settingsOpened = 0;

  final counts = StreamController<int>.broadcast();
  final samples = StreamController<AccelSample>.broadcast();

  @override
  Future<PermissionResult> checkPermission() async =>
      asked ? permission : PermissionResult.denied;

  @override
  Future<PermissionResult> requestPermission() async {
    asked = true;
    return permission;
  }

  @override
  Stream<int> stepCounts() => hasStepSensor
      ? counts.stream
      : Stream.error(StateError('StepCount not available'));

  @override
  Stream<AccelSample> accelerometer() => samples.stream;

  @override
  Future<void> openSettings() async => settingsOpened++;
}

class TestApp {
  TestApp(this.backend, this.steps, this.notifications, this.store);
  final MemoryBackend backend;
  final FakeStepPlatform steps;
  final FakeNotificationService notifications;
  final LocalStore store;

  /// The time the app believes it is. Tests may move it.
  DateTime now = DateTime(2026, 11, 18, 10); // a Wednesday
}

final _wgerFixture =
    File('test/fixtures/wger_exerciseinfo.json').readAsStringSync();

/// Starts the whole app on the in-memory backend.
Future<TestApp> pumpApp(
  WidgetTester tester, {
  MemoryBackend? backend,
  FakeStepPlatform? steps,
  bool notificationsAllowed = true,
  bool wgerOnline = true,
}) async {
  // A tall screen, so lists build all their rows.
  await tester.binding.setSurfaceSize(const Size(480, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  SharedPreferences.setMockInitialValues({});
  final app = TestApp(
    backend ?? MemoryBackend(),
    steps ?? FakeStepPlatform(),
    FakeNotificationService(permissionGranted: notificationsAllowed),
    LocalStore(await SharedPreferences.getInstance()),
  );

  final client = MockClient((request) async {
    if (!wgerOnline) throw const SocketException('offline');
    final body = request.url.path.contains('exerciseinfo')
        ? _wgerFixture
        : '{"results":[{"id":9,"name":"Legs"}]}';
    return http.Response.bytes(utf8.encode(body), 200);
  });

  await tester.pumpWidget(ProviderScope(
    overrides: [
      backendProvider.overrideWithValue(app.backend.asBackend()),
      localStoreProvider.overrideWithValue(app.store),
      notificationServiceProvider.overrideWithValue(app.notifications),
      stepPlatformProvider.overrideWithValue(app.steps),
      httpClientProvider.overrideWithValue(client),
      clockProvider.overrideWithValue(() => app.now),
    ],
    child: const FitHabitApp(),
  ));
  await tester.pumpAndSettle();
  return app;
}

/// Creates an account through the Account access screen.
Future<void> signUp(WidgetTester tester,
    {String email = 'kabeer@example.com', String password = 'secret1'}) async {
  await tester.tap(find.text('Create account').first);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('auth-name')), 'Kabeer');
  await tester.enterText(find.byKey(const Key('auth-email')), email);
  await tester.enterText(find.byKey(const Key('auth-password')), password);
  await tester.enterText(find.byKey(const Key('auth-confirm')), password);
  await tester.tap(find.byKey(const Key('auth-submit')));
  await tester.pumpAndSettle();
}

/// Switches to one of the four root tabs.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
      of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}
