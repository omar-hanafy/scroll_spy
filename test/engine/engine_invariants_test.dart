import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/widget_harness.dart';

Widget _liteFeed({
  required ScrollSpyController<int> controller,
  required ScrollController scrollController,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 400,
        height: 600,
        child: ScrollSpyScope<int>(
          controller: controller,
          region: const ScrollSpyRegion.zone(
            anchor: ScrollSpyAnchor.fraction(0.5),
            extentPx: 200,
          ),
          policy: const ScrollSpyPolicy.closestToAnchor(),
          scrollController: scrollController,
          child: ListView.builder(
            controller: scrollController,
            itemExtent: 100,
            itemCount: 200,
            itemBuilder: (context, i) => ScrollSpyItemLite<int>(
              id: i,
              child: const SizedBox.expand(),
              builder: (context, isPrimary, isFocused, child) => child!,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('performance invariants', () {
    testWidgets(
        'steady scrolling performs zero full measures after warmup '
        '(all fast-tier hits)', (tester) async {
      final harness = ScrollSpyTestHarness(
        itemCount: 200,
        itemExtent: 100,
        viewportSize: const Size(400, 600),
        scrollController: ScrollController(),
      );
      addTearDown(harness.controller.dispose);
      await harness.pump(tester);

      // Warmup: land on the working offset so every mounted item has a
      // captured geometry anchor.
      harness.scrollController!.jumpTo(1000);
      await tester.pump();
      await tester.pump();

      final engine = harness.scopeState(tester).engine;
      final geometry = engine.debugGeometry;
      final measuresAfterWarmup = geometry.fullMeasures;
      final fastHitsBefore = geometry.fastHits;

      // Small never-seen offsets that keep the mounted set stable.
      for (var i = 1; i <= 8; i++) {
        harness.scrollController!.jumpTo(1000.0 + i);
        await tester.pump();
        await tester.pump();
      }

      expect(geometry.fullMeasures, measuresAfterWarmup,
          reason: 'steady scrolling must not re-measure geometry');
      expect(geometry.fastHits, greaterThan(fastHitsBefore),
          reason: 'positions must come from the O(1) fast tier');

      // And the engine still tracks correctly.
      expect(harness.controller.primaryId.value, isNotNull);
    });

    testWidgets(
        'boolean-only (Lite) feeds materialize no snapshots and no '
        'per-item focus objects', (tester) async {
      final controller = ScrollSpyController<int>();
      final scrollController = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(_liteFeed(
        controller: controller,
        scrollController: scrollController,
      ));
      await tester.pump();
      await tester.pump();

      for (var i = 1; i <= 10; i++) {
        scrollController.jumpTo(i * 150.0);
        await tester.pump();
        await tester.pump();
      }

      expect(controller.debugMaterializedSnapshots, 0,
          reason: 'nobody listens to snapshots');
      expect(controller.debugMaterializedItemFocus, 0,
          reason: 'Lite consumers use boolean signals only');
      expect(controller.primaryId.value, isNotNull,
          reason: 'tracking still works');
    });
  });
}
