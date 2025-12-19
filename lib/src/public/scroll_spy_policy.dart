import 'package:flutter/foundation.dart';

import 'package:scroll_spy/src/public/scroll_spy_models.dart';

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
typedef ScrollSpyComparator<T> = int Function(
    ScrollSpyItemFocus<T> a, ScrollSpyItemFocus<T> b);

/// Defines the strategy for selecting the "primary" item when multiple items
/// are focused.
///
/// While the focus region (`ScrollSpyRegion`) determines *which* items are
/// candidates (by checking intersection), this policy determines *who wins*.
///
/// The selection logic runs after geometry calculation and before stability
/// rules (`ScrollSpyStability`) are applied.
///
/// Tie-breakers:
/// If [compare] returns `0` for two candidates, the engine applies deterministic
/// tie-breakers in this order:
/// 1) Higher `focusProgress`
/// 2) Higher `visibleFraction`
/// 3) Smaller absolute `distanceToAnchorPx`
/// 4) Stable fallback (preserves input/registration order)
@immutable
sealed class ScrollSpyPolicy<T> {
  const ScrollSpyPolicy();

  /// Compares two candidates to determine which one is "better".
  ///
  /// Must behave like [Comparator]:
  /// - `< 0` when [a] should win over [b]
  /// - `> 0` when [b] should win over [a]
  /// - `0` when they are tied (engine tie-breakers apply)
  int compare(ScrollSpyItemFocus<T> a, ScrollSpyItemFocus<T> b);

  /// A policy that selects the item whose center is closest to the focus anchor.
  ///
  /// This is the most common policy for feeds (e.g., Instagram, TikTok).
  const factory ScrollSpyPolicy.closestToAnchor() = ClosestToAnchorPolicy<T>;

  /// A policy that selects the item with the largest fraction of itself visible in the viewport.
  ///
  /// Good for galleries where you want the "most visible" item to be primary,
  /// even if it is not closest to the anchor.
  const factory ScrollSpyPolicy.largestVisibleFraction() =
      LargestVisibleFractionPolicy<T>;

  /// A policy that selects the item with the largest physical overlap with the focus region.
  const factory ScrollSpyPolicy.largestFocusOverlap() =
      LargestFocusOverlapPolicy<T>;

  /// A policy that selects the item with the highest focus progress.
  ///
  /// `focusProgress` is region-defined (for example, for a zone it increases as
  /// the item’s center approaches the anchor; for a line it increases as the
  /// anchor approaches the item’s center).
  const factory ScrollSpyPolicy.largestFocusProgress() =
      LargestFocusProgressPolicy<T>;

  /// A policy that uses a user-provided comparator to select the winner.
  ///
  /// Use this if you have complex business logic (e.g., "prefer ads over organic content
  /// if both are equally close").
  ///
  /// If your comparator returns `0`, the engine will fall back to the
  /// deterministic tie-breakers documented on [ScrollSpyPolicy].
  const factory ScrollSpyPolicy.custom({
    required ScrollSpyComparator<T> compare,
  }) = CustomFocusPolicy<T>;
}

@immutable

/// Policy implementation for [ScrollSpyPolicy.closestToAnchor].
///
/// Ranks candidates by absolute `distanceToAnchorPx` (smaller wins).
final class ClosestToAnchorPolicy<T> extends ScrollSpyPolicy<T> {
  /// Creates a policy that prefers the candidate closest to the anchor.
  const ClosestToAnchorPolicy();

  @override
  int compare(ScrollSpyItemFocus<T> a, ScrollSpyItemFocus<T> b) {
    final da = a.absDistanceToAnchorPx;
    final db = b.absDistanceToAnchorPx;
    if (da < db) return -1;
    if (da > db) return 1;
    return 0;
  }

  @override
  String toString() => 'ScrollSpyPolicy.closestToAnchor()';
}

@immutable

/// Policy implementation for [ScrollSpyPolicy.largestVisibleFraction].
///
/// Ranks candidates by `visibleFraction` (larger wins).
final class LargestVisibleFractionPolicy<T> extends ScrollSpyPolicy<T> {
  /// Creates a policy that prefers the most visible candidate.
  const LargestVisibleFractionPolicy();

  @override
  int compare(ScrollSpyItemFocus<T> a, ScrollSpyItemFocus<T> b) {
    final va = a.visibleFraction;
    final vb = b.visibleFraction;
    if (va > vb) return -1;
    if (va < vb) return 1;
    return 0;
  }

  @override
  String toString() => 'ScrollSpyPolicy.largestVisibleFraction()';
}

@immutable

/// Policy implementation for [ScrollSpyPolicy.largestFocusOverlap].
///
/// Ranks candidates by `focusOverlapFraction` (larger wins).
final class LargestFocusOverlapPolicy<T> extends ScrollSpyPolicy<T> {
  /// Creates a policy that prefers the largest region overlap.
  const LargestFocusOverlapPolicy();

  @override
  int compare(ScrollSpyItemFocus<T> a, ScrollSpyItemFocus<T> b) {
    final oa = a.focusOverlapFraction;
    final ob = b.focusOverlapFraction;
    if (oa > ob) return -1;
    if (oa < ob) return 1;
    return 0;
  }

  @override
  String toString() => 'ScrollSpyPolicy.largestFocusOverlap()';
}

@immutable

/// Policy implementation for [ScrollSpyPolicy.largestFocusProgress].
///
/// Ranks candidates by `focusProgress` (larger wins).
final class LargestFocusProgressPolicy<T> extends ScrollSpyPolicy<T> {
  /// Creates a policy that prefers the highest focus progress.
  const LargestFocusProgressPolicy();

  @override
  int compare(ScrollSpyItemFocus<T> a, ScrollSpyItemFocus<T> b) {
    final pa = a.focusProgress;
    final pb = b.focusProgress;
    if (pa > pb) return -1;
    if (pa < pb) return 1;
    return 0;
  }

  @override
  String toString() => 'ScrollSpyPolicy.largestFocusProgress()';
}

@immutable

/// Policy implementation for [ScrollSpyPolicy.custom].
///
/// Delegates ranking to the user-provided [ScrollSpyComparator].
final class CustomFocusPolicy<T> extends ScrollSpyPolicy<T> {
  final ScrollSpyComparator<T> _compare;

  /// Creates a policy backed by a custom comparator.
  ///
  /// If the comparator returns 0, the engine applies deterministic tie-breakers.
  const CustomFocusPolicy({required ScrollSpyComparator<T> compare})
      : _compare = compare;

  @override
  int compare(ScrollSpyItemFocus<T> a, ScrollSpyItemFocus<T> b) =>
      _compare(a, b);

  @override
  String toString() => 'ScrollSpyPolicy.custom(compare: $_compare)';
}
