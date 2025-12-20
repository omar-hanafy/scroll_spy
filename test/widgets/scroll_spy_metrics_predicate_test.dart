import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

void main() {
  group('ScrollSpyScope metricsNotificationPredicate', () {
    Future<int> currentSequence(WidgetTester tester, GlobalKey scopeKey) async {
      final state = scopeKey.currentState as ScrollSpyScopeState<int>;
      return state.engine.debugFrame.value?.sequence ?? 0;
    }

    Future<void> pumpUntilComputed(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    ScrollMetricsNotification metricsNotification(
      BuildContext context,
      WidgetTester tester,
    ) {
      return ScrollMetricsNotification(
        context: context,
        metrics: FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 100,
          pixels: 0,
          viewportDimension: 200,
          axisDirection: AxisDirection.down,
          devicePixelRatio: tester.view.devicePixelRatio,
        ),
      );
    }

    testWidgets(
        'filters ScrollMetricsNotification when metricsNotificationPredicate is false',
        (tester) async {
      final controller = ScrollSpyController<int>();
      final scopeKey = GlobalKey<ScrollSpyScopeState<int>>();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: 200,
            child: ScrollSpyScope<int>(
              key: scopeKey,
              controller: controller,
              region: const ScrollSpyRegion.line(
                anchor: ScrollSpyAnchor.pixels(0),
              ),
              policy: const ScrollSpyPolicy.closestToAnchor(),
              metricsNotificationPredicate: (_) => false,
              child: ListView(
                children: List.generate(
                  4,
                  (i) => ScrollSpyItem<int>(
                    id: i,
                    builder: (context, focus, child) =>
                        SizedBox(height: 50, child: child),
                    child: Text('item $i'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await pumpUntilComputed(tester);
      final int initialSequence = await currentSequence(tester, scopeKey);

      final BuildContext listContext = tester.element(find.byType(ListView));
      metricsNotification(listContext, tester).dispatch(listContext);

      await tester.pump();
      final int afterSequence = await currentSequence(tester, scopeKey);

      expect(afterSequence, initialSequence);
    });

    testWidgets(
        'allows ScrollMetricsNotification when metricsNotificationPredicate is true',
        (tester) async {
      final controller = ScrollSpyController<int>();
      final scopeKey = GlobalKey<ScrollSpyScopeState<int>>();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: 200,
            child: ScrollSpyScope<int>(
              key: scopeKey,
              controller: controller,
              region: const ScrollSpyRegion.line(
                anchor: ScrollSpyAnchor.pixels(0),
              ),
              policy: const ScrollSpyPolicy.closestToAnchor(),
              metricsNotificationPredicate: (_) => true,
              child: ListView(
                children: List.generate(
                  4,
                  (i) => ScrollSpyItem<int>(
                    id: i,
                    builder: (context, focus, child) =>
                        SizedBox(height: 50, child: child),
                    child: Text('item $i'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await pumpUntilComputed(tester);
      final int initialSequence = await currentSequence(tester, scopeKey);

      final BuildContext listContext = tester.element(find.byType(ListView));
      metricsNotification(listContext, tester).dispatch(listContext);

      await tester.pump();
      final int afterSequence = await currentSequence(tester, scopeKey);

      expect(afterSequence, greaterThan(initialSequence));
    });
  });
}
