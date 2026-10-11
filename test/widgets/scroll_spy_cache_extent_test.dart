import 'package:flutter/rendering.dart' as rendering show ScrollCacheExtent;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

void main() {
  for (final kind in <String>['list', 'separated', 'grid', 'custom']) {
    testWidgets('$kind supports pixels, viewport multiples, and legacy cache', (
      tester,
    ) async {
      final focus = ScrollSpyController<int>();
      addTearDown(focus.dispose);
      for (final testCase
          in <
            ({
              double? legacy,
              rendering.ScrollCacheExtent? extent,
              rendering.ScrollCacheExtent? expected,
            })
          >[
            (legacy: null, extent: null, expected: null),
            (
              legacy: 500,
              extent: null,
              expected: const rendering.ScrollCacheExtent.pixels(500),
            ),
            (
              legacy: null,
              extent: const rendering.ScrollCacheExtent.pixels(300),
              expected: const rendering.ScrollCacheExtent.pixels(300),
            ),
            (
              legacy: null,
              extent: const rendering.ScrollCacheExtent.viewport(2),
              expected: const rendering.ScrollCacheExtent.viewport(2),
            ),
            (
              legacy: 500,
              extent: const rendering.ScrollCacheExtent.viewport(2),
              expected: const rendering.ScrollCacheExtent.viewport(2),
            ),
          ]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 400,
                height: 300,
                child: _wrapper(kind, focus, testCase.legacy, testCase.extent),
              ),
            ),
          ),
        );
        await tester.pump();
        final viewport = tester.widget<Viewport>(find.byType(Viewport));
        expect(viewport.scrollCacheExtent, testCase.expected);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Widget _wrapper(
  String kind,
  ScrollSpyController<int> focus,
  double? legacy,
  rendering.ScrollCacheExtent? extent,
) {
  const region = ScrollSpyRegion.line(anchor: ScrollSpyAnchor.fraction(0.5));
  const policy = ScrollSpyPolicy<int>.closestToAnchor();
  Widget itemBuilder(BuildContext context, int index) =>
      SizedBox(height: 100, child: Text('$index'));
  switch (kind) {
    case 'list':
      return ScrollSpyListView<int>.builder(
        controller: focus,
        region: region,
        policy: policy,
        cacheExtent: legacy,
        scrollCacheExtent: extent,
        itemCount: 20,
        itemExtent: 100,
        itemBuilder: itemBuilder,
      );
    case 'separated':
      return ScrollSpyListView<int>.separated(
        controller: focus,
        region: region,
        policy: policy,
        cacheExtent: legacy,
        scrollCacheExtent: extent,
        itemCount: 20,
        itemBuilder: itemBuilder,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
      );
    case 'grid':
      return ScrollSpyGridView<int>.builder(
        controller: focus,
        region: region,
        policy: policy,
        cacheExtent: legacy,
        scrollCacheExtent: extent,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          mainAxisExtent: 100,
        ),
        itemCount: 20,
        itemBuilder: itemBuilder,
      );
    default:
      return ScrollSpyCustomScrollView<int>(
        controller: focus,
        region: region,
        policy: policy,
        cacheExtent: legacy,
        scrollCacheExtent: extent,
        slivers: <Widget>[
          SliverFixedExtentList(
            itemExtent: 100,
            delegate: SliverChildBuilderDelegate(itemBuilder, childCount: 20),
          ),
        ],
      );
  }
}
