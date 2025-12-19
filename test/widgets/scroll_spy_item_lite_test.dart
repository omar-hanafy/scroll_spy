import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/focus_fixtures.dart';

void main() {
  group('ScrollSpyItemLite', () {
    testWidgets('rebuilds ONLY on status toggles, ignores metric drift',
        (tester) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      int buildCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollSpyScope<int>(
            controller: controller,
            region: const ScrollSpyRegion.line(
              anchor: ScrollSpyAnchor.fraction(0.5),
            ),
            policy: const ScrollSpyPolicy.closestToAnchor(),
            child: ListView(
              children: [
                ScrollSpyItemLite<int>(
                  id: 1,
                  child: const SizedBox(height: 100),
                  builder: (context, isPrimary, isFocused, child) {
                    buildCount++;
                    return child!;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      // Let registration + engine compute settle before assertions.
      await tester.pump();
      await tester.pump();
      buildCount = 0;

      // Frame 1: Item becomes Primary + Focused
      controller.commitFrame(makeSnapshot(
        primaryId: 1,
        focusedIds: {1},
        items: {
          1: makeFocusItem(
            id: 1,
            isPrimary: true,
            isFocused: true,
            distanceToAnchorPx: 0,
          )
        },
      ));
      await tester.pump();
      expect(buildCount, 1, reason: 'Status changed to Primary/Focused');

      // Frame 2: Metric Drift (distance changes, but still primary/focused)
      controller.commitFrame(makeSnapshot(
        primaryId: 1,
        focusedIds: {1},
        items: {
          1: makeFocusItem(
            id: 1,
            isPrimary: true,
            isFocused: true,
            distanceToAnchorPx: 5.0, // Changed from 0
            visibleFraction: 0.9,
          )
        },
      ));
      await tester.pump();
      expect(
        buildCount,
        1,
        reason:
            'Should NOT rebuild on metric drift if boolean status is stable',
      );

      // Frame 2b: Visibility changes only (primary/focused unchanged)
      controller.commitFrame(makeSnapshot(
        primaryId: 1,
        focusedIds: {1},
        visibleIds: const {},
        items: {
          1: makeFocusItem(
            id: 1,
            isPrimary: true,
            isFocused: true,
            isVisible: false,
          )
        },
      ));
      await tester.pump();
      expect(
        buildCount,
        1,
        reason: 'Should NOT rebuild on visibility-only changes',
      );

      // Frame 3: Toggle Primary Off (still Focused)
      controller.commitFrame(makeSnapshot(
        primaryId: 2, // 1 lost primary
        focusedIds: {1, 2},
        items: {
          1: makeFocusItem(
            id: 1,
            isPrimary: false,
            isFocused: true,
            distanceToAnchorPx: 10.0,
          ),
          2: makeFocusItem(id: 2, isPrimary: true),
        },
      ));
      await tester.pump();
      expect(buildCount, 2, reason: 'Status changed (Primary false)');

      // Frame 4: Toggle Focused Off
      controller.commitFrame(makeSnapshot(
        primaryId: 2,
        focusedIds: {2}, // 1 lost focus
        items: {
          1: makeFocusItem(id: 1, isPrimary: false, isFocused: false),
        },
      ));
      await tester.pump();
      expect(buildCount, 3, reason: 'Status changed (Focused false)');
    });
  });
}
