import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/focus_fixtures.dart';

ScrollSpySnapshot<int> _frame({int primaryId = 1}) => makeSnapshot(
  primaryId: primaryId,
  focusedIds: {primaryId},
  visibleIds: const {1, 2},
  items: {
    for (final id in [1, 2])
      id: makeFocusItem(
        id: id,
        isFocused: id == primaryId,
        isPrimary: id == primaryId,
      ),
  },
);

void main() {
  test('focus callbacks can subscribe to another item', () {
    final controller = ScrollSpyController<int>();
    addTearDown(controller.dispose);
    controller.itemFocusOf(1).addListener(() {
      controller.itemFocusOf(2).addListener(() {});
    });

    expect(() => controller.commitFrame(_frame()), returnsNormally);
    expect(controller.primaryId.value, 1);
    expect(controller.itemFocusOf(2).value.isVisible, isTrue);
    expect(() => controller.commitFrame(_frame(primaryId: 2)), returnsNormally);
    expect(controller.itemFocusOf(2).value.isPrimary, isTrue);
  });

  test('boolean callbacks can subscribe to another item', () {
    final controller = ScrollSpyController<int>();
    addTearDown(controller.dispose);
    controller.itemIsPrimaryOf(1).addListener(() {
      controller.itemIsPrimaryOf(2).addListener(() {});
    });

    expect(() => controller.commitFrame(_frame()), returnsNormally);
    expect(controller.primaryId.value, 1);
    expect(controller.itemIsPrimaryOf(2).value, isFalse);
    expect(() => controller.commitFrame(_frame(primaryId: 2)), returnsNormally);
    expect(controller.itemIsPrimaryOf(2).value, isTrue);
  });

  test('primary callbacks read the current snapshot', () {
    final controller = ScrollSpyController<int>();
    addTearDown(controller.dispose);
    expect(controller.snapshot.value.primaryId, isNull);
    int? observedPrimary;
    controller.primaryId.addListener(() {
      observedPrimary = controller.snapshot.value.primaryId;
    });

    controller.commitFrame(_frame());
    expect(observedPrimary, 1);
    expect(controller.debugMaterializedSnapshots, 1);
    expect(controller.snapshot.value.primaryId, 1);
    expect(controller.debugMaterializedSnapshots, 1);
  });

  test('removing an unknown callback keeps active item listeners', () {
    final controller = ScrollSpyController<int>();
    addTearDown(controller.dispose);
    final listenable = controller.itemFocusOf(1);
    var notifications = 0;
    listenable.addListener(() => notifications++);
    listenable.removeListener(() {});

    controller.commitFrame(_frame());
    controller.commitFrame(makeSnapshot());

    expect(listenable.value.isVisible, isFalse);
    expect(notifications, 2);
    expect(identical(controller.itemFocusOf(1), listenable), isTrue);
  });

  test('callbacks can dispose the controller during fan-out', () {
    final controller = ScrollSpyController<int>();
    addTearDown(controller.dispose);
    controller.itemFocusOf(1).addListener(controller.dispose);
    controller.itemFocusOf(2).addListener(() {});

    expect(() => controller.commitFrame(_frame()), returnsNormally);
    expect(() => controller.commitFrame(_frame(primaryId: 2)), returnsNormally);
  });
}
