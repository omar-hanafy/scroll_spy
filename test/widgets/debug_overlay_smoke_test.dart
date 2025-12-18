import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewport_focus/viewport_focus.dart';

import '../helpers/widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ViewportFocusDebugOverlay', () {
    testWidgets(
      'debug overlay can build/paint when enabled (scope debug=true)',
      (tester) async {
        final harness = ViewportFocusTestHarness(
          itemCount: 20,
          itemExtent: 100.0,
          viewportSize: const Size(400, 300),
          region: const ViewportFocusRegion.zone(
            anchor: ViewportAnchor.fraction(0.5),
            extentPx: 100.0,
          ),
          policy: const ViewportFocusPolicy<int>.closestToAnchor(),
          updatePolicy: const ViewportUpdatePolicy.perFrame(),
          scrollController: null,
          debug: true,
          debugConfig: const ViewportFocusDebugConfig(
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

        expect(find.byType(ViewportFocusDebugOverlay<int>), findsOneWidget);

        // Trigger some movement to force repaint paths.
        await tester.drag(find.byKey(harness.listKey), const Offset(0, -50));
        await tester.pump();
      },
    );

    testWidgets('disabled config renders nothing', (tester) async {
      final frame = ValueNotifier<FocusDebugFrame<int>?>(
        FocusDebugFrame.empty<int>(),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 200,
            height: 200,
            child: ViewportFocusDebugOverlay<int>(
              debugFrameListenable: frame,
              config: ViewportFocusDebugConfig.disabled,
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
