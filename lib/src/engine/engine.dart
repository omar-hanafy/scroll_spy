import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:scroll_spy/src/debug/debug_config.dart' as debug;
import 'package:scroll_spy/src/engine/engine_frame.dart';
import 'package:scroll_spy/src/engine/engine_geometry.dart';
import 'package:scroll_spy/src/engine/engine_selection.dart';
import 'package:scroll_spy/src/engine/item_slot.dart';
import 'package:scroll_spy/src/engine/slot_registry.dart';
import 'package:scroll_spy/src/public/scroll_spy_controller.dart';
import 'package:scroll_spy/src/public/scroll_spy_models.dart';
import 'package:scroll_spy/src/public/scroll_spy_policy.dart';
import 'package:scroll_spy/src/public/scroll_spy_region.dart';
import 'package:scroll_spy/src/public/scroll_spy_stability.dart';
import 'package:scroll_spy/src/public/scroll_spy_update_policy.dart';
import 'package:scroll_spy/src/utils/throttle.dart';

/// Turns scroll/layout signals into focus state.
///
/// This is the runtime core used by `ScrollSpyScopeState`; applications
/// configure it through `ScrollSpyScope` and observe results through a
/// [ScrollSpyController].
///
/// Pipeline per compute pass (all steady-state work is allocation-free):
/// 1) [EngineGeometry] brings every registered [ItemSlot] up to date; items
///    under standard sliver lists derive their position from a cached anchor
///    with O(1) validation instead of walking the render tree.
/// 2) Visibility, distance and region metrics are written into the slots and
///    membership into two reused id sets.
/// 3) [EngineSelection] applies policy + stability and picks the primary.
/// 4) The controller receives a reused [EngineFrame] and fans out diff-only,
///    materializing immutable objects only for active listeners.
///
/// Scheduling:
/// - Work always runs on a post-frame callback so layout is stable, coalesced
///   to at most one compute per frame.
/// - [ScrollSpyUpdatePolicy] decides which triggers are honored during drag,
///   ballistic scrolling, and idle time.
///
/// Debug frames are produced only when [debugEnabled] is true; a disabled
/// engine spends nothing on debugging.
class ScrollSpyEngine<T> {
  /// Creates an engine publishing into [controller].
  ScrollSpyEngine({
    required ScrollSpyController<T> controller,
    required ScrollSpyRegion region,
    required ScrollSpyPolicy<T> policy,
    required ScrollSpyStability stability,
    required ScrollSpyUpdatePolicy updatePolicy,
    required bool debugEnabled,
    required bool includeItemRects,
    EdgeInsets viewportInsets = EdgeInsets.zero,
    bool insetsAffectVisibility = true,
  })  : _controller = controller,
        _region = region,
        _policy = policy,
        _stability = stability,
        _updatePolicy = updatePolicy,
        _debugEnabled = debugEnabled,
        _includeItemRects = includeItemRects,
        _viewportInsets = viewportInsets,
        _insetsAffectVisibility = insetsAffectVisibility,
        _debugFrame = ValueNotifier<debug.ScrollSpyDebugFrame<T>?>(
          debug.ScrollSpyDebugFrame.empty<T>(),
        ) {
    _frame = EngineFrame<T>(
      slotOf: _registry.slotOf,
      materializeSnapshot: _materializeSnapshot,
    );
    _configureSchedulersForPolicy(updatePolicy);
  }

  ScrollSpyController<T> _controller;
  ScrollSpyRegion _region;
  ScrollSpyPolicy<T> _policy;
  ScrollSpyStability _stability;
  ScrollSpyUpdatePolicy _updatePolicy;
  bool _debugEnabled;
  bool _includeItemRects;
  EdgeInsets _viewportInsets;
  bool _insetsAffectVisibility;

  final SlotRegistry<T> _registry = SlotRegistry<T>();
  final EngineGeometry _geometry = EngineGeometry();
  final RegionScratch _regionScratch = RegionScratch();
  final PrimarySelection<T> _selectionScratch = PrimarySelection<T>();
  final Set<T> _focusedScratch = <T>{};
  final Set<T> _visibleScratch = <T>{};
  late final EngineFrame<T> _frame;

  /// Monotonic clock for stability timing.
  final Stopwatch _clock = Stopwatch()..start();

  RenderAbstractViewport? _viewport;
  Axis _axisHint = Axis.vertical;

  ScrollController? _scrollController;

  bool _attached = false;
  bool _disposed = false;
  bool _dirty = false;
  bool _postFrameScheduled = false;

  bool _isScrolling = false;
  bool _isDragging = false;

  T? _previousPrimaryId;
  Duration? _previousPrimarySince;

  Debouncer? _scrollEndDebouncer;
  Throttler? _flingThrottler;

  int _debugSequence = 0;
  final ValueNotifier<debug.ScrollSpyDebugFrame<T>?> _debugFrame;

  /// Total compute passes executed (including empty commits).
  @visibleForTesting
  int debugComputePasses = 0;

  /// Geometry counters, exposed for perf-invariant tests.
  @visibleForTesting
  EngineGeometry get debugGeometry => _geometry;

  /// Number of currently registered item slots.
  @visibleForTesting
  int get debugRegisteredCount => _registry.length;

  /// Runs one synchronous compute pass, bypassing scheduling. Benchmarks and
  /// invariant tests only; production computes always run post-frame.
  @visibleForTesting
  void debugComputeNow() {
    _dirty = true;
    _computeIfDirty();
  }

  // Per-pass state consumed by the reused region-input closure and the
  // debug/snapshot materializers.
  ItemSlot<T>? _regionSlot;
  Rect _effectiveRect = Rect.zero;
  double _anchorPos = 0;

  // Cached tear-off so built-in regions never cause per-item allocations.
  late final ScrollSpyRegionInput Function() _regionInput = _buildRegionInput;

  ScrollSpyRegionInput _buildRegionInput() {
    final slot = _regionSlot!;
    return ScrollSpyRegionInput(
      itemRectInViewport: _rectOfSlot(slot),
      viewportRect: _effectiveRect,
      axis: _geometry.axis,
      anchorOffsetPx: _anchorPos,
    );
  }

  /// A stream of debug frames produced after each compute pass, published
  /// only when the engine was constructed/configured with `debugEnabled`.
  ValueListenable<debug.ScrollSpyDebugFrame<T>?> get debugFrame => _debugFrame;

  /// Activates the engine and schedules the initial compute pass.
  void attach({ScrollController? scrollController}) {
    if (_disposed) return;
    if (!_attached) {
      _attached = true;
      updateScrollController(scrollController);
      _requestCompute(immediate: true);
    } else {
      updateScrollController(scrollController);
    }
  }

  /// Deactivates the engine; no further computes until [attach].
  void detach() {
    if (_disposed) return;
    _attached = false;
    updateScrollController(null);
  }

  /// Updates which [ScrollController] the engine listens to (programmatic
  /// jumps do not always produce drag notifications).
  void updateScrollController(ScrollController? controller) {
    if (_disposed) return;
    if (identical(_scrollController, controller)) return;

    _scrollController?.removeListener(_onScrollControllerTick);
    _scrollController = controller;
    _scrollController?.addListener(_onScrollControllerTick);
  }

  /// Updates the engine configuration; meaningful changes force a recompute.
  void updateConfig({
    required ScrollSpyController<T> controller,
    required ScrollSpyRegion region,
    required ScrollSpyPolicy<T> policy,
    required ScrollSpyStability stability,
    required ScrollSpyUpdatePolicy updatePolicy,
    required bool debugEnabled,
    required bool includeItemRects,
    EdgeInsets? viewportInsets,
    bool? insetsAffectVisibility,
  }) {
    if (_disposed) return;

    final EdgeInsets resolvedInsets = viewportInsets ?? _viewportInsets;
    final bool resolvedInsetsVisibility =
        insetsAffectVisibility ?? _insetsAffectVisibility;

    final bool changed = !identical(_controller, controller) ||
        _region != region ||
        _policy != policy ||
        _stability != stability ||
        _updatePolicy != updatePolicy ||
        _debugEnabled != debugEnabled ||
        _includeItemRects != includeItemRects ||
        _viewportInsets != resolvedInsets ||
        _insetsAffectVisibility != resolvedInsetsVisibility;

    if (_updatePolicy != updatePolicy) {
      _configureSchedulersForPolicy(updatePolicy);
    }

    _controller = controller;
    _region = region;
    _policy = policy;
    _stability = stability;
    _updatePolicy = updatePolicy;
    _debugEnabled = debugEnabled;
    _includeItemRects = includeItemRects;
    _viewportInsets = resolvedInsets;
    _insetsAffectVisibility = resolvedInsetsVisibility;

    if (changed) {
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
        break;
      case OnScrollEndUpdatePolicy(:final debounce):
        _scrollEndDebouncer = Debouncer(delay: debounce);
      case HybridUpdatePolicy(
          :final scrollEndDebounce,
          :final ballisticInterval,
        ):
        _scrollEndDebouncer = Debouncer(delay: scrollEndDebounce);
        _flingThrottler = Throttler(interval: ballisticInterval);
    }
  }

  /// Registers an item probe for geometry tracking.
  void registerItem(
    T id, {
    required BuildContext context,
    required RenderBox box,
  }) {
    if (_disposed) return;
    _registry.register(id, context: context, box: box);
    _requestComputeForNonScrollChange();
  }

  /// Unregisters an item probe.
  void unregisterItem(T id) {
    if (_disposed) return;
    _registry.unregister(id);
    _requestComputeForNonScrollChange();
  }

  void _requestComputeForNonScrollChange() {
    if (_disposed || !_attached) return;

    _dirty = true;

    switch (_updatePolicy) {
      case PerFrameUpdatePolicy():
        _schedulePostFrameCompute(ensureVisualUpdate: true);

      case OnScrollEndUpdatePolicy():
        if (_isScrolling) return;
        _schedulePostFrameCompute(ensureVisualUpdate: true);

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
    }
  }

  /// Handles scroll notifications from the owning scope. Always returns
  /// false so the notification keeps bubbling.
  bool handleScrollNotification(ScrollNotification n) {
    if (_disposed) return false;

    _axisHint = axisDirectionToAxis(n.metrics.axisDirection);

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

      case OnScrollEndUpdatePolicy(:final debounce):
        if (n is ScrollEndNotification) {
          (_scrollEndDebouncer ??= Debouncer(delay: debounce)).run(() {
            _requestCompute(immediate: true);
          });
        }

      case HybridUpdatePolicy(
          :final scrollEndDebounce,
          :final ballisticInterval,
          :final computePerFrameWhileDragging,
        ):
        if (n is ScrollUpdateNotification) {
          if (n.dragDetails != null) {
            if (computePerFrameWhileDragging) {
              _requestCompute(immediate: false);
            }
          } else {
            (_flingThrottler ??= Throttler(interval: ballisticInterval)).run(
              () => _requestCompute(immediate: true),
            );
          }
        } else if (n is ScrollEndNotification) {
          (_scrollEndDebouncer ??= Debouncer(delay: scrollEndDebounce)).run(
            () => _requestCompute(immediate: true),
          );
        }
    }

    return false;
  }

  /// Handles viewport dimension changes. Chatty during scrolling, so ignored
  /// while a scroll is active (the scroll pipeline already drives computes).
  bool handleScrollMetricsNotification(ScrollMetricsNotification n) {
    if (_disposed) return false;
    _axisHint = axisDirectionToAxis(n.metrics.axisDirection);
    if (_isScrolling || _isDragging) return false;
    _requestCompute(immediate: true);
    return false;
  }

  /// Signals external metrics changed (rotation, keyboard insets, parent
  /// resize). Drops all geometry anchors.
  void handleMetricsChanged() {
    if (_disposed) return;
    _registry.invalidateAllGeometry();
    _requestCompute(immediate: true);
  }

  void _onScrollControllerTick() {
    if (_disposed) return;

    switch (_updatePolicy) {
      case PerFrameUpdatePolicy():
        _requestCompute(immediate: false);

      case OnScrollEndUpdatePolicy(:final debounce):
        (_scrollEndDebouncer ??= Debouncer(delay: debounce)).run(() {
          _requestCompute(immediate: true);
        });

      case HybridUpdatePolicy(
          :final scrollEndDebounce,
          :final ballisticInterval,
        ):
        (_flingThrottler ??= Throttler(interval: ballisticInterval)).run(() {
          _requestCompute(immediate: true);
        });
        (_scrollEndDebouncer ??= Debouncer(delay: scrollEndDebounce)).run(() {
          _requestCompute(immediate: true);
        });
    }
  }

  void _requestCompute({required bool immediate}) {
    if (_disposed || !_attached) return;
    _dirty = true;
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
      // Timer-driven triggers can fire while the app is idle; without a
      // scheduled frame the post-frame callback would never run.
      SchedulerBinding.instance.ensureVisualUpdate();
    }
  }

  void _computeIfDirty() {
    if (_disposed || !_attached || !_dirty) return;
    _dirty = false;
    debugComputePasses++;

    final RenderAbstractViewport? viewport = _resolveViewport();
    if (viewport == null ||
        !_geometry.beginPass(viewport: viewport, axisHint: _axisHint)) {
      _commitEmpty();
      return;
    }

    final bool vertical = _geometry.axis == Axis.vertical;
    final double fullMainHi = _geometry.viewportMainExtent;
    final double fullCrossHi = _geometry.viewportCrossExtent;

    final double insetMainLo =
        vertical ? _viewportInsets.top : _viewportInsets.left;
    final double insetMainHi =
        vertical ? _viewportInsets.bottom : _viewportInsets.right;
    final double insetCrossLo =
        vertical ? _viewportInsets.left : _viewportInsets.top;
    final double insetCrossHi =
        vertical ? _viewportInsets.right : _viewportInsets.bottom;

    final double effMainLo = insetMainLo.clamp(0.0, fullMainHi);
    final double effMainHi = (fullMainHi - insetMainHi).clamp(0.0, fullMainHi);
    final double effCrossLo = insetCrossLo.clamp(0.0, fullCrossHi);
    final double effCrossHi =
        (fullCrossHi - insetCrossHi).clamp(0.0, fullCrossHi);

    if (effMainHi - effMainLo <= 0 || effCrossHi - effCrossLo <= 0) {
      _commitEmpty();
      return;
    }

    final double visMainLo = _insetsAffectVisibility ? effMainLo : 0.0;
    final double visMainHi = _insetsAffectVisibility ? effMainHi : fullMainHi;
    final double visCrossLo = _insetsAffectVisibility ? effCrossLo : 0.0;
    final double visCrossHi =
        _insetsAffectVisibility ? effCrossHi : fullCrossHi;

    _anchorPos =
        effMainLo + _region.anchor.resolveFromStart(effMainHi - effMainLo);

    final bool needsEffectiveRect =
        _region is ScrollSpyCustomRegion || _debugEnabled;
    if (needsEffectiveRect) {
      _effectiveRect = vertical
          ? Rect.fromLTRB(effCrossLo, effMainLo, effCrossHi, effMainHi)
          : Rect.fromLTRB(effMainLo, effCrossLo, effMainHi, effCrossHi);
    }

    _focusedScratch.clear();
    _visibleScratch.clear();
    int measurableCount = 0;

    _registry.beginCompute();
    for (final slot in _registry.slots) {
      final BuildContext? context = slot.context;
      final RenderBox? box = slot.box;
      if (context == null || !context.mounted || box == null || !box.attached) {
        slot.resetMetrics();
        _registry.markDead(slot);
        continue;
      }

      _geometry.ensureMeasured(slot);
      if (!slot.measurable) continue;
      measurableCount++;

      // Visibility: 2D intersection with the visibility bounds.
      final double itemMain = slot.mainEnd - slot.mainStart;
      final double itemCross = slot.crossEndNow - slot.crossStartNow;
      final double itemArea = itemMain.abs() * itemCross.abs();

      final double visMainStart =
          slot.mainStart > visMainLo ? slot.mainStart : visMainLo;
      final double visMainEnd =
          slot.mainEnd < visMainHi ? slot.mainEnd : visMainHi;
      final double visCrossStart =
          slot.crossStartNow > visCrossLo ? slot.crossStartNow : visCrossLo;
      final double visCrossEnd =
          slot.crossEndNow < visCrossHi ? slot.crossEndNow : visCrossHi;

      final double visMain =
          visMainEnd - visMainStart > 0 ? visMainEnd - visMainStart : 0.0;
      final double visCross =
          visCrossEnd - visCrossStart > 0 ? visCrossEnd - visCrossStart : 0.0;

      final double visibleFraction = itemArea <= 0
          ? 0.0
          : ((visMain * visCross) / itemArea).clamp(0.0, 1.0);
      final bool isVisible = visibleFraction > 0.0;

      slot.visibleFraction = visibleFraction;
      slot.isVisible = isVisible;
      slot.distanceToAnchorPx =
          (slot.mainStart + slot.mainEnd) / 2.0 - _anchorPos;

      if (isVisible) {
        _regionSlot = slot;
        _region.evaluateMainAxisInto(
          _regionScratch,
          itemStart: slot.mainStart,
          itemEnd: slot.mainEnd,
          anchorPos: _anchorPos,
          input: _regionInput,
        );
        final bool isFocused = _regionScratch.isFocused;
        slot.isFocused = isFocused;
        slot.focusProgress = isFocused ? _regionScratch.focusProgress : 0.0;
        slot.focusOverlapFraction =
            isFocused ? _regionScratch.overlapFraction : 0.0;
      } else {
        slot.isFocused = false;
        slot.focusProgress = 0.0;
        slot.focusOverlapFraction = 0.0;
      }

      if (_includeItemRects) {
        slot.itemRectCache = _rectOfSlot(slot);
        slot.visibleRectCache = (visMain > 0 && visCross > 0)
            ? (vertical
                ? Rect.fromLTRB(
                    visCrossStart, visMainStart, visCrossEnd, visMainEnd)
                : Rect.fromLTRB(
                    visMainStart, visCrossStart, visMainEnd, visCrossEnd))
            : null;
      } else {
        slot.itemRectCache = null;
        slot.visibleRectCache = null;
      }

      if (isVisible) _visibleScratch.add(slot.id);
      if (slot.isFocused) _focusedScratch.add(slot.id);
    }
    _regionSlot = null;
    _registry.endCompute();

    if (measurableCount == 0) {
      _commitEmpty();
      return;
    }

    final PrimarySelection<T> selection = EngineSelection.select<T>(
      slots: _registry.slots,
      policy: _policy,
      stability: _stability,
      previousPrimaryId: _previousPrimaryId,
      previousPrimarySince: _previousPrimarySince,
      now: _clock.elapsed,
      into: _selectionScratch,
    );
    _previousPrimaryId = selection.primaryId;
    _previousPrimarySince = selection.primarySince;

    _frame
      ..primaryId = selection.primaryId
      ..focusedIds = _focusedScratch
      ..visibleIds = _visibleScratch;
    _controller.commit(_frame);

    if (_debugEnabled) _publishDebugFrame();
  }

  RenderAbstractViewport? _resolveViewport() {
    final RenderAbstractViewport? current = _viewport;
    if (current != null && current.attached) return current;
    _viewport = null;

    for (final slot in _registry.slots) {
      final RenderBox? box = slot.box;
      if (box == null || !box.attached) continue;
      final RenderAbstractViewport? viewport = EngineGeometry.viewportOf(box);
      if (viewport != null) {
        _viewport = viewport;
        break;
      }
    }
    return _viewport;
  }

  void _commitEmpty() {
    _previousPrimaryId = null;
    _previousPrimarySince = null;

    for (final slot in _registry.slots) {
      slot.resetMetrics();
    }

    _focusedScratch.clear();
    _visibleScratch.clear();
    _frame
      ..primaryId = null
      ..focusedIds = _focusedScratch
      ..visibleIds = _visibleScratch;
    _controller.commit(_frame);

    if (_debugEnabled) {
      _debugFrame.value = debug.ScrollSpyDebugFrame<T>(
        sequence: ++_debugSequence,
        viewportRect: Rect.zero,
        focusRegionRect: null,
        focusRegionLabel: _buildFocusRegionLabel(_region),
        primaryId: null,
        focusedIds: const {},
        items: const {},
        snapshot: _materializeSnapshot(),
      );
    }
  }

  Rect _rectOfSlot(ItemSlot<T> slot) {
    return _geometry.axis == Axis.vertical
        ? Rect.fromLTRB(
            slot.crossStartNow, slot.mainStart, slot.crossEndNow, slot.mainEnd)
        : Rect.fromLTRB(
            slot.mainStart, slot.crossStartNow, slot.mainEnd, slot.crossEndNow);
  }

  ScrollSpySnapshot<T> _materializeSnapshot() {
    final Map<T, ScrollSpyItemFocus<T>> items = <T, ScrollSpyItemFocus<T>>{};
    for (final slot in _registry.slots) {
      if (!slot.measurable) continue;
      items[slot.id] = slot.toItemFocus(
        itemRect: slot.itemRectCache,
        visibleRect: slot.visibleRectCache,
      );
    }
    return ScrollSpySnapshot<T>(
      computedAt: DateTime.now(),
      primaryId: _previousPrimaryId,
      focusedIds: Set<T>.of(_frame.focusedIds),
      visibleIds: Set<T>.of(_frame.visibleIds),
      items: items,
    );
  }

  void _publishDebugFrame() {
    final Map<T, debug.ScrollSpyDebugItem<T>> items =
        <T, debug.ScrollSpyDebugItem<T>>{};
    for (final slot in _registry.slots) {
      final Rect? rect = slot.itemRectCache;
      if (!slot.measurable || rect == null) continue;
      items[slot.id] = debug.ScrollSpyDebugItem<T>(
        id: slot.id,
        itemRect: rect,
        visibleRect: slot.visibleRectCache,
        focus: slot.toItemFocus(
          itemRect: slot.itemRectCache,
          visibleRect: slot.visibleRectCache,
        ),
      );
    }

    _debugFrame.value = debug.ScrollSpyDebugFrame<T>(
      sequence: ++_debugSequence,
      viewportRect: _effectiveRect,
      focusRegionRect: _buildFocusRegionRect(),
      focusRegionLabel: _buildFocusRegionLabel(_region),
      primaryId: _previousPrimaryId,
      focusedIds: Set<T>.of(_frame.focusedIds),
      items: Map<T, debug.ScrollSpyDebugItem<T>>.unmodifiable(items),
      snapshot: _materializeSnapshot(),
    );
  }

  Rect? _buildFocusRegionRect() {
    if (_effectiveRect.isEmpty) return null;

    final double thicknessPx = switch (_region) {
      ScrollSpyLineRegion(:final thicknessPx) =>
        thicknessPx <= 0.0 ? 1.0 : thicknessPx,
      ScrollSpyZoneRegion(:final extentPx) => extentPx,
      ScrollSpyCustomRegion() => 1.0,
    };
    final double halfThickness = thicknessPx / 2.0;

    return _geometry.axis == Axis.vertical
        ? Rect.fromLTWH(
            _effectiveRect.left,
            _anchorPos - halfThickness,
            _effectiveRect.width,
            thicknessPx,
          )
        : Rect.fromLTWH(
            _anchorPos - halfThickness,
            _effectiveRect.top,
            thicknessPx,
            _effectiveRect.height,
          );
  }

  String? _buildFocusRegionLabel(ScrollSpyRegion region) {
    return switch (region) {
      ScrollSpyZoneRegion(:final anchor, :final extentPx) =>
        'zone @ $anchor (extent ${extentPx.toStringAsFixed(0)}px)',
      ScrollSpyLineRegion(:final anchor, :final thicknessPx) =>
        thicknessPx <= 0.0
            ? 'line @ $anchor'
            : 'line @ $anchor (th ${thicknessPx.toStringAsFixed(1)}px)',
      ScrollSpyCustomRegion(:final anchor) => 'custom @ $anchor',
    };
  }

  /// Releases listeners, timers, and debug notifiers. The engine becomes
  /// inert; all subsequent calls are ignored.
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
