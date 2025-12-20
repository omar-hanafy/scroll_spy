import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:scroll_spy/src/utils/throttle.dart';

import 'package:scroll_spy/src/debug/debug_config.dart' as debug;
import 'package:scroll_spy/src/public/scroll_spy_controller.dart';
import 'package:scroll_spy/src/public/scroll_spy_models.dart';
import 'package:scroll_spy/src/public/scroll_spy_policy.dart';
import 'package:scroll_spy/src/public/scroll_spy_region.dart';
import 'package:scroll_spy/src/public/scroll_spy_stability.dart';
import 'package:scroll_spy/src/public/scroll_spy_update_policy.dart';
import 'package:scroll_spy/src/engine/focus_diff.dart';
import 'package:scroll_spy/src/engine/focus_geometry.dart';
import 'package:scroll_spy/src/engine/focus_registry.dart';
import 'package:scroll_spy/src/engine/focus_selection.dart';

/// Internal engine that turns scroll/layout signals into focus snapshots.
///
/// This is the runtime core used by `ScrollSpyScopeState`. It is not
/// typically constructed directly by application code; instead, configure a
/// `ScrollSpyScope` (region/policy/stability/updatePolicy) and listen via a
/// [ScrollSpyController].
///
/// Pipeline per compute pass:
/// 1) Reads currently registered items from the [FocusRegistry].
/// 2) Measures viewport + item geometry using [FocusGeometry].
/// 3) Evaluates [ScrollSpyRegion] and selects primary/focused sets using
///    [FocusSelection] and the configured [ScrollSpyPolicy] +
///    [ScrollSpyStability].
/// 4) Commits the resulting [ScrollSpySnapshot] to the controller through
///    [FocusDiff] (so the controller can do diff-only notifications and
///    per-item listenable management).
///
/// Scheduling:
/// - Work is always performed on a post-frame callback so layout/paint
///   transforms are stable.
/// - Multiple triggers are coalesced into at most one compute per frame.
/// - [ScrollSpyUpdatePolicy] determines which triggers are honored during user
///   drag, ballistic scrolling, and idle time.
///
/// Debug:
/// - A debug frame is published after each compute pass via [debugFrame], which
///   the overlay listens to.
/// - Per-item rectangles are only included when [includeItemRects] is true to
///   avoid extra allocations.
class ScrollSpyEngine<T> {
  /// Creates a focus engine tied to a scope's controller and registry.
  ///
  /// The engine reads from [registry], uses [region]/[policy]/[stability] to
  /// select focus, and publishes snapshots into [controller]. If
  /// [includeItemRects] is true, per-item rects are included in debug frames.
  ScrollSpyEngine({
    required ScrollSpyController<T> controller,
    required ScrollSpyRegistry<T> registry,
    required ScrollSpyRegion region,
    required ScrollSpyPolicy<T> policy,
    required ScrollSpyStability stability,
    required ScrollSpyUpdatePolicy updatePolicy,
    required bool includeItemRects,
    EdgeInsets viewportInsets = EdgeInsets.zero,
    bool insetsAffectVisibility = true,
  })  : _controller = controller,
        _registry = registry,
        _region = region,
        _policy = policy,
        _stability = stability,
        _updatePolicy = updatePolicy,
        _includeItemRects = includeItemRects,
        _viewportInsets = viewportInsets,
        _insetsAffectVisibility = insetsAffectVisibility,
        _debugFrame = ValueNotifier<debug.ScrollSpyDebugFrame<T>?>(
          debug.ScrollSpyDebugFrame.empty<T>(),
        ) {
    _configureSchedulersForPolicy(updatePolicy);
  }

  ScrollSpyController<T> _controller;
  final ScrollSpyRegistry<T> _registry;

  ScrollSpyRegion _region;
  ScrollSpyPolicy<T> _policy;
  ScrollSpyStability _stability;
  ScrollSpyUpdatePolicy _updatePolicy;
  EdgeInsets _viewportInsets;
  bool _insetsAffectVisibility;

  bool _includeItemRects;

  int _debugSequence = 0;

  final ValueNotifier<debug.ScrollSpyDebugFrame<T>?> _debugFrame;

  /// A stream of debug frames produced after each compute pass.
  ///
  /// `ScrollSpyScope(debug: true)` wires this into the debug overlay. The
  /// value is updated even when the controller’s diff-only signals (like
  /// `primaryId`) do not change, because it reflects raw per-frame metrics.
  ValueListenable<debug.ScrollSpyDebugFrame<T>?> get debugFrame => _debugFrame;

  ScrollController? _scrollController;

  bool _attached = false;
  bool _disposed = false;

  bool _dirty = false;
  bool _postFrameScheduled = false;

  Axis _axis = Axis.vertical;

  bool _isScrolling = false;
  bool _isDragging = false;

  // Primary stability bookkeeping.
  T? _previousPrimaryId;
  DateTime? _previousPrimarySince;

  // Policy schedulers.
  Debouncer? _scrollEndDebouncer;
  Throttler? _flingThrottler;

  /// Activates the engine.
  ///
  /// When attached, the engine listens to the optional [scrollController] (to
  /// catch programmatic scroll changes) and will respond to notification-based
  /// scroll signals from the owning scope.
  ///
  /// The first compute pass is scheduled after the next frame to ensure all
  /// registered items have stable layout/paint information.
  void attach({ScrollController? scrollController}) {
    if (_disposed) return;
    if (!_attached) {
      _attached = true;
      updateScrollController(scrollController);
      // Initial compute (after first frame of attachment).
      _requestCompute(immediate: true);
    } else {
      // Still update controller if provided.
      updateScrollController(scrollController);
    }
  }

  /// Deactivates the engine and stops listening to scroll controller ticks.
  ///
  /// The registry is retained, but no further compute passes are scheduled
  /// until [attach] is called again.
  void detach() {
    if (_disposed) return;
    _attached = false;
    updateScrollController(null);
  }

  /// Updates which [ScrollController] the engine listens to.
  ///
  /// This is used by the owning scope whenever its effective scroll controller
  /// changes (including adopting a `PrimaryScrollController` from above).
  void updateScrollController(ScrollController? controller) {
    if (_disposed) return;
    if (identical(_scrollController, controller)) return;

    _scrollController?.removeListener(_onScrollControllerTick);
    _scrollController = controller;
    _scrollController?.addListener(_onScrollControllerTick);
  }

  /// Updates the engine configuration.
  ///
  /// Any meaningful change forces an immediate recompute so downstream
  /// listenables reflect the new region/policy/stability/update policy.
  void updateConfig({
    required ScrollSpyController<T> controller,
    required ScrollSpyRegion region,
    required ScrollSpyPolicy<T> policy,
    required ScrollSpyStability stability,
    required ScrollSpyUpdatePolicy updatePolicy,
    required bool includeItemRects,
    EdgeInsets? viewportInsets,
    bool? insetsAffectVisibility,
  }) {
    if (_disposed) return;

    final bool controllerChanged = !identical(_controller, controller);
    final bool regionChanged = _region != region;
    final bool policyChanged = _policy != policy;
    final bool stabilityChanged = _stability != stability;
    final bool updatePolicyChanged = _updatePolicy != updatePolicy;
    final bool rectsChanged = _includeItemRects != includeItemRects;
    final EdgeInsets resolvedViewportInsets = viewportInsets ?? _viewportInsets;
    final bool resolvedInsetsAffectVisibility =
        insetsAffectVisibility ?? _insetsAffectVisibility;
    final bool insetsChanged = _viewportInsets != resolvedViewportInsets;
    final bool visibilityChanged =
        _insetsAffectVisibility != resolvedInsetsAffectVisibility;

    _controller = controller;
    _region = region;
    _policy = policy;
    _stability = stability;
    _viewportInsets = resolvedViewportInsets;
    _insetsAffectVisibility = resolvedInsetsAffectVisibility;

    if (updatePolicyChanged) {
      _updatePolicy = updatePolicy;
      _configureSchedulersForPolicy(updatePolicy);
    }

    if (rectsChanged) {
      _includeItemRects = includeItemRects;
    }

    if (controllerChanged ||
        regionChanged ||
        policyChanged ||
        stabilityChanged ||
        updatePolicyChanged ||
        rectsChanged ||
        insetsChanged ||
        visibilityChanged) {
      // Force a recompute with the new configuration.
      _requestCompute(immediate: true);
    }
  }

  void _configureSchedulersForPolicy(ScrollSpyUpdatePolicy policy) {
    _scrollEndDebouncer?.dispose();
    _flingThrottler?.dispose();
    _scrollEndDebouncer = null;
    _flingThrottler = null;

    switch (policy) {
      case PerFrameUpdatePolicy():
        // No timers needed.
        break;

      case OnScrollEndUpdatePolicy(:final debounce):
        _scrollEndDebouncer = Debouncer(delay: debounce);
        break;

      case HybridUpdatePolicy(
          :final scrollEndDebounce,
          :final ballisticInterval,
        ):
        _scrollEndDebouncer = Debouncer(delay: scrollEndDebounce);
        _flingThrottler = Throttler(interval: ballisticInterval);
        break;
    }
  }

  /// Registers an item for geometry tracking.
  ///
  /// Called by the owning scope when a `ScrollSpyItem` has a stable
  /// [RenderBox]. Registering marks the engine dirty and schedules a compute
  /// pass (respecting the current [ScrollSpyUpdatePolicy]).
  void registerItem(
    T id, {
    required BuildContext context,
    required RenderBox box,
  }) {
    if (_disposed) return;
    _registry.register(id, context: context, box: box);
    _requestComputeForNonScrollChange();
  }

  /// Unregisters an item ID from geometry tracking.
  ///
  /// This is called when a `ScrollSpyItem` is disposed or changes its ID.
  /// The next compute pass will no longer include this item (and the controller
  /// may eventually evict its per-item notifier if one exists).
  void unregisterItem(T id) {
    if (_disposed) return;
    _registry.unregister(id);
    _requestComputeForNonScrollChange();
  }

  void _requestComputeForNonScrollChange() {
    if (_disposed || !_attached) return;

    _dirty = true;

    // Respect the configured update policy:
    // - onScrollEnd: do not recompute while scrolling (including during drag)
    // - hybrid: if computePerFrameWhileDragging=false, avoid recompute during drag
    //   (but allow throttled recompute during ballistic scrolling)
    switch (_updatePolicy) {
      case PerFrameUpdatePolicy():
        _schedulePostFrameCompute(ensureVisualUpdate: true);
        break;

      case OnScrollEndUpdatePolicy():
        if (_isScrolling) return;
        _schedulePostFrameCompute(ensureVisualUpdate: true);
        break;

      case HybridUpdatePolicy(
          :final ballisticInterval,
          :final computePerFrameWhileDragging,
        ):
        if (_isDragging && !computePerFrameWhileDragging) return;

        if (_isScrolling && !_isDragging) {
          (_flingThrottler ??= Throttler(interval: ballisticInterval)).run(() {
            _schedulePostFrameCompute(ensureVisualUpdate: true);
          });
          return;
        }

        _schedulePostFrameCompute(ensureVisualUpdate: true);
        break;
    }
  }

  /// Handles scroll notifications coming from the owning scope’s
  /// `NotificationListener`.
  ///
  /// This updates the current axis inference and scroll state (dragging vs.
  /// ballistic) and schedules compute passes according to the configured
  /// [ScrollSpyUpdatePolicy].
  ///
  /// Always returns `false` so the notification continues bubbling.
  bool handleScrollNotification(ScrollNotification n) {
    if (_disposed) return false;

    _axis = _axisFromAxisDirection(n.metrics.axisDirection);

    // Track scrolling state so other signal sources (e.g. ScrollMetricsNotification)
    // don't violate the configured update policy during active scroll.
    if (n is ScrollStartNotification) {
      _isScrolling = true;
      _isDragging = n.dragDetails != null;
    } else if (n is ScrollUpdateNotification) {
      _isScrolling = true;
      _isDragging = n.dragDetails != null;
    } else if (n is ScrollEndNotification) {
      _isScrolling = false;
      _isDragging = false;
    }

    switch (_updatePolicy) {
      case PerFrameUpdatePolicy():
        _requestCompute(immediate: false);
        break;

      case OnScrollEndUpdatePolicy(:final debounce):
        if (n is ScrollEndNotification) {
          (_scrollEndDebouncer ??= Debouncer(delay: debounce)).run(() {
            _requestCompute(immediate: true);
          });
        }
        break;

      case HybridUpdatePolicy(
          :final scrollEndDebounce,
          :final ballisticInterval,
          :final computePerFrameWhileDragging,
        ):
        if (n is ScrollUpdateNotification) {
          if (n.dragDetails != null) {
            // User drag:
            // - per-frame when enabled
            // - otherwise do not recompute (only recompute on scroll end)
            if (computePerFrameWhileDragging) {
              _requestCompute(immediate: false);
            }
          } else {
            // Ballistic fling: throttled.
            (_flingThrottler ??= Throttler(interval: ballisticInterval)).run(
              () {
                _requestCompute(immediate: true);
              },
            );
          }
        } else if (n is ScrollEndNotification) {
          (_scrollEndDebouncer ??= Debouncer(delay: scrollEndDebounce)).run(() {
            _requestCompute(immediate: true);
          });
        }
        break;
    }

    return false;
  }

  /// Handles `ScrollMetricsNotification`s (viewport extent/position changes).
  ///
  /// These notifications can be very chatty during active scrolling. The engine
  /// ignores them while the user is scrolling/dragging to respect the configured
  /// [ScrollSpyUpdatePolicy], and only triggers a compute when idle.
  bool handleScrollMetricsNotification(ScrollMetricsNotification n) {
    if (_disposed) return false;
    _axis = _axisFromAxisDirection(n.metrics.axisDirection);

    // ScrollMetricsNotification fires frequently during active scrolling because
    // `extentBefore/inside/after` change as the scroll offset changes. We must
    // ignore it while scrolling to avoid violating the configured update policy
    // (e.g. onScrollEnd, or hybrid with computePerFrameWhileDragging=false).
    if (_isScrolling || _isDragging) return false;

    _requestCompute(immediate: true);
    return false;
  }

  /// Signals that external metrics changed (rotation, keyboard insets, parent
  /// size changes, etc).
  ///
  /// The owning scope calls this from `didChangeMetrics` and from layout change
  /// notifications so focus is recomputed against the new viewport geometry.
  void handleMetricsChanged() {
    if (_disposed) return;
    _requestCompute(immediate: true);
  }

  void _onScrollControllerTick() {
    if (_disposed) return;

    // ScrollController can fire rapidly; respect the update policy.
    switch (_updatePolicy) {
      case PerFrameUpdatePolicy():
        _requestCompute(immediate: false);
        break;

      case OnScrollEndUpdatePolicy(:final debounce):
        (_scrollEndDebouncer ??= Debouncer(delay: debounce)).run(() {
          _requestCompute(immediate: true);
        });
        break;

      case HybridUpdatePolicy(
          :final scrollEndDebounce,
          :final ballisticInterval,
        ):
        // During controller-driven flings, throttle.
        (_flingThrottler ??= Throttler(interval: ballisticInterval)).run(() {
          _requestCompute(immediate: true);
        });
        // Also ensure final settle.
        (_scrollEndDebouncer ??= Debouncer(delay: scrollEndDebounce)).run(() {
          _requestCompute(immediate: true);
        });
        break;
    }
  }

  Axis _axisFromAxisDirection(AxisDirection axisDirection) {
    return (axisDirection == AxisDirection.up ||
            axisDirection == AxisDirection.down)
        ? Axis.vertical
        : Axis.horizontal;
  }

  void _requestCompute({required bool immediate}) {
    if (_disposed || !_attached) return;

    _dirty = true;

    // Always compute on a post-frame callback to ensure layout/paint transforms are stable.
    // `immediate` here affects whether we attempt to schedule right away; for per-frame
    // we still coalesce to <= 1 compute per frame.
    _schedulePostFrameCompute(ensureVisualUpdate: immediate);
  }

  void _schedulePostFrameCompute({required bool ensureVisualUpdate}) {
    if (_disposed) return;

    if (!_postFrameScheduled) {
      _postFrameScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _postFrameScheduled = false;
        _computeIfDirty();
      });
    }

    if (ensureVisualUpdate) {
      // Debounced/throttled triggers often run from timers while the app is idle.
      // If no frame is scheduled, the post-frame callback will never fire.
      SchedulerBinding.instance.ensureVisualUpdate();
    }
  }

  void _computeIfDirty() {
    if (_disposed || !_attached) return;
    if (!_dirty) return;

    // Consume the dirty flag; if something else marks dirty during this compute,
    // the next frame callback will be scheduled separately.
    _dirty = false;

    _registry.pruneUnmounted();

    final Axis axis = _resolveAxisFallback(_axis);
    final ScrollSpyGeometryResult<T> geom = ScrollSpyGeometry.compute<T>(
      entries: _registry.entriesSnapshot(),
      region: _region,
      axis: axis,
      includeItemRects: _includeItemRects,
      viewportInsets: _viewportInsets,
      insetsAffectVisibility: _insetsAffectVisibility,
    );

    final DateTime now = DateTime.now();

    if (geom.items.isEmpty) {
      final empty = ScrollSpySnapshot<T>(
        computedAt: now,
        primaryId: null,
        focusedIds: const {},
        visibleIds: const {},
        items: const {},
      );

      ScrollSpyDiff.commitToController<T>(controller: _controller, next: empty);

      _previousPrimaryId = null;
      _previousPrimarySince = null;

      _debugFrame.value = debug.ScrollSpyDebugFrame<T>(
        sequence: ++_debugSequence,
        viewportRect: geom.effectiveViewportRect,
        focusRegionRect: _buildFocusRegionRect(
          viewportRect: geom.effectiveViewportRect,
          axis: axis,
          region: _region,
          anchorOffsetPx: geom.anchorOffsetPx,
        ),
        focusRegionLabel: _buildFocusRegionLabel(_region),
        primaryId: null,
        focusedIds: const {},
        items: const {},
        snapshot: empty,
      );

      return;
    }

    final ScrollSpySelectionResult<T> selection = ScrollSpySelection.select<T>(
      items: geom.items,
      policy: _policy,
      stability: _stability,
      previousPrimaryId: _previousPrimaryId,
      previousPrimarySince: _previousPrimarySince,
      now: now,
    );

    final ScrollSpySnapshot<T> next = ScrollSpySnapshot<T>(
      computedAt: now,
      primaryId: selection.primaryId,
      focusedIds: selection.focusedIds,
      visibleIds: selection.visibleIds,
      items: selection.itemsById,
    );

    ScrollSpyDiff.commitToController<T>(controller: _controller, next: next);

    _previousPrimaryId = selection.primaryId;
    _previousPrimarySince = selection.primarySince;

    _debugFrame.value = debug.ScrollSpyDebugFrame<T>(
      sequence: ++_debugSequence,
      viewportRect: geom.effectiveViewportRect,
      focusRegionRect: _buildFocusRegionRect(
        viewportRect: geom.effectiveViewportRect,
        axis: axis,
        region: _region,
        anchorOffsetPx: geom.anchorOffsetPx,
      ),
      focusRegionLabel: _buildFocusRegionLabel(_region),
      primaryId: selection.primaryId,
      focusedIds: selection.focusedIds,
      items: _buildDebugItems(selection.itemsById),
      snapshot: next,
    );
  }

  Rect? _buildFocusRegionRect({
    required Rect viewportRect,
    required Axis axis,
    required ScrollSpyRegion region,
    required double? anchorOffsetPx,
  }) {
    if (viewportRect.isEmpty || anchorOffsetPx == null) return null;

    final double thicknessPx = switch (region) {
      ScrollSpyLineRegion(:final thicknessPx) =>
        thicknessPx <= 0.0 ? 1.0 : thicknessPx,
      ScrollSpyZoneRegion(:final extentPx) => extentPx,
      ScrollSpyCustomRegion() => 1.0,
    };

    final double halfThickness = thicknessPx / 2.0;

    return axis == Axis.vertical
        ? Rect.fromLTWH(
            viewportRect.left,
            anchorOffsetPx - halfThickness,
            viewportRect.width,
            thicknessPx,
          )
        : Rect.fromLTWH(
            anchorOffsetPx - halfThickness,
            viewportRect.top,
            thicknessPx,
            viewportRect.height,
          );
  }

  String? _buildFocusRegionLabel(ScrollSpyRegion region) {
    if (region is ScrollSpyZoneRegion) {
      return 'zone @ ${region.anchor} (extent ${region.extentPx.toStringAsFixed(0)}px)';
    }
    if (region is ScrollSpyLineRegion) {
      return region.thicknessPx <= 0.0
          ? 'line @ ${region.anchor}'
          : 'line @ ${region.anchor} (th ${region.thicknessPx.toStringAsFixed(1)}px)';
    }
    if (region is ScrollSpyCustomRegion) {
      return 'custom @ ${region.anchor}';
    }
    return null;
  }

  Map<T, debug.ScrollSpyDebugItem<T>> _buildDebugItems(
    Map<T, ScrollSpyItemFocus<T>> itemsById,
  ) {
    if (itemsById.isEmpty) return const {};

    final map = <T, debug.ScrollSpyDebugItem<T>>{};

    for (final entry in itemsById.entries) {
      final focus = entry.value;
      final rect = focus.itemRectInViewport;
      if (rect == null) continue;

      map[entry.key] = debug.ScrollSpyDebugItem<T>(
        id: entry.key,
        itemRect: rect,
        visibleRect: focus.visibleRectInViewport,
        focus: focus,
      );
    }

    return Map<T, debug.ScrollSpyDebugItem<T>>.unmodifiable(map);
  }

  Axis _resolveAxisFallback(Axis current) {
    if (_registry.entriesSnapshot().isEmpty) return current;

    // If we never received a scroll notification, infer from Scrollable.of(itemContext).
    for (final entry in _registry.entriesSnapshot()) {
      final scrollable = Scrollable.maybeOf(entry.context);
      if (scrollable != null) {
        return _axisFromAxisDirection(scrollable.widget.axisDirection);
      }
    }
    return current;
  }

  /// Releases scroll listeners, timers, and debug notifiers.
  ///
  /// After disposal the engine becomes inert; all subsequent method calls are
  /// ignored.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _scrollController?.removeListener(_onScrollControllerTick);
    _scrollController = null;

    _scrollEndDebouncer?.dispose();
    _flingThrottler?.dispose();
    _scrollEndDebouncer = null;
    _flingThrottler = null;

    _debugFrame.dispose();
  }
}
