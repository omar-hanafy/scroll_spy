import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScrollSpyItem lifecycle', () {
    testWidgets(
      'shrinking list unregisters removed items and snapshot.items reduces to new count',
      (tester) async {
        final controller = ScrollSpyController<int>();
        final itemCount = ValueNotifier<int>(20);

        Widget buildHost() {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 400,
              height: 300,
              child: ScrollSpyScope<int>(
                controller: controller,
                region: const ScrollSpyRegion.zone(
                  anchor: ScrollSpyAnchor.fraction(0.5),
                  extentPx: 100.0,
                ),
                policy: const ScrollSpyPolicy<int>.closestToAnchor(),
                updatePolicy: const ScrollSpyUpdatePolicy.perFrame(),
                child: ValueListenableBuilder<int>(
                  valueListenable: itemCount,
                  builder: (context, count, _) {
                    return ListView.builder(
                      key: const ValueKey('list'),
                      itemCount: count,
                      itemExtent: 100.0,
                      // Make sure many (ideally all) children are built/registered,
                      // so shrinking actually removes registered items.
                      cacheExtent: 5000.0,
                      itemBuilder: (context, index) {
                        return ScrollSpyItem<int>(
                          id: index,
                          child: const SizedBox.expand(),
                          builder: (context, focus, child) =>
                              SizedBox(height: 100.0, child: child),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildHost());
        // Allow registrations + compute.
        await tester.pump();
        await tester.pump();

        // With huge cacheExtent, we expect all 20 to be registered eventually.
        await _pumpUntil(
          tester,
          () => controller.snapshot.value.items.length == 20,
          reason:
              'Expected initial snapshot.items to include all 20 registered items.',
        );

        // Shrink the list: items 5..19 should dispose + unregister cleanly.
        itemCount.value = 5;
        await tester.pump();
        await tester.pump();
        await tester.pump();

        await _pumpUntil(
          tester,
          () => controller.snapshot.value.items.length == 5,
          reason:
              'After shrinking to 5 items, snapshot.items should reduce to exactly 5.',
        );

        itemCount.dispose();
        controller.dispose();
      },
    );
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  required String reason,
  int maxPumps = 40,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (predicate()) return;
    await tester.pump();
  }
  expect(predicate(), isTrue, reason: reason);
}
