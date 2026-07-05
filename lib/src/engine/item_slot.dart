import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:scroll_spy/src/public/scroll_spy_models.dart';

/// How an item's geometry is derived on a compute pass.
enum GeometryTier {
  /// No valid anchor; a full measure is required before use.
  unmeasured,

  /// Pure-translation chain into a [RenderSliverMultiBoxAdaptor]: position is
  /// derived from a cached scroll-space anchor with an O(1) validation.
  fast,

  /// Pure-translation chain under any other sliver type: re-measured each
  /// pass with the allocation-free walk.
  walk,

  /// The chain contains a non-translation segment (scale/rotation/...):
  /// re-measured each pass in matrix mode.
  matrix,
}

/// Mutable per-item engine state, allocated once per registered item.
///
/// Slots are the hot-path data structure of the engine: geometry anchors,
/// validation fingerprints, and the latest computed metrics all live here as
/// plain fields so a steady-state compute pass allocates nothing.
final class ItemSlot<T> {
  ItemSlot({required this.id, required this.registrationOrder});

  /// The item identifier used by the scope/controller.
  final T id;

  /// Stable monotonic order assigned on first registration; deterministic
  /// tie-breaker for selection.
  final int registrationOrder;

  /// Context of the item subtree, used for `mounted` checks.
  BuildContext? context;

  /// The probe render object used for geometry.
  RenderBox? box;

  // Geometry anchor (linear scroll model). Valid when [tier] != unmeasured.

  GeometryTier tier = GeometryTier.unmeasured;

  /// Viewport epoch the anchor was captured under; anchors from an older
  /// epoch (viewport identity/size/axis changed) are not trusted.
  int anchorEpoch = -1;

  /// Main-axis start in viewport coordinates at capture time.
  double mainStart0 = 0;

  /// Cross-axis start in viewport coordinates (stable across scroll).
  double crossStart = 0;

  /// Main-axis extent at capture time.
  double mainExtent = 0;

  /// Cross-axis extent at capture time.
  double crossExtent = 0;

  /// Scroll offset at capture time.
  double pixels0 = 0;

  /// Enclosing sliver on the chain (fast-tier fingerprint).
  RenderSliver? sliver;

  /// Direct child of [sliver] on the chain (fast-tier fingerprint).
  RenderObject? sliverChild;

  /// [SliverMultiBoxAdaptorParentData.layoutOffset] at capture time.
  double layoutOffset0 = 0;

  /// `sliver.constraints.precedingScrollExtent` at capture time.
  double precedingExtent0 = 0;

  /// Probe box size at capture time.
  double boxW0 = 0;
  double boxH0 = 0;

  // Latest computed metrics. Valid when [measurable] is true.

  /// Whether the item could be measured on the latest pass.
  bool measurable = false;

  bool isVisible = false;
  bool isFocused = false;
  bool isPrimary = false;
  double visibleFraction = 0;
  double distanceToAnchorPx = double.infinity;
  double focusProgress = 0;
  double focusOverlapFraction = 0;

  // Item rect in viewport coordinates for the latest pass, decomposed along
  // the engine axis.
  double mainStart = 0;
  double mainEnd = 0;
  double crossStartNow = 0;
  double crossEndNow = 0;

  /// Materialized rects for the latest pass. Populated only when the engine
  /// is configured with `includeItemRects` (debug); null otherwise.
  Rect? itemRectCache;
  Rect? visibleRectCache;

  /// Drops the geometry anchor so the next pass performs a full measure.
  ///
  /// Latest metrics are intentionally preserved: they describe the last
  /// committed state, not the anchor.
  void invalidateGeometry() {
    tier = GeometryTier.unmeasured;
    sliver = null;
    sliverChild = null;
  }

  /// Materializes an immutable [ScrollSpyItemFocus] from the current metrics.
  ///
  /// Only called for slots someone is observing (per-item listeners, snapshot
  /// materialization, custom policy comparators); the steady-state hot path
  /// never materializes.
  ScrollSpyItemFocus<T> toItemFocus({Rect? itemRect, Rect? visibleRect}) {
    return ScrollSpyItemFocus<T>(
      id: id,
      isVisible: isVisible,
      isFocused: isFocused,
      isPrimary: isPrimary,
      visibleFraction: visibleFraction,
      distanceToAnchorPx: distanceToAnchorPx,
      focusProgress: focusProgress,
      focusOverlapFraction: focusOverlapFraction,
      itemRectInViewport: itemRect,
      visibleRectInViewport: visibleRect,
    );
  }

  /// Marks the item unmeasurable and resets metrics to the unknown state.
  ///
  /// The geometry anchor is preserved; it revalidates on the next pass.
  void resetMetrics() {
    measurable = false;
    isVisible = false;
    isFocused = false;
    isPrimary = false;
    visibleFraction = 0;
    distanceToAnchorPx = double.infinity;
    focusProgress = 0;
    focusOverlapFraction = 0;
    mainStart = 0;
    mainEnd = 0;
    crossStartNow = 0;
    crossEndNow = 0;
    itemRectCache = null;
    visibleRectCache = null;
  }
}
