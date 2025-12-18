import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewport_focus/viewport_focus.dart';

import '../helpers/widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FocusEngine (ViewportUpdatePolicy.perFrame)', () {
    testWidgets('updates primary during an active drag (before finger up)', (
      tester,
    ) async {
      final harness = ViewportFocusTestHarness(
        itemCount: 30,
        itemExtent: 100.0,
        viewportSize: const Size(400, 300),
        region: const ViewportFocusRegion.zone(
          anchor: ViewportAnchor.fraction(0.5),
          extentPx: 100.0,
        ),
        policy: const ViewportFocusPolicy<int>.closestToAnchor(),
        updatePolicy: const ViewportUpdatePolicy.perFrame(),
        scrollController: null,
        debug: false,
      );

      await harness.pump(tester);

      expect(harness.controller.primaryId.value, 1);

      final listFinder = find.byKey(harness.listKey);
      expect(listFinder, findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(listFinder));

      // Drag up => scroll down enough to make item 2 the focused winner.
      await gesture.moveBy(const Offset(0, -120));
      await tester.pump();

      // Critical assertion: must change BEFORE finger is lifted.
      expect(
        harness.controller.primaryId.value,
        2,
        reason: 'perFrame policy must recompute primary during the drag.',
      );

      await gesture.up();
      await tester.pump();
    });
  });
}
