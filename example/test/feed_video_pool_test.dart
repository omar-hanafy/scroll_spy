import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy_example/common.dart';
import 'package:scroll_spy_example/demos/feed_autoplay_page.dart';
import 'package:scroll_spy_example/demos/feed_video_pool.dart';
import 'package:scroll_spy_example/theme.dart';

void main() {
  test('pool keeps primary plus neighbors and plays exactly one', () async {
    final List<String> events = <String>[];
    final Map<int, _FakeFeedVideoHandle> handles =
        <int, _FakeFeedVideoHandle>{};
    late FeedVideoPool pool;
    int largestCountBeforeCreate = 0;

    pool = FeedVideoPool(
      itemCount: 20,
      factory: (index) {
        largestCountBeforeCreate =
            largestCountBeforeCreate < pool.controllerCount
            ? pool.controllerCount
            : largestCountBeforeCreate;
        return handles[index] = _FakeFeedVideoHandle(index, events);
      },
    );

    await pool.setPrimary(5);

    expect(pool.retainedIndices, <int>{4, 5, 6});
    expect(pool.controllerCount, 3);
    expect(pool.playingIndices, <int>{5});
    expect(handles[4]!.initialized, isTrue);
    expect(handles[5]!.initialized, isTrue);
    expect(handles[6]!.initialized, isTrue);

    events.clear();
    await pool.setPrimary(6);

    expect(pool.retainedIndices, <int>{5, 6, 7});
    expect(pool.controllerCount, 3);
    expect(pool.playingIndices, <int>{6});
    expect(handles[4]!.disposed, isTrue);
    expect(events.indexOf('pause:5'), lessThan(events.indexOf('play:6')));
    expect(largestCountBeforeCreate, lessThan(3));

    await pool.close();
    expect(handles.values.every((handle) => handle.disposed), isTrue);
  });

  test(
    'pool pauses for lifecycle and releases everything without a primary',
    () async {
      final Map<int, _FakeFeedVideoHandle> handles =
          <int, _FakeFeedVideoHandle>{};
      final FeedVideoPool pool = FeedVideoPool(
        itemCount: 20,
        factory: (index) => handles[index] = _FakeFeedVideoHandle(index),
      );

      await pool.setPrimary(8);
      expect(pool.playingIndices, <int>{8});

      await pool.setActive(false);
      expect(pool.playingIndices, isEmpty);
      expect(pool.retainedIndices, <int>{7, 8, 9});

      await pool.setActive(true);
      expect(pool.playingIndices, <int>{8});

      await pool.setPrimary(null);
      expect(pool.playingIndices, isEmpty);
      expect(pool.controllerCount, 0);
      expect(handles.values.every((handle) => handle.disposed), isTrue);

      await pool.close();
    },
  );

  testWidgets('feed pauses under routes and while the app is inactive', (
    tester,
  ) async {
    final Map<int, _FakeFeedVideoHandle> handles =
        <int, _FakeFeedVideoHandle>{};
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: buildShowcaseTheme(),
        home: FeedAutoplayPage(
          info: _feedInfo,
          videoFactory: (index) => handles[index] = _FakeFeedVideoHandle(index),
        ),
      ),
    );
    await _pumpFeed(tester);

    expect(_playing(handles), hasLength(1));
    expect(handles.length, lessThanOrEqualTo(3));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(_playing(handles), isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_playing(handles), hasLength(1));

    unawaited(
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump();
    expect(_playing(handles), isEmpty);

    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump();
    expect(_playing(handles), hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(handles.values.every((handle) => handle.disposed), isTrue);
  });
}

Future<void> _pumpFeed(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump();
}

Set<int> _playing(Map<int, _FakeFeedVideoHandle> handles) {
  return <int>{
    for (final MapEntry<int, _FakeFeedVideoHandle> entry in handles.entries)
      if (entry.value.state.value.isPlaying) entry.key,
  };
}

final DemoInfo _feedInfo = DemoInfo(
  title: 'Autoplay feed',
  tagline: 'test',
  description: 'test',
  apis: const <String>[],
  icon: Icons.play_circle_fill_rounded,
  accent: SpyColors.primary,
  builder: (_, _) => const SizedBox.shrink(),
);

class _FakeFeedVideoHandle implements FeedVideoHandle {
  _FakeFeedVideoHandle(this.index, [this.events]);

  final int index;
  final List<String>? events;

  final ValueNotifier<FeedVideoState> _state = ValueNotifier<FeedVideoState>(
    const FeedVideoState(),
  );

  bool initialized = false;
  bool disposed = false;

  @override
  ValueListenable<FeedVideoState> get state => _state;

  @override
  Widget buildView() {
    return ColoredBox(
      key: ValueKey<String>('fake-video-$index'),
      color: Colors.black,
    );
  }

  @override
  Future<void> initialize() async {
    if (initialized) return;
    initialized = true;
    events?.add('initialize:$index');
    _state.value = const FeedVideoState(
      isInitialized: true,
      aspectRatio: 9 / 16,
    );
  }

  @override
  Future<void> play() async {
    events?.add('play:$index');
    _state.value = const FeedVideoState(
      isInitialized: true,
      isPlaying: true,
      aspectRatio: 9 / 16,
    );
  }

  @override
  Future<void> pause() async {
    events?.add('pause:$index');
    _state.value = const FeedVideoState(
      isInitialized: true,
      aspectRatio: 9 / 16,
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    events?.add('dispose:$index');
    if (_state.value.isPlaying) await pause();
  }
}
