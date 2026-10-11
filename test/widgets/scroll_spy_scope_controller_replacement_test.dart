import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/focus_fixtures.dart';

void main() {
  testWidgets('cached descendants reconnect when scope controller changes', (
    tester,
  ) async {
    final first = ScrollSpyController<int>();
    final second = ScrollSpyController<int>();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final events = <int?>[];
    final child = Column(
      children: <Widget>[
        ScrollSpyPrimaryBuilder<int>(
          builder: (_, id, _) => Text('primary:$id'),
        ),
        ScrollSpyPrimaryListener<int>(
          onChanged: (_, current) => events.add(current),
          child: const SizedBox.shrink(),
        ),
        ScrollSpyItem<int>(
          id: 1,
          builder: (_, focus, _) => Text('item:${focus.isPrimary}'),
        ),
        ScrollSpyItemLite<int>(
          id: 2,
          builder: (_, _, focused, _) => Text('lite:$focused'),
        ),
      ],
    );

    Widget host(ScrollSpyController<int> controller) => Directionality(
      textDirection: TextDirection.ltr,
      child: ScrollSpyScope<int>(
        controller: controller,
        region: const ScrollSpyRegion.line(
          anchor: ScrollSpyAnchor.fraction(0.5),
        ),
        policy: const ScrollSpyPolicy.closestToAnchor(),
        child: child,
      ),
    );

    await tester.pumpWidget(host(first));
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(host(second));
    await tester.pump();
    await tester.pump();
    events.clear();

    first.commitFrame(makeSnapshot(primaryId: 3));
    await tester.pump();
    expect(events, isEmpty);
    expect(find.text('primary:null'), findsOneWidget);

    second.commitFrame(
      makeSnapshot(
        primaryId: 1,
        focusedIds: <int>{1, 2},
        items: <int, ScrollSpyItemFocus<int>>{
          1: makeFocusItem(id: 1, isPrimary: true, isFocused: true),
          2: makeFocusItem(id: 2, isFocused: true),
        },
      ),
    );
    await tester.pump();
    expect(events, <int?>[1]);
    expect(find.text('primary:1'), findsOneWidget);
    expect(find.text('item:true'), findsOneWidget);
    expect(find.text('lite:true'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
