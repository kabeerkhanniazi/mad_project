/// Step tracking: permission, sensors, the daily total and saving it.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import '../domain/models.dart';
import '../domain/step_detector.dart';
import '../domain/step_tracker.dart';
import '../providers.dart';
import 'step_platform.dart';

enum StepStatus {
  /// Checking permission after start-up.
  starting,

  /// The user has not turned tracking on.
  off,

  /// The activity permission was refused; the dialog can be shown again.
  denied,

  /// Refused for good; only the system settings can change it.
  permanentlyDenied,

  /// The phone has no usable sensor.
  unavailable,

  tracking,
}

class StepView {
  const StepView({
    required this.status,
    this.steps = 0,
    this.source = StepSource.sensor,
    this.trackedFrom,
  });

  final StepStatus status;

  /// Today's recorded steps. Meaningful only while [status] is tracking.
  final int steps;
  final StepSource source;
  final DateTime? trackedFrom;

  bool get isTracking => status == StepStatus.tracking;
}

class StepController extends Notifier<StepView> {
  StreamSubscription<Object?>? _subscription;
  Timer? _flushTimer;
  StepState? _state;
  String? _uid;
  var _dirty = false;
  var _source = StepSource.sensor;

  /// How long changes wait before being written, to keep writes few.
  static const _flushDelay = Duration(seconds: 15);

  StepPlatform get _platform => ref.read(stepPlatformProvider);
  DateTime get _now => ref.read(clockProvider)();

  @override
  StepView build() {
    final uid = ref.watch(uidProvider);
    final enabled = ref.watch(profileProvider
        .select((p) => p.value?.stepTrackingEnabled ?? false));
    ref.onDispose(_stopListening);

    _uid = uid;
    _state = uid == null ? null : ref.read(localStoreProvider).loadStepState(uid);
    if (uid == null || !enabled) return const StepView(status: StepStatus.off);

    Future.microtask(_begin);
    return const StepView(status: StepStatus.starting);
  }

  /// Turns tracking on. Shows the permission dialog when needed.
  Future<void> enable() async {
    if (!_platform.isSupported) {
      state = const StepView(status: StepStatus.unavailable);
      return;
    }
    final permission = await _platform.requestPermission();
    if (permission != PermissionResult.granted) {
      state = StepView(status: _deniedStatus(permission));
      return;
    }
    final profile = ref.read(profileProvider).value;
    if (profile != null && !profile.stepTrackingEnabled) {
      // Saving the preference rebuilds this controller, which starts tracking.
      await ref
          .read(backendProvider)
          .profiles
          .saveProfile(profile.copyWith(stepTrackingEnabled: true));
    } else {
      await _begin();
    }
  }

  /// Turns tracking off and keeps what was recorded.
  Future<void> disable() async {
    await flush();
    _state = _state?.withoutBaseline();
    _persistLocal();
    final profile = ref.read(profileProvider).value;
    if (profile != null && profile.stepTrackingEnabled) {
      await ref
          .read(backendProvider)
          .profiles
          .saveProfile(profile.copyWith(stepTrackingEnabled: false));
    }
  }

  /// Rechecks permission. Called when the app returns to the foreground,
  /// for example after a visit to the system settings.
  Future<void> refresh() async {
    final status = state.status;
    if (status == StepStatus.denied ||
        status == StepStatus.permanentlyDenied) {
      await _begin();
    } else if (status == StepStatus.tracking) {
      _publish(); // The date may have changed while the app was away.
    }
  }

  Future<void> openSettings() => _platform.openSettings();

  /// Writes pending steps now. Called when the app goes to the background.
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (!_dirty) return;
    _dirty = false;
    _persistLocal();
    final uid = _uid;
    final s = _state;
    final profile = ref.read(profileProvider).value;
    if (uid == null || s == null || profile == null) return;
    await ref.read(backendProvider).steps.saveDay(
          uid,
          StepDay(
            date: s.date,
            steps: s.steps,
            goal: profile.stepGoal,
            source: s.source,
            trackedFrom: s.trackedFrom,
          ),
        );
  }

  // ------------------------------------------------------------ internals

  StepStatus _deniedStatus(PermissionResult p) =>
      p == PermissionResult.permanentlyDenied
          ? StepStatus.permanentlyDenied
          : StepStatus.denied;

  Future<void> _begin() async {
    _stopListening();
    if (!_platform.isSupported) {
      state = const StepView(status: StepStatus.unavailable);
      return;
    }
    final permission = await _platform.checkPermission();
    if (!ref.mounted) return;
    if (permission != PermissionResult.granted) {
      state = StepView(status: _deniedStatus(permission));
      return;
    }
    _source = StepSource.sensor;
    _subscription = _platform.stepCounts().listen(
          _onCounter,
          // No step-counter sensor: count with the accelerometer instead.
          onError: (Object _) => _useAccelerometer(),
        );
    _publish();
  }

  void _useAccelerometer() {
    _stopListening();
    final detector = StepDetector();
    _source = StepSource.accelerometer;
    _state = _state?.withoutBaseline();
    _subscription = _platform.accelerometer().listen(
      (sample) {
        if (detector.addSample(sample.x, sample.y, sample.z, sample.timeMs)) {
          _state = StepTracker.addSteps(_state, 1, _now);
          _afterChange();
        }
      },
      onError: (Object _) {
        _stopListening();
        state = const StepView(status: StepStatus.unavailable);
      },
    );
    _publish();
  }

  void _onCounter(int raw) {
    _state = StepTracker.applyRaw(_state, raw, _now);
    _afterChange();
  }

  void _afterChange() {
    _dirty = true;
    _checkGoal();
    _publish();
    _flushTimer ??= Timer(_flushDelay, flush);
  }

  void _checkGoal() {
    final s = _state;
    final goal = ref.read(profileProvider).value?.stepGoal;
    if (s == null || goal == null || s.goalNotified || s.steps < goal) return;
    _state = s.copyWith(goalNotified: true);
    unawaited(ref
        .read(notificationServiceProvider)
        .showGoalReached(s.steps, goal)
        .catchError((Object _) {}));
  }

  void _publish() {
    final s = _state;
    final isToday = s != null && s.date == dateKey(_now);
    state = StepView(
      status: StepStatus.tracking,
      steps: isToday ? s.steps : 0,
      source: _source,
      trackedFrom: isToday ? s.trackedFrom : null,
    );
  }

  void _persistLocal() {
    final uid = _uid;
    final s = _state;
    if (uid != null && s != null) {
      unawaited(ref.read(localStoreProvider).saveStepState(uid, s));
    }
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _flushTimer?.cancel();
    _flushTimer = null;
  }
}

final stepControllerProvider =
    NotifierProvider<StepController, StepView>(StepController.new);
