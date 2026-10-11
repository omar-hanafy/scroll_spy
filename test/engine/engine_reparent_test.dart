import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

void main() {
  testWidgets(
    'a preserved item refreshes a newly inserted ancestor transform',
    (tester) async {
      final controller = ScrollSpyController<int>();
      final scrollController = ScrollController();
      final shifted = ValueNotifier<bool>(false);
      addTearDown(controller.dispose);
      addTearDown(scrollController.dispose);
      addTearDown(shifted.dispose);
      final groupKey = GlobalKey();
      final itemKey = GlobalKey();
      final stableGroup = Semantics(
        key: groupKey,
        child: ScrollSpyItemLite<int>(
          key: itemKey,
          id: 0,
          builder: (context, primary, focused, child) =>
              const SizedBox(height: 100),
        ),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollSpyScope<int>(
            controller: controller,
            scrollController: scrollController,
            region: const ScrollSpyRegion.line(
              anchor: ScrollSpyAnchor.fraction(0.5),
            ),
            policy: const ScrollSpyPolicy.closestToAnchor(),
            debug: true,
            child: ValueListenableBuilder<bool>(
              valueListenable: shifted,
              builder: (context, move, child) => ListView.builder(
                controller: scrollController,
                itemExtent: 100,
                itemCount: 20,
                itemBuilder: (context, i) => i == 0
                    ? RepaintBoundary(
                        child: move
                            ? Transform.translate(
                                offset: const Offset(0, 50),
                                child: stableGroup,
                              )
                            : stableGroup,
                      )
                    : ScrollSpyItemLite<int>(
                        id: i,
                        builder: (context, primary, focused, child) =>
                            const SizedBox(height: 100),
                      ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final scope = tester.state<ScrollSpyScopeState<int>>(
        find.byType(ScrollSpyScope<int>),
      );
      scope.engine.debugComputeNow();
      expect(scope.engine.debugGeometry.fastHits, greaterThan(0));
      final originalBox =
          itemKey.currentContext!.findRenderObject() as RenderBox;

      shifted.value = true;
      await tester.pump();
      await tester.pump();
      scrollController.jumpTo(1);
      await tester.pump();
      await tester.pump();

      final box = itemKey.currentContext!.findRenderObject() as RenderBox;
      expect(identical(box, originalBox), isTrue);
      final viewport = RenderAbstractViewport.of(box) as RenderBox;
      final actual = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      expect(actual, 49);
      expect(
        controller.snapshot.value.items[0]!.itemRectInViewport!.top,
        closeTo(actual, 0.01),
      );
    },
  );

  test('a primary callback can dispose the engine during an empty commit', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final controller = ScrollSpyController<int>(
      initialSnapshot: ScrollSpySnapshot<int>(
        computedAt: DateTime.fromMillisecondsSinceEpoch(0),
        primaryId: 1,
        focusedIds: const {1},
        visibleIds: const {1},
        items: const {},
      ),
    );
    addTearDown(controller.dispose);
    final engine = ScrollSpyEngine<int>(
      controller: controller,
      region: const ScrollSpyRegion.line(anchor: ScrollSpyAnchor.fraction(0.5)),
      policy: const ScrollSpyPolicy.closestToAnchor(),
      stability: const ScrollSpyStability(),
      updatePolicy: const ScrollSpyUpdatePolicy.perFrame(),
      debugEnabled: true,
      includeItemRects: true,
    );
    addTearDown(engine.dispose);
    engine.attach();
    controller.primaryId.addListener(engine.dispose);

    expect(engine.debugComputeNow, returnsNormally);
  });

  test('a debug callback can dispose the engine during an empty frame', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final errors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previousOnError);
    final controller = ScrollSpyController<int>();
    addTearDown(controller.dispose);
    final engine = ScrollSpyEngine<int>(
      controller: controller,
      region: const ScrollSpyRegion.line(anchor: ScrollSpyAnchor.fraction(0.5)),
      policy: const ScrollSpyPolicy.closestToAnchor(),
      stability: const ScrollSpyStability(),
      updatePolicy: const ScrollSpyUpdatePolicy.perFrame(),
      debugEnabled: true,
      includeItemRects: true,
    );
    addTearDown(engine.dispose);
    engine.debugFrame.addListener(engine.dispose);
    engine.attach();

    engine.debugComputeNow();

    expect(errors, isEmpty);
    final passesAtDisposal = engine.debugComputePasses;
    engine.debugComputeNow();
    expect(engine.debugComputePasses, passesAtDisposal);
  });

  testWidgets('a debug callback can dispose the engine during an item frame', (
    tester,
  ) async {
    final controller = ScrollSpyController<int>();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ScrollSpyScope<int>(
          controller: controller,
          region: const ScrollSpyRegion.line(
            anchor: ScrollSpyAnchor.fraction(0.5),
          ),
          policy: const ScrollSpyPolicy.closestToAnchor(),
          debug: true,
          child: ListView(
            children: [
              ScrollSpyItemLite<int>(
                id: 1,
                builder: (context, primary, focused, child) =>
                    const SizedBox(height: 800),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final engine = tester
        .state<ScrollSpyScopeState<int>>(find.byType(ScrollSpyScope<int>))
        .engine;
    engine.debugComputeNow();
    expect(engine.debugFrame.value!.items, contains(1));
    engine.debugFrame.addListener(engine.dispose);

    engine.debugComputeNow();

    expect(tester.takeException(), isNull);
    final passesAtDisposal = engine.debugComputePasses;
    engine.debugComputeNow();
    expect(engine.debugComputePasses, passesAtDisposal);
  });
}
