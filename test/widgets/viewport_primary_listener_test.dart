import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewport_focus/viewport_focus.dart';

void main() {
  group('ViewportPrimaryListener', () {
    testWidgets(
      'switches controllers and stops listening to the old controller',
      (tester) async {
        final controllerA = ViewportFocusController<int>();
        final controllerB = ViewportFocusController<int>();
        addTearDown(controllerA.dispose);
        addTearDown(controllerB.dispose);

        final events = <String>[];

        Widget build(ViewportFocusController<int> controller) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: ViewportPrimaryListener<int>(
              controller: controller,
              onChanged: (previous, current) {
                events.add('prev=$previous curr=$current');
              },
              child: const SizedBox.shrink(),
            ),
          );
        }

        // Mount with controller A.
        await tester.pumpWidget(build(controllerA));
        await tester.pump();

        // Update controller A => callback fires.
        controllerA.commitFrame(
          ViewportFocusSnapshot<int>(
            computedAt: DateTime.fromMillisecondsSinceEpoch(1),
            primaryId: 1,
            focusedIds: const <int>{1},
            visibleIds: const <int>{1},
            items: const <int, ViewportItemFocus<int>>{},
          ),
        );
        await tester.pump();

        expect(events, <String>['prev=null curr=1']);
        events.clear();

        // Rebuild with controller B.
        await tester.pumpWidget(build(controllerB));
        await tester.pump();

        // Updating controller A MUST NOT trigger callback anymore.
        controllerA.commitFrame(
          ViewportFocusSnapshot<int>(
            computedAt: DateTime.fromMillisecondsSinceEpoch(2),
            primaryId: 2,
            focusedIds: const <int>{2},
            visibleIds: const <int>{2},
            items: const <int, ViewportItemFocus<int>>{},
          ),
        );
        await tester.pump();
        expect(events, isEmpty);

        // Updating controller B MUST trigger callback.
        controllerB.commitFrame(
          ViewportFocusSnapshot<int>(
            computedAt: DateTime.fromMillisecondsSinceEpoch(3),
            primaryId: 7,
            focusedIds: const <int>{7},
            visibleIds: const <int>{7},
            items: const <int, ViewportItemFocus<int>>{},
          ),
        );
        await tester.pump();

        expect(events, <String>['prev=null curr=7']);
      },
    );
  });
}
