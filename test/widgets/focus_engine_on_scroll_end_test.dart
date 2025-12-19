import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FocusEngine (ScrollSpyUpdatePolicy.onScrollEnd)', () {
    testWidgets(
      'does not update primary during drag; updates only after scroll end debounce',
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
          updatePolicy: ScrollSpyUpdatePolicy.onScrollEnd(
            debounce: const Duration(milliseconds: 200),
          ),
          // IMPORTANT: keep null so we isolate behavior to ScrollNotifications.
          scrollController: null,
          debug: false,
        );

        await harness.pump(tester);

        final int? initialPrimary = harness.controller.primaryId.value;
        expect(initialPrimary, 1, reason: 'Initial primary should be item 1.');

        final listFinder = find.byKey(harness.listKey);
        expect(listFinder, findsOneWidget);

        final gesture = await tester.startGesture(tester.getCenter(listFinder));

        // Drag up => scroll down.
        await gesture.moveBy(const Offset(0, -120));
        await tester.pump();

        // While still dragging, onScrollEnd must not recompute primary.
        expect(
          harness.controller.primaryId.value,
          initialPrimary,
          reason: 'Primary must not update mid-drag for onScrollEnd policy.',
        );

        // Wait while finger is still down to ensure velocity ~0 (no ballistic fling).
        await tester.pump(const Duration(milliseconds: 250));
        expect(harness.controller.primaryId.value, initialPrimary);

        await gesture.up();
        await tester
            .pump(); // deliver ScrollEndNotification + schedule debounce timer

        // Debounce not elapsed yet.
        await tester.pump(const Duration(milliseconds: 199));
        expect(
          harness.controller.primaryId.value,
          initialPrimary,
          reason: 'Primary must not update before debounce elapses.',
        );

        // Cross debounce boundary.
        await tester.pump(const Duration(milliseconds: 2));
        // Run the post-frame compute scheduled by the debouncer.
        await tester.pump();

        expect(
          harness.controller.primaryId.value,
          2,
          reason: 'After scroll end debounce, primary should update to item 2.',
        );
      },
    );
  });
}
