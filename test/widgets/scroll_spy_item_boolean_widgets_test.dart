import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/focus_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScrollSpyItem boolean builders', () {
    testWidgets('primary builder rebuilds only on toggle', (tester) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      final values = <bool>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollSpyItemPrimaryBuilder<int>(
            controller: controller,
            id: 1,
            builder: (context, isPrimary, _) {
              values.add(isPrimary);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(values, <bool>[false]);

      controller.commitFrame(
        makeSnapshot(
          primaryId: 1,
          items: {
            1: makeFocusItem(id: 1, isPrimary: true),
          },
        ),
      );
      await tester.pump();

      expect(values, <bool>[false, true]);

      controller.commitFrame(
        makeSnapshot(
          primaryId: 1,
          items: {
            1: makeFocusItem(id: 1, isPrimary: true, distanceToAnchorPx: 50),
          },
        ),
      );
      await tester.pump();

      expect(values, <bool>[false, true]);

      controller.commitFrame(
        makeSnapshot(
          primaryId: null,
          items: {
            1: makeFocusItem(id: 1, isPrimary: false),
          },
        ),
      );
      await tester.pump();

      expect(values, <bool>[false, true, false]);
    });

    testWidgets('focused builder rebuilds only on toggle', (tester) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      final values = <bool>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollSpyItemFocusedBuilder<int>(
            controller: controller,
            id: 7,
            builder: (context, isFocused, _) {
              values.add(isFocused);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(values, <bool>[false]);

      controller.commitFrame(
        makeSnapshot(
          focusedIds: {7},
          items: {
            7: makeFocusItem(id: 7, isFocused: true),
          },
        ),
      );
      await tester.pump();

      expect(values, <bool>[false, true]);

      controller.commitFrame(
        makeSnapshot(
          focusedIds: {7},
          items: {
            7: makeFocusItem(
              id: 7,
              isFocused: true,
              distanceToAnchorPx: 99,
            ),
          },
        ),
      );
      await tester.pump();

      expect(values, <bool>[false, true]);

      controller.commitFrame(
        makeSnapshot(
          focusedIds: const {},
          items: {
            7: makeFocusItem(id: 7, isFocused: false),
          },
        ),
      );
      await tester.pump();

      expect(values, <bool>[false, true, false]);
    });

    testWidgets('visible builder rebuilds only on toggle', (tester) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      final values = <bool>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollSpyItemVisibleBuilder<int>(
            controller: controller,
            id: 3,
            builder: (context, isVisible, _) {
              values.add(isVisible);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(values, <bool>[false]);

      controller.commitFrame(
        makeSnapshot(
          visibleIds: {3},
          items: {
            3: makeFocusItem(id: 3, isVisible: true),
          },
        ),
      );
      await tester.pump();

      expect(values, <bool>[false, true]);

      controller.commitFrame(
        makeSnapshot(
          visibleIds: {3},
          items: {
            3: makeFocusItem(id: 3, isVisible: true, visibleFraction: 0.5),
          },
        ),
      );
      await tester.pump();

      expect(values, <bool>[false, true]);

      controller.commitFrame(
        makeSnapshot(
          visibleIds: const {},
          items: {
            3: makeFocusItem(id: 3, isVisible: false),
          },
        ),
      );
      await tester.pump();

      expect(values, <bool>[false, true, false]);
    });
  });

  group('ScrollSpyItem boolean listeners', () {
    testWidgets('listeners fire on toggles and ignore metric drift', (
      tester,
    ) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      final events = <String>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: <Widget>[
              ScrollSpyItemPrimaryListener<int>(
                controller: controller,
                id: 1,
                onChanged: (previous, current) {
                  events.add('p:$previous->$current');
                },
                child: const SizedBox.shrink(),
              ),
              ScrollSpyItemFocusedListener<int>(
                controller: controller,
                id: 1,
                onChanged: (previous, current) {
                  events.add('f:$previous->$current');
                },
                child: const SizedBox.shrink(),
              ),
              ScrollSpyItemVisibleListener<int>(
                controller: controller,
                id: 1,
                onChanged: (previous, current) {
                  events.add('v:$previous->$current');
                },
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );

      controller.commitFrame(
        makeSnapshot(
          primaryId: 1,
          focusedIds: {1},
          visibleIds: {1},
          items: {
            1: makeFocusItem(
              id: 1,
              isPrimary: true,
              isFocused: true,
              isVisible: true,
            ),
          },
        ),
      );
      await tester.pump();

      expect(
        events,
        unorderedEquals(<String>['p:false->true', 'f:false->true', 'v:false->true']),
      );
      events.clear();

      controller.commitFrame(
        makeSnapshot(
          primaryId: 1,
          focusedIds: {1},
          visibleIds: {1},
          items: {
            1: makeFocusItem(
              id: 1,
              isPrimary: true,
              isFocused: true,
              isVisible: true,
              distanceToAnchorPx: 20,
            ),
          },
        ),
      );
      await tester.pump();

      expect(events, isEmpty);

      controller.commitFrame(
        makeSnapshot(
          primaryId: null,
          focusedIds: const {},
          visibleIds: const {},
          items: {
            1: makeFocusItem(
              id: 1,
              isPrimary: false,
              isFocused: false,
              isVisible: false,
            ),
          },
        ),
      );
      await tester.pump();

      expect(
        events,
        unorderedEquals(<String>['p:true->false', 'f:true->false', 'v:true->false']),
      );
    });

    testWidgets('primary listener switches controllers and id', (tester) async {
      final controllerA = ScrollSpyController<int>();
      final controllerB = ScrollSpyController<int>();
      addTearDown(controllerA.dispose);
      addTearDown(controllerB.dispose);

      final events = <String>[];

      Widget build(ScrollSpyController<int> controller, int id) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollSpyItemPrimaryListener<int>(
            controller: controller,
            id: id,
            onChanged: (previous, current) {
              events.add('id=$id $previous->$current');
            },
            child: const SizedBox.shrink(),
          ),
        );
      }

      await tester.pumpWidget(build(controllerA, 1));
      await tester.pump();

      controllerA.commitFrame(
        makeSnapshot(
          primaryId: 1,
          items: {1: makeFocusItem(id: 1, isPrimary: true)},
        ),
      );
      await tester.pump();

      expect(events, <String>['id=1 false->true']);
      events.clear();

      await tester.pumpWidget(build(controllerB, 2));
      await tester.pump();

      controllerA.commitFrame(
        makeSnapshot(
          primaryId: 1,
          items: {1: makeFocusItem(id: 1, isPrimary: true)},
        ),
      );
      await tester.pump();
      expect(events, isEmpty);

      controllerB.commitFrame(
        makeSnapshot(
          primaryId: 2,
          items: {2: makeFocusItem(id: 2, isPrimary: true)},
        ),
      );
      await tester.pump();

      expect(events, <String>['id=2 false->true']);
    });
  });

  group('ScrollSpyItem boolean widgets (scope resolution)', () {
    testWidgets('primary builder resolves controller from scope', (tester) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      final values = <bool>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollSpyScope<int>(
            controller: controller,
            region: const ScrollSpyRegion.line(
              anchor: ScrollSpyAnchor.fraction(0.5),
            ),
            policy: const ScrollSpyPolicy.closestToAnchor(),
            child: ScrollSpyItemPrimaryBuilder<int>(
              id: 1,
              builder: (context, isPrimary, _) {
                values.add(isPrimary);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      // Allow engine compute to settle.
      await tester.pump();
      await tester.pump();

      expect(values, <bool>[false]);

      controller.commitFrame(
        makeSnapshot(
          primaryId: 1,
          items: {
            1: makeFocusItem(id: 1, isPrimary: true),
          },
        ),
      );
      await tester.pump();

      expect(values, <bool>[false, true]);
    });

    testWidgets('primary listener resolves controller from scope', (tester) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      final events = <String>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollSpyScope<int>(
            controller: controller,
            region: const ScrollSpyRegion.line(
              anchor: ScrollSpyAnchor.fraction(0.5),
            ),
            policy: const ScrollSpyPolicy.closestToAnchor(),
            child: ScrollSpyItemPrimaryListener<int>(
              id: 1,
              onChanged: (previous, current) {
                events.add('$previous->$current');
              },
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      // Allow engine compute to settle.
      await tester.pump();
      await tester.pump();

      controller.commitFrame(
        makeSnapshot(
          primaryId: 1,
          items: {
            1: makeFocusItem(id: 1, isPrimary: true),
          },
        ),
      );
      await tester.pump();

      expect(events, <String>['false->true']);

      controller.commitFrame(
        makeSnapshot(
          primaryId: null,
          items: {
            1: makeFocusItem(id: 1, isPrimary: false),
          },
        ),
      );
      await tester.pump();

      expect(events, <String>['false->true', 'true->false']);
    });

    testWidgets('focused builder resolves controller from scope', (tester) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      final values = <bool>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollSpyScope<int>(
            controller: controller,
            region: const ScrollSpyRegion.line(
              anchor: ScrollSpyAnchor.fraction(0.5),
            ),
            policy: const ScrollSpyPolicy.closestToAnchor(),
            child: ScrollSpyItemFocusedBuilder<int>(
              id: 7,
              builder: (context, isFocused, _) {
                values.add(isFocused);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(values, <bool>[false]);

      controller.commitFrame(
        makeSnapshot(
          focusedIds: {7},
          items: {
            7: makeFocusItem(id: 7, isFocused: true),
          },
        ),
      );
      await tester.pump();

      expect(values, <bool>[false, true]);
    });

    testWidgets('focused listener resolves controller from scope', (tester) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      final events = <String>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollSpyScope<int>(
            controller: controller,
            region: const ScrollSpyRegion.line(
              anchor: ScrollSpyAnchor.fraction(0.5),
            ),
            policy: const ScrollSpyPolicy.closestToAnchor(),
            child: ScrollSpyItemFocusedListener<int>(
              id: 7,
              onChanged: (previous, current) {
                events.add('$previous->$current');
              },
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      controller.commitFrame(
        makeSnapshot(
          focusedIds: {7},
          items: {
            7: makeFocusItem(id: 7, isFocused: true),
          },
        ),
      );
      await tester.pump();

      expect(events, <String>['false->true']);

      controller.commitFrame(
        makeSnapshot(
          focusedIds: const {},
          items: {
            7: makeFocusItem(id: 7, isFocused: false),
          },
        ),
      );
      await tester.pump();

      expect(events, <String>['false->true', 'true->false']);
    });

    testWidgets('visible builder resolves controller from scope', (tester) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      final values = <bool>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollSpyScope<int>(
            controller: controller,
            region: const ScrollSpyRegion.line(
              anchor: ScrollSpyAnchor.fraction(0.5),
            ),
            policy: const ScrollSpyPolicy.closestToAnchor(),
            child: ScrollSpyItemVisibleBuilder<int>(
              id: 4,
              builder: (context, isVisible, _) {
                values.add(isVisible);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(values, <bool>[false]);

      controller.commitFrame(
        makeSnapshot(
          visibleIds: {4},
          items: {
            4: makeFocusItem(id: 4, isVisible: true),
          },
        ),
      );
      await tester.pump();

      expect(values, <bool>[false, true]);
    });

    testWidgets('visible listener resolves controller from scope', (tester) async {
      final controller = ScrollSpyController<int>();
      addTearDown(controller.dispose);

      final events = <String>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScrollSpyScope<int>(
            controller: controller,
            region: const ScrollSpyRegion.line(
              anchor: ScrollSpyAnchor.fraction(0.5),
            ),
            policy: const ScrollSpyPolicy.closestToAnchor(),
            child: ScrollSpyItemVisibleListener<int>(
              id: 4,
              onChanged: (previous, current) {
                events.add('$previous->$current');
              },
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      controller.commitFrame(
        makeSnapshot(
          visibleIds: {4},
          items: {
            4: makeFocusItem(id: 4, isVisible: true),
          },
        ),
      );
      await tester.pump();

      expect(events, <String>['false->true']);

      controller.commitFrame(
        makeSnapshot(
          visibleIds: const {},
          items: {
            4: makeFocusItem(id: 4, isVisible: false),
          },
        ),
      );
      await tester.pump();

      expect(events, <String>['false->true', 'true->false']);
    });
  });
}
