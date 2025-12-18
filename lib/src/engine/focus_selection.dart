import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:viewport_focus/src/public/viewport_focus_models.dart';
import 'package:viewport_focus/src/public/viewport_focus_policy.dart';
import 'package:viewport_focus/src/public/viewport_focus_stability.dart';
import 'package:viewport_focus/src/utils/equality.dart';

/// Pure selection + stability logic.
///
/// Input: a list of [ViewportItemFocus] objects computed from geometry.
/// Output: a [FocusSelectionResult] describing:
/// - visibleIds
/// - focusedIds
/// - primaryId (winner inside focusedIds, or null)
/// - primarySince (timestamp maintained by stability rules)
/// - itemsById map (with isPrimary updated for exactly one winner)
///
/// NOTE:
/// - This file intentionally has no Flutter rendering imports.
/// - It is designed to be fully unit-testable with plain Dart tests.
final class FocusSelection {
  const FocusSelection._();

  /// Selects the next focus frame state.
  ///
  /// Rules:
  /// - primary is chosen ONLY among focused candidates.
  /// - if no focused candidates:
  ///   - if [ViewportFocusStability.allowPrimaryWhenNoItemFocused] is true,
  ///     keep the previous primary if still visible, else pick the best visible.
  ///   - otherwise primaryId becomes null.
  /// - stability (min duration + hysteresis) is applied only when:
  ///   - there is a previous primary that is still focused, and
  ///   - there is a different focused candidate that would otherwise win.
  ///
  /// Comparator contract for custom policies:
  /// - [ViewportFocusPolicy.custom]'s compare must behave like [Comparator]:
  ///   return < 0 if (a) is better than (b).
  static FocusSelectionResult<T> select<T>({
    required List<ViewportItemFocus<T>> items,
    required ViewportFocusPolicy<T> policy,
    required ViewportFocusStability stability,
    required T? previousPrimaryId,
    required DateTime? previousPrimarySince,
    required DateTime now,
  }) {
    // Preserve input ordering (used as stable tie-breaker).
    final LinkedHashMap<T, ViewportItemFocus<T>> baseById =
        LinkedHashMap<T, ViewportItemFocus<T>>();
    for (final item in items) {
      baseById[item.id] = item;
    }

    final LinkedHashSet<T> visibleIds = LinkedHashSet<T>();
    final LinkedHashSet<T> focusedIds = LinkedHashSet<T>();

    final List<ViewportItemFocus<T>> focusedCandidates =
        <ViewportItemFocus<T>>[];
    final List<ViewportItemFocus<T>> visibleCandidates =
        <ViewportItemFocus<T>>[];

    for (final item in items) {
      if (item.isVisible) {
        visibleIds.add(item.id);
        visibleCandidates.add(item);
      }
      if (item.isFocused) {
        focusedIds.add(item.id);
        focusedCandidates.add(item);
      }
    }

    final ViewportItemFocus<T>? previousPrimaryItem =
        previousPrimaryId == null ? null : baseById[previousPrimaryId];

    final bool previousPrimaryStillFocused =
        previousPrimaryItem != null && previousPrimaryItem.isFocused;
    final bool previousPrimaryStillVisible =
        previousPrimaryItem != null && previousPrimaryItem.isVisible;

    // Determine the best focused candidate according to policy.
    final ViewportItemFocus<T>? bestFocused =
        focusedCandidates.isEmpty ? null : _pickBest(focusedCandidates, policy);

    final ViewportItemFocus<T>? bestVisible =
        visibleCandidates.isEmpty ? null : _pickBest(visibleCandidates, policy);

    T? nextPrimaryId;
    DateTime? nextPrimarySince;

    if (bestFocused == null) {
      // No focused candidates.
      if (!stability.allowPrimaryWhenNoItemFocused) {
        nextPrimaryId = null;
        nextPrimarySince = null;
      } else if (previousPrimaryStillVisible) {
        nextPrimaryId = previousPrimaryItem.id;
        nextPrimarySince = previousPrimarySince ?? now;
      } else if (bestVisible != null) {
        nextPrimaryId = bestVisible.id;
        nextPrimarySince = now;
      } else {
        nextPrimaryId = null;
        nextPrimarySince = null;
      }
    } else if (!previousPrimaryStillFocused) {
      // No eligible previous primary => accept best.
      nextPrimaryId = bestFocused.id;
      nextPrimarySince = now;
    } else {
      // Previous primary is still focused.
      final T currentId = previousPrimaryItem.id;
      final DateTime currentSince = previousPrimarySince ?? now;

      if (bestFocused.id == currentId) {
        // Winner unchanged.
        nextPrimaryId = currentId;
        nextPrimarySince = currentSince;
      } else {
        // Candidate differs; apply stability rules.
        final bool minDurationSatisfied = _isMinDurationSatisfied(
          currentSince,
          stability.minPrimaryDuration,
          now,
        );

        if (!minDurationSatisfied) {
          // Too soon to switch.
          nextPrimaryId = currentId;
          nextPrimarySince = currentSince;
        } else if (!stability.preferCurrentPrimary) {
          // Not sticky beyond minDuration: switch immediately to best.
          nextPrimaryId = bestFocused.id;
          nextPrimarySince = now;
        } else {
          // Sticky: candidate must beat current by hysteresis margin.
          final bool candidateBeatsByHysteresis = _beatsByHysteresis(
            current: previousPrimaryItem,
            candidate: bestFocused,
            hysteresisPx: stability.hysteresisPx,
          );

          if (candidateBeatsByHysteresis) {
            nextPrimaryId = bestFocused.id;
            nextPrimarySince = now;
          } else {
            nextPrimaryId = currentId;
            nextPrimarySince = currentSince;
          }
        }
      }
    }

    // Build final itemsById, ensuring exactly one isPrimary (or none).
    final LinkedHashMap<T, ViewportItemFocus<T>> itemsById =
        LinkedHashMap<T, ViewportItemFocus<T>>();

    for (final item in items) {
      final bool shouldBePrimary =
          nextPrimaryId != null && item.id == nextPrimaryId;

      final ViewportItemFocus<T> updated = item.isPrimary == shouldBePrimary
          ? item
          : item.copyWith(isPrimary: shouldBePrimary);

      itemsById[updated.id] = updated;
    }

    return FocusSelectionResult<T>(
      primaryId: nextPrimaryId,
      primarySince: nextPrimarySince,
      focusedIds: focusedIds,
      visibleIds: visibleIds,
      itemsById: itemsById,
    );
  }

  static bool _isMinDurationSatisfied(
    DateTime since,
    Duration minDuration,
    DateTime now,
  ) {
    if (minDuration == Duration.zero) return true;
    return now.difference(since) >= minDuration;
  }

  static bool _beatsByHysteresis<T>({
    required ViewportItemFocus<T> current,
    required ViewportItemFocus<T> candidate,
    required double hysteresisPx,
  }) {
    if (hysteresisPx <= 0) {
      // With 0 hysteresis, any "best candidate" can steal focus
      // once minDuration is satisfied.
      return true;
    }

    final double currentAbs = current.distanceToAnchorPx.abs();
    final double candidateAbs = candidate.distanceToAnchorPx.abs();

    // Candidate must be closer by at least hysteresisPx:
    // currentAbs - candidateAbs >= hysteresisPx
    final double improvement = currentAbs - candidateAbs;

    // Use tolerant compare to avoid churn from tiny float noise.
    return improvement > 0 &&
        (improvement > hysteresisPx || nearlyEqual(improvement, hysteresisPx));
  }

  static ViewportItemFocus<T> _pickBest<T>(
    List<ViewportItemFocus<T>> candidates,
    ViewportFocusPolicy<T> policy,
  ) {
    assert(candidates.isNotEmpty);

    ViewportItemFocus<T> best = candidates.first;
    for (var i = 1; i < candidates.length; i++) {
      final ViewportItemFocus<T> c = candidates[i];
      if (_isBetter(candidate: c, currentBest: best, policy: policy)) {
        best = c;
      }
    }
    return best;
  }

  static bool _isBetter<T>({
    required ViewportItemFocus<T> candidate,
    required ViewportItemFocus<T> currentBest,
    required ViewportFocusPolicy<T> policy,
  }) {
    final int cmp = _compare(candidate, currentBest, policy);
    if (cmp < 0) return true;
    if (cmp > 0) return false;

    // Tie-breakers (deterministic and stable):
    // 1) prefer higher focusProgress
    final int fp = _compareDesc(
      candidate.focusProgress,
      currentBest.focusProgress,
      epsilon: kViewportFocusDefaultEpsilonFraction,
    );
    if (fp != 0) return fp < 0;

    // 2) prefer higher visibleFraction
    final int vf = _compareDesc(
      candidate.visibleFraction,
      currentBest.visibleFraction,
      epsilon: kViewportFocusDefaultEpsilonFraction,
    );
    if (vf != 0) return vf < 0;

    // 3) prefer smaller absolute distance to anchor
    final int dist = _compareAsc(
      candidate.distanceToAnchorPx.abs(),
      currentBest.distanceToAnchorPx.abs(),
      epsilon: kViewportFocusDefaultEpsilonPx,
    );
    if (dist != 0) return dist < 0;

    // 4) stable fallback: keep current best (preserves input order)
    return false;
  }

  static int _compare<T>(
    ViewportItemFocus<T> a,
    ViewportItemFocus<T> b,
    ViewportFocusPolicy<T> policy,
  ) {
    // Custom comparator wins.
    if (policy is CustomFocusPolicy<T>) {
      final int custom = policy.compare(a, b);
      if (custom != 0) return custom;

      // If tied, fall back to distance-to-anchor.
      return _compareAsc(
        a.distanceToAnchorPx.abs(),
        b.distanceToAnchorPx.abs(),
        epsilon: kViewportFocusDefaultEpsilonPx,
      );
    }

    if (policy is ClosestToAnchorPolicy<T>) {
      return _compareAsc(
        a.distanceToAnchorPx.abs(),
        b.distanceToAnchorPx.abs(),
        epsilon: kViewportFocusDefaultEpsilonPx,
      );
    }

    if (policy is LargestVisibleFractionPolicy<T>) {
      return _compareDesc(
        a.visibleFraction,
        b.visibleFraction,
        epsilon: kViewportFocusDefaultEpsilonFraction,
      );
    }

    if (policy is LargestFocusOverlapPolicy<T>) {
      return _compareDesc(
        a.focusOverlapFraction,
        b.focusOverlapFraction,
        epsilon: kViewportFocusDefaultEpsilonFraction,
      );
    }

    if (policy is LargestFocusProgressPolicy<T>) {
      return _compareDesc(
        a.focusProgress,
        b.focusProgress,
        epsilon: kViewportFocusDefaultEpsilonFraction,
      );
    }

    // Unknown policy type (future-proof): use distance-to-anchor.
    return _compareAsc(
      a.distanceToAnchorPx.abs(),
      b.distanceToAnchorPx.abs(),
      epsilon: kViewportFocusDefaultEpsilonPx,
    );
  }

  static int _compareAsc(double a, double b, {required double epsilon}) {
    if (nearlyEqual(a, b, epsilon: epsilon)) return 0;
    return a < b ? -1 : 1;
  }

  static int _compareDesc(double a, double b, {required double epsilon}) =>
      -_compareAsc(a, b, epsilon: epsilon);
}

@immutable

/// Result of a selection pass (focused set + chosen primary).
///
/// This is an internal representation used by the engine pipeline. It is
/// converted to a public [ViewportFocusSnapshot] before being committed to the
/// [ViewportFocusController]. Collections are frozen to prevent mutation after
/// selection so downstream components can treat them as stable inputs.
final class FocusSelectionResult<T> {
  /// The chosen primary item ID, or `null` when no primary is selected.
  final T? primaryId;

  /// When the current [primaryId] started being considered primary.
  ///
  /// This timestamp is maintained across frames to support minimum-duration
  /// stability rules.
  final DateTime? primarySince;

  /// IDs that currently intersect the configured focus region.
  final Set<T> focusedIds;

  /// IDs that have any visible intersection with the viewport.
  final Set<T> visibleIds;

  /// Final per-item state keyed by ID, with isPrimary updated.
  ///
  /// Order is stable and matches input ordering.
  final Map<T, ViewportItemFocus<T>> itemsById;

  /// Creates a selection result with frozen collections.
  ///
  /// The constructor wraps sets/maps in unmodifiable views to preserve
  /// selection invariants for downstream consumers.
  FocusSelectionResult({
    required this.primaryId,
    required this.primarySince,
    required Set<T> focusedIds,
    required Set<T> visibleIds,
    required Map<T, ViewportItemFocus<T>> itemsById,
  })  : focusedIds = focusedIds is UnmodifiableSetView<T>
            ? focusedIds
            : UnmodifiableSetView<T>(focusedIds),
        visibleIds = visibleIds is UnmodifiableSetView<T>
            ? visibleIds
            : UnmodifiableSetView<T>(visibleIds),
        itemsById = itemsById is UnmodifiableMapView<T, ViewportItemFocus<T>>
            ? itemsById
            : UnmodifiableMapView<T, ViewportItemFocus<T>>(itemsById);

  /// Converts this selection result to a public snapshot object.
  ///
  /// [computedAt] defaults to `DateTime.now()` when omitted.
  ///
  /// Set [includeItemsMap] to `false` to drop the per-item map when only the
  /// global primary/sets are needed. The engine typically keeps it `true` so
  /// per-item listenables can be updated.
  ViewportFocusSnapshot<T> toSnapshot({
    DateTime? computedAt,
    bool includeItemsMap = true,
  }) {
    return ViewportFocusSnapshot<T>(
      computedAt: computedAt ?? DateTime.now(),
      primaryId: primaryId,
      focusedIds: focusedIds,
      visibleIds: visibleIds,
      items: includeItemsMap ? itemsById : const {},
    );
  }
}
