import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:scroll_spy/scroll_spy.dart';
import 'package:scroll_spy_example/demos/demos.dart';
import 'package:scroll_spy_example/demos/feed_autoplay_page.dart';
import 'package:scroll_spy_example/demos/reading_progress_page.dart';
import 'package:scroll_spy_example/main.dart';
import 'package:video_player/video_player.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final previousHitTestPolicy = WidgetController.hitTestWarningShouldBeFatal;
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(
    () => WidgetController.hitTestWarningShouldBeFatal = previousHitTestPolicy,
  );

  testWidgets('gallery navigation, real video ownership, and article TOC', (
    tester,
  ) async {
    await tester.pumpWidget(const ShowcaseApp());
    await tester.pumpAndSettle();

    for (final demo in kDemos) {
      await tester.scrollUntilVisible(
        find.text(demo.title),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text(demo.title).hitTestable(), findsOneWidget);
      await tester.tap(find.text(demo.title));
      await _waitUntil(
        tester,
        () =>
            find.byType(AppBar).evaluate().isNotEmpty &&
            ModalRoute.of(tester.element(find.byType(AppBar)))
                    ?.animation
                    ?.status ==
                AnimationStatus.completed,
        'demo route opens',
      );

      if (demo.title == 'Autoplay feed') {
        final scope = tester.widget<ScrollSpyScope<int>>(
          find.descendant(
            of: find.byType(FeedAutoplayPage),
            matching: find.byType(ScrollSpyScope<int>),
          ),
        );
        await _waitForVideoOwner(tester, scope.controller);
        final firstPrimary = scope.controller.primaryId.value;
        final player = _playingPlayers(tester).single;
        final initialPosition = player.value.position;
        await _waitUntil(
          tester,
          () => player.value.position > initialPosition,
          'bundled video position advances',
        );

        final feed = find.descendant(
          of: find.byType(FeedAutoplayPage),
          matching: find.byType(Scrollable),
        );
        await tester.drag(feed, const Offset(0, -520));
        await _waitUntil(
          tester,
          () => scope.controller.primaryId.value != firstPrimary,
          'scrolling changes the primary clip',
        );
        await _waitForVideoOwner(tester, scope.controller);

        await tester.tap(find.byTooltip('About this demo'));
        await _waitUntil(
          tester,
          () => _playingPlayers(tester).isEmpty,
          'covering the feed pauses playback',
        );
        expect(
          find.textContaining('controllers warm - 0 playing'),
          findsOneWidget,
        );
        await _waitUntil(
          tester,
          () =>
              find.byType(BottomSheet).evaluate().length == 1 &&
              ModalRoute.of(tester.element(find.byType(BottomSheet)))
                      ?.animation
                      ?.status ==
                  AnimationStatus.completed,
          'about sheet finishes opening',
        );
        expect(
          ModalRoute.of(tester.element(find.byType(BottomSheet)))?.isCurrent,
          isTrue,
        );
        // System back addresses the current modal route. The page's app-bar
        // back button is behind the scrim and is not a dismissal target.
        expect(await tester.binding.handlePopRoute(), isTrue);
        await _waitUntil(
          tester,
          () => find.byType(BottomSheet).evaluate().isEmpty,
          'about sheet closes',
        );
        await _waitForVideoOwner(tester, scope.controller);
      } else if (demo.title == 'Reading progress') {
        await _jumpArticle(tester, 'Wrap up');
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
        await _jumpArticle(tester, 'What scroll_spy answers');
        expect(find.text('Section 1 of 10'), findsOneWidget);
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          lessThan(0.01),
        );
      } else {
        final scrollables = find.byType(Scrollable);
        if (scrollables.evaluate().isNotEmpty) {
          final state = tester.state<ScrollableState>(scrollables.last);
          final delta =
              state.axisDirection == AxisDirection.left ||
                  state.axisDirection == AxisDirection.right
              ? const Offset(-240, 0)
              : const Offset(0, -240);
          await tester.drag(scrollables.last, delta);
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      expect(tester.takeException(), isNull, reason: demo.title);
      expect(find.byTooltip('Back').hitTestable(), findsOneWidget);
      await tester.pageBack();
      await _waitUntil(
        tester,
        () => find.byType(AppBar).evaluate().isEmpty,
        'back navigation returns to gallery',
      );
      expect(find.byType(HomeGalleryPage), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final kind in <String>['list', 'grid', 'custom']) {
    testWidgets('$kind reconnects primary and focus controllers at runtime', (
      tester,
    ) async {
      final first = ScrollSpyController<int>();
      final second = ScrollSpyController<int>();
      final firstScroll = ScrollController();
      final secondScroll = ScrollController();
      final replace = ValueNotifier<bool>(false);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      addTearDown(firstScroll.dispose);
      addTearDown(secondScroll.dispose);
      addTearDown(replace.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: replace,
              builder: (_, changed, _) => PrimaryScrollController(
                controller: changed ? secondScroll : firstScroll,
                child: _wrapper(kind, changed ? second : first),
              ),
            ),
          ),
        ),
      );
      await _waitUntil(
        tester,
        () => first.primaryId.value != null,
        'first focus',
      );
      _expectAttached(tester, firstScroll);
      firstScroll.jumpTo(450);
      await tester.pump();
      await tester.pump();
      final oldPrimary = first.primaryId.value;

      replace.value = true;
      await _waitUntil(
        tester,
        () => second.primaryId.value != null,
        'new focus',
      );
      _expectAttached(tester, secondScroll);
      expect(firstScroll.hasClients, isFalse);
      final newPrimary = second.primaryId.value;
      secondScroll.jumpTo(750);
      await _waitUntil(
        tester,
        () => second.primaryId.value != newPrimary,
        'replacement scroll controller updates selection',
      );
      expect(first.primaryId.value, oldPrimary);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() condition,
  String reason,
) async {
  final deadline = Stopwatch()..start();
  while (!condition()) {
    expect(
      deadline.elapsed,
      lessThan(const Duration(seconds: 20)),
      reason: reason,
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

Set<VideoPlayerController> _playingPlayers(WidgetTester tester) => tester
    .widgetList<VideoPlayer>(find.byType(VideoPlayer))
    .map((player) => player.controller)
    .where((controller) => controller.value.isPlaying)
    .toSet();

Future<void> _waitForVideoOwner(
  WidgetTester tester,
  ScrollSpyController<int> focus,
) async {
  await _waitUntil(tester, () {
    final owner = find.descendant(
      of: find.byKey(ValueKey<String>('feed-card-${focus.primaryId.value}')),
      matching: find.byType(VideoPlayer),
    );
    if (owner.evaluate().length != 1) return false;
    final controller = tester.widget<VideoPlayer>(owner).controller;
    return controller.value.isInitialized &&
        controller.value.isPlaying &&
        _playingPlayers(tester).length == 1 &&
        find.textContaining('controllers warm - 1 playing').evaluate().length ==
            1;
  }, 'exactly one real video is playing');
  final owner = find.descendant(
    of: find.byKey(ValueKey<String>('feed-card-${focus.primaryId.value}')),
    matching: find.byType(VideoPlayer),
  );
  final controller = tester.widget<VideoPlayer>(owner).controller;
  expect(controller.value.isInitialized, isTrue);
  expect(controller.value.isPlaying, isTrue);
  expect(controller.value.errorDescription, isNull);
  expect(_playingPlayers(tester), <VideoPlayerController>{controller});
  expect(
    find.textContaining(RegExp(r'^[0-3]/3 controllers warm - 1 playing$')),
    findsOneWidget,
  );
}

Future<void> _jumpArticle(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip('Table of contents'));
  await tester.pumpAndSettle();
  final tile = find.widgetWithText(ListTile, title);
  await tester.scrollUntilVisible(
    tile,
    200,
    scrollable: find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
  expect(tile.hitTestable(), findsOneWidget);
  await tester.tap(tile);
  await tester.pumpAndSettle();
  expect(find.byType(ReadingProgressPage), findsOneWidget);
}

void _expectAttached(WidgetTester tester, ScrollController controller) {
  final scope = tester.widget<ScrollSpyScope<int>>(
    find.byType(ScrollSpyScope<int>),
  );
  final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
  expect(scope.scrollController, same(controller));
  expect(controller.positions, contains(scrollable.position));
}

Widget _wrapper(String kind, ScrollSpyController<int> controller) {
  const region = ScrollSpyRegion.line(anchor: ScrollSpyAnchor.fraction(0.5));
  const policy = ScrollSpyPolicy<int>.closestToAnchor();
  Widget item(BuildContext context, int index) => ScrollSpyItemLite<int>(
    id: index,
    builder: (_, primary, _, _) => ColoredBox(
      color: primary ? Colors.green : Colors.grey,
      child: Center(child: Text('Item $index: $primary')),
    ),
  );
  switch (kind) {
    case 'list':
      return ScrollSpyListView<int>.builder(
        controller: controller,
        region: region,
        policy: policy,
        primary: true,
        itemCount: 30,
        itemExtent: 100,
        itemBuilder: item,
      );
    case 'grid':
      return ScrollSpyGridView<int>.builder(
        controller: controller,
        region: region,
        policy: policy,
        primary: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          mainAxisExtent: 100,
        ),
        itemCount: 30,
        itemBuilder: item,
      );
    default:
      return ScrollSpyCustomScrollView<int>(
        controller: controller,
        region: region,
        policy: policy,
        primary: true,
        slivers: <Widget>[
          SliverFixedExtentList(
            itemExtent: 100,
            delegate: SliverChildBuilderDelegate(item, childCount: 30),
          ),
        ],
      );
  }
}
