/// The phone features step tracking needs, behind an interface so the logic
/// in step_service.dart can be tested without a phone.
library;

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum PermissionResult { granted, denied, permanentlyDenied }

class AccelSample {
  const AccelSample(this.x, this.y, this.z, this.timeMs);
  final double x, y, z;
  final int timeMs;
}

abstract interface class StepPlatform {
  /// False where step counting cannot work at all, such as the web.
  bool get isSupported;

  /// Reads the activity permission without showing a dialog.
  Future<PermissionResult> checkPermission();

  /// Shows the system permission dialog when the system allows it.
  Future<PermissionResult> requestPermission();

  /// Steps since the phone restarted. Emits an error when the phone has no
  /// step-counter sensor.
  Stream<int> stepCounts();

  Stream<AccelSample> accelerometer();

  Future<void> openSettings();
}

class DeviceStepPlatform implements StepPlatform {
  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool get isSupported => _isAndroid || _isIos;

  static PermissionResult _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return PermissionResult.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionResult.permanentlyDenied;
    }
    return PermissionResult.denied;
  }

  // On iOS the Motion & Fitness dialog appears by itself when the step
  // stream starts, and a refusal arrives as a stream error. Only Android
  // has a permission to ask for up front.

  @override
  Future<PermissionResult> checkPermission() async => _isAndroid
      ? _map(await Permission.activityRecognition.status)
      : PermissionResult.granted;

  @override
  Future<PermissionResult> requestPermission() async => _isAndroid
      ? _map(await Permission.activityRecognition.request())
      : PermissionResult.granted;

  @override
  Stream<int> stepCounts() => Pedometer.stepCountStream.map((e) => e.steps);

  @override
  Stream<AccelSample> accelerometer() =>
      accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
          .map((e) => AccelSample(
              e.x, e.y, e.z, DateTime.now().millisecondsSinceEpoch));

  @override
  Future<void> openSettings() async {
    // There is no app settings page to open on the web.
    if (isSupported) await openAppSettings();
  }
}
