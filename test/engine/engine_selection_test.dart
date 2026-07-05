import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';
import 'package:scroll_spy/src/engine/engine_selection.dart';
import 'package:scroll_spy/src/engine/item_slot.dart';

ItemSlot<int> makeSlot({
  required int id,
  required int order,
  bool isVisible = false,
  bool isFocused = false,
  double distanceToAnchorPx = 0,
  double visibleFraction = 1.0,
  double focusProgress = 0,
  double focusOverlapFraction = 0,
}) {
  return ItemSlot<int>(id: id, registrationOrder: order)
    ..measurable = true
    ..isVisible = isVisible
    ..isFocused = isFocused
    ..visibleFraction = visibleFraction
    ..distanceToAnchorPx = distanceToAnchorPx
    ..focusProgress = focusProgress
    ..focusOverlapFraction = focusOverlapFraction;
}

void main() {
  const now = Duration(seconds: 100);

  group('EngineSelection.select', () {
    test('chooses primary only among focused candidates', () {
      final slots = [
        makeSlot(id: 1, order: 0, isVisible: true, distanceToAnchorPx: 0),
        makeSlot(
          id: 2,
          order: 1,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 200,
          focusProgress: 0.2,
          focusOverlapFraction: 1.0,
        ),
      ];

      final result = EngineSelection.select<int>(
        slots: slots,
        policy: const ScrollSpyPolicy.closestToAnchor(),
        stability: const ScrollSpyStability(),
        previousPrimaryId: null,
        previousPrimarySince: null,
        now: now,
      );

      expect(result.primaryId, 2);
      expect(slots[1].isPrimary, isTrue);
      expect(slots[0].isPrimary, isFalse);
    });

    test('null primary when none focused and allow=false', () {
      final slots = [
        makeSlot(id: 1, order: 0, isVisible: true, distanceToAnchorPx: 0),
        makeSlot(id: 2, order: 1, isVisible: true, distanceToAnchorPx: 50),
      ];

      final result = EngineSelection.select<int>(
        slots: slots,
        policy: const ScrollSpyPolicy.closestToAnchor(),
        stability:
            const ScrollSpyStability(allowPrimaryWhenNoItemFocused: false),
        previousPrimaryId: 1,
        previousPrimarySince: now - const Duration(milliseconds: 500),
        now: now,
      );

      expect(result.primaryId, isNull);
      expect(result.primarySince, isNull);
      expect(slots[0].isPrimary, isFalse);
      expect(slots[1].isPrimary, isFalse);
    });

    test('none focused + allow=true keeps previous primary if still visible',
        () {
      final previousSince = now - const Duration(seconds: 2);
      final slots = [
        makeSlot(id: 1, order: 0, isVisible: true, distanceToAnchorPx: 500),
        makeSlot(id: 2, order: 1, isVisible: true, distanceToAnchorPx: 0),
      ];

      final result = EngineSelection.select<int>(
        slots: slots,
        policy: const ScrollSpyPolicy.closestToAnchor(),
        stability:
            const ScrollSpyStability(allowPrimaryWhenNoItemFocused: true),
        previousPrimaryId: 1,
        previousPrimarySince: previousSince,
        now: now,
      );

      expect(result.primaryId, 1);
      expect(result.primarySince, previousSince);
      expect(slots[0].isPrimary, isTrue);
      expect(slots[1].isPrimary, isFalse);
    });

    test('none focused + allow=true picks best visible when previous is not',
        () {
      final slots = [
        makeSlot(id: 1, order: 0, distanceToAnchorPx: 0, visibleFraction: 0),
        makeSlot(id: 2, order: 1, isVisible: true, distanceToAnchorPx: 10),
      ];

      final result = EngineSelection.select<int>(
        slots: slots,
        policy: const ScrollSpyPolicy.closestToAnchor(),
        stability:
            const ScrollSpyStability(allowPrimaryWhenNoItemFocused: true),
        previousPrimaryId: 1,
        previousPrimarySince: now - const Duration(seconds: 10),
        now: now,
      );

      expect(result.primaryId, 2);
      expect(result.primarySince, now);
      expect(slots[1].isPrimary, isTrue);
      expect(slots[0].isPrimary, isFalse);
    });

    test('minPrimaryDuration blocks switching even if candidate would win', () {
      final previousSince = now - const Duration(milliseconds: 50);
      final slots = [
        makeSlot(
          id: 1,
          order: 0,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 100,
          focusProgress: 0.5,
          focusOverlapFraction: 1.0,
        ),
        makeSlot(
          id: 2,
          order: 1,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 0,
          focusProgress: 1.0,
          focusOverlapFraction: 1.0,
        ),
      ];

      final result = EngineSelection.select<int>(
        slots: slots,
        policy: const ScrollSpyPolicy.closestToAnchor(),
        stability: const ScrollSpyStability(
          minPrimaryDuration: Duration(milliseconds: 100),
          preferCurrentPrimary: false,
        ),
        previousPrimaryId: 1,
        previousPrimarySince: previousSince,
        now: now,
      );

      expect(result.primaryId, 1);
      expect(result.primarySince, previousSince);
      expect(slots[0].isPrimary, isTrue);
      expect(slots[1].isPrimary, isFalse);
    });

    test('hysteresis blocks switching until margin is beaten', () {
      final previousSince = now - const Duration(milliseconds: 250);
      const stability = ScrollSpyStability(
        minPrimaryDuration: Duration(milliseconds: 100),
        hysteresisPx: 50,
      );

      final notEnough = [
        makeSlot(
          id: 1,
          order: 0,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 100,
          focusProgress: 0.4,
          focusOverlapFraction: 1.0,
        ),
        makeSlot(
          id: 2,
          order: 1,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 80,
          focusProgress: 0.6,
          focusOverlapFraction: 1.0,
        ),
      ];

      final r1 = EngineSelection.select<int>(
        slots: notEnough,
        policy: const ScrollSpyPolicy.closestToAnchor(),
        stability: stability,
        previousPrimaryId: 1,
        previousPrimarySince: previousSince,
        now: now,
      );
      expect(r1.primaryId, 1);
      expect(r1.primarySince, previousSince);

      final enough = [
        makeSlot(
          id: 1,
          order: 0,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 100,
          focusProgress: 0.4,
          focusOverlapFraction: 1.0,
        ),
        makeSlot(
          id: 2,
          order: 1,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 40,
          focusProgress: 0.9,
          focusOverlapFraction: 1.0,
        ),
      ];

      final r2 = EngineSelection.select<int>(
        slots: enough,
        policy: const ScrollSpyPolicy.closestToAnchor(),
        stability: stability,
        previousPrimaryId: 1,
        previousPrimarySince: previousSince,
        now: now,
      );
      expect(r2.primaryId, 2);
      expect(r2.primarySince, now);
    });

    test('visibleFraction tie-breaker uses fraction epsilon, not px', () {
      final slots = [
        makeSlot(
          id: 1,
          order: 0,
          isVisible: true,
          isFocused: true,
          focusProgress: 0.5,
          visibleFraction: 0.55,
          distanceToAnchorPx: 0,
          focusOverlapFraction: 1.0,
        ),
        makeSlot(
          id: 2,
          order: 1,
          isVisible: true,
          isFocused: true,
          focusProgress: 0.5,
          visibleFraction: 0.65,
          distanceToAnchorPx: 200,
          focusOverlapFraction: 1.0,
        ),
      ];

      final result = EngineSelection.select<int>(
        slots: slots,
        policy: const ScrollSpyPolicy.largestFocusProgress(),
        stability: const ScrollSpyStability(),
        previousPrimaryId: null,
        previousPrimarySince: null,
        now: now,
      );

      expect(result.primaryId, 2,
          reason: 'visibleFraction must break focusProgress ties');
    });

    test('fully tied candidates fall back to stable input order', () {
      final slots = [
        makeSlot(
          id: 1,
          order: 0,
          isVisible: true,
          isFocused: true,
          focusProgress: 0.5,
          visibleFraction: 0.8,
          distanceToAnchorPx: 10,
          focusOverlapFraction: 1.0,
        ),
        makeSlot(
          id: 2,
          order: 1,
          isVisible: true,
          isFocused: true,
          focusProgress: 0.5,
          visibleFraction: 0.8,
          distanceToAnchorPx: 10,
          focusOverlapFraction: 1.0,
        ),
      ];

      final result = EngineSelection.select<int>(
        slots: slots,
        policy: const ScrollSpyPolicy.largestFocusProgress(),
        stability: const ScrollSpyStability(),
        previousPrimaryId: null,
        previousPrimarySince: null,
        now: now,
      );

      expect(result.primaryId, 1);
      expect(slots[0].isPrimary, isTrue);
      expect(slots[1].isPrimary, isFalse);
    });

    test('custom comparator tie falls back to distance-to-anchor', () {
      final slots = [
        makeSlot(
          id: 1,
          order: 0,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 200,
          focusProgress: 0.5,
          visibleFraction: 0.8,
          focusOverlapFraction: 1.0,
        ),
        makeSlot(
          id: 2,
          order: 1,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 10,
          focusProgress: 0.5,
          visibleFraction: 0.1,
          focusOverlapFraction: 1.0,
        ),
      ];

      final result = EngineSelection.select<int>(
        slots: slots,
        policy: ScrollSpyPolicy<int>.custom(compare: (a, b) => 0),
        stability: const ScrollSpyStability(),
        previousPrimaryId: null,
        previousPrimarySince: null,
        now: now,
      );

      expect(result.primaryId, 2);
    });

    test('custom comparator can override distance-to-anchor', () {
      final slots = [
        makeSlot(
          id: 1,
          order: 0,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 0,
          focusProgress: 1.0,
          focusOverlapFraction: 1.0,
        ),
        makeSlot(
          id: 2,
          order: 1,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 200,
          focusProgress: 0.0,
          focusOverlapFraction: 1.0,
        ),
      ];

      final result = EngineSelection.select<int>(
        slots: slots,
        policy: ScrollSpyPolicy.custom(
          compare: (a, b) => b.id.compareTo(a.id),
        ),
        stability: const ScrollSpyStability(),
        previousPrimaryId: null,
        previousPrimarySince: null,
        now: now,
      );

      expect(result.primaryId, 2);
    });

    test('preferCurrentPrimary=false ignores hysteresis after min duration',
        () {
      final previousSince = now - const Duration(seconds: 2);
      final slots = [
        makeSlot(
          id: 1,
          order: 0,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 100,
          focusProgress: 0.4,
          focusOverlapFraction: 1.0,
        ),
        makeSlot(
          id: 2,
          order: 1,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 99,
          focusProgress: 0.41,
          focusOverlapFraction: 1.0,
        ),
      ];

      final result = EngineSelection.select<int>(
        slots: slots,
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
    });

    test('null previousPrimarySince blocks switching until min duration', () {
      final slots = [
        makeSlot(
          id: 1,
          order: 0,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 100,
          focusProgress: 0.2,
          focusOverlapFraction: 1.0,
        ),
        makeSlot(
          id: 2,
          order: 1,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 0,
          focusProgress: 1.0,
          focusOverlapFraction: 1.0,
        ),
      ];

      final result = EngineSelection.select<int>(
        slots: slots,
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
    });

    test('unmeasurable slots are ignored entirely', () {
      final dead = makeSlot(
        id: 1,
        order: 0,
        isVisible: true,
        isFocused: true,
        distanceToAnchorPx: 0,
      )..measurable = false;
      final slots = [
        dead,
        makeSlot(
          id: 2,
          order: 1,
          isVisible: true,
          isFocused: true,
          distanceToAnchorPx: 300,
          focusOverlapFraction: 1.0,
        ),
      ];

      final result = EngineSelection.select<int>(
        slots: slots,
        policy: const ScrollSpyPolicy.closestToAnchor(),
        stability: const ScrollSpyStability(),
        previousPrimaryId: null,
        previousPrimarySince: null,
        now: now,
      );

      expect(result.primaryId, 2);
      expect(dead.isPrimary, isFalse);
    });
  });
}
