import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FocusEngine (ScrollSpyUpdatePolicy.hybrid)', () {
    testWidgets(
      'computePerFrameWhileDragging=false keeps primary stable during drag and shortly after release',
      (tester) async {
        final harness = ScrollSpyTestHarness(
          itemCount: 30,
          itemExtent: 100.0,
          viewportSize: const Size(400, 300),
          region: const ScrollSpyRegion.zone(
            anchor: ScrollSpyAnchor.fraction(0.5),
            extentPx: 100.0,
          ),
          policy: const ScrollSpyPolicy<int>.closestToAnchor(),
          updatePolicy: ScrollSpyUpdatePolicy.hybrid(
            scrollEndDebounce: const Duration(seconds: 5),
            ballisticInterval: const Duration(seconds: 5),
            computePerFrameWhileDragging: false,
          ),
          // IMPORTANT: keep null so we isolate behavior to ScrollNotifications.
          scrollController: null,
          debug: false,
        );

        await harness.pump(tester);

        final int? initialPrimary = harness.controller.primaryId.value;
        expect(initialPrimary, 1);

        final listFinder = find.byKey(harness.listKey);
        expect(listFinder, findsOneWidget);

        final gesture = await tester.startGesture(tester.getCenter(listFinder));

        // Drag up => scroll down.
        await gesture.moveBy(const Offset(0, -120));
        await tester.pump();

        // With computePerFrameWhileDragging=false, primary should NOT update mid-drag.
        expect(
          harness.controller.primaryId.value,
          initialPrimary,
          reason:
              'Hybrid policy with computePerFrameWhileDragging=false should not recompute during drag.',
        );

        // Pause with finger still down so release velocity becomes ~0 (avoid ballistic).
        await tester.pump(const Duration(milliseconds: 250));
        expect(harness.controller.primaryId.value, initialPrimary);

        await gesture.up();
        await tester
            .pump(); // ScrollEndNotification should schedule scrollEndDebounce timer.

        // "Shortly after release": still within scrollEndDebounce (5s), so no update.
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          harness.controller.primaryId.value,
          initialPrimary,
          reason:
              'Hybrid policy should not recompute shortly after release when scrollEndDebounce is very large.',
        );

        // After the debounce window, it should update.
        await tester.pump(const Duration(seconds: 5));
        // Allow the debounced _requestCompute() to run its post-frame callback.
        await tester.pump();

        expect(
          harness.controller.primaryId.value,
          2,
          reason:
              'After the long scrollEndDebounce window, the engine should finally recompute primary.',
        );
      },
    );

    testWidgets(
      'computePerFrameWhileDragging=true updates primary during drag (even with huge debounce/interval)',
      (tester) async {
        final harness = ScrollSpyTestHarness(
          itemCount: 30,
          itemExtent: 100.0,
          viewportSize: const Size(400, 300),
          region: const ScrollSpyRegion.zone(
            anchor: ScrollSpyAnchor.fraction(0.5),
            extentPx: 100.0,
          ),
          policy: const ScrollSpyPolicy<int>.closestToAnchor(),
          updatePolicy: ScrollSpyUpdatePolicy.hybrid(
            scrollEndDebounce: const Duration(seconds: 5),
            ballisticInterval: const Duration(seconds: 5),
            computePerFrameWhileDragging: true,
          ),
          scrollController: null,
          debug: false,
        );

        await harness.pump(tester);

        expect(harness.controller.primaryId.value, 1);

        final listFinder = find.byKey(harness.listKey);
        expect(listFinder, findsOneWidget);

        final gesture = await tester.startGesture(tester.getCenter(listFinder));

        await gesture.moveBy(const Offset(0, -120));
        await tester.pump();

        expect(
          harness.controller.primaryId.value,
          2,
          reason:
              'Hybrid policy with computePerFrameWhileDragging=true should recompute during drag.',
        );

        await gesture.up();
        await tester.pump();
      },
    );
  });
}
