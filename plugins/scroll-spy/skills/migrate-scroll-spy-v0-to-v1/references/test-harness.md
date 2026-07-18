# Deterministic widget-test harness for scroll_spy

Two facts make naive scroll_spy tests fail, and both are by design:

1. `ScrollSpyItem` registers itself in a **post-frame callback**, and the
   engine computes and commits in a **post-frame callback** of its own. After
   `pumpWidget`, pump **two more frames** before any focus state exists.
   Asserting after a single pump reads `primaryId == null` and empty sets.
2. Per-item listenables (`itemFocusOf`, `itemIsVisibleOf`, ...) notify on
   **changes** after the first commit; there is no initial callback for
   attaching a listener. Read `.value` for current state; listeners are for
   transitions.

Update-policy timing in tests:

- `perFrame` (default): one `pump()` after a scroll delivers the new state.
- `onScrollEnd(debounce: d)`: nothing updates mid-drag (that is the policy's
  contract, not a bug). After the gesture ends, `pump()` once to deliver the
  end notification, then `pump(d + margin)` to fire the debounce timer, then
  one more `pump()` for the compute frame.
- `hybrid(...)`: per-frame while dragging (if enabled); after a fling, pump
  past `ballisticInterval` steps; always ends with a settle pass after
  `scrollEndDebounce`.
- `tester.pumpAndSettle()` also works for the settle-based policies as long
  as timers are the only pending work.

Copy-paste harness (int ids `0..itemCount-1`, fixed `itemExtent`, enforced
viewport size, scroll controller wired to **both** the list and the scope so
programmatic `jumpTo` is observed):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

class SpyHarness {
  SpyHarness({
    this.itemCount = 20,
    this.itemExtent = 100.0,
    this.viewportSize = const Size(400, 300),
    ScrollSpyRegion? region,
    this.policy = const ScrollSpyPolicy<int>.closestToAnchor(),
    this.stability = const ScrollSpyStability(),
    this.updatePolicy = const ScrollSpyUpdatePolicy.perFrame(),
  }) : region = region ??
            ScrollSpyRegion.zone(
              anchor: const ScrollSpyAnchor.fraction(0.5),
              extentPx: itemExtent,
            );

  final controller = ScrollSpyController<int>();
  final scroll = ScrollController();
  final int itemCount;
  final double itemExtent;
  final Size viewportSize;
  final ScrollSpyRegion region;
  final ScrollSpyPolicy<int> policy;
  final ScrollSpyStability stability;
  final ScrollSpyUpdatePolicy updatePolicy;
  final listKey = const Key('spy_list');

  Widget build() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(size: viewportSize),
        child: Center(
          child: SizedBox(
            width: viewportSize.width,
            height: viewportSize.height,
            child: ScrollSpyScope<int>(
              controller: controller,
              region: region,
              policy: policy,
              stability: stability,
              updatePolicy: updatePolicy,
              scrollController: scroll,
              child: ListView.builder(
                key: listKey,
                controller: scroll,
                itemExtent: itemExtent,
                itemCount: itemCount,
                itemBuilder: (context, index) => ScrollSpyItem<int>(
                  id: index,
                  child: const SizedBox.expand(),
                  builder: (context, focus, child) => child!,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// pumpWidget + the two extra frames (registration, then compute+commit).
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pump();
  }

  void dispose() {
    controller.dispose();
    scroll.dispose();
  }
}
```

Usage patterns (each verified against scroll_spy 1.0.x):

```dart
testWidgets('initial primary is the anchor item', (tester) async {
  final h = SpyHarness();
  await h.pump(tester);
  // 300px viewport, anchor 0.5 => 150px; 100px items => item 1 spans 100..200.
  expect(h.controller.primaryId.value, 1);
  h.dispose();
});

testWidgets('primary follows a programmatic jump', (tester) async {
  final h = SpyHarness();
  await h.pump(tester);
  h.scroll.jumpTo(500); // item 6 now spans viewport 100..200, on the anchor
  // TWO pumps: the jump reveals items that were never built; they register
  // in the post-frame of pump 1, and the engine includes them in pump 2's
  // pass. After one pump the primary is still chosen from the old items.
  await tester.pump();
  await tester.pump();
  expect(h.controller.primaryId.value, 6);
  h.dispose();
});

testWidgets('onScrollEnd settles after the debounce', (tester) async {
  final h = SpyHarness(
    updatePolicy: ScrollSpyUpdatePolicy.onScrollEnd(
      debounce: const Duration(milliseconds: 200),
    ),
  );
  await h.pump(tester);
  await tester.drag(find.byKey(h.listKey), const Offset(0, -300));
  await tester.pump();                                  // end notification
  await tester.pump(const Duration(milliseconds: 250)); // debounce fires
  await tester.pump();                                  // compute frame
  // Offset 300; anchor at content 450; item 4 spans 400..500.
  expect(h.controller.primaryId.value, 4);
  h.dispose();
});
```

Staleness caveat: only assert "primary did not move yet" while the finger is
still down (`tester.startGesture` + `moveBy`, before `up()`). After a
completed gesture, other signals (for example a trailing metrics
notification) may legally trigger an early compute, so asserting staleness
after `tester.drag` is flaky by design. Assert the settled value after
pumping past the debounce instead.

Determinism rules: fix the viewport with `SizedBox` + `MediaQuery`, use fixed
`itemExtent`, avoid `pumpAndSettle` with `perFrame` plus infinite animations,
give every assertion a geometry comment (viewport, anchor position, item
span), and after any scroll that reveals newly built items allow one extra
`pump()` for their post-frame registration.
