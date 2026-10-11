import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

void main() {
  for (final kind in <String>['list', 'grid', 'custom']) {
    for (final scenario in <_Scenario>[
      const _Scenario('mobile default', TargetPlatform.android, inherits: true),
      const _Scenario('desktop default', TargetPlatform.macOS),
      const _Scenario(
        'disabled inheritance',
        TargetPlatform.android,
        disable: true,
      ),
      const _Scenario(
        'explicit primary',
        TargetPlatform.macOS,
        primary: true,
        inherits: true,
      ),
      const _Scenario(
        'explicit nonprimary',
        TargetPlatform.android,
        primary: false,
      ),
      const _Scenario(
        'horizontal inheritance',
        TargetPlatform.android,
        axis: Axis.horizontal,
        inherits: true,
      ),
    ]) {
      testWidgets('$kind uses one controller for ${scenario.name}', (
        tester,
      ) async {
        final focus = ScrollSpyController<int>();
        final ambient = ScrollController();
        addTearDown(focus.dispose);
        addTearDown(ambient.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: scenario.platform),
            home: PrimaryScrollController(
              controller: ambient,
              automaticallyInheritForPlatforms: scenario.disable
                  ? const <TargetPlatform>{}
                  : const <TargetPlatform>{
                      TargetPlatform.android,
                      TargetPlatform.iOS,
                      TargetPlatform.fuchsia,
                    },
              scrollDirection: scenario.axis,
              child: _wrapper(kind, focus, scenario),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        final scope = tester.widget<ScrollSpyScope<int>>(
          find.byType(ScrollSpyScope<int>),
        );
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable),
        );
        expect(
          scope.scrollController!.positions,
          contains(scrollable.position),
        );
        expect(identical(scope.scrollController, ambient), scenario.inherits);
        expect(ambient.hasClients, scenario.inherits);

        final initial = focus.primaryId.value;
        expect(initial, isNotNull);
        scope.scrollController!.jumpTo(450);
        await tester.pump();
        await tester.pump();
        expect(focus.primaryId.value, isNot(initial));
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

Widget _wrapper(
  String kind,
  ScrollSpyController<int> focus,
  _Scenario scenario,
) {
  const region = ScrollSpyRegion.line(anchor: ScrollSpyAnchor.fraction(0.5));
  const policy = ScrollSpyPolicy<int>.closestToAnchor();
  Widget itemBuilder(BuildContext context, int index) => ScrollSpyItemLite<int>(
    id: index,
    builder: (_, _, _, _) => const SizedBox.expand(),
  );
  switch (kind) {
    case 'list':
      return ScrollSpyListView<int>.builder(
        controller: focus,
        region: region,
        policy: policy,
        primary: scenario.primary,
        scrollDirection: scenario.axis,
        itemCount: 20,
        itemExtent: 100,
        itemBuilder: itemBuilder,
      );
    case 'grid':
      return ScrollSpyGridView<int>.builder(
        controller: focus,
        region: region,
        policy: policy,
        primary: scenario.primary,
        scrollDirection: scenario.axis,
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
        primary: scenario.primary,
        scrollDirection: scenario.axis,
        slivers: <Widget>[
          SliverFixedExtentList(
            itemExtent: 100,
            delegate: SliverChildBuilderDelegate(itemBuilder, childCount: 20),
          ),
        ],
      );
  }
}

class _Scenario {
  const _Scenario(
    this.name,
    this.platform, {
    this.primary,
    this.axis = Axis.vertical,
    this.disable = false,
    this.inherits = false,
  });
  final String name;
  final TargetPlatform platform;
  final bool? primary;
  final Axis axis;
  final bool disable;
  final bool inherits;
}
