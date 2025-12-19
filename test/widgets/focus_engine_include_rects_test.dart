import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FocusEngine - includeItemRects', () {
    testWidgets('debug=false => snapshot items have no rects', (tester) async {
      final harness = ScrollSpyTestHarness(
        itemCount: 20,
        itemExtent: 100,
        viewportSize: const Size(400, 300),
        debug: false,
      );
      addTearDown(harness.controller.dispose);

      await harness.pump(tester);

      final items = harness.controller.snapshot.value.items.values.toList();
      expect(items, isNotEmpty);

      final any = items.first;
      expect(any.itemRectInViewport, isNull);
      expect(any.visibleRectInViewport, isNull);
    });

    testWidgets(
      'debug=true + includeItemRectsInFrame=true => rects are present',
      (tester) async {
        final harness = ScrollSpyTestHarness(
          itemCount: 20,
          itemExtent: 100,
          viewportSize: const Size(400, 300),
          debug: true,
          debugConfig: const ScrollSpyDebugConfig(
            enabled: true,
            includeItemRectsInFrame: true,
            showLabels: false,
          ),
        );
        addTearDown(harness.controller.dispose);

        await harness.pump(tester);

        final visible = harness.controller.snapshot.value.items.values
            .firstWhere((e) => e.isVisible);

        expect(visible.itemRectInViewport, isNotNull);
        expect(visible.visibleRectInViewport, isNotNull);
      },
    );

    testWidgets(
      'debug=true + includeItemRectsInFrame=false => rects are omitted',
      (tester) async {
        final harness = ScrollSpyTestHarness(
          itemCount: 20,
          itemExtent: 100,
          viewportSize: const Size(400, 300),
          debug: true,
          debugConfig: const ScrollSpyDebugConfig(
            enabled: true,
            includeItemRectsInFrame: false,
            showLabels: false,
          ),
        );
        addTearDown(harness.controller.dispose);

        await harness.pump(tester);

        final items = harness.controller.snapshot.value.items.values.toList();
        expect(items, isNotEmpty);

        final any = items.first;
        expect(any.itemRectInViewport, isNull);
        expect(any.visibleRectInViewport, isNull);
      },
    );
  });
}
