import 'dart:async';

/// Runs an action at most once per [interval].
///
/// This implementation is intentionally small:
/// - Executes immediately on the first call in a window (leading).
/// - Remembers the last call during the window and runs it once at the end
///   (trailing), then opens a new window if needed.
///
/// The focus engine uses this to limit compute frequency during fast scroll
/// phases while still ensuring a final trailing update.
final class Throttler {
  /// Creates a throttler with the given [interval].
  Throttler({required this.interval}) : assert(interval > Duration.zero);

  /// The minimum time window between leading executions.
  final Duration interval;

  Timer? _timer;
  void Function()? _pending;

  /// Whether a throttle window is currently active.
  bool get isThrottling => _timer != null;

  /// Runs [action] with leading + trailing throttling.
  ///
  /// - If no window is active, [action] executes immediately and starts a
  ///   throttle window.
  /// - If a window is active, [action] is stored as the pending trailing action
  ///   (replacing any previously pending action).
  void run(void Function() action) {
    if (_timer == null) {
      action();
      _timer = Timer(interval, _onWindowEnd);
      return;
    }

    _pending = action;
  }

  void _onWindowEnd() {
    _timer?.cancel();
    _timer = null;

    final pending = _pending;
    _pending = null;
    if (pending == null) return;

    run(pending);
  }

  /// Cancels any active window and clears any pending trailing action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  /// Alias for [cancel].
  void dispose() => cancel();
}

/// Consolidates rapid calls into a single action after [delay].
///
/// The focus engine uses this for "scroll end" behavior so a burst of updates
/// produces exactly one compute after the gesture settles.
final class Debouncer {
  /// Creates a debouncer with the given [delay].
  Debouncer({required this.delay}) : assert(delay >= Duration.zero);

  /// How long to wait after the most recent call before running the action.
  final Duration delay;

  Timer? _timer;

  /// Whether a debounced action is currently scheduled.
  bool get isRunning => _timer?.isActive ?? false;

  /// Schedules [action] to run after [delay], canceling any previous schedule.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancels any scheduled action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Alias for [cancel].
  void dispose() => cancel();
}
