import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

void main() {
  group('viewportInsets', () {
    Future<List<ScrollSpyRegistryEntry<int>>> entriesForKeys(
      WidgetTester tester,
      List<Key> keys,
    ) async {
      final entries = <ScrollSpyRegistryEntry<int>>[];
      for (var i = 0; i < keys.length; i++) {
        final finder = find.byKey(keys[i]);
        if (finder.evaluate().isEmpty) continue; // Skip unmounted items
        final element = tester.element(finder);
        final box = tester.renderObject(finder) as RenderBox;
        entries.add(
          ScrollSpyRegistryEntry<int>(
            id: i,
            context: element,
            box: box,
            registrationOrder: i,
          ),
        );
      }
      return entries;
    }

    testWidgets(
        'geometry: top inset shifts effective viewport, visibility and anchor (line)',
        (tester) async {
      const viewportSize = Size(300, 200);
      const itemExtent = 50.0;
      const insetTop = 100.0;

      final keys = List<Key>.generate(6, (i) => ValueKey('item$i'));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: viewportSize.width,
              height: viewportSize.height,
              child: ListView(
                children: List.generate(
                  keys.length,
                  (i) => SizedBox(key: keys[i], height: itemExtent),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final entries = await entriesForKeys(tester, keys);

      final geom = ScrollSpyGeometry.compute<int>(
        entries: entries,
        region: const ScrollSpyRegion.line(anchor: ScrollSpyAnchor.pixels(0)),
        axis: Axis.vertical,
        includeItemRects: true,
        viewportInsets: const EdgeInsets.only(top: insetTop),
        insetsAffectVisibility: true,
      );

      expect(geom.viewportRect.top, insetTop);
      expect(geom.viewportRect.bottom, viewportSize.height);

      final double anchorPos = geom.viewportRect.top;

      for (final item in geom.items) {
        final Rect itemRect = item.itemRectInViewport!;
        final Rect expectedVisible = itemRect.intersect(geom.viewportRect);
        final bool expectedIsVisible = !expectedVisible.isEmpty;

        expect(item.isVisible, expectedIsVisible);

        final bool expectedIsFocused = expectedIsVisible &&
            itemRect.top <= anchorPos &&
            itemRect.bottom >= anchorPos;

        expect(item.isFocused, expectedIsFocused);

        if (expectedVisible.isEmpty) {
          expect(item.visibleRectInViewport, isNull);
          expect(item.visibleFraction, 0);
        } else {
          expect(item.visibleRectInViewport, isNotNull);
          expect(item.visibleFraction, greaterThan(0));
        }
      }
    });

    testWidgets('geometry: top inset behaves for zone region too',
        (tester) async {
      const viewportSize = Size(300, 200);
      const itemExtent = 50.0;
      const insetTop = 100.0;
      const zoneExtent = 20.0;

      final keys = List<Key>.generate(6, (i) => ValueKey('item$i'));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: viewportSize.width,
              height: viewportSize.height,
              child: ListView(
                children: List.generate(
                  keys.length,
                  (i) => SizedBox(key: keys[i], height: itemExtent),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final entries = await entriesForKeys(tester, keys);

      final geom = ScrollSpyGeometry.compute<int>(
        entries: entries,
        region: const ScrollSpyRegion.zone(
          anchor: ScrollSpyAnchor.pixels(0),
          extentPx: zoneExtent,
        ),
        axis: Axis.vertical,
        includeItemRects: true,
        viewportInsets: const EdgeInsets.only(top: insetTop),
        insetsAffectVisibility: true,
      );

      final double anchorPos = geom.viewportRect.top;
      final double half = zoneExtent / 2.0;
      final double zoneStart = anchorPos - half;
      final double zoneEnd = anchorPos + half;

      double overlap(double aStart, double aEnd, double bStart, double bEnd) {
        final lo = aStart > bStart ? aStart : bStart;
        final hi = aEnd < bEnd ? aEnd : bEnd;
        final v = hi - lo;
        return v > 0 ? v : 0;
      }

      for (final item in geom.items) {
        final Rect itemRect = item.itemRectInViewport!;
        final Rect expectedVisible = itemRect.intersect(geom.viewportRect);
        final bool expectedIsVisible = !expectedVisible.isEmpty;

        final bool expectedIsFocused = expectedIsVisible &&
            overlap(itemRect.top, itemRect.bottom, zoneStart, zoneEnd) > 0;

        expect(item.isFocused, expectedIsFocused);
      }
    });

    testWidgets(
        'geometry: insetsAffectVisibility=false keeps full visibility but shifts anchor',
        (tester) async {
      const viewportSize = Size(300, 200);
      const itemExtent = 50.0;
      const insetTop = 100.0;

      final keys = List<Key>.generate(6, (i) => ValueKey('item$i'));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: viewportSize.width,
              height: viewportSize.height,
              child: ListView(
                children: List.generate(
                  keys.length,
                  (i) => SizedBox(key: keys[i], height: itemExtent),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final entries = await entriesForKeys(tester, keys);

      final geom = ScrollSpyGeometry.compute<int>(
        entries: entries,
        region: const ScrollSpyRegion.line(anchor: ScrollSpyAnchor.pixels(0)),
        axis: Axis.vertical,
        includeItemRects: true,
        viewportInsets: const EdgeInsets.only(top: insetTop),
        insetsAffectVisibility: false,
      );

      // Anchor is still shifted into the effective viewport.
      expect(geom.viewportRect.top, insetTop);

      for (final item in geom.items) {
        final Rect itemRect = item.itemRectInViewport!;
        // Visibility is checked against full viewport
        final Rect expectedVisible = itemRect.intersect(geom.fullViewportRect);
        expect(item.isVisible, !expectedVisible.isEmpty);
      }
    });

    testWidgets('geometry: horizontal axis respects left inset',
        (tester) async {
      const viewportSize = Size(200, 120);
      const itemExtent = 50.0;
      const insetLeft = 80.0;

      final keys = List<Key>.generate(6, (i) => ValueKey('item$i'));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: viewportSize.width,
              height: viewportSize.height,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: List.generate(
                  keys.length,
                  (i) => SizedBox(key: keys[i], width: itemExtent),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final entries = await entriesForKeys(tester, keys);

      final geom = ScrollSpyGeometry.compute<int>(
        entries: entries,
        region: const ScrollSpyRegion.line(anchor: ScrollSpyAnchor.pixels(0)),
        axis: Axis.horizontal,
        includeItemRects: true,
        viewportInsets: const EdgeInsets.only(left: insetLeft),
        insetsAffectVisibility: true,
      );

      expect(geom.viewportRect.left, insetLeft);

      final double anchorPos = geom.viewportRect.left;

      for (final item in geom.items) {
        final Rect itemRect = item.itemRectInViewport!;
        final Rect expectedVisible = itemRect.intersect(geom.viewportRect);
        final bool expectedIsVisible = !expectedVisible.isEmpty;
        expect(item.isVisible, expectedIsVisible);

        final bool expectedIsFocused = expectedIsVisible &&
            itemRect.left <= anchorPos &&
            itemRect.right >= anchorPos;
        expect(item.isFocused, expectedIsFocused);
      }
    });

    testWidgets(
        'geometry: reverse scroll direction still applies insets in viewport coordinates',
        (tester) async {
      const viewportSize = Size(300, 200);
      const itemExtent = 50.0;
      const insetTop = 100.0;

      final keys = List<Key>.generate(6, (i) => ValueKey('item$i'));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: viewportSize.width,
              height: viewportSize.height,
              child: ListView(
                reverse: true,
                children: List.generate(
                  keys.length,
                  (i) => SizedBox(key: keys[i], height: itemExtent),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final entries = await entriesForKeys(tester, keys);

      final geom = ScrollSpyGeometry.compute<int>(
        entries: entries,
        region: const ScrollSpyRegion.line(anchor: ScrollSpyAnchor.pixels(0)),
        axis: Axis.vertical,
        includeItemRects: true,
        viewportInsets: const EdgeInsets.only(top: insetTop),
        insetsAffectVisibility: true,
      );

      expect(geom.viewportRect.top, insetTop);
    });

    testWidgets(
        'geometry: mixed viewports are skipped (nested scrollables guard)',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: ListView(
                  children: const [
                    SizedBox(key: ValueKey('a0'), height: 50),
                  ],
                ),
              ),
              SizedBox(
                width: 200,
                height: 200,
                child: ListView(
                  children: const [
                    SizedBox(key: ValueKey('b0'), height: 50),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      final aFinder = find.byKey(const ValueKey('a0'));
      final bFinder = find.byKey(const ValueKey('b0'));

      final aEntry = ScrollSpyRegistryEntry<int>(
        id: 0,
        context: tester.element(aFinder),
        box: tester.renderObject(aFinder) as RenderBox,
        registrationOrder: 0,
      );

      final bEntry = ScrollSpyRegistryEntry<int>(
        id: 1,
        context: tester.element(bFinder),
        box: tester.renderObject(bFinder) as RenderBox,
        registrationOrder: 1,
      );

      // Should not throw: bEntry will be skipped because it doesn't belong to aEntry's viewport.
      final geom = ScrollSpyGeometry.compute<int>(
        entries: [aEntry, bEntry],
        region: const ScrollSpyRegion.line(anchor: ScrollSpyAnchor.pixels(0)),
        axis: Axis.vertical,
        includeItemRects: true,
        viewportInsets: EdgeInsets.zero,
        insetsAffectVisibility: true,
      );

      expect(geom.items.length, 1);
      expect(geom.items.single.id, 0);
    });

    testWidgets('engine: updates when viewportInsets changes', (tester) async {
      final controller = ScrollSpyController<int>();

      Widget buildWithInsets(EdgeInsets insets) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: ScrollSpyScope<int>(
                controller: controller,
                viewportInsets: insets,
                region: const ScrollSpyRegion.line(
                    anchor: ScrollSpyAnchor.pixels(0)),
                policy: const ScrollSpyPolicy.closestToAnchor(),
                child: ListView(
                  children: List.generate(
                    6,
                    (i) => ScrollSpyItem<int>(
                      id: i,
                      builder: (context, focus, child) {
                        return SizedBox(height: 50, child: child);
                      },
                      child: Text('item $i'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWithInsets(EdgeInsets.zero));
      await tester.pump(); // register items
      await tester.pump(); // compute

      expect(controller.primaryId.value, 0);

      await tester.pumpWidget(buildWithInsets(const EdgeInsets.only(top: 100)));
      await tester.pump();
      await tester.pump();

      // With 100px inset:
      // Effective viewport 100..200 (height 100).
      // Anchor 0 -> 100px.
      // Item 0: 0..50 (hidden under inset)
      // Item 1: 50..100 (hidden under inset)
      // Item 2: 100..150 (visible, starts at anchor) -> Primary
      expect(controller.primaryId.value, 2);
    });
  });
}
