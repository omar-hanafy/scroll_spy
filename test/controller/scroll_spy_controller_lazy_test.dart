import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/focus_fixtures.dart';

void main() {
  group('ScrollSpyController - lazy materialization', () {
    test('no snapshot listeners: commits materialize nothing; value on demand',
        () {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      controller.commitFrame(makeSnapshot(
        computedAt: DateTime.fromMillisecondsSinceEpoch(1),
        primaryId: 1,
        focusedIds: const {1},
        visibleIds: const {1},
        items: {1: makeFocusItem(id: 1, isFocused: true, isPrimary: true)},
      ));
      controller.commitFrame(makeSnapshot(
        computedAt: DateTime.fromMillisecondsSinceEpoch(2),
        primaryId: 2,
        focusedIds: const {2},
        visibleIds: const {2},
        items: {2: makeFocusItem(id: 2, isFocused: true, isPrimary: true)},
      ));

      expect(controller.debugMaterializedSnapshots, 0,
          reason: 'no listener, no reads => zero snapshots built');

      final snapshot = controller.snapshot.value;
      expect(snapshot.primaryId, 2);
      expect(controller.debugMaterializedSnapshots, 1);

      // A second read without a new commit reuses the cached value.
      expect(identical(controller.snapshot.value, snapshot), isTrue);
      expect(controller.debugMaterializedSnapshots, 1);
    });

    test('with a snapshot listener: one materialization per commit', () {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.snapshot.addListener(() => notifications++);

      controller.commitFrame(makeSnapshot(primaryId: 1));
      controller.commitFrame(makeSnapshot(primaryId: 1));

      expect(controller.debugMaterializedSnapshots, 2);
      expect(notifications, 2,
          reason: 'snapshot listeners are notified per pass');
    });

    test('itemFocus materialization only past tolerance', () {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);
      const id = 3;

      final listenable = controller.itemFocusOf(id);
      listenable.addListener(() {});

      controller.commitFrame(makeSnapshot(
        primaryId: id,
        focusedIds: const {id},
        visibleIds: const {id},
        items: {
          id: makeFocusItem(
            id: id,
            isFocused: true,
            isPrimary: true,
            distanceToAnchorPx: 10.0,
          ),
        },
      ));
      final afterFirst = controller.debugMaterializedItemFocus;
      expect(afterFirst, greaterThan(0));

      // Sub-tolerance jitter: no new materialization.
      controller.commitFrame(makeSnapshot(
        primaryId: id,
        focusedIds: const {id},
        visibleIds: const {id},
        items: {
          id: makeFocusItem(
            id: id,
            isFocused: true,
            isPrimary: true,
            distanceToAnchorPx: 10.2,
          ),
        },
      ));
      expect(controller.debugMaterializedItemFocus, afterFirst);

      // Meaningful change: exactly one more.
      controller.commitFrame(makeSnapshot(
        primaryId: id,
        focusedIds: const {id},
        visibleIds: const {id},
        items: {
          id: makeFocusItem(
            id: id,
            isFocused: true,
            isPrimary: true,
            distanceToAnchorPx: 20.0,
          ),
        },
      ));
      expect(controller.debugMaterializedItemFocus, afterFirst + 1);
    });

    test('boolean-only consumers never materialize item focus', () {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);
      const id = 4;

      controller.itemIsPrimaryOf(id).addListener(() {});
      controller.itemIsFocusedOf(id).addListener(() {});

      controller.commitFrame(makeSnapshot(
        primaryId: id,
        focusedIds: const {id},
        visibleIds: const {id},
        items: {
          id: makeFocusItem(id: id, isFocused: true, isPrimary: true),
        },
      ));
      controller.commitFrame(makeSnapshot(
        primaryId: null,
        focusedIds: const {},
        visibleIds: const {id},
        items: {id: makeFocusItem(id: id)},
      ));

      expect(controller.debugMaterializedItemFocus, 0);
      expect(controller.debugMaterializedSnapshots, 0);
    });

    test('focusedIds keeps the same instance when membership is unchanged',
        () {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      controller.commitFrame(makeSnapshot(
        primaryId: 1,
        focusedIds: const {1, 2},
        visibleIds: const {1, 2},
        items: {
          1: makeFocusItem(id: 1, isFocused: true, isPrimary: true),
          2: makeFocusItem(id: 2, isFocused: true),
        },
      ));
      final first = controller.focusedIds.value;

      controller.commitFrame(makeSnapshot(
        primaryId: 1,
        focusedIds: const {2, 1},
        visibleIds: const {1, 2},
        items: {
          1: makeFocusItem(id: 1, isFocused: true, isPrimary: true),
          2: makeFocusItem(id: 2, isFocused: true),
        },
      ));

      expect(identical(controller.focusedIds.value, first), isTrue,
          reason: 'unchanged membership must not allocate a new set');
    });
  });
}
