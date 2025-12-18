import 'package:flutter/foundation.dart';

/// Defines the timing strategy for focus recalculations.
///
/// Focus computation involves geometry calculations for all items. While optimized,
/// doing this too frequently on lower-end devices can affect scroll performance.
/// This policy allows you to balance responsiveness vs. CPU usage.
///
/// This policy does **not** change how focus is computed; it only changes when
/// the engine schedules compute passes in response to:
/// - scroll notifications (drag/fling/settle),
/// - scroll controller ticks (programmatic scroll), and
/// - viewport/metrics changes.
@immutable
sealed class ViewportUpdatePolicy {
  const ViewportUpdatePolicy();

  /// Recalculates focus on every frame while scrolling.
  ///
  /// In practice, the engine still coalesces work to **at most one compute per
  /// rendered frame**, but it will attempt to run on every frame while scroll
  /// offset is changing.
  ///
  /// Use this for highly responsive effects (e.g., interpolating UI from
  /// `focusProgress` as the user drags).
  const factory ViewportUpdatePolicy.perFrame() = PerFrameUpdatePolicy;

  /// Defers calculation until scrolling stops (with a debounce delay).
  ///
  /// Use this when focus is only needed for resting states (e.g., snapping to an
  /// item) and you do not want focus updates during active scrolling.
  const factory ViewportUpdatePolicy.onScrollEnd({Duration debounce}) =
      OnScrollEndUpdatePolicy;

  /// A balanced strategy:
  /// - Updates per-frame when the user is actively dragging (finger down).
  /// - Throttles updates during ballistic scrolling (fling).
  /// - Ensures a final update when scrolling stops.
  const factory ViewportUpdatePolicy.hybrid({
    Duration scrollEndDebounce,
    Duration ballisticInterval,
    bool computePerFrameWhileDragging,
  }) = HybridUpdatePolicy;
}

/// Strategy: Compute focus on every frame.
///
/// This provides the smoothest visual updates for effects driven by `focusProgress`
/// or `distanceToAnchor`.
@immutable
final class PerFrameUpdatePolicy extends ViewportUpdatePolicy {
  /// Creates a per-frame update policy.
  const PerFrameUpdatePolicy();

  @override
  String toString() => 'ViewportUpdatePolicy.perFrame()';
}

/// Strategy: Compute focus only when scrolling settles.
///
/// The cheapest option in terms of CPU.
/// The `debounce` parameter avoids triggering calculations during brief pauses in a scroll gesture.
///
/// Trade-off:
/// - `primaryId` / `focusedIds` can remain stale while the user is actively
///   scrolling, then update once after settle.
@immutable
final class OnScrollEndUpdatePolicy extends ViewportUpdatePolicy {
  /// The duration to wait after the last scroll event before triggering a computation.
  final Duration debounce;

  /// Creates a scroll-end update policy with an optional debounce.
  const OnScrollEndUpdatePolicy({
    this.debounce = const Duration(milliseconds: 80),
  }) : assert(debounce >= Duration.zero);

  @override
  String toString() => 'ViewportUpdatePolicy.onScrollEnd(debounce: $debounce)';
}

/// Strategy: Adaptive frequency based on scroll state.
///
/// - **User Drag:** High frequency (optional).
/// - **Ballistic Fling:** Throttled frequency (e.g., 20fps).
/// - **Idle:** No updates.
///
/// This is the recommended default for most feed applications.
@immutable
final class HybridUpdatePolicy extends ViewportUpdatePolicy {
  /// The duration to wait after scrolling settles before the final reliable pass.
  final Duration scrollEndDebounce;

  /// The minimum interval between computations during ballistic scrolling (flinging).
  ///
  /// Setting this to `50ms` (~20fps) significantly reduces CPU load during fast scrolls
  /// while still keeping the primary ID reasonably up to date.
  final Duration ballisticInterval;

  /// Whether to compute per-frame while the user is physically dragging the list.
  ///
  /// Set to `true` for responsive drag effects.
  final bool computePerFrameWhileDragging;

  /// Creates a hybrid update policy tuned for drag + ballistic scrolling.
  const HybridUpdatePolicy({
    this.scrollEndDebounce = const Duration(milliseconds: 80),
    this.ballisticInterval = const Duration(milliseconds: 50),
    this.computePerFrameWhileDragging = true,
  })  : assert(scrollEndDebounce >= Duration.zero),
        assert(ballisticInterval > Duration.zero);

  @override
  String toString() => 'ViewportUpdatePolicy.hybrid('
      'scrollEndDebounce: $scrollEndDebounce, '
      'ballisticInterval: $ballisticInterval, '
      'computePerFrameWhileDragging: $computePerFrameWhileDragging'
      ')';
}
