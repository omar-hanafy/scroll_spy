import 'package:flutter/foundation.dart';

import 'package:viewport_focus/src/public/viewport_focus_models.dart';

/// A function signature for comparing two focus items.
///
/// This comparator is invoked by the engine’s selection step when multiple
/// *focused* candidates compete for the primary spot. It is expected to be:
/// - **Pure** (no side effects).
/// - **Fast** (it may be called many times per scroll frame).
/// - **Deterministic** (same inputs -> same output), to avoid primary churn.
///
/// - Return negative if `a` should be prioritized over `b`.
/// - Return positive if `b` should be prioritized over `a`.
/// - Return zero if they are considered equal.
typedef ViewportFocusComparator<T> = int Function(
    ViewportItemFocus<T> a, ViewportItemFocus<T> b);

/// Defines the strategy for selecting the "primary" item when multiple items
/// are focused.
///
/// While the focus region (`ViewportFocusRegion`) determines *which* items are
/// candidates (by checking intersection), this policy determines *who wins*.
///
/// The selection logic runs after geometry calculation and before stability
/// rules (`ViewportFocusStability`) are applied.
///
/// Tie-breakers:
/// If [compare] returns `0` for two candidates, the engine applies deterministic
/// tie-breakers in this order:
/// 1) Higher `focusProgress`
/// 2) Higher `visibleFraction`
/// 3) Smaller absolute `distanceToAnchorPx`
/// 4) Stable fallback (preserves input/registration order)
@immutable
sealed class ViewportFocusPolicy<T> {
  const ViewportFocusPolicy();

  /// Compares two candidates to determine which one is "better".
  ///
  /// Must behave like [Comparator]:
  /// - `< 0` when [a] should win over [b]
  /// - `> 0` when [b] should win over [a]
  /// - `0` when they are tied (engine tie-breakers apply)
  int compare(ViewportItemFocus<T> a, ViewportItemFocus<T> b);

  /// A policy that selects the item whose center is closest to the focus anchor.
  ///
  /// This is the most common policy for feeds (e.g., Instagram, TikTok).
  const factory ViewportFocusPolicy.closestToAnchor() =
      ClosestToAnchorPolicy<T>;

  /// A policy that selects the item with the largest fraction of itself visible in the viewport.
  ///
  /// Good for galleries where you want the "most visible" item to be primary,
  /// even if it is not closest to the anchor.
  const factory ViewportFocusPolicy.largestVisibleFraction() =
      LargestVisibleFractionPolicy<T>;

  /// A policy that selects the item with the largest physical overlap with the focus region.
  const factory ViewportFocusPolicy.largestFocusOverlap() =
      LargestFocusOverlapPolicy<T>;

  /// A policy that selects the item with the highest focus progress.
  ///
  /// `focusProgress` is region-defined (for example, for a zone it increases as
  /// the item’s center approaches the anchor; for a line it increases as the
  /// anchor approaches the item’s center).
  const factory ViewportFocusPolicy.largestFocusProgress() =
      LargestFocusProgressPolicy<T>;

  /// A policy that uses a user-provided comparator to select the winner.
  ///
  /// Use this if you have complex business logic (e.g., "prefer ads over organic content
  /// if both are equally close").
  ///
  /// If your comparator returns `0`, the engine will fall back to the
  /// deterministic tie-breakers documented on [ViewportFocusPolicy].
  const factory ViewportFocusPolicy.custom({
    required ViewportFocusComparator<T> compare,
  }) = CustomFocusPolicy<T>;
}

@immutable

/// Policy implementation for [ViewportFocusPolicy.closestToAnchor].
///
/// Ranks candidates by absolute `distanceToAnchorPx` (smaller wins).
final class ClosestToAnchorPolicy<T> extends ViewportFocusPolicy<T> {
  /// Creates a policy that prefers the candidate closest to the anchor.
  const ClosestToAnchorPolicy();

  @override
  int compare(ViewportItemFocus<T> a, ViewportItemFocus<T> b) {
    final da = a.absDistanceToAnchorPx;
    final db = b.absDistanceToAnchorPx;
    if (da < db) return -1;
    if (da > db) return 1;
    return 0;
  }

  @override
  String toString() => 'ViewportFocusPolicy.closestToAnchor()';
}

@immutable

/// Policy implementation for [ViewportFocusPolicy.largestVisibleFraction].
///
/// Ranks candidates by `visibleFraction` (larger wins).
final class LargestVisibleFractionPolicy<T> extends ViewportFocusPolicy<T> {
  /// Creates a policy that prefers the most visible candidate.
  const LargestVisibleFractionPolicy();

  @override
  int compare(ViewportItemFocus<T> a, ViewportItemFocus<T> b) {
    final va = a.visibleFraction;
    final vb = b.visibleFraction;
    if (va > vb) return -1;
    if (va < vb) return 1;
    return 0;
  }

  @override
  String toString() => 'ViewportFocusPolicy.largestVisibleFraction()';
}

@immutable

/// Policy implementation for [ViewportFocusPolicy.largestFocusOverlap].
///
/// Ranks candidates by `focusOverlapFraction` (larger wins).
final class LargestFocusOverlapPolicy<T> extends ViewportFocusPolicy<T> {
  /// Creates a policy that prefers the largest region overlap.
  const LargestFocusOverlapPolicy();

  @override
  int compare(ViewportItemFocus<T> a, ViewportItemFocus<T> b) {
    final oa = a.focusOverlapFraction;
    final ob = b.focusOverlapFraction;
    if (oa > ob) return -1;
    if (oa < ob) return 1;
    return 0;
  }

  @override
  String toString() => 'ViewportFocusPolicy.largestFocusOverlap()';
}

@immutable

/// Policy implementation for [ViewportFocusPolicy.largestFocusProgress].
///
/// Ranks candidates by `focusProgress` (larger wins).
final class LargestFocusProgressPolicy<T> extends ViewportFocusPolicy<T> {
  /// Creates a policy that prefers the highest focus progress.
  const LargestFocusProgressPolicy();

  @override
  int compare(ViewportItemFocus<T> a, ViewportItemFocus<T> b) {
    final pa = a.focusProgress;
    final pb = b.focusProgress;
    if (pa > pb) return -1;
    if (pa < pb) return 1;
    return 0;
  }

  @override
  String toString() => 'ViewportFocusPolicy.largestFocusProgress()';
}

@immutable

/// Policy implementation for [ViewportFocusPolicy.custom].
///
/// Delegates ranking to the user-provided [ViewportFocusComparator].
final class CustomFocusPolicy<T> extends ViewportFocusPolicy<T> {
  final ViewportFocusComparator<T> _compare;

  /// Creates a policy backed by a custom comparator.
  ///
  /// If the comparator returns 0, the engine applies deterministic tie-breakers.
  const CustomFocusPolicy({required ViewportFocusComparator<T> compare})
      : _compare = compare;

  @override
  int compare(ViewportItemFocus<T> a, ViewportItemFocus<T> b) => _compare(a, b);

  @override
  String toString() => 'ViewportFocusPolicy.custom(compare: $_compare)';
}
