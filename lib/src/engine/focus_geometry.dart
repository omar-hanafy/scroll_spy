import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:scroll_spy/src/public/scroll_spy_models.dart';
import 'package:scroll_spy/src/public/scroll_spy_region.dart';
import 'package:scroll_spy/src/engine/focus_registry.dart';

/// Output of a single geometry pass.
///
/// This is an internal data structure produced by [FocusGeometry.compute] and
/// consumed by the selection step. It contains the resolved viewport bounds and
/// per-item metrics required to decide visibility/focus/primary, and it is also
/// used by the engine to build debug frames when enabled.
@immutable
class ScrollSpyGeometryResult<T> {
  /// Creates a geometry result for a single compute pass.
  ///
  /// Use [ScrollSpyGeometry.compute] to build this with correct coordinate spaces.
  const ScrollSpyGeometryResult({
    required this.viewportRect,
    required this.effectiveViewportRect,
    required this.viewportGlobalRect,
    required this.axis,
    required this.items,
    this.fullViewportRect = Rect.zero,
    this.fullViewportGlobalRect = Rect.zero,
    this.viewportInsets = EdgeInsets.zero,
    this.insetsAffectVisibility = true,
    this.anchorOffsetPx,
  });

  /// Effective viewport rect after applying [viewportInsets] (viewport-local coords).
  ///
  /// When insets are non-zero, this rect can have a non-zero origin.
  final Rect viewportRect;

  /// Effective viewport rect used for logic, deflated by insets.
  ///
  /// This is the same as [viewportRect] but explicitly named to avoid confusion.
  final Rect effectiveViewportRect;

  /// Effective viewport rect after applying [viewportInsets] (global coords).
  final Rect viewportGlobalRect;

  /// Full viewport rect without insets (viewport-local coords).
  final Rect fullViewportRect;

  /// Full viewport rect without insets (global coords).
  final Rect fullViewportGlobalRect;

  /// The insets used to deflate the viewport.
  final EdgeInsets viewportInsets;

  /// Whether [viewportInsets] affect visibility checks.
  final bool insetsAffectVisibility;

  /// The axis used to interpret "main axis" measurements (anchor position,
  /// distance-to-anchor, region extent).
  final Axis axis;

  /// Per-item metrics (primary selection happens later).
  ///
  /// This list includes every registered entry whose render object is currently
  /// mounted, attached, and has a size. Items may still appear here even when
  /// [ScrollSpyItemFocus.isVisible] is false (for example, when they are built
  /// but fully outside the viewport).
  final List<ScrollSpyItemFocus<T>> items;

  /// The resolved absolute anchor position in viewport-local pixels.
  final double? anchorOffsetPx;

  /// Returns an empty geometry result.
  ///
  /// This is typically used when the engine cannot yet resolve a viewport
  /// render object (for example, before the first layout pass).
  factory ScrollSpyGeometryResult.empty({Axis axis = Axis.vertical}) {
    return ScrollSpyGeometryResult<T>(
      viewportRect: Rect.zero,
      effectiveViewportRect: Rect.zero,
      viewportGlobalRect: Rect.zero,
      fullViewportRect: Rect.zero,
      fullViewportGlobalRect: Rect.zero,
      viewportInsets: EdgeInsets.zero,
      insetsAffectVisibility: true,
      axis: axis,
      items: const [],
      anchorOffsetPx: null,
    );
  }
}

/// RenderBox/viewport geometry utilities.
///
/// Computes per-item metrics relative to the scrollable viewport:
/// - item rect in **viewport-local** coordinates
/// - visible fraction (intersection area / item area)
/// - signed distance from item center to the configured anchor
/// - focus hit/progress based on [ScrollSpyRegion.evaluate]
///
/// The selection step runs later and decides the primary winner.
class ScrollSpyGeometry {
  const ScrollSpyGeometry._();

  /// Computes geometry for the current [entries] snapshot.
  ///
  /// Viewport discovery:
  /// - The viewport is inferred from the first entry that is mounted, attached,
  ///   and has a valid [RenderAbstractViewport].
  /// - If no viewport can be found, an empty result is returned.
  ///
  /// Coordinate space:
  /// - `viewportRect` is `(Offset.zero & viewportBox.size)`.
  /// - `ScrollSpyItemFocus.itemRectInViewport` (when included) uses the same
  ///   coordinate system: the viewport’s top-left is `(0, 0)`.
  ///
  /// Allocation control:
  /// - When [includeItemRects] is false, rect fields on [ScrollSpyItemFocus] are
  ///   set to `null` to reduce per-frame allocations (useful outside of debug).
  static ScrollSpyGeometryResult<T> compute<T>({
    required Iterable<ScrollSpyRegistryEntry<T>> entries,
    required ScrollSpyRegion region,
    required Axis axis,
    required bool includeItemRects,
    EdgeInsets viewportInsets = EdgeInsets.zero,
    bool insetsAffectVisibility = true,
  }) {
    RenderBox? viewportBox;

    for (final entry in entries) {
      if (!entry.context.mounted) continue;

      final RenderBox ro = entry.box;
      if (!ro.hasSize || !ro.attached) continue;

      final viewport = RenderAbstractViewport.of(ro);
      final RenderBox? viewportRenderBox =
          viewport is RenderBox ? viewport as RenderBox : null;
      if (viewportRenderBox != null &&
          viewportRenderBox.hasSize &&
          viewportRenderBox.attached) {
        viewportBox = viewportRenderBox;
        break;
      }
    }

    if (viewportBox == null) {
      return ScrollSpyGeometryResult<T>.empty(axis: axis);
    }

    final Offset viewportGlobalTopLeft = viewportBox.localToGlobal(Offset.zero);
    final Rect fullViewportGlobalRect =
        viewportGlobalTopLeft & viewportBox.size;
    final Rect fullViewportRect = Offset.zero & viewportBox.size;

    final bool hasInsets = viewportInsets != EdgeInsets.zero;

    // 1. Compute effective viewport based on insets.
    final Rect effectiveViewportRect = hasInsets
        ? _deflateViewportRect(fullViewportRect, viewportInsets)
        : fullViewportRect;

    final Rect effectiveViewportGlobalRect = hasInsets
        ? _deflateViewportRect(fullViewportGlobalRect, viewportInsets)
        : fullViewportGlobalRect;

    // Guard against insets larger than the viewport size.
    if (effectiveViewportRect.width <= 0 || effectiveViewportRect.height <= 0) {
      return ScrollSpyGeometryResult<T>.empty(axis: axis);
    }

    // Visibility and region evaluation can optionally ignore insets.
    final Rect visibilityRect =
        insetsAffectVisibility ? effectiveViewportRect : fullViewportRect;

    // Region evaluation always uses the effective viewport.
    final Rect evaluationViewportRect = effectiveViewportRect;

    // 2. Resolve anchor. The anchor is ALWAYS resolved relative to the *effective* viewport.
    final double anchorOffsetPx = _resolveAnchorOffsetPx(
      region: region,
      viewportRect: effectiveViewportRect,
      axis: axis,
    );

    final List<ScrollSpyItemFocus<T>> items = <ScrollSpyItemFocus<T>>[];

    for (final entry in entries) {
      if (!entry.context.mounted) continue;

      final RenderBox ro = entry.box;
      if (!ro.hasSize || !ro.attached) continue;

      // Robustness guard: skip entries that don't belong to the selected viewport.
      final RenderAbstractViewport itemViewport = RenderAbstractViewport.of(ro);
      final RenderBox? itemViewportBox =
          itemViewport is RenderBox ? itemViewport as RenderBox : null;
      if (itemViewportBox == null || !identical(itemViewportBox, viewportBox)) {
        continue;
      }

      // Compute item rect in viewport-local coordinates.
      //
      // IMPORTANT:
      // Do not compute itemRect by shifting global coordinates, because that can
      // break under ancestor transforms (e.g. scale/rotation in the widget tree).
      final Rect itemRect = _itemRectInViewportSpace(ro, viewportBox);

      final Rect visibleRect = itemRect.intersect(visibilityRect);
      final double visibleFraction = _visibleFraction(
        itemRect: itemRect,
        visibleRect: visibleRect,
      );

      final bool isVisible = visibleFraction > 0.0;

      // Signed distance from item center to anchor (main axis).
      final double itemCenter = axis == Axis.vertical
          ? (itemRect.top + itemRect.height / 2.0)
          : (itemRect.left + itemRect.width / 2.0);

      final double distanceToAnchorPx = itemCenter - anchorOffsetPx;

      final ScrollSpyRegionResult regionResult = isVisible
          ? region.evaluate(
              ScrollSpyRegionInput(
                itemRectInViewport: itemRect,
                viewportRect: evaluationViewportRect,
                axis: axis,
                anchorOffsetPx: anchorOffsetPx,
              ),
            )
          : ScrollSpyRegionResult.notFocused;

      final bool isFocused = isVisible && regionResult.isFocused;

      items.add(
        ScrollSpyItemFocus<T>(
          id: entry.id,
          isVisible: isVisible,
          isFocused: isFocused,
          isPrimary: false,
          visibleFraction: visibleFraction,
          distanceToAnchorPx: distanceToAnchorPx,
          focusProgress: isFocused ? regionResult.focusProgress : 0.0,
          focusOverlapFraction: isFocused ? regionResult.overlapFraction : 0.0,
          itemRectInViewport: includeItemRects ? itemRect : null,
          visibleRectInViewport: includeItemRects
              ? (visibleRect.isEmpty ? null : visibleRect)
              : null,
        ),
      );
    }

    return ScrollSpyGeometryResult<T>(
      viewportRect:
          effectiveViewportRect, // Backward compatibility for tests/usage expecting "the viewport"
      effectiveViewportRect: effectiveViewportRect,
      viewportGlobalRect: effectiveViewportGlobalRect,
      fullViewportRect: fullViewportRect,
      fullViewportGlobalRect: fullViewportGlobalRect,
      viewportInsets: viewportInsets,
      insetsAffectVisibility: insetsAffectVisibility,
      axis: axis,
      items: items,
      anchorOffsetPx: anchorOffsetPx,
    );
  }

  static Rect _itemRectInViewportSpace(RenderBox item, RenderBox viewportBox) {
    final Size s = item.size;

    // Use `ancestor: viewportBox` so the result is already in viewport coords.
    final Offset p1 = item.localToGlobal(Offset.zero, ancestor: viewportBox);
    final Offset p2 = item.localToGlobal(
      Offset(s.width, 0),
      ancestor: viewportBox,
    );
    final Offset p3 = item.localToGlobal(
      Offset(0, s.height),
      ancestor: viewportBox,
    );
    final Offset p4 = item.localToGlobal(
      Offset(s.width, s.height),
      ancestor: viewportBox,
    );

    final double left = math.min(
      math.min(p1.dx, p2.dx),
      math.min(p3.dx, p4.dx),
    );
    final double top = math.min(math.min(p1.dy, p2.dy), math.min(p3.dy, p4.dy));
    final double right = math.max(
      math.max(p1.dx, p2.dx),
      math.max(p3.dx, p4.dx),
    );
    final double bottom = math.max(
      math.max(p1.dy, p2.dy),
      math.max(p3.dy, p4.dy),
    );

    return Rect.fromLTRB(left, top, right, bottom);
  }

  static double _resolveAnchorOffsetPx({
    required ScrollSpyRegion region,
    required Rect viewportRect,
    required Axis axis,
  }) {
    final ScrollSpyAnchor anchor = switch (region) {
      ScrollSpyLineRegion(:final anchor) => anchor,
      ScrollSpyZoneRegion(:final anchor) => anchor,
      ScrollSpyCustomRegion(:final anchor) => anchor,
    };

    return anchor.resolveInViewport(viewportRect, axis);
  }

  static Rect _deflateViewportRect(Rect rect, EdgeInsets insets) {
    if (insets == EdgeInsets.zero) return rect;

    final double left =
        (rect.left + insets.left).clamp(rect.left, rect.right).toDouble();
    final double top =
        (rect.top + insets.top).clamp(rect.top, rect.bottom).toDouble();
    final double right =
        (rect.right - insets.right).clamp(rect.left, rect.right).toDouble();
    final double bottom =
        (rect.bottom - insets.bottom).clamp(rect.top, rect.bottom).toDouble();

    final double normalizedRight = right < left ? left : right;
    final double normalizedBottom = bottom < top ? top : bottom;

    return Rect.fromLTRB(left, top, normalizedRight, normalizedBottom);
  }

  static double _visibleFraction({
    required Rect itemRect,
    required Rect visibleRect,
  }) {
    final double itemW = itemRect.width.abs();
    final double itemH = itemRect.height.abs();
    final double itemArea = itemW * itemH;
    if (itemArea <= 0) return 0;

    final double visW = math.max(0.0, visibleRect.width);
    final double visH = math.max(0.0, visibleRect.height);
    final double visArea = visW * visH;

    final double fraction = visArea / itemArea;
    return fraction.clamp(0.0, 1.0);
  }
}
