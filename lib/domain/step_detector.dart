/// Counts steps from accelerometer samples.
///
/// Fallback for phones without a step-counter sensor. It works only while
/// the app is open and is less accurate than the hardware counter, so totals
/// from it are labelled in the UI.
library;

import 'dart:math' as math;

class StepDetector {
  StepDetector({
    this.threshold = 1.3,
    this.rearmBelow = 0.3,
    this.minStepIntervalMs = 280,
  });

  /// Acceleration above the resting level (m/s²) that counts as a step.
  final double threshold;

  /// The signal must fall below this before another step can be counted.
  final double rearmBelow;

  /// Shortest time between two steps. 280 ms allows a fast run and rejects
  /// vibration.
  final int minStepIntervalMs;

  double? _resting;
  bool _armed = true;
  int _lastStepMs = -1 << 31;

  /// Feeds one sample. Returns true when it completes a step.
  bool addSample(double x, double y, double z, int timeMs) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    // A slow moving average follows gravity, whatever way the phone is held.
    _resting = _resting == null ? magnitude : _resting! * 0.95 + magnitude * 0.05;
    final value = magnitude - _resting!;

    if (value < rearmBelow) {
      _armed = true;
      return false;
    }
    if (_armed &&
        value > threshold &&
        timeMs - _lastStepMs >= minStepIntervalMs) {
      _armed = false;
      _lastStepMs = timeMs;
      return true;
    }
    return false;
  }
}
