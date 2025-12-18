import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Axis;

/// Defines a fixed point within the viewport that serves as the reference for
/// focus calculations.
///
/// The anchor determines "where the user is looking."
/// - For a vertical list, `ViewportAnchor.fraction(0.5)` places the anchor
///   exactly in the vertical center.
/// - `ViewportAnchor.pixels(0)` places it at the very top.
///
/// This anchor is used by:
/// - [ViewportFocusRegion]: To position the line or zone relative to the
///   viewport.
/// - `ViewportFocusPolicy`: To determine which item is "closest" to this point.
@immutable
sealed class ViewportAnchor {
  /// An additional pixel offset applied *after* the base position is resolved.
  ///
  /// Useful for adjusting the anchor to account for fixed headers, safe areas, or
  /// simply to bias the focus point slightly off-center (e.g., "center + 50px").
  final double offsetPx;

  const ViewportAnchor({this.offsetPx = 0.0});

  /// Calculates the absolute pixel offset of this anchor from the viewport's
  /// start edge (top for vertical, left for horizontal).
  ///
  /// The returned value includes [offsetPx]. It is not clamped to the viewport
  /// extent; providing an offset that pushes the anchor outside the viewport is
  /// allowed and will affect distance/region calculations accordingly.
  double resolveFromStart(double viewportMainAxisExtent);

  /// Resolves the anchor to an absolute coordinate in the viewport's local
  /// coordinate space.
  ///
  /// This is a convenience wrapper around [resolveFromStart] that accounts for
  /// the viewport rect’s start offset.
  double resolveInViewport(Rect viewportRect, Axis axis) {
    final start = _mainAxisStart(viewportRect, axis);
    final extent = _mainAxisExtent(viewportRect, axis);
    return start + resolveFromStart(extent);
  }

  /// Creates an anchor defined as a fraction of the viewport's main axis size.
  ///
  /// - `0.0`: Start of the viewport (top/left).
  /// - `0.5`: Center of the viewport.
  /// - `1.0`: End of the viewport (bottom/right).
  const factory ViewportAnchor.fraction(double fraction, {double offsetPx}) =
      FractionViewportAnchor;

  /// Creates an anchor defined as a fixed pixel distance from the start of the viewport.
  ///
  /// - `0.0`: Exactly at the start (top/left).
  const factory ViewportAnchor.pixels(
    double pixelsFromStart, {
    double offsetPx,
  }) = PixelsViewportAnchor;
}

/// An anchor positioned at a fractional distance along the viewport's main axis.
///
/// Example: `ViewportAnchor.fraction(0.5)` represents the exact center.
@immutable
final class FractionViewportAnchor extends ViewportAnchor {
  /// The fraction of the viewport’s main-axis extent (0.0 to 1.0).
  final double fraction;

  /// Creates an anchor positioned at a fraction of the main axis extent.
  ///
  /// Use [offsetPx] to bias the anchor after the fraction is resolved.
  const FractionViewportAnchor(this.fraction, {super.offsetPx = 0.0})
      : assert(fraction >= 0.0 && fraction <= 1.0);

  @override
  double resolveFromStart(double viewportMainAxisExtent) {
    return (fraction * viewportMainAxisExtent) + offsetPx;
  }

  @override
  String toString() =>
      'ViewportAnchor.fraction($fraction, offsetPx: $offsetPx)';
}

/// An anchor positioned at a fixed pixel distance from the viewport's start edge.
///
/// Example: `ViewportAnchor.pixels(100)` places the anchor 100px from the top.
@immutable
final class PixelsViewportAnchor extends ViewportAnchor {
  /// The base pixel distance from the viewport’s start edge.
  final double pixelsFromStart;

  /// Creates an anchor positioned at a fixed pixel distance from the start.
  const PixelsViewportAnchor(this.pixelsFromStart, {super.offsetPx = 0.0});

  @override
  double resolveFromStart(double viewportMainAxisExtent) {
    return pixelsFromStart + offsetPx;
  }

  @override
  String toString() =>
      'ViewportAnchor.pixels($pixelsFromStart, offsetPx: $offsetPx)';
}

/// Data passed to [ViewportFocusRegion.evaluate] for a specific item.
///
/// This context allows custom regions to make complex decisions based on the
/// item's position relative to the viewport and the anchor.
@immutable
class ViewportRegionInput {
  /// The item’s bounding rect in viewport-local coordinates.
  ///
  /// The engine computes this in the same coordinate space as the viewport
  /// rect: `(0, 0)` represents the viewport’s top-left.
  final Rect itemRectInViewport;

  /// The viewport bounds in viewport-local coordinates.
  final Rect viewportRect;

  /// The axis used to interpret "main axis" values.
  final Axis axis;

  /// The resolved pixel position of the anchor relative to the viewport start.
  final double anchorOffsetPx;

  /// Creates the input data passed to region evaluators.
  ///
  /// All rects are in viewport-local coordinates.
  const ViewportRegionInput({
    required this.itemRectInViewport,
    required this.viewportRect,
    required this.axis,
    required this.anchorOffsetPx,
  });

  /// Item start along the main axis (top/left).
  double get itemMainAxisStart => _mainAxisStart(itemRectInViewport, axis);

  /// Item end along the main axis (bottom/right).
  double get itemMainAxisEnd => _mainAxisEnd(itemRectInViewport, axis);

  /// Item center along the main axis.
  double get itemMainAxisCenter => _mainAxisCenter(itemRectInViewport, axis);

  /// Item extent along the main axis (height/width).
  double get itemMainAxisExtent => _mainAxisExtent(itemRectInViewport, axis);

  /// Viewport start along the main axis (usually 0).
  double get viewportMainAxisStart => _mainAxisStart(viewportRect, axis);

  /// Viewport end along the main axis (height/width).
  double get viewportMainAxisEnd => _mainAxisEnd(viewportRect, axis);

  /// Viewport center along the main axis.
  double get viewportMainAxisCenter => _mainAxisCenter(viewportRect, axis);

  /// Viewport extent along the main axis (height/width).
  double get viewportMainAxisExtent => _mainAxisExtent(viewportRect, axis);
}

/// The result of evaluating whether an item intersects a [ViewportFocusRegion].
@immutable
class ViewportRegionResult {
  /// Whether the item is considered "in focus" by the region.
  final bool isFocused;

  /// A normalized value (0.0 to 1.0) representing center-closeness or
  /// progression.
  ///
  /// Used for interpolating UI effects and for policies that prefer higher
  /// progress.
  final double focusProgress;

  /// A normalized value (0.0 to 1.0) representing the physical overlap ratio
  /// between the item and the region's band.
  final double overlapFraction;

  /// Creates a region evaluation result.
  ///
  /// Values are expected to be normalized (0.0 to 1.0).
  const ViewportRegionResult({
    required this.isFocused,
    required this.focusProgress,
    required this.overlapFraction,
  })  : assert(focusProgress >= 0.0 && focusProgress <= 1.0),
        assert(overlapFraction >= 0.0 && overlapFraction <= 1.0);

  /// A reusable "not focused" result (all metrics set to zero).
  static const ViewportRegionResult notFocused = ViewportRegionResult(
    isFocused: false,
    focusProgress: 0.0,
    overlapFraction: 0.0,
  );

  /// Returns a copy with [focusProgress] and [overlapFraction] clamped to 0..1.
  ///
  /// This is used by the custom-region implementation to enforce invariants.
  ViewportRegionResult clamp01() {
    double c(double v) => v.clamp(0.0, 1.0);
    return ViewportRegionResult(
      isFocused: isFocused,
      focusProgress: c(focusProgress),
      overlapFraction: c(overlapFraction),
    );
  }

  @override
  String toString() =>
      'ViewportRegionResult(focused: $isFocused, progress: $focusProgress, overlap: $overlapFraction)';
}

/// Function signature for custom region logic.
///
/// Custom regions must return a [ViewportRegionResult] whose numeric fields are
/// in the 0..1 range. The engine will clamp them as a safety net.
typedef ViewportRegionEvaluator = ViewportRegionResult Function(
    ViewportRegionInput input);

/// Defines the "active area" within the viewport that confers focus status.
///
/// Items that intersect this region are marked as `isFocused`. The engine then
/// selects one of these focused items to be the "primary" winner. The region
/// also produces normalized metrics (progress/overlap) used by selection
/// policies and UI effects.
///
/// **Why not just use visibility?**
/// Using the entire visible area as the focus region is often too broad for feeds.
/// Typically, you want an item to be focused only when it crosses a specific line
/// (like a "snapping line") or enters a central "sweet spot".
///
/// **Common Configurations:**
/// - **Zone (Recommended):** A band of fixed size (e.g., 200px) centered on the anchor.
///   Good for allowing items to remain focused while the user scrolls slightly.
/// - **Line:** An infinitely thin line. Good for strict trigger points.
@immutable
sealed class ViewportFocusRegion {
  const ViewportFocusRegion();

  /// Determines if and how the given item interacts with this focus region.
  ///
  /// This method is called by the engine for each *visible* item on each
  /// compute pass. The returned [ViewportRegionResult]:
  /// - decides whether the item is considered focused (`isFocused`), and
  /// - provides normalized metrics used by selection policies and UI effects.
  ViewportRegionResult evaluate(ViewportRegionInput input);

  /// Creates a region defined by a single line (or a very thin band) at the anchor.
  ///
  /// Items are focused only if they physically intersect this line.
  ///
  /// [thicknessPx] can be set to a small positive value (e.g., 1.0) to make the
  /// target easier to hit, essentially creating a very thin zone.
  const factory ViewportFocusRegion.line({
    required ViewportAnchor anchor,
    double thicknessPx,
  }) = ViewportFocusLineRegion;

  /// Creates a region defined by a zone (band) centered on the anchor.
  ///
  /// The zone extends `extentPx / 2` in both directions from the anchor.
  /// Items are focused as long as they overlap with this zone.
  ///
  /// This is the most robust option for feed UIs, as it prevents focus from
  /// dropping immediately when an item moves slightly off-center.
  const factory ViewportFocusRegion.zone({
    required ViewportAnchor anchor,
    required double extentPx,
  }) = ViewportFocusZoneRegion;

  /// Creates a region with fully custom evaluation logic.
  ///
  /// Use this for complex shapes or asymmetric regions (e.g., "focus region starts
  /// at the top and covers 30% of the screen").
  const factory ViewportFocusRegion.custom({
    required ViewportAnchor anchor,
    required ViewportRegionEvaluator evaluator,
  }) = ViewportFocusCustomRegion;
}

/// A focus region defined by a line (or thin band) at [anchor].
///
/// Semantics:
/// - With `thicknessPx == 0`, focus behaves like an infinitesimal line: an item
///   is focused when the anchor position lies between the item’s start and end.
/// - With `thicknessPx > 0`, focus behaves like a thin band centered on the
///   anchor: an item is focused when it overlaps the band.
///
/// Metrics:
/// - `focusProgress` describes how close the item’s center is to the anchor,
///   normalized by half the item extent.
/// - `overlapFraction` describes how much of the line band is overlapped (or
///   1/0 for a zero-thickness line).
@immutable
final class ViewportFocusLineRegion extends ViewportFocusRegion {
  /// The anchor that positions the line/band.
  final ViewportAnchor anchor;

  /// Thickness of the line band. If 0, treated as an infinitesimal line.
  ///
  /// Values > 0 effectively create a tiny zone around the anchor.
  final double thicknessPx;

  /// Creates a line-based focus region centered on [anchor].
  ///
  /// Use [thicknessPx] to make the line into a thin band.
  const ViewportFocusLineRegion({required this.anchor, this.thicknessPx = 0.0})
      : assert(thicknessPx >= 0.0);

  @override
  ViewportRegionResult evaluate(ViewportRegionInput input) {
    final itemStart = input.itemMainAxisStart;
    final itemEnd = input.itemMainAxisEnd;
    final itemExtent = input.itemMainAxisExtent;

    final anchorPos = input.anchorOffsetPx;

    final halfThickness = thicknessPx / 2.0;
    final regionStart = anchorPos - halfThickness;
    final regionEnd = anchorPos + halfThickness;

    final overlapPx = _overlapPx(itemStart, itemEnd, regionStart, regionEnd);
    final isFocused = thicknessPx == 0.0
        ? (itemStart <= anchorPos && itemEnd >= anchorPos)
        : (overlapPx > 0.0);

    final overlapFraction = thicknessPx == 0.0
        ? (isFocused ? 1.0 : 0.0)
        : (overlapPx / thicknessPx).clamp(0.0, 1.0);

    if (!isFocused || itemExtent <= 0.0) {
      return const ViewportRegionResult(
        isFocused: false,
        focusProgress: 0.0,
        overlapFraction: 0.0,
      );
    }

    // For a "line", progress is based on how close the item center is to the anchor,
    // normalized by half the item extent. This gives:
    // - 1.0 at perfect center
    // - 0.0 when anchor is at the item's edge
    final itemCenter = input.itemMainAxisCenter;
    final itemHalf = (itemExtent / 2.0).clamp(1e-6, double.infinity);
    final distance = (itemCenter - anchorPos).abs();
    final progress = (1.0 - (distance / itemHalf)).clamp(0.0, 1.0);

    return ViewportRegionResult(
      isFocused: true,
      focusProgress: progress,
      overlapFraction: overlapFraction,
    );
  }

  @override
  String toString() =>
      'ViewportFocusRegion.line(anchor: $anchor, thicknessPx: $thicknessPx)';
}

/// A focus region defined by a fixed-size zone centered on [anchor].
///
/// The zone is a band of thickness [extentPx] centered on the anchor. An item is
/// focused when it overlaps this band.
///
/// Metrics:
/// - `focusProgress` describes how close the item’s center is to the anchor,
///   normalized by half the zone extent.
/// - `overlapFraction` describes the overlap of item vs. zone thickness
///   (`overlapPx / extentPx`, clamped).
@immutable
final class ViewportFocusZoneRegion extends ViewportFocusRegion {
  /// The anchor that centers the zone.
  final ViewportAnchor anchor;

  /// Total zone thickness along the main axis.
  /// The zone spans ±extentPx/2 around the anchor.
  final double extentPx;

  /// Creates a zone-based focus region centered on [anchor].
  const ViewportFocusZoneRegion({required this.anchor, required this.extentPx})
      : assert(extentPx > 0.0);

  @override
  ViewportRegionResult evaluate(ViewportRegionInput input) {
    final itemStart = input.itemMainAxisStart;
    final itemEnd = input.itemMainAxisEnd;

    final anchorPos = input.anchorOffsetPx;
    final halfExtent = (extentPx / 2.0).clamp(1e-6, double.infinity);
    final zoneStart = anchorPos - halfExtent;
    final zoneEnd = anchorPos + halfExtent;

    final overlapPx = _overlapPx(itemStart, itemEnd, zoneStart, zoneEnd);
    final isFocused = overlapPx > 0.0;
    if (!isFocused) {
      return ViewportRegionResult.notFocused;
    }

    final overlapFraction = (overlapPx / extentPx).clamp(0.0, 1.0);

    // Progress for zone is based on center closeness to anchor, normalized by half zone.
    final itemCenter = input.itemMainAxisCenter;
    final distance = (itemCenter - anchorPos).abs();
    final progress = (1.0 - (distance / halfExtent)).clamp(0.0, 1.0);

    return ViewportRegionResult(
      isFocused: true,
      focusProgress: progress,
      overlapFraction: overlapFraction,
    );
  }

  @override
  String toString() =>
      'ViewportFocusRegion.zone(anchor: $anchor, extentPx: $extentPx)';
}

/// A focus region whose behavior is defined by a user-provided [evaluator].
///
/// The engine still uses [anchor] to compute distance-to-anchor metrics and to
/// label/debug the region, but focus membership and progress/overlap values come
/// from [evaluator].
///
/// Results are clamped to 0..1 to enforce invariants expected by policies and
/// UI effects.
@immutable
final class ViewportFocusCustomRegion extends ViewportFocusRegion {
  /// The anchor used for distance-to-anchor and debug labeling.
  final ViewportAnchor anchor;

  /// Custom evaluation callback.
  final ViewportRegionEvaluator evaluator;

  /// Creates a custom focus region driven by [evaluator].
  ///
  /// The engine still uses [anchor] for distance metrics and debug labeling.
  const ViewportFocusCustomRegion({
    required this.anchor,
    required this.evaluator,
  });

  @override
  ViewportRegionResult evaluate(ViewportRegionInput input) {
    final result = evaluator(input);
    // Ensure values are clamped to avoid downstream surprises.
    return result.clamp01();
  }

  @override
  String toString() =>
      'ViewportFocusRegion.custom(anchor: $anchor, evaluator: $evaluator)';
}

/// Returns overlap length between [aStart..aEnd] and [bStart..bEnd].
double _overlapPx(double aStart, double aEnd, double bStart, double bEnd) {
  final lo = aStart > bStart ? aStart : bStart;
  final hi = aEnd < bEnd ? aEnd : bEnd;
  final v = hi - lo;
  return v > 0.0 ? v : 0.0;
}

double _mainAxisStart(Rect rect, Axis axis) =>
    axis == Axis.vertical ? rect.top : rect.left;

double _mainAxisEnd(Rect rect, Axis axis) =>
    axis == Axis.vertical ? rect.bottom : rect.right;

double _mainAxisCenter(Rect rect, Axis axis) =>
    axis == Axis.vertical ? rect.center.dy : rect.center.dx;

double _mainAxisExtent(Rect rect, Axis axis) =>
    axis == Axis.vertical ? rect.height : rect.width;
