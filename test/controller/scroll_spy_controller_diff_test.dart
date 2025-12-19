import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/focus_fixtures.dart';

void main() {
  group('ScrollSpyController - diff-only notifications', () {
    test('primaryId notifies only when primary changes', () {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      var primaryNotifications = 0;
      controller.primaryId.addListener(() => primaryNotifications++);

      controller.commitFrame(
        makeSnapshot(
          computedAt: DateTime.fromMillisecondsSinceEpoch(1),
          primaryId: 1,
          focusedIds: const <int>{1},
          visibleIds: const <int>{1},
        ),
      );
      expect(primaryNotifications, 1);

      // Same primary again => MUST NOT notify.
      controller.commitFrame(
        makeSnapshot(
          computedAt: DateTime.fromMillisecondsSinceEpoch(2),
          primaryId: 1,
          focusedIds: const <int>{1},
          visibleIds: const <int>{1},
        ),
      );
      expect(
        primaryNotifications,
        1,
        reason: 'primaryId should not notify when value is unchanged.',
      );

      // Change primary => notify.
      controller.commitFrame(
        makeSnapshot(
          computedAt: DateTime.fromMillisecondsSinceEpoch(3),
          primaryId: 2,
          focusedIds: const <int>{2},
          visibleIds: const <int>{2},
        ),
      );
      expect(primaryNotifications, 2);
    });

    test(
      'focusedIds notifies only when set contents change (not instance)',
      () {
        final controller = ScrollSpyController<int>();
        addTearDown(controller.dispose);

        var focusedNotifications = 0;
        controller.focusedIds.addListener(() => focusedNotifications++);

        controller.commitFrame(
          makeSnapshot(
            computedAt: DateTime.fromMillisecondsSinceEpoch(1),
            primaryId: 1,
            focusedIds: <int>{1, 2},
            visibleIds: <int>{1, 2},
          ),
        );
        expect(focusedNotifications, 1);

        // New Set instance with same contents => MUST NOT notify.
        controller.commitFrame(
          makeSnapshot(
            computedAt: DateTime.fromMillisecondsSinceEpoch(2),
            primaryId: 1,
            focusedIds: <int>{2, 1},
            visibleIds: <int>{1, 2},
          ),
        );
        expect(
          focusedNotifications,
          1,
          reason:
              'focusedIds should not notify if the set contents are unchanged.',
        );

        // Contents change => notify.
        controller.commitFrame(
          makeSnapshot(
            computedAt: DateTime.fromMillisecondsSinceEpoch(3),
            primaryId: 1,
            focusedIds: <int>{1},
            visibleIds: <int>{1, 2},
          ),
        );
        expect(focusedNotifications, 2);

        // Unmodifiable guarantee.
        expect(
          () => controller.focusedIds.value.add(999),
          throwsUnsupportedError,
          reason: 'focusedIds.value should be unmodifiable.',
        );
      },
    );

    test(
      'per-item notifier ignores micro jitter within epsilon (floats + rects), updates on meaningful change',
      () {
        final controller = ScrollSpyController<int>();
        addTearDown(controller.dispose);

        const id = 7;
        final ValueListenable<ScrollSpyItemFocus<int>> listenable =
            controller.itemFocusOf(id);

        var itemNotifications = 0;
        void onItemChanged() => itemNotifications++;
        listenable.addListener(onItemChanged);
        addTearDown(() => listenable.removeListener(onItemChanged));

        final a = const ScrollSpyItemFocus<int>(
          id: id,
          isVisible: true,
          isFocused: true,
          isPrimary: true,
          visibleFraction: 0.5000,
          distanceToAnchorPx: 10.0,
          focusProgress: 0.8000,
          focusOverlapFraction: 0.6000,
          itemRectInViewport: Rect.fromLTWH(0, 0, 100, 100),
          visibleRectInViewport: Rect.fromLTWH(0, 0, 100, 100),
        );

        controller.commitFrame(
          makeSnapshot(
            computedAt: DateTime.fromMillisecondsSinceEpoch(1),
            primaryId: id,
            focusedIds: <int>{id},
            visibleIds: <int>{id},
            items: <int, ScrollSpyItemFocus<int>>{id: a},
          ),
        );

        expect(itemNotifications, 1);
        expect(listenable.value.distanceToAnchorPx, closeTo(10.0, 1e-9));

        // Small changes within epsilon:
        // - fraction/progress/overlap < 0.001 difference
        // - distance < 0.5 px difference
        // - rect edges < 0.5 px difference
        final b = const ScrollSpyItemFocus<int>(
          id: id,
          isVisible: true,
          isFocused: true,
          isPrimary: true,
          visibleFraction: 0.5005,
          distanceToAnchorPx: 10.2,
          focusProgress: 0.8004,
          focusOverlapFraction: 0.6003,
          itemRectInViewport: Rect.fromLTWH(0.25, 0.25, 100, 100),
          visibleRectInViewport: Rect.fromLTWH(0.25, 0.25, 100, 100),
        );

        controller.commitFrame(
          makeSnapshot(
            computedAt: DateTime.fromMillisecondsSinceEpoch(2),
            primaryId: id,
            focusedIds: <int>{id},
            visibleIds: <int>{id},
            items: <int, ScrollSpyItemFocus<int>>{id: b},
          ),
        );

        expect(
          itemNotifications,
          1,
          reason:
              'No notifier update expected for jitter within controller epsilons.',
        );
        expect(
          listenable.value.distanceToAnchorPx,
          closeTo(10.0, 1e-9),
          reason: 'Value should remain the previous stable value.',
        );

        // Meaningful change beyond epsilon => should update.
        final c = b.copyWith(distanceToAnchorPx: 11.0); // +0.8 > 0.5
        controller.commitFrame(
          makeSnapshot(
            computedAt: DateTime.fromMillisecondsSinceEpoch(3),
            primaryId: id,
            focusedIds: <int>{id},
            visibleIds: <int>{id},
            items: <int, ScrollSpyItemFocus<int>>{id: c},
          ),
        );

        expect(itemNotifications, 2);
        expect(listenable.value.distanceToAnchorPx, closeTo(11.0, 1e-9));
      },
    );

    test(
      'tryGetItemFocus prefers snapshot; itemFocusOf seeds from snapshot and is stable',
      () {
        final controller = ScrollSpyController<int>();
        addTearDown(controller.dispose);

        const id = 5;
        final focus = makeFocusItem(
          id: id,
          isVisible: true,
          isFocused: true,
          isPrimary: true,
          visibleFraction: 0.75,
          distanceToAnchorPx: 3.0,
          focusProgress: 0.9,
          focusOverlapFraction: 1.0,
        );

        // Commit without ever calling itemFocusOf.
        controller.commitFrame(
          makeSnapshot(
            computedAt: DateTime.fromMillisecondsSinceEpoch(1),
            primaryId: id,
            focusedIds: <int>{id},
            visibleIds: <int>{id},
            items: <int, ScrollSpyItemFocus<int>>{id: focus},
          ),
        );

        final fromTry = controller.tryGetItemFocus(id);
        expect(fromTry, isNotNull);
        expect(fromTry!.isPrimary, isTrue);

        // itemFocusOf should seed from snapshot (not "unknown").
        final a = controller.itemFocusOf(id);
        expect(a.value.isVisible, isTrue);
        expect(a.value.isPrimary, isTrue);

        // Same notifier instance on repeated calls.
        final b = controller.itemFocusOf(id);
        expect(identical(a, b), isTrue);
      },
    );
  });
}
