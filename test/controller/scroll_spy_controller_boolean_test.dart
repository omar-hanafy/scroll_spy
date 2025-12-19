import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/focus_fixtures.dart';

void main() {
  group('ScrollSpyController - Boolean Notifiers', () {
    test('itemIsPrimaryOf notifies only on toggle', () {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);
      const id = 1;

      final notifier = controller.itemIsPrimaryOf(id);
      int updates = 0;
      notifier.addListener(() => updates++);

      // 1. Initial (Primary)
      controller.commitFrame(makeSnapshot(
        primaryId: 1,
        items: {
          1: makeFocusItem(id: 1, isPrimary: true, distanceToAnchorPx: 0)
        },
      ));
      expect(updates, 1);
      expect(notifier.value, true);

      // 2. Metric Change (Distance) - Should NOT notify
      controller.commitFrame(makeSnapshot(
        primaryId: 1,
        items: {
          1: makeFocusItem(id: 1, isPrimary: true, distanceToAnchorPx: 5)
        },
      ));
      expect(updates, 1);

      // 3. Toggle off
      controller.commitFrame(makeSnapshot(
        primaryId: 2,
        items: {
          1: makeFocusItem(id: 1, isPrimary: false, distanceToAnchorPx: 10),
          2: makeFocusItem(id: 2, isPrimary: true, distanceToAnchorPx: 0),
        },
      ));
      expect(updates, 2);
      expect(notifier.value, false);
    });

    test('itemIsFocusedOf notifies only on toggle', () {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);
      const id = 10;

      final notifier = controller.itemIsFocusedOf(id);
      int updates = 0;
      notifier.addListener(() => updates++);

      // 1. Initial (Focused)
      controller.commitFrame(makeSnapshot(
        focusedIds: {id},
        items: {id: makeFocusItem(id: id, isFocused: true)},
      ));
      expect(updates, 1);
      expect(notifier.value, true);

      // 2. Metric Change - Should NOT notify
      controller.commitFrame(makeSnapshot(
        focusedIds: {id},
        items: {
          id: makeFocusItem(
              id: id, isFocused: true, distanceToAnchorPx: 999)
        },
      ));
      expect(updates, 1);

      // 3. Toggle Focus - Should notify
      controller.commitFrame(makeSnapshot(
        focusedIds: {},
        items: {id: makeFocusItem(id: id, isFocused: false)},
      ));
      expect(updates, 2);
      expect(notifier.value, false);
    });

    test('itemIsVisibleOf notifies only on toggle', () {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);
      const id = 5;

      final notifier = controller.itemIsVisibleOf(id);
      int updates = 0;
      notifier.addListener(() => updates++);

      // 1. Initial (Visible)
      controller.commitFrame(makeSnapshot(
        visibleIds: {id},
        items: {id: makeFocusItem(id: id, isVisible: true)},
      ));
      expect(updates, 1);
      expect(notifier.value, true);

      // 2. Metric Change - Should NOT notify
      controller.commitFrame(makeSnapshot(
        visibleIds: {id},
        items: {
          id: makeFocusItem(id: id, isVisible: true, visibleFraction: 0.5)
        },
      ));
      expect(updates, 1);

      // 3. Toggle Visibility - Should notify
      controller.commitFrame(makeSnapshot(
        visibleIds: {},
        items: {id: makeFocusItem(id: id, isVisible: false)},
      ));
      expect(updates, 2);
      expect(notifier.value, false);
    });

    test('diff-based updates notify only changed IDs', () {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      final n1 = controller.itemIsFocusedOf(1);
      final n2 = controller.itemIsFocusedOf(2);
      final n3 = controller.itemIsFocusedOf(3);

      int c1 = 0, c2 = 0, c3 = 0;
      n1.addListener(() => c1++);
      n2.addListener(() => c2++);
      n3.addListener(() => c3++);

      // Frame A: {1, 2} focused
      controller.commitFrame(makeSnapshot(
        focusedIds: {1, 2},
        items: {
          1: makeFocusItem(id: 1, isFocused: true),
          2: makeFocusItem(id: 2, isFocused: true),
          3: makeFocusItem(id: 3, isFocused: false),
        },
      ));
      expect(c1, 1); // false -> true
      expect(c2, 1); // false -> true
      expect(c3, 0); // false -> false (no change)

      // Frame B: {2, 3} focused
      // 1: true -> false (change)
      // 2: true -> true (no change)
      // 3: false -> true (change)
      controller.commitFrame(makeSnapshot(
        focusedIds: {2, 3},
        items: {
          1: makeFocusItem(id: 1, isFocused: false),
          2: makeFocusItem(id: 2, isFocused: true),
          3: makeFocusItem(id: 3, isFocused: true),
        },
      ));

      expect(c1, 2);
      expect(c2, 1);
      expect(c3, 1);
    });

    test('boolean notifiers seed from snapshot when created after commit', () {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      const id = 12;

      controller.commitFrame(makeSnapshot(
        primaryId: id,
        focusedIds: {id},
        visibleIds: {id},
        items: {
          id: makeFocusItem(
            id: id,
            isPrimary: true,
            isFocused: true,
            isVisible: true,
          ),
        },
      ));

      final primary = controller.itemIsPrimaryOf(id);
      final focused = controller.itemIsFocusedOf(id);
      final visible = controller.itemIsVisibleOf(id);

      expect(primary.value, isTrue);
      expect(focused.value, isTrue);
      expect(visible.value, isTrue);
    });

    test('boolean notifier eviction mirrors itemFocusOf', () {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);
      const id = 99;

      final primary = controller.itemIsPrimaryOf(id);
      final focused = controller.itemIsFocusedOf(id);
      final visible = controller.itemIsVisibleOf(id);

      int primaryUpdates = 0;
      int focusedUpdates = 0;
      int visibleUpdates = 0;

      void primaryListener() => primaryUpdates++;
      void focusedListener() => focusedUpdates++;
      void visibleListener() => visibleUpdates++;

      primary.addListener(primaryListener);
      focused.addListener(focusedListener);
      visible.addListener(visibleListener);

      // 1. Make it true
      controller.commitFrame(makeSnapshot(
        primaryId: id,
        focusedIds: {id},
        visibleIds: {id},
        items: {
          id: makeFocusItem(
            id: id,
            isPrimary: true,
            isFocused: true,
            isVisible: true,
          ),
        },
      ));
      expect(primaryUpdates, 1);
      expect(focusedUpdates, 1);
      expect(visibleUpdates, 1);
      expect(primary.value, true);
      expect(focused.value, true);
      expect(visible.value, true);

      // 2. Item disappears from snapshot (engine stops tracking it).
      // Since it has a listener, it should be updated to false (unknown).
      controller.commitFrame(
        makeSnapshot(
          primaryId: null,
          focusedIds: const {},
          visibleIds: const {},
          items: const {},
        ),
      );
      expect(primaryUpdates, 2);
      expect(focusedUpdates, 2);
      expect(visibleUpdates, 2);
      expect(primary.value, false);
      expect(focused.value, false);
      expect(visible.value, false);

      // 3. Remove listener.
      primary.removeListener(primaryListener);
      focused.removeListener(focusedListener);
      visible.removeListener(visibleListener);

      // 4. Commit another frame omitting id.
      controller.commitFrame(
        makeSnapshot(
          primaryId: null,
          focusedIds: const {},
          visibleIds: const {},
          items: const {},
        ),
      );

      // 5. Verify eviction by requesting it again and checking identity.
      final newPrimary = controller.itemIsPrimaryOf(id);
      final newFocused = controller.itemIsFocusedOf(id);
      final newVisible = controller.itemIsVisibleOf(id);
      expect(
        identical(primary, newPrimary),
        isFalse,
        reason: 'Primary notifier should have been evicted and recreated.',
      );
      expect(
        identical(focused, newFocused),
        isFalse,
        reason: 'Focused notifier should have been evicted and recreated.',
      );
      expect(
        identical(visible, newVisible),
        isFalse,
        reason: 'Visible notifier should have been evicted and recreated.',
      );
    });
  });
}
