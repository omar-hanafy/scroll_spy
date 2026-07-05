import 'package:scroll_spy/src/engine/item_slot.dart';
import 'package:scroll_spy/src/public/scroll_spy_policy.dart';
import 'package:scroll_spy/src/public/scroll_spy_stability.dart';
import 'package:scroll_spy/src/utils/equality.dart';

/// Result of a selection pass.
final class PrimarySelection<T> {
  /// The chosen primary id, or null.
  T? primaryId;

  /// Monotonic time the current primary started being primary.
  Duration? primarySince;
}

/// Pure selection + stability logic over [ItemSlot]s.
///
/// Behavior contract (identical to the pre-1.0 selection semantics):
/// - primary is chosen ONLY among focused candidates;
/// - with no focused candidates and `allowPrimaryWhenNoItemFocused`, the
///   previous primary is kept while visible, else the best visible wins;
/// - stability (min duration + hysteresis) applies only when a previous
///   primary is still focused and a different candidate would win;
/// - deterministic tie-breaks: focusProgress desc, visibleFraction desc,
///   |distance| asc, then stable input (registration) order.
///
/// Timing is monotonic ([Duration] since the engine started), so wall-clock
/// jumps cannot corrupt `minPrimaryDuration`.
final class EngineSelection {
  const EngineSelection._();

  /// Selects the next primary and writes `isPrimary` flags on [slots]
  /// (exactly one true, or none). Unmeasurable slots are ignored.
  static PrimarySelection<T> select<T>({
    required List<ItemSlot<T>> slots,
    required ScrollSpyPolicy<T> policy,
    required ScrollSpyStability stability,
    required T? previousPrimaryId,
    required Duration? previousPrimarySince,
    required Duration now,
    PrimarySelection<T>? into,
  }) {
    final PrimarySelection<T> result = into ?? PrimarySelection<T>();

    ItemSlot<T>? bestFocused;
    ItemSlot<T>? bestVisible;
    ItemSlot<T>? previousPrimary;

    for (final slot in slots) {
      if (!slot.measurable) continue;
      if (previousPrimaryId != null && slot.id == previousPrimaryId) {
        previousPrimary = slot;
      }
      if (slot.isVisible) {
        if (bestVisible == null || _isBetter(slot, bestVisible, policy)) {
          bestVisible = slot;
        }
        if (slot.isFocused) {
          if (bestFocused == null || _isBetter(slot, bestFocused, policy)) {
            bestFocused = slot;
          }
        }
      }
    }

    final bool previousStillFocused =
        previousPrimary != null && previousPrimary.isFocused;
    final bool previousStillVisible =
        previousPrimary != null && previousPrimary.isVisible;

    ItemSlot<T>? winner;
    Duration? since;

    if (bestFocused == null) {
      if (!stability.allowPrimaryWhenNoItemFocused) {
        winner = null;
        since = null;
      } else if (previousStillVisible) {
        winner = previousPrimary;
        since = previousPrimarySince ?? now;
      } else if (bestVisible != null) {
        winner = bestVisible;
        since = now;
      }
    } else if (!previousStillFocused) {
      winner = bestFocused;
      since = now;
    } else if (identical(bestFocused, previousPrimary)) {
      winner = previousPrimary;
      since = previousPrimarySince ?? now;
    } else {
      final Duration currentSince = previousPrimarySince ?? now;
      final bool minDurationSatisfied =
          stability.minPrimaryDuration == Duration.zero ||
              now - currentSince >= stability.minPrimaryDuration;

      if (!minDurationSatisfied) {
        winner = previousPrimary;
        since = currentSince;
      } else if (!stability.preferCurrentPrimary) {
        winner = bestFocused;
        since = now;
      } else if (_beatsByHysteresis(
        current: previousPrimary,
        candidate: bestFocused,
        hysteresisPx: stability.hysteresisPx,
      )) {
        winner = bestFocused;
        since = now;
      } else {
        winner = previousPrimary;
        since = currentSince;
      }
    }

    for (final slot in slots) {
      slot.isPrimary = identical(slot, winner);
    }

    result
      ..primaryId = winner?.id
      ..primarySince = since;
    return result;
  }

  static bool _beatsByHysteresis<T>({
    required ItemSlot<T> current,
    required ItemSlot<T> candidate,
    required double hysteresisPx,
  }) {
    if (hysteresisPx <= 0) return true;

    final double improvement =
        current.distanceToAnchorPx.abs() - candidate.distanceToAnchorPx.abs();

    // Tolerant compare avoids churn from tiny float noise.
    return improvement > 0 &&
        (improvement > hysteresisPx || nearlyEqual(improvement, hysteresisPx));
  }

  static bool _isBetter<T>(
    ItemSlot<T> candidate,
    ItemSlot<T> currentBest,
    ScrollSpyPolicy<T> policy,
  ) {
    final int cmp = _compare(candidate, currentBest, policy);
    if (cmp < 0) return true;
    if (cmp > 0) return false;

    // Tie-breakers (deterministic and stable).
    final int byProgress = _compareDesc(
      candidate.focusProgress,
      currentBest.focusProgress,
      epsilon: kScrollSpyDefaultEpsilonFraction,
    );
    if (byProgress != 0) return byProgress < 0;

    final int byFraction = _compareDesc(
      candidate.visibleFraction,
      currentBest.visibleFraction,
      epsilon: kScrollSpyDefaultEpsilonFraction,
    );
    if (byFraction != 0) return byFraction < 0;

    final int byDistance = _compareAsc(
      candidate.distanceToAnchorPx.abs(),
      currentBest.distanceToAnchorPx.abs(),
      epsilon: kScrollSpyDefaultEpsilonPx,
    );
    if (byDistance != 0) return byDistance < 0;

    // Stable fallback: keep the earlier candidate (input order).
    return false;
  }

  static int _compare<T>(
    ItemSlot<T> a,
    ItemSlot<T> b,
    ScrollSpyPolicy<T> policy,
  ) {
    switch (policy) {
      case CustomFocusPolicy<T>(:final compare):
        // Custom comparators receive the public immutable type; this is the
        // documented allocation cost of custom policies.
        final int custom = compare(a.toItemFocus(), b.toItemFocus());
        if (custom != 0) return custom;
        return _compareAsc(
          a.distanceToAnchorPx.abs(),
          b.distanceToAnchorPx.abs(),
          epsilon: kScrollSpyDefaultEpsilonPx,
        );

      case ClosestToAnchorPolicy<T>():
        return _compareAsc(
          a.distanceToAnchorPx.abs(),
          b.distanceToAnchorPx.abs(),
          epsilon: kScrollSpyDefaultEpsilonPx,
        );

      case LargestVisibleFractionPolicy<T>():
        return _compareDesc(
          a.visibleFraction,
          b.visibleFraction,
          epsilon: kScrollSpyDefaultEpsilonFraction,
        );

      case LargestFocusOverlapPolicy<T>():
        return _compareDesc(
          a.focusOverlapFraction,
          b.focusOverlapFraction,
          epsilon: kScrollSpyDefaultEpsilonFraction,
        );

      case LargestFocusProgressPolicy<T>():
        return _compareDesc(
          a.focusProgress,
          b.focusProgress,
          epsilon: kScrollSpyDefaultEpsilonFraction,
        );
    }
  }

  static int _compareAsc(double a, double b, {required double epsilon}) {
    if (nearlyEqual(a, b, epsilon: epsilon)) return 0;
    return a < b ? -1 : 1;
  }

  static int _compareDesc(double a, double b, {required double epsilon}) =>
      -_compareAsc(a, b, epsilon: epsilon);
}
