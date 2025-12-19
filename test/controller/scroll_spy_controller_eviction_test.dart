import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/focus_fixtures.dart';

void main() {
  group('ScrollSpyController - per-item notifier eviction', () {
    test(
      'updates missing id to unknown when listener exists, then evicts when no listeners',
      () {
        final controller = ScrollSpyController<int>();
        addTearDown(controller.dispose);

        const int id = 42;

        // Create the notifier (unknown/offscreen initially).
        final ValueListenable<ScrollSpyItemFocus<int>> listenable =
            controller.itemFocusOf(id);

        // Sanity: tryGetItemFocus returns non-null once a notifier exists.
        expect(controller.tryGetItemFocus(id), isNotNull);
        expect(listenable.value.id, id);
        expect(listenable.value.isVisible, isFalse);
        expect(listenable.value.isFocused, isFalse);
        expect(listenable.value.isPrimary, isFalse);

        int notifications = 0;
        void onItemChanged() => notifications++;

        // Attach a listener so the controller considers this notifier "active".
        listenable.addListener(onItemChanged);

        // 1) Commit a frame where the item is present and visible/focused/primary.
        controller.commitFrame(
          makeSnapshot(
            computedAt: DateTime.fromMillisecondsSinceEpoch(1),
            primaryId: id,
            focusedIds: <int>{id},
            visibleIds: <int>{id},
            items: <int, ScrollSpyItemFocus<int>>{
              id: makeFocusItem(
                id: id,
                isVisible: true,
                isFocused: true,
                isPrimary: true,
                visibleFraction: 0.5,
                distanceToAnchorPx: 12.0,
                focusProgress: 0.8,
                focusOverlapFraction: 0.6,
              ),
            },
          ),
        );

        expect(listenable.value.id, id);
        expect(listenable.value.isVisible, isTrue);
        expect(listenable.value.isFocused, isTrue);
        expect(listenable.value.isPrimary, isTrue);
        expect(listenable.value.visibleFraction, closeTo(0.5, 1e-9));
        expect(listenable.value.distanceToAnchorPx, closeTo(12.0, 1e-9));
        expect(listenable.value.focusProgress, closeTo(0.8, 1e-9));
        expect(listenable.value.focusOverlapFraction, closeTo(0.6, 1e-9));
        expect(notifications, greaterThanOrEqualTo(1));

        // 2) Commit a frame that omits the item.
        //
        // Expected behavior (per architecture spec):
        // - Because a listener exists, the controller updates the notifier to
        //   the "unknown/offscreen" focus state.
        controller.commitFrame(
          makeSnapshot(
            computedAt: DateTime.fromMillisecondsSinceEpoch(2),
            primaryId: null,
            focusedIds: const <int>{},
            visibleIds: const <int>{},
            items: const <int, ScrollSpyItemFocus<int>>{},
          ),
        );

        final off = listenable.value;
        expect(off.id, id);
        expect(off.isVisible, isFalse);
        expect(off.isFocused, isFalse);
        expect(off.isPrimary, isFalse);
        expect(off.visibleFraction, 0.0);
        expect(off.distanceToAnchorPx, double.infinity);
        expect(off.focusProgress, 0.0);
        expect(off.focusOverlapFraction, 0.0);
        expect(off.itemRectInViewport, isNull);
        expect(off.visibleRectInViewport, isNull);

        // We should have seen another notification for the "drop to unknown".
        expect(notifications, greaterThanOrEqualTo(2));

        // 3) Remove listener; subsequent frames that still omit the id should allow
        // the controller to evict the idle notifier.
        listenable.removeListener(onItemChanged);

        controller.commitFrame(
          makeSnapshot(
            computedAt: DateTime.fromMillisecondsSinceEpoch(3),
            primaryId: null,
            focusedIds: const <int>{},
            visibleIds: const <int>{},
            items: const <int, ScrollSpyItemFocus<int>>{},
          ),
        );

        // Expected behavior (per architecture spec): notifier is evicted.
        expect(controller.tryGetItemFocus(id), isNull);
      },
    );
  });
}
