import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

void main() {
  group('ScrollSpyListView.separated', () {
    testWidgets('maps findItemIndexCallback to child indices', (tester) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      int? findItemIndexCallback(Key key) {
        if (key is ValueKey<int>) {
          return key.value;
        }
        return null;
      }

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollSpyListView<int>.separated(
            controller: controller,
            region: const ScrollSpyRegion.line(
              anchor: ScrollSpyAnchor.fraction(0.5),
            ),
            policy: const ScrollSpyPolicy.closestToAnchor(),
            itemCount: 3,
            itemBuilder: (context, index) {
              return SizedBox(
                key: ValueKey<int>(index),
                height: 40,
              );
            },
            separatorBuilder: (context, index) {
              return const SizedBox(height: 8);
            },
            findItemIndexCallback: findItemIndexCallback,
          ),
        ),
      );

      await tester.pump();

      final listView = tester.widget<ListView>(find.byType(ListView));
      final delegate = listView.childrenDelegate as SliverChildBuilderDelegate;
      final callback = delegate.findChildIndexCallback;

      expect(callback, isNotNull);
      expect(callback!(const ValueKey<int>(0)), 0);
      expect(callback(const ValueKey<int>(1)), 2);
      expect(callback(const ValueKey<int>(2)), 4);
    });
  });
}
