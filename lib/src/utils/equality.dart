import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:viewport_focus/src/public/viewport_focus_models.dart';

/// Default tolerance (in pixels) used when comparing geometry values.
///
/// This is tuned to avoid churn from sub-pixel scroll jitter while still
/// treating meaningful movement as a change.
const double kViewportFocusDefaultEpsilonPx = 0.5;

/// Default tolerance used when comparing normalized 0..1 values (fractions).
const double kViewportFocusDefaultEpsilonFraction = 0.001;

/// Tolerance-based double comparison.
///
/// IMPORTANT:
/// - The default [epsilon] is in *pixels*.
/// - For normalized 0..1 values (fractions/progress), pass
///   [kViewportFocusDefaultEpsilonFraction] explicitly (or use
///   [nearlyEqualFraction]).
bool nearlyEqual(
  double a,
  double b, {
  double epsilon = kViewportFocusDefaultEpsilonPx,
}) {
  if (identical(a, b)) return true;

  // Handle NaN explicitly.
  if (a.isNaN || b.isNaN) return false;

  // Handle infinities.
  if (a.isInfinite || b.isInfinite) return a == b;

  return (a - b).abs() <= epsilon;
}

/// Convenience wrapper around [nearlyEqual] for pixel-domain values.
bool nearlyEqualPx(
  double a,
  double b, {
  double epsilonPx = kViewportFocusDefaultEpsilonPx,
}) {
  return nearlyEqual(a, b, epsilon: epsilonPx);
}

/// Convenience wrapper around [nearlyEqual] for fraction/progress values (0..1).
bool nearlyEqualFraction(
  double a,
  double b, {
  double epsilonFraction = kViewportFocusDefaultEpsilonFraction,
}) {
  return nearlyEqual(a, b, epsilon: epsilonFraction);
}

/// Tolerance-based rectangle comparison.
///
/// Each edge is compared with [epsilon] (in pixels).
bool rectNearlyEqual(
  Rect? a,
  Rect? b, {
  double epsilon = kViewportFocusDefaultEpsilonPx,
}) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;

  return nearlyEqual(a.left, b.left, epsilon: epsilon) &&
      nearlyEqual(a.top, b.top, epsilon: epsilon) &&
      nearlyEqual(a.right, b.right, epsilon: epsilon) &&
      nearlyEqual(a.bottom, b.bottom, epsilon: epsilon);
}

/// Unordered set equality.
///
/// This is a small wrapper around [setEquals] used to make intent explicit in
/// the engine/controller code (focused/visible sets are treated as unordered).
bool setUnorderedEquals<T>(Set<T> a, Set<T> b) {
  return setEquals<T>(a, b);
}

/// Semantic, tolerance-based equality for [ViewportItemFocus].
///
/// This is used by the controller and engine to avoid notifying listeners when
/// values change only by tiny amounts (for example, sub-pixel distance jitter).
///
/// Set [compareRects] to `false` to ignore rect differences (useful when rects
/// are not part of your public contract or are omitted for performance).
bool viewportItemFocusNearlyEqual<T>(
  ViewportItemFocus<T> a,
  ViewportItemFocus<T> b, {
  double epsilonPx = kViewportFocusDefaultEpsilonPx,
  double epsilonFraction = kViewportFocusDefaultEpsilonFraction,
  bool compareRects = true,
}) {
  if (identical(a, b)) return true;

  if (a.id != b.id) return false;

  if (a.isVisible != b.isVisible) return false;
  if (a.isFocused != b.isFocused) return false;
  if (a.isPrimary != b.isPrimary) return false;

  if (!nearlyEqual(
    a.visibleFraction,
    b.visibleFraction,
    epsilon: epsilonFraction,
  )) {
    return false;
  }

  // Distance can be very chatty; allow small tolerance.
  if (!nearlyEqual(
    a.distanceToAnchorPx,
    b.distanceToAnchorPx,
    epsilon: epsilonPx,
  )) {
    return false;
  }

  if (!nearlyEqual(
    a.focusProgress,
    b.focusProgress,
    epsilon: epsilonFraction,
  )) {
    return false;
  }

  if (!nearlyEqual(
    a.focusOverlapFraction,
    b.focusOverlapFraction,
    epsilon: epsilonFraction,
  )) {
    return false;
  }

  if (compareRects) {
    if (!rectNearlyEqual(
      a.itemRectInViewport,
      b.itemRectInViewport,
      epsilon: epsilonPx,
    )) {
      return false;
    }
    if (!rectNearlyEqual(
      a.visibleRectInViewport,
      b.visibleRectInViewport,
      epsilon: epsilonPx,
    )) {
      return false;
    }
  }

  return true;
}

/// A helper that clamps a value into a stable range.
///
/// Useful for callers that want to convert noisy float signals into a
/// controlled output domain (e.g. for progress), especially when input values
/// can be NaN during layout/scroll transitions.
double clampDouble(double value, double min, double max) {
  if (value.isNaN) return min;
  return math.min(max, math.max(min, value));
}

/// Deep-ish equality for snapshots.
///
/// Use sparingly: this walks sets and items.
///
/// This is primarily intended for tests and internal diffing. The default
/// [compareRects] is `false` because rects are often omitted by the engine (and
/// can be noisy even when present).
bool viewportFocusSnapshotNearlyEqual<T>(
  ViewportFocusSnapshot<T> a,
  ViewportFocusSnapshot<T> b, {
  double epsilonPx = kViewportFocusDefaultEpsilonPx,
  double epsilonFraction = kViewportFocusDefaultEpsilonFraction,
  bool compareRects = false,
}) {
  if (identical(a, b)) return true;

  if (a.primaryId != b.primaryId) return false;
  if (!setUnorderedEquals<T>(a.focusedIds, b.focusedIds)) return false;
  if (!setUnorderedEquals<T>(a.visibleIds, b.visibleIds)) return false;

  if (a.items.length != b.items.length) return false;

  for (final entry in a.items.entries) {
    final id = entry.key;
    final aItem = entry.value;
    final bItem = b.items[id];
    if (bItem == null) return false;

    if (!viewportItemFocusNearlyEqual<T>(
      aItem,
      bItem,
      epsilonPx: epsilonPx,
      epsilonFraction: epsilonFraction,
      compareRects: compareRects,
    )) {
      return false;
    }
  }

  return true;
}
