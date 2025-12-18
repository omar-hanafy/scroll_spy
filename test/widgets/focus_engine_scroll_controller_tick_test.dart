import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewport_focus/viewport_focus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FocusEngine - ScrollController tick path', () {
    testWidgets(
      'perFrame policy recomputes on programmatic jumpTo when notifications are filtered out',
      (tester) async {
        final controller = ViewportFocusController<int>();
        final scrollController = ScrollController();
        addTearDown(controller.dispose);
        addTearDown(scrollController.dispose);

        Widget buildHost() {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(400, 300)),
              child: Center(
                child: SizedBox(
                  width: 400,
                  height: 300,
                  child: ViewportFocusScope<int>(
                    controller: controller,
                    region: const ViewportFocusRegion.zone(
                      anchor: ViewportAnchor.fraction(0.5),
                      extentPx: 100,
                    ),
                    policy: const ViewportFocusPolicy<int>.closestToAnchor(),
                    updatePolicy: const ViewportUpdatePolicy.perFrame(),
                    scrollController: scrollController,
                    // Ignore notifications so only ScrollController listener path is exercised.
                    notificationDepth: 1,
                    child: ListView.builder(
                      controller: scrollController,
                      itemExtent: 100,
                      itemCount: 30,
                      cacheExtent: 5000,
                      itemBuilder: (context, index) {
                        return ViewportFocusItem<int>(
                          id: index,
                          child: const SizedBox.expand(),
                          builder: (context, focus, child) => child!,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildHost());
        await tester.pump(); // registrations
        await tester.pump(); // engine compute

        await _pumpUntil(
          tester,
          () => controller.snapshot.value.items.length == 30,
          reason:
              'Expected all items to be registered before programmatic scroll.',
        );

        expect(controller.primaryId.value, 1);

        scrollController.jumpTo(120);
        await tester.pump();
        await tester.pump();

        expect(
          controller.primaryId.value,
          2,
          reason:
              'Programmatic scroll should recompute via ScrollController listener even when notifications are filtered.',
        );
      },
    );

    testWidgets(
      'onScrollEnd policy recomputes after debounce on programmatic jumpTo when notifications are filtered out',
      (tester) async {
        final controller = ViewportFocusController<int>();
        final scrollController = ScrollController();
        addTearDown(controller.dispose);
        addTearDown(scrollController.dispose);

        const debounce = Duration(milliseconds: 200);

        Widget buildHost() {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(400, 300)),
              child: Center(
                child: SizedBox(
                  width: 400,
                  height: 300,
                  child: ViewportFocusScope<int>(
                    controller: controller,
                    region: const ViewportFocusRegion.zone(
                      anchor: ViewportAnchor.fraction(0.5),
                      extentPx: 100,
                    ),
                    policy: const ViewportFocusPolicy<int>.closestToAnchor(),
                    updatePolicy: ViewportUpdatePolicy.onScrollEnd(
                      debounce: debounce,
                    ),
                    scrollController: scrollController,
                    notificationDepth: 1,
                    child: ListView.builder(
                      controller: scrollController,
                      itemExtent: 100,
                      itemCount: 30,
                      cacheExtent: 5000,
                      itemBuilder: (context, index) {
                        return ViewportFocusItem<int>(
                          id: index,
                          child: const SizedBox.expand(),
                          builder: (context, focus, child) => child!,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildHost());
        await tester.pump();
        await tester.pump();

        await _pumpUntil(
          tester,
          () => controller.snapshot.value.items.length == 30,
          reason:
              'Expected all items to be registered before programmatic scroll.',
        );

        final initialPrimary = controller.primaryId.value;
        expect(initialPrimary, 1);

        scrollController.jumpTo(120);
        await tester.pump();

        // Still within debounce => no update yet.
        await tester.pump(const Duration(milliseconds: 199));
        expect(controller.primaryId.value, initialPrimary);

        // Cross debounce boundary; then run post-frame compute.
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pump();

        expect(controller.primaryId.value, 2);
      },
    );
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  required String reason,
  int maxPumps = 60,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (predicate()) return;
    await tester.pump();
  }
  expect(predicate(), isTrue, reason: reason);
}
