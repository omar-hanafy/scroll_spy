import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

/// Indicative compute-pass timings (debug VM; not CI-gated).
///
/// Prints mean/max wall time of a full engine pass (geometry validation,
/// region evaluation, selection, commit) at different mounted-item counts,
/// with no expensive listeners attached (the booleans-first steady state).
void main() {
  Future<void> run(
    WidgetTester tester, {
    required double itemExtent,
  }) async {
    final controller = ScrollSpyController<int>();
    final scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scrollController.dispose);
    final scopeKey = GlobalKey<ScrollSpyScopeState<int>>();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ScrollSpyScope<int>(
          key: scopeKey,
          controller: controller,
          region: const ScrollSpyRegion.zone(
            anchor: ScrollSpyAnchor.fraction(0.5),
            extentPx: 200,
          ),
          policy: const ScrollSpyPolicy.closestToAnchor(),
          scrollController: scrollController,
          child: ListView.builder(
            controller: scrollController,
            itemExtent: itemExtent,
            itemCount: 3000,
            itemBuilder: (context, i) => ScrollSpyItemLite<int>(
              id: i,
              child: const SizedBox.expand(),
              builder: (context, isPrimary, isFocused, child) => child!,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    scrollController.jumpTo(500);
    await tester.pump();
    await tester.pump();

    final engine = scopeKey.currentState!.engine;
    final int mounted = engine.debugRegisteredCount;

    // Warmup.
    for (var i = 0; i < 50; i++) {
      engine.debugComputeNow();
    }

    const iterations = 300;
    final stopwatch = Stopwatch();
    var maxUs = 0;
    var totalUs = 0;
    for (var i = 0; i < iterations; i++) {
      stopwatch
        ..reset()
        ..start();
      engine.debugComputeNow();
      stopwatch.stop();
      final us = stopwatch.elapsedMicroseconds;
      totalUs += us;
      if (us > maxUs) maxUs = us;
    }

    // ignore: avoid_print
    print('compute pass @ $mounted mounted items: '
        'mean ${(totalUs / iterations).toStringAsFixed(1)}us, max ${maxUs}us '
        '($iterations iterations, debug VM, indicative only)');

    expect(controller.primaryId.value, isNotNull);
  }

  testWidgets('compute pass timing, ~10 mounted', (tester) async {
    await run(tester, itemExtent: 110);
  });

  testWidgets('compute pass timing, ~50 mounted', (tester) async {
    await run(tester, itemExtent: 22);
  });

  testWidgets('compute pass timing, ~200 mounted', (tester) async {
    await run(tester, itemExtent: 5.5);
  });
}
