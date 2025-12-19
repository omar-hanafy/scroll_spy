import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/focus_fixtures.dart';

void main() {
  group('ScrollSpySelection.select', () {
    test('chooses primary only among focused candidates', () {
      final now = DateTime(2024, 1, 1);

      // Item 1 is "best" by distance, but it is NOT focused.
      // Item 2 is focused, so it must win primary (primary is only among focused).
      final items = <ScrollSpyItemFocus<int>>[
        makeFocusItem(
          id: 1,
          isVisible: true,
          isFocused: false,
          distanceToAnchorPx: 0,
          focusProgress: 0.0,
          focusOverlapFraction: 0.0,
        ),
        makeFocusItem(
          id: 2,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 200,
          focusProgress: 0.2,
          focusOverlapFraction: 1.0,
        ),
      ];

      final result = ScrollSpySelection.select<int>(
        items: items,
        policy: const ScrollSpyPolicy.closestToAnchor(),
        stability: const ScrollSpyStability(),
        previousPrimaryId: null,
        previousPrimarySince: null,
        now: now,
      );

      expect(result.primaryId, 2);
      expect(result.focusedIds, unorderedEquals(<int>[2]));
      expect(result.visibleIds, unorderedEquals(<int>[1, 2]));
      expect(result.itemsById[2]!.isPrimary, true);
      expect(result.itemsById[1]!.isPrimary, false);
    });

    test(
      'returns null primary when no items focused and allowPrimaryWhenNoItemFocused=false',
      () {
        final now = DateTime(2024, 1, 1);

        final items = <ScrollSpyItemFocus<int>>[
          makeFocusItem(
            id: 1,
            isVisible: true,
            isFocused: false,
            distanceToAnchorPx: 0,
            focusProgress: 0.0,
            focusOverlapFraction: 0.0,
          ),
          makeFocusItem(
            id: 2,
            isVisible: true,
            isFocused: false,
            distanceToAnchorPx: 50,
            focusProgress: 0.0,
            focusOverlapFraction: 0.0,
          ),
        ];

        final result = ScrollSpySelection.select<int>(
          items: items,
          policy: const ScrollSpyPolicy.closestToAnchor(),
          stability: const ScrollSpyStability(
            allowPrimaryWhenNoItemFocused: false,
          ),
          previousPrimaryId: 1,
          previousPrimarySince: now.subtract(const Duration(milliseconds: 500)),
          now: now,
        );

        expect(result.primaryId, isNull);
        expect(result.primarySince, isNull);
        expect(result.focusedIds, isEmpty);
        expect(result.visibleIds, unorderedEquals(<int>[1, 2]));
        expect(result.itemsById[1]!.isPrimary, false);
        expect(result.itemsById[2]!.isPrimary, false);
      },
    );

    test(
      'when no items focused and allowPrimaryWhenNoItemFocused=true, keeps previous primary if still visible',
      () {
        final now = DateTime(2024, 1, 1);
        final previousSince = now.subtract(const Duration(seconds: 2));

        // No one is focused.
        // Policy would pick item 2 by distance, but stability rule says keep previous
        // primary if it's still visible.
        final items = <ScrollSpyItemFocus<int>>[
          makeFocusItem(
            id: 1,
            isVisible: true,
            isFocused: false,
            distanceToAnchorPx: 500,
            focusProgress: 0.0,
            focusOverlapFraction: 0.0,
          ),
          makeFocusItem(
            id: 2,
            isVisible: true,
            isFocused: false,
            distanceToAnchorPx: 0,
            focusProgress: 0.0,
            focusOverlapFraction: 0.0,
          ),
        ];

        final result = ScrollSpySelection.select<int>(
          items: items,
          policy: const ScrollSpyPolicy.closestToAnchor(),
          stability: const ScrollSpyStability(
            allowPrimaryWhenNoItemFocused: true,
          ),
          previousPrimaryId: 1,
          previousPrimarySince: previousSince,
          now: now,
        );

        expect(result.primaryId, 1);
        expect(result.primarySince, previousSince);
        expect(result.focusedIds, isEmpty);
        expect(result.visibleIds, unorderedEquals(<int>[1, 2]));
        expect(result.itemsById[1]!.isPrimary, true);
        expect(result.itemsById[2]!.isPrimary, false);
      },
    );

    test(
      'when no items focused and allowPrimaryWhenNoItemFocused=true, chooses best visible if previous not visible',
      () {
        final now = DateTime(2024, 1, 1);

        final items = <ScrollSpyItemFocus<int>>[
          // Previous primary exists in frame but is NOT visible.
          makeFocusItem(
            id: 1,
            isVisible: false,
            isFocused: false,
            distanceToAnchorPx: 0,
            visibleFraction: 0.0,
            focusProgress: 0.0,
            focusOverlapFraction: 0.0,
          ),
          // Only visible item.
          makeFocusItem(
            id: 2,
            isVisible: true,
            isFocused: false,
            distanceToAnchorPx: 10,
            visibleFraction: 1.0,
            focusProgress: 0.0,
            focusOverlapFraction: 0.0,
          ),
        ];

        final result = ScrollSpySelection.select<int>(
          items: items,
          policy: const ScrollSpyPolicy.closestToAnchor(),
          stability: const ScrollSpyStability(
            allowPrimaryWhenNoItemFocused: true,
          ),
          previousPrimaryId: 1,
          previousPrimarySince: now.subtract(const Duration(seconds: 10)),
          now: now,
        );

        expect(result.primaryId, 2);
        expect(result.primarySince, now);
        expect(result.focusedIds, isEmpty);
        expect(result.visibleIds, unorderedEquals(<int>[2]));
        expect(result.itemsById[2]!.isPrimary, true);
        expect(result.itemsById[1]!.isPrimary, false);
      },
    );

    test('minPrimaryDuration blocks switching even if candidate would win', () {
      final now = DateTime(2024, 1, 1);
      final previousSince = now.subtract(const Duration(milliseconds: 50));

      // Both focused, candidate 2 is clearly better by closest-to-anchor,
      // but minPrimaryDuration has NOT elapsed => keep previous primary (1).
      final items = <ScrollSpyItemFocus<int>>[
        makeFocusItem(
          id: 1,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 100,
          focusProgress: 0.5,
          focusOverlapFraction: 1.0,
        ),
        makeFocusItem(
          id: 2,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 0,
          focusProgress: 1.0,
          focusOverlapFraction: 1.0,
        ),
      ];

      final result = ScrollSpySelection.select<int>(
        items: items,
        policy: const ScrollSpyPolicy.closestToAnchor(),
        stability: const ScrollSpyStability(
          minPrimaryDuration: Duration(milliseconds: 100),
          preferCurrentPrimary: false, // even if not sticky, min duration wins
        ),
        previousPrimaryId: 1,
        previousPrimarySince: previousSince,
        now: now,
      );

      expect(result.primaryId, 1);
      expect(result.primarySince, previousSince);
      expect(result.focusedIds, unorderedEquals(<int>[1, 2]));
      expect(result.itemsById[1]!.isPrimary, true);
      expect(result.itemsById[2]!.isPrimary, false);
    });

    test(
      'hysteresis blocks switching until candidate beats current by margin',
      () {
        final now = DateTime(2024, 1, 1);
        final previousSince = now.subtract(const Duration(milliseconds: 250));

        // Current primary is 1 at distance 100.
        // Candidate 2 is better (80), but not better by hysteresis margin (50).
        // Improvement = 20 < 50 => keep current.
        final itemsNotEnough = <ScrollSpyItemFocus<int>>[
          makeFocusItem(
            id: 1,
            isVisible: true,
            isFocused: true,
            distanceToAnchorPx: 100,
            focusProgress: 0.4,
            focusOverlapFraction: 1.0,
          ),
          makeFocusItem(
            id: 2,
            isVisible: true,
            isFocused: true,
            distanceToAnchorPx: 80,
            focusProgress: 0.6,
            focusOverlapFraction: 1.0,
          ),
        ];

        final stability = const ScrollSpyStability(
          minPrimaryDuration: Duration(milliseconds: 100),
          preferCurrentPrimary: true,
          hysteresisPx: 50,
        );

        final r1 = ScrollSpySelection.select<int>(
          items: itemsNotEnough,
          policy: const ScrollSpyPolicy.closestToAnchor(),
          stability: stability,
          previousPrimaryId: 1,
          previousPrimarySince: previousSince,
          now: now,
        );

        expect(r1.primaryId, 1);
        expect(r1.primarySince, previousSince);

        // Now candidate improves enough: current=100, candidate=40 => improvement=60 >= 50.
        final itemsEnough = <ScrollSpyItemFocus<int>>[
          makeFocusItem(
            id: 1,
            isVisible: true,
            isFocused: true,
            distanceToAnchorPx: 100,
            focusProgress: 0.4,
            focusOverlapFraction: 1.0,
          ),
          makeFocusItem(
            id: 2,
            isVisible: true,
            isFocused: true,
            distanceToAnchorPx: 40,
            focusProgress: 0.9,
            focusOverlapFraction: 1.0,
          ),
        ];

        final r2 = ScrollSpySelection.select<int>(
          items: itemsEnough,
          policy: const ScrollSpyPolicy.closestToAnchor(),
          stability: stability,
          previousPrimaryId: 1,
          previousPrimarySince: previousSince,
          now: now,
        );

        expect(r2.primaryId, 2);
        expect(r2.primarySince, now);
      },
    );

    test(
      'visibleFraction tie-breaker is sensitive to fraction differences (not px epsilon)',
      () {
        final now = DateTime(2024, 1, 1);

        // Use a policy that compares ONLY focusProgress.
        // We set focusProgress equal so the policy comparator returns 0,
        // forcing tie-breakers to decide:
        // 1) focusProgress (tied)
        // 2) visibleFraction (should pick item 2)
        // 3) abs distance (would pick item 1 if visibleFraction were treated as "equal")
        final items = <ScrollSpyItemFocus<int>>[
          makeFocusItem(
            id: 1,
            isVisible: true,
            isFocused: true,
            focusProgress: 0.5,
            visibleFraction: 0.55,
            distanceToAnchorPx: 0, // closer
            focusOverlapFraction: 1.0,
          ),
          makeFocusItem(
            id: 2,
            isVisible: true,
            isFocused: true,
            focusProgress: 0.5, // equal progress
            visibleFraction: 0.65, // higher fraction (should win tie-break)
            distanceToAnchorPx: 200, // farther
            focusOverlapFraction: 1.0,
          ),
        ];

        final result = ScrollSpySelection.select<int>(
          items: items,
          policy: const ScrollSpyPolicy.largestFocusProgress(),
          stability: const ScrollSpyStability(),
          previousPrimaryId: null,
          previousPrimarySince: null,
          now: now,
        );

        expect(
          result.primaryId,
          2,
          reason:
              'When focusProgress ties, visibleFraction must break ties even '
              'for small (fractional) differences.',
        );
      },
    );

    test('fully tied candidates fall back to stable input order', () {
      final now = DateTime(2024, 1, 1);

      // All comparator + tie-breaker signals are identical:
      // - focusProgress equal
      // - visibleFraction equal
      // - abs distance equal
      // => stable fallback keeps the first candidate in the input list.
      final items = <ScrollSpyItemFocus<int>>[
        makeFocusItem(
          id: 1,
          isVisible: true,
          isFocused: true,
          focusProgress: 0.5,
          visibleFraction: 0.8,
          distanceToAnchorPx: 10,
          focusOverlapFraction: 1.0,
        ),
        makeFocusItem(
          id: 2,
          isVisible: true,
          isFocused: true,
          focusProgress: 0.5,
          visibleFraction: 0.8,
          distanceToAnchorPx: 10,
          focusOverlapFraction: 1.0,
        ),
      ];

      final result = ScrollSpySelection.select<int>(
        items: items,
        policy: const ScrollSpyPolicy.largestFocusProgress(),
        stability: const ScrollSpyStability(),
        previousPrimaryId: null,
        previousPrimarySince: null,
        now: now,
      );

      expect(result.primaryId, 1);
      expect(result.itemsById[1]!.isPrimary, true);
      expect(result.itemsById[2]!.isPrimary, false);
    });

    test('custom policy comparator tie falls back to distance-to-anchor', () {
      final now = DateTime(2024, 1, 1);

      final items = <ScrollSpyItemFocus<int>>[
        makeFocusItem(
          id: 1,
          isVisible: true,
          isFocused: true,
          // farther
          distanceToAnchorPx: 200,
          focusProgress: 0.5,
          visibleFraction: 0.8,
          focusOverlapFraction: 1.0,
        ),
        makeFocusItem(
          id: 2,
          isVisible: true,
          isFocused: true,
          // closer (should win if comparator ties)
          distanceToAnchorPx: 10,
          focusProgress: 0.5,
          visibleFraction: 0.1,
          focusOverlapFraction: 1.0,
        ),
      ];

      final result = ScrollSpySelection.select<int>(
        items: items,
        policy: ScrollSpyPolicy<int>.custom(compare: (a, b) => 0),
        stability: const ScrollSpyStability(),
        previousPrimaryId: null,
        previousPrimarySince: null,
        now: now,
      );

      expect(
        result.primaryId,
        2,
        reason:
            'When the custom comparator ties, the engine should fall back to '
            'distance-to-anchor to keep selection deterministic.',
      );
    });

    test('custom policy comparator can override distance-to-anchor', () {
      final now = DateTime(2024, 1, 1);

      // Item 1 is closer, but the custom comparator prefers higher id.
      final items = <ScrollSpyItemFocus<int>>[
        makeFocusItem(
          id: 1,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 0,
          focusProgress: 1.0,
          focusOverlapFraction: 1.0,
        ),
        makeFocusItem(
          id: 2,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 200,
          focusProgress: 0.0,
          focusOverlapFraction: 1.0,
        ),
      ];

      final result = ScrollSpySelection.select<int>(
        items: items,
        policy: ScrollSpyPolicy.custom(
          compare: (a, b) => b.id.compareTo(a.id), // prefer larger id
        ),
        stability: const ScrollSpyStability(),
        previousPrimaryId: null,
        previousPrimarySince: null,
        now: now,
      );

      expect(result.primaryId, 2);
    });

    test(
      'preferCurrentPrimary=false ignores hysteresis once minPrimaryDuration is satisfied',
      () {
        final now = DateTime(2024, 1, 1);
        final previousSince = now.subtract(const Duration(seconds: 2));

        // Both focused.
        // Candidate 2 is only slightly better by distance, and would NOT beat
        // the large hysteresis margin, but preferCurrentPrimary=false should
        // switch immediately once minPrimaryDuration is satisfied.
        final items = <ScrollSpyItemFocus<int>>[
          makeFocusItem(
            id: 1,
            isVisible: true,
            isFocused: true,
            distanceToAnchorPx: 100,
            focusProgress: 0.4,
            focusOverlapFraction: 1.0,
          ),
          makeFocusItem(
            id: 2,
            isVisible: true,
            isFocused: true,
            distanceToAnchorPx: 99,
            focusProgress: 0.41,
            focusOverlapFraction: 1.0,
          ),
        ];

        final result = ScrollSpySelection.select<int>(
          items: items,
          policy: const ScrollSpyPolicy.closestToAnchor(),
          stability: const ScrollSpyStability(
            minPrimaryDuration: Duration(milliseconds: 100),
            hysteresisPx: 999,
            preferCurrentPrimary: false,
          ),
          previousPrimaryId: 1,
          previousPrimarySince: previousSince,
          now: now,
        );

        expect(result.primaryId, 2);
        expect(result.primarySince, now);
      },
    );

    test(
      'null previousPrimarySince is treated as now (blocks switching until min duration elapses)',
      () {
        final now = DateTime(2024, 1, 1);

        final items = <ScrollSpyItemFocus<int>>[
          makeFocusItem(
            id: 1,
            isVisible: true,
            isFocused: true,
            distanceToAnchorPx: 100,
            focusProgress: 0.2,
            focusOverlapFraction: 1.0,
          ),
          makeFocusItem(
            id: 2,
            isVisible: true,
            isFocused: true,
            distanceToAnchorPx: 0,
            focusProgress: 1.0,
            focusOverlapFraction: 1.0,
          ),
        ];

        final result = ScrollSpySelection.select<int>(
          items: items,
          policy: const ScrollSpyPolicy.closestToAnchor(),
          stability: const ScrollSpyStability(
            minPrimaryDuration: Duration(milliseconds: 100),
            preferCurrentPrimary: false,
          ),
          previousPrimaryId: 1,
          previousPrimarySince: null,
          now: now,
        );

        expect(result.primaryId, 1);
        expect(result.primarySince, now);
      },
    );
  });
}
