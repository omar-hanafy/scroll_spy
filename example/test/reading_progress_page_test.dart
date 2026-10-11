import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';
import 'package:scroll_spy_example/demos/demos.dart';
import 'package:scroll_spy_example/demos/reading_progress_page.dart';
import 'package:scroll_spy_example/theme.dart';

void main() {
  final previousHitTestPolicy = WidgetController.hitTestWarningShouldBeFatal;
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(
    () => WidgetController.hitTestWarningShouldBeFatal = previousHitTestPolicy,
  );
  for (final size in <Size>[
    const Size(320, 800),
    const Size(400, 800),
    const Size(1200, 900),
  ]) {
    testWidgets('TOC reaches distant sections and returns at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final demo = kDemos.singleWhere(
        (demo) => demo.title == 'Reading progress',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildShowcaseTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReadingProgressPage(info: demo),
                  ),
                ),
                child: const Text('Open article'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open article'));
      await tester.pumpAndSettle();

      await _jumpTo(tester, 'Wrap up');
      final wrapper = tester.widget<ScrollSpyCustomScrollView<int>>(
        find.byType(ScrollSpyCustomScrollView<int>),
      );
      expect(wrapper.controller.primaryId.value, 9);
      expect(find.text('Section 10 of 10'), findsOneWidget);
      expect(find.text('10. Wrap up').hitTestable(), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        greaterThan(0.8),
      );

      await _jumpTo(tester, 'What scroll_spy answers');
      expect(wrapper.controller.primaryId.value, 0);
      expect(find.text('Section 1 of 10'), findsOneWidget);
      expect(
        find.text('1. What scroll_spy answers').hitTestable(),
        findsOneWidget,
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        lessThan(0.01),
      );
      await tester.tap(find.byTooltip('About this demo'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      if (size.width <= 400) {
        final sheetScroll = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        );
        final sheetState = tester.state<ScrollableState>(sheetScroll);
        expect(sheetState.position.maxScrollExtent, greaterThan(0));
        await tester.drag(sheetScroll, const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(sheetState.position.pixels, greaterThan(0));
      }
      expect(
        ModalRoute.of(tester.element(find.byType(BottomSheet)))?.isCurrent,
        isTrue,
      );
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(ReadingProgressPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Open article'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _jumpTo(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip('Table of contents'));
  await tester.pumpAndSettle();
  final tile = find.widgetWithText(ListTile, title);
  final sheetScroll = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(tile, 200, scrollable: sheetScroll);
  await tester.pumpAndSettle();
  expect(tile.hitTestable(), findsOneWidget);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}
