import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/widget_harness.dart';

Widget _scoped({
  required ScrollSpyController<int> controller,
  required ScrollSpyRegion region,
  EdgeInsets viewportInsets = EdgeInsets.zero,
  bool insetsAffectVisibility = true,
  ScrollController? scrollController,
  int itemCount = 20,
  double itemExtent = 50,
  Size viewportSize = const Size(300, 200),
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: viewportSize.width,
        height: viewportSize.height,
        child: ScrollSpyScope<int>(
          controller: controller,
          region: region,
          policy: const ScrollSpyPolicy.closestToAnchor(),
          viewportInsets: viewportInsets,
          insetsAffectVisibility: insetsAffectVisibility,
          scrollController: scrollController,
          child: ListView.builder(
            controller: scrollController,
            itemExtent: itemExtent,
            itemCount: itemCount,
            itemBuilder: (context, i) => ScrollSpyItem<int>(
              id: i,
              child: const SizedBox.expand(),
              builder: (context, focus, child) => child!,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ScrollSpyEngine compute', () {
    testWidgets(
        'zone + closestToAnchor picks the centered item and updates '
        'after jumpTo', (tester) async {
      final harness = ScrollSpyTestHarness(
        itemCount: 30,
        itemExtent: 100,
        viewportSize: const Size(400, 300),
        scrollController: ScrollController(),
      );
      addTearDown(harness.controller.dispose);
      await harness.pump(tester);

      // Viewport 300 high, anchor at 150; item 1 (100..200) contains it.
      expect(harness.controller.primaryId.value, 1);
      expect(harness.controller.focusedIds.value, contains(1));

      harness.scrollController!.jumpTo(1000);
      await tester.pump();
      await tester.pump();

      // Offset 1000: anchor at content position 1150 => item 11.
      expect(harness.controller.primaryId.value, 11);

      final snapshot = harness.controller.snapshot.value;
      expect(snapshot.primaryId, 11);
      expect(snapshot.visibleIds, contains(10));
      expect(snapshot.items[11]!.isPrimary, isTrue);
    });

    testWidgets('empty scope commits empty state', (tester) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_scoped(
        controller: controller,
        region: const ScrollSpyRegion.line(anchor: ScrollSpyAnchor.pixels(0)),
        itemCount: 0,
      ));
      await tester.pump();
      await tester.pump();

      expect(controller.primaryId.value, isNull);
      expect(controller.focusedIds.value, isEmpty);
      expect(controller.snapshot.value.items, isEmpty);
    });

    testWidgets(
        'top inset shifts anchor and hides covered items when '
        'insetsAffectVisibility is true', (tester) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      // Viewport 200 high, inset 100 => effective viewport 100..200,
      // anchor pixels(0) sits at 100 => item 2 (100..150) wins.
      await tester.pumpWidget(_scoped(
        controller: controller,
        region: const ScrollSpyRegion.line(anchor: ScrollSpyAnchor.pixels(0)),
        viewportInsets: const EdgeInsets.only(top: 100),
      ));
      await tester.pump();
      await tester.pump();

      expect(controller.primaryId.value, 2);

      final snapshot = controller.snapshot.value;
      // Item 0 (0..50) is fully behind the inset: not visible.
      expect(snapshot.items[0]!.isVisible, isFalse);
      expect(snapshot.visibleIds, isNot(contains(0)));
      // Item 2 straddles the anchor: focused.
      expect(snapshot.items[2]!.isFocused, isTrue);
    });

    testWidgets(
        'insetsAffectVisibility=false keeps covered items visible '
        'but still shifts the anchor', (tester) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      // Anchor pixels(10) resolves to 110 in the effective viewport
      // (100..200); only item 2 (100..150) straddles it.
      await tester.pumpWidget(_scoped(
        controller: controller,
        region: const ScrollSpyRegion.line(anchor: ScrollSpyAnchor.pixels(10)),
        viewportInsets: const EdgeInsets.only(top: 100),
        insetsAffectVisibility: false,
      ));
      await tester.pump();
      await tester.pump();

      expect(controller.primaryId.value, 2);
      final snapshot = controller.snapshot.value;
      expect(snapshot.items[0]!.isVisible, isTrue);
      expect(snapshot.visibleIds, contains(0));
    });

    testWidgets('insets larger than the viewport commit empty state',
        (tester) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_scoped(
        controller: controller,
        region: const ScrollSpyRegion.line(anchor: ScrollSpyAnchor.pixels(0)),
        viewportInsets: const EdgeInsets.only(top: 400),
      ));
      await tester.pump();
      await tester.pump();

      expect(controller.primaryId.value, isNull);
      expect(controller.focusedIds.value, isEmpty);
    });

    testWidgets('debug frames are not produced when debug is off',
        (tester) async {
      final harness = ScrollSpyTestHarness();
      addTearDown(harness.controller.dispose);
      await harness.pump(tester);

      final engine = harness.scopeState(tester).engine;
      expect(engine.debugFrame.value!.sequence, 0,
          reason: 'no debug frames published with debug disabled');
      expect(harness.controller.primaryId.value, isNotNull,
          reason: 'engine still computes normally');
    });

    testWidgets('items leaving the tree disappear from state', (tester) async {
      final controller = ScrollSpyController<int>();
      final scrollController = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(_scoped(
        controller: controller,
        region: const ScrollSpyRegion.zone(
          anchor: ScrollSpyAnchor.fraction(0.5),
          extentPx: 50,
        ),
        scrollController: scrollController,
        itemCount: 100,
      ));
      await tester.pump();
      await tester.pump();

      expect(controller.snapshot.value.items.containsKey(0), isTrue);

      // Scroll far away so item 0 unmounts.
      scrollController.jumpTo(3000);
      await tester.pump();
      await tester.pump();

      expect(controller.snapshot.value.items.containsKey(0), isFalse);
      expect(controller.tryGetItemFocus(0), isNull);
    });
  });
}
