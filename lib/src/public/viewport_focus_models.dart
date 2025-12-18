import 'dart:collection';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import 'package:viewport_focus/src/utils/equality.dart';

/// Represents the computed focus state of a single item within the viewport at a
/// specific moment in time.
///
/// This class serves as the immutable "source of truth" for an item's
/// relationship with the focus region. Instances are produced by the internal
/// focus engine during scroll or layout updates and are delivered to the UI via
/// [ViewportFocusController].
///
/// Developers typically consume this object in the builder of a [ViewportFocusItem] to:
/// - Trigger animations when an item enters/exits the focus region.
/// - Start or stop media playback (autoplay) when [isPrimary] becomes true.
/// - Log analytics events when [visibleFraction] exceeds a threshold.
///
/// This class is designed to be deeply immutable and efficiently diffable to minimize
/// unnecessary widget rebuilds.
@immutable
class ViewportItemFocus<T> {
  /// A stable identifier for the item (post id, key, database ID, etc).
  ///
  /// This ID must be unique among all registered items in the [ViewportFocusScope].
  final T id;

  /// Whether any portion of the item is currently visible within the viewport's bounds.
  ///
  /// Use this to detach heavy resources (like video controllers) for items that are
  /// completely off-screen to save memory.
  final bool isVisible;

  /// Whether this item intersects the active [ViewportFocusRegion].
  ///
  /// Being "focused" means the item is within the "attention zone" defined by the configuration.
  /// Multiple items can be focused simultaneously (e.g., if the focus region is a large zone).
  ///
  /// This is distinct from [isPrimary], which is granted to only one focused item at a time.
  final bool isFocused;

  /// Whether this item is the single "winner" among all focused items.
  ///
  /// The primary item is determined by the [ViewportFocusPolicy] (e.g., closest to center)
  /// and filtered by [ViewportFocusStability] rules (hysteresis, min duration).
  ///
  /// This property is the standard signal for "autoplay" logic.
  final bool isPrimary;

  /// The fraction of the item's total size that is currently visible in the viewport (0.0 to 1.0).
  ///
  /// - `1.0`: The item is fully visible.
  /// - `0.0`: The item has no visible intersection with the viewport (and
  ///   [isVisible] will be false).
  ///
  /// This is useful for analytics (e.g., "viewed 50%") or for visibility-driven
  /// effects.
  final double visibleFraction;

  /// The signed distance (in pixels) from the center of this item to the configured [ViewportAnchor].
  ///
  /// This value is critical for determining which item is "closest" to the target focus point.
  /// - A negative value indicates the item's center is before the anchor (e.g., above it in a vertical list).
  /// - A positive value indicates the item's center is after the anchor (e.g., below it in a vertical list).
  /// - A value of `0.0` means the item is perfectly centered on the anchor.
  ///
  /// This metric is the primary driver for [ViewportFocusPolicy.closestToAnchor].
  final double distanceToAnchorPx;

  /// A normalized value (0.0 to 1.0) indicating how "centered" the item is relative to the
  /// focus region's anchor.
  ///
  /// - `1.0`: The item is perfectly centered at the anchor.
  /// - `0.0`: The item is far away from the anchor (outside the region's scale).
  ///
  /// This is useful for interpolation effects, such as scaling an item up as it approaches the center.
  /// Unlike [focusOverlapFraction], this measures center-closeness, not physical overlap.
  final double focusProgress;

  /// The fraction of the focus region's band that overlaps this item,
  /// normalized by the region's size.
  ///
  /// - For a `ViewportFocusRegion.line` with `thicknessPx == 0`, this is `1.0`
  ///   when the line intersects the item, otherwise `0.0`.
  /// - For a line with `thicknessPx > 0`, this is the fraction of the line band
  ///   that is overlapped by the item (`overlapPx / thicknessPx`, clamped).
  /// - For `ViewportFocusRegion.zone`, this is the fraction of the zone band
  ///   overlapped by the item (`overlapPx / extentPx`, clamped).
  ///
  /// This is the primary driver for [ViewportFocusPolicy.largestFocusOverlap].
  final double focusOverlapFraction;

  /// The bounding box of the item in viewport coordinates.
  ///
  /// This is typically `null` to save memory, unless debug mode is enabled or the engine
  /// is configured to include rects. Useful for custom debugging or advanced geometry checks.
  final Rect? itemRectInViewport;

  /// The bounding box of the *visible portion* of the item in viewport coordinates.
  ///
  /// This is typically `null` unless debug mode is enabled.
  final Rect? visibleRectInViewport;

  /// Creates an immutable focus state for a single item at a point in time.
  ///
  /// Instances are produced by the engine and should be treated as snapshots
  /// rather than mutable state.
  const ViewportItemFocus({
    required this.id,
    required this.isVisible,
    required this.isFocused,
    required this.isPrimary,
    required this.visibleFraction,
    required this.distanceToAnchorPx,
    required this.focusProgress,
    required this.focusOverlapFraction,
    this.itemRectInViewport,
    this.visibleRectInViewport,
  })  : assert(visibleFraction >= 0.0 && visibleFraction <= 1.0),
        assert(focusProgress >= 0.0 && focusProgress <= 1.0),
        assert(focusOverlapFraction >= 0.0 && focusOverlapFraction <= 1.0);

  /// Creates a default "off-screen" state for an item ID.
  ///
  /// This is used when the controller is asked for the state of an item that
  /// hasn't been detected by the engine yet (or has scrolled far away).
  factory ViewportItemFocus.unknown({required T id}) {
    return ViewportItemFocus<T>(
      id: id,
      isVisible: false,
      isFocused: false,
      isPrimary: false,
      visibleFraction: 0.0,
      distanceToAnchorPx: double.infinity,
      focusProgress: 0.0,
      focusOverlapFraction: 0.0,
      itemRectInViewport: null,
      visibleRectInViewport: null,
    );
  }

  /// The absolute distance in pixels from the item's center to the anchor.
  double get absDistanceToAnchorPx => distanceToAnchorPx.abs();

  /// Whether geometry rects are populated in this instance.
  bool get hasRects => itemRectInViewport != null;

  /// Returns a copy of this focus state with selected fields changed.
  ///
  /// The [id] is preserved. This is used internally by the engine to update
  /// flags like [isPrimary] without re-allocating unrelated fields.
  ViewportItemFocus<T> copyWith({
    bool? isVisible,
    bool? isFocused,
    bool? isPrimary,
    double? visibleFraction,
    double? distanceToAnchorPx,
    double? focusProgress,
    double? focusOverlapFraction,
    Rect? itemRectInViewport,
    Rect? visibleRectInViewport,
  }) {
    return ViewportItemFocus<T>(
      id: id,
      isVisible: isVisible ?? this.isVisible,
      isFocused: isFocused ?? this.isFocused,
      isPrimary: isPrimary ?? this.isPrimary,
      visibleFraction: visibleFraction ?? this.visibleFraction,
      distanceToAnchorPx: distanceToAnchorPx ?? this.distanceToAnchorPx,
      focusProgress: focusProgress ?? this.focusProgress,
      focusOverlapFraction: focusOverlapFraction ?? this.focusOverlapFraction,
      itemRectInViewport: itemRectInViewport ?? this.itemRectInViewport,
      visibleRectInViewport:
          visibleRectInViewport ?? this.visibleRectInViewport,
    );
  }

  /// Performs a semantic equality check with tolerance for floating-point
  /// values.
  ///
  /// Use this method when deciding whether to rebuild a widget, as standard
  /// equality (`==`) might return false for infinitesimally small changes in
  /// scroll position that don't affect the UI. The controller uses similar
  /// logic to avoid noisy per-item updates.
  bool nearlyEquals(
    ViewportItemFocus<T> other, {
    double epsilon = 0.01,
    double rectEpsilon = 0.5,
  }) {
    if (identical(this, other)) return true;
    if (id != other.id) return false;

    return isVisible == other.isVisible &&
        isFocused == other.isFocused &&
        isPrimary == other.isPrimary &&
        nearlyEqual(visibleFraction, other.visibleFraction, epsilon: epsilon) &&
        nearlyEqual(
          distanceToAnchorPx,
          other.distanceToAnchorPx,
          epsilon: rectEpsilon,
        ) &&
        nearlyEqual(focusProgress, other.focusProgress, epsilon: epsilon) &&
        nearlyEqual(
          focusOverlapFraction,
          other.focusOverlapFraction,
          epsilon: epsilon,
        ) &&
        rectNearlyEqual(
          itemRectInViewport,
          other.itemRectInViewport,
          epsilon: rectEpsilon,
        ) &&
        rectNearlyEqual(
          visibleRectInViewport,
          other.visibleRectInViewport,
          epsilon: rectEpsilon,
        );
  }

  @override
  String toString() {
    return 'ViewportItemFocus('
        'id: $id, '
        'visible: $isVisible, '
        'focused: $isFocused, '
        'primary: $isPrimary, '
        'visibleFraction: ${visibleFraction.toStringAsFixed(3)}, '
        'distanceToAnchorPx: ${distanceToAnchorPx.toStringAsFixed(1)}, '
        'focusProgress: ${focusProgress.toStringAsFixed(3)}, '
        'focusOverlapFraction: ${focusOverlapFraction.toStringAsFixed(3)}'
        ')';
  }

  @override
  bool operator ==(Object other) {
    return other is ViewportItemFocus<T> &&
        other.id == id &&
        other.isVisible == isVisible &&
        other.isFocused == isFocused &&
        other.isPrimary == isPrimary &&
        other.visibleFraction == visibleFraction &&
        other.distanceToAnchorPx == distanceToAnchorPx &&
        other.focusProgress == focusProgress &&
        other.focusOverlapFraction == focusOverlapFraction &&
        other.itemRectInViewport == itemRectInViewport &&
        other.visibleRectInViewport == visibleRectInViewport;
  }

  @override
  int get hashCode => Object.hash(
        id,
        isVisible,
        isFocused,
        isPrimary,
        visibleFraction,
        distanceToAnchorPx,
        focusProgress,
        focusOverlapFraction,
        itemRectInViewport,
        visibleRectInViewport,
      );
}

/// A complete, immutable snapshot of the focus state for the entire scope at a
/// specific moment.
///
/// While [ViewportFocusController] exposes individual signals like `primaryId`
/// or `focusedIds`, this class captures the entire state of the engine in one
/// object.
///
/// Advanced users can listen to this via [ViewportFocusController.snapshot] to
/// implement complex logic that requires a holistic view of all items (e.g.,
/// "prefetch the 3 items following the primary one").
@immutable
class ViewportFocusSnapshot<T> {
  /// The timestamp when this snapshot was computed.
  final DateTime computedAt;

  /// The ID of the single primary winner.
  ///
  /// Is `null` if no items are focused, or if the policy/stability rules prevented a selection.
  final T? primaryId;

  /// The set of all IDs that currently intersect the focus region.
  final Set<T> focusedIds;

  /// The set of all IDs that are currently visible in the viewport.
  final Set<T> visibleIds;

  /// A map containing detailed focus information for items in this snapshot.
  ///
  /// In this package’s default engine, this map contains one entry for every
  /// registered item that was **measurable** during this compute pass (mounted,
  /// attached, and with a valid size) — regardless of whether the item ended up
  /// visible or focused.
  ///
  /// The map can be empty when there are no registered items, or when the
  /// engine cannot yet resolve a viewport (for example before the first layout
  /// pass).
  final Map<T, ViewportItemFocus<T>> items;

  /// Creates a snapshot of the focus state for all measurable items.
  ///
  /// Collections are wrapped in unmodifiable views to prevent mutation.
  ViewportFocusSnapshot({
    required this.computedAt,
    required this.primaryId,
    required Set<T> focusedIds,
    required Set<T> visibleIds,
    required Map<T, ViewportItemFocus<T>> items,
  })  : focusedIds = UnmodifiableSetView(focusedIds),
        visibleIds = UnmodifiableSetView(visibleIds),
        items = UnmodifiableMapView(items);

  /// Creates an empty snapshot.
  ///
  /// This is useful as an initial value before any real compute pass happens.
  factory ViewportFocusSnapshot.empty({DateTime? computedAt}) {
    return ViewportFocusSnapshot<T>(
      computedAt: computedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      primaryId: null,
      focusedIds: const {},
      visibleIds: const {},
      items: const {},
    );
  }

  /// Returns the focus state for [id] if present in [items].
  ViewportItemFocus<T>? itemOf(T id) => items[id];

  /// Whether a non-null [primaryId] is present.
  bool get hasPrimary => primaryId != null;

  /// Tolerance-based semantic equality.
  ///
  /// Useful for snapshot-based diffing while ignoring micro jitter.
  bool nearlyEquals(
    ViewportFocusSnapshot<T> other, {
    double epsilon = 0.01,
    double rectEpsilon = 0.5,
  }) {
    if (identical(this, other)) return true;

    if (primaryId != other.primaryId) return false;
    if (!setEquals(focusedIds, other.focusedIds)) return false;
    if (!setEquals(visibleIds, other.visibleIds)) return false;

    if (items.length != other.items.length) return false;
    for (final entry in items.entries) {
      final b = other.items[entry.key];
      if (b == null) return false;
      if (!entry.value.nearlyEquals(
        b,
        epsilon: epsilon,
        rectEpsilon: rectEpsilon,
      )) {
        return false;
      }
    }
    return true;
  }

  /// Returns a copy with the provided fields replaced.
  ///
  /// This preserves the immutability contract (collections remain unmodifiable)
  /// and is useful for tests or derived state.
  ViewportFocusSnapshot<T> copyWith({
    DateTime? computedAt,
    T? primaryId,
    Set<T>? focusedIds,
    Set<T>? visibleIds,
    Map<T, ViewportItemFocus<T>>? items,
  }) {
    return ViewportFocusSnapshot<T>(
      computedAt: computedAt ?? this.computedAt,
      primaryId: primaryId ?? this.primaryId,
      focusedIds: focusedIds ?? this.focusedIds,
      visibleIds: visibleIds ?? this.visibleIds,
      items: items ?? this.items,
    );
  }

  @override
  String toString() {
    return 'ViewportFocusSnapshot('
        'computedAt: $computedAt, '
        'primaryId: $primaryId, '
        'focusedIds: ${focusedIds.length}, '
        'visibleIds: ${visibleIds.length}, '
        'items: ${items.length}'
        ')';
  }

  @override
  bool operator ==(Object other) {
    return other is ViewportFocusSnapshot<T> &&
        other.computedAt == computedAt &&
        other.primaryId == primaryId &&
        setEquals(other.focusedIds, focusedIds) &&
        setEquals(other.visibleIds, visibleIds) &&
        mapEquals(other.items, items);
  }

  @override
  int get hashCode => Object.hash(
        computedAt,
        primaryId,
        Object.hashAllUnordered(focusedIds),
        Object.hashAllUnordered(visibleIds),
        Object.hashAll(items.entries.map((e) => Object.hash(e.key, e.value))),
      );
}
