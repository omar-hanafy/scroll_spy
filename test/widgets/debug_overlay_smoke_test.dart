import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScrollSpyDebugOverlay', () {
    testWidgets(
      'debug overlay can build/paint when enabled (scope debug=true)',
      (tester) async {
        final harness = ScrollSpyTestHarness(
          itemCount: 20,
          itemExtent: 100.0,
          viewportSize: const Size(400, 300),
          region: const ScrollSpyRegion.zone(
            anchor: ScrollSpyAnchor.fraction(0.5),
            extentPx: 100.0,
          ),
          policy: const ScrollSpyPolicy<int>.closestToAnchor(),
          updatePolicy: const ScrollSpyUpdatePolicy.perFrame(),
          scrollController: null,
          debug: true,
          debugConfig: const ScrollSpyDebugConfig(
            enabled: true,
            includeItemRectsInFrame: true,
            showFocusRegion: true,
            showVisibleBounds: true,
            showLabels: false,
            showPrimaryOutline: true,
            showFocusedOutlines: true,
            showItemBounds: false,
            showViewportBounds: false,
          ),
        );

        await harness.pump(tester);

        expect(find.byType(ScrollSpyDebugOverlay<int>), findsOneWidget);

        // Trigger some movement to force repaint paths.
        await tester.drag(find.byKey(harness.listKey), const Offset(0, -50));
        await tester.pump();
      },
    );

    testWidgets('disabled config renders nothing', (tester) async {
      final frame = ValueNotifier<ScrollSpyDebugFrame<int>?>(
        ScrollSpyDebugFrame.empty<int>(),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 200,
            height: 200,
            child: ScrollSpyDebugOverlay<int>(
              debugFrameListenable: frame,
              config: ScrollSpyDebugConfig.disabled,
            ),
          ),
        ),
      );

      // When disabled, the overlay should not paint (no CustomPaint subtree).
      expect(find.byType(CustomPaint), findsNothing);

      frame.dispose();
    });
  });
}
