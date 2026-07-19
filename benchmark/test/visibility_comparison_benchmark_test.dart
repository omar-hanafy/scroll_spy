import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_test/flutter_test.dart';
import 'package:inview_notifier_list/inview_notifier_list.dart';
import 'package:scroll_spy/scroll_spy.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _viewportSize = Size(400, 600);
const _itemExtent = 100.0;
const _itemCount = 3000;
const _initialOffset = 100025.0;
const _measuredSteps = 40;
const _stepExtent = 25.0;

enum _Implementation {
  scrollSpy('scroll_spy'),
  inViewNotifier('inview_notifier_list'),
  visibilityDetector('visibility_detector');

  const _Implementation(this.label);

  final String label;
}

class _Profile {
  const _Profile(this.label, this.cacheExtent);

  final String label;
  final double cacheExtent;
}

const _profiles = <_Profile>[
  _Profile('small-cache', 200),
  _Profile('medium-cache', 2200),
  _Profile('large-cache', 9700),
];

class _Counters {
  int listItemBuilds = 0;
  int staticChildBuilds = 0;
  int registrationBuilds = 0;
  int reactiveBuilds = 0;
  int callbacks = 0;
  int stateTransitions = 0;
  int repeatedStateDeliveries = 0;

  final Map<int, bool> _lastState = <int, bool>{};
  final Set<int> visibleIds = <int>{};

  void recordState(int id, bool isVisible) {
    final previous = _lastState[id];
    if (previous == null) {
      // Treat a newly mounted visible item as hidden -> visible. All three
      // packages otherwise have different initial-delivery conventions.
      if (isVisible) stateTransitions += 1;
    } else if (previous == isVisible) {
      repeatedStateDeliveries += 1;
    } else {
      stateTransitions += 1;
    }
    _lastState[id] = isVisible;
    if (isVisible) {
      visibleIds.add(id);
    } else {
      visibleIds.remove(id);
    }
  }

  void resetMeasuredCounts() {
    listItemBuilds = 0;
    staticChildBuilds = 0;
    registrationBuilds = 0;
    reactiveBuilds = 0;
    callbacks = 0;
    stateTransitions = 0;
    repeatedStateDeliveries = 0;
  }
}

class _Result {
  const _Result({
    required this.implementation,
    required this.profile,
    required this.mountedItems,
    required this.counters,
    required this.stepMicros,
  });

  final _Implementation implementation;
  final _Profile profile;
  final int mountedItems;
  final _Counters counters;
  final List<int> stepMicros;

  int get meanStepMicros =>
      stepMicros.reduce((a, b) => a + b) ~/ stepMicros.length;

  int percentile(double percentile) {
    final sorted = stepMicros.toList()..sort();
    final index = ((sorted.length - 1) * percentile).round();
    return sorted[index];
  }
}

class _StaticChild extends StatelessWidget {
  const _StaticChild(this.counters);

  final _Counters counters;

  @override
  Widget build(BuildContext context) {
    counters.staticChildBuilds += 1;
    return const ColoredBox(color: Color(0xff202124));
  }
}

class _VisibilityDetectorConsumer extends StatefulWidget {
  const _VisibilityDetectorConsumer({
    super.key,
    required this.id,
    required this.counters,
    required this.child,
  });

  final int id;
  final _Counters counters;
  final Widget child;

  @override
  State<_VisibilityDetectorConsumer> createState() =>
      _VisibilityDetectorConsumerState();
}

class _VisibilityDetectorConsumerState
    extends State<_VisibilityDetectorConsumer> {
  bool _isVisible = false;
  late final VisibilityChangedCallback _stableCallback = _onVisibilityChanged;
  late final Key _detectorKey = ValueKey<String>('visibility-${widget.id}');

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    widget.counters.callbacks += 1;
    final next = info.visibleFraction > 0;
    widget.counters.recordState(widget.id, next);
    if (next != _isVisible) {
      setState(() => _isVisible = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.counters.reactiveBuilds += 1;
    return VisibilityDetector(
      key: _detectorKey,
      onVisibilityChanged: _stableCallback,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    VisibilityDetectorController.instance.forget(_detectorKey);
    super.dispose();
  }
}

class _Harness {
  _Harness(this.implementation, this.profile)
      : counters = _Counters(),
        scrollController = ScrollController(
          initialScrollOffset: _initialOffset,
        ),
        scrollSpyController = implementation == _Implementation.scrollSpy
            ? ScrollSpyController<int>()
            : null;

  final _Implementation implementation;
  final _Profile profile;
  final _Counters counters;
  final ScrollController scrollController;
  final ScrollSpyController<int>? scrollSpyController;

  Widget build() {
    final Widget child = switch (implementation) {
      _Implementation.scrollSpy => _buildScrollSpy(),
      _Implementation.inViewNotifier => _buildInViewNotifier(),
      _Implementation.visibilityDetector => _buildVisibilityDetector(),
    };

    return MediaQuery(
      data: const MediaQueryData(size: _viewportSize),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox.fromSize(size: _viewportSize, child: child),
        ),
      ),
    );
  }

  Widget _buildScrollSpy() {
    final controller = scrollSpyController!;
    return ScrollSpyScope<int>(
      controller: controller,
      scrollController: scrollController,
      // This comparison exercises the common denominator: viewport
      // visibility. Keep ScrollSpy's focus/primary selection inactive so the
      // other packages are not compared against work they cannot perform.
      region: const ScrollSpyRegion.line(
        anchor: ScrollSpyAnchor.pixels(-10000),
      ),
      policy: const ScrollSpyPolicy<int>.closestToAnchor(),
      child: ListView.builder(
        controller: scrollController,
        itemCount: _itemCount,
        itemExtent: _itemExtent,
        scrollCacheExtent: ScrollCacheExtent.pixels(profile.cacheExtent),
        itemBuilder: (context, index) {
          counters.listItemBuilds += 1;
          return ScrollSpyItemLite<int>(
            key: ValueKey<String>('scroll-spy-$index'),
            id: index,
            child: ScrollSpyItemVisibleListener<int>(
              controller: controller,
              id: index,
              onChanged: (previous, current) {
                counters.callbacks += 1;
              },
              child: _StaticChild(counters),
            ),
            builder: (context, isPrimary, isFocused, child) {
              counters.registrationBuilds += 1;
              return ScrollSpyItemVisibleBuilder<int>(
                controller: controller,
                id: index,
                child: child,
                builder: (context, isVisible, staticChild) {
                  counters.reactiveBuilds += 1;
                  counters.recordState(index, isVisible);
                  return staticChild!;
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInViewNotifier() {
    return InViewNotifierList(
      controller: scrollController,
      itemCount: _itemCount,
      itemExtent: _itemExtent,
      // inview_notifier_list 4.1.0 exposes only the legacy double parameter.
      cacheExtent: profile.cacheExtent,
      // Match ScrollSpy's per-frame policy and VisibilityDetector's zero
      // interval. The package default is a semantically different 200 ms.
      throttleDuration: Duration.zero,
      isInViewPortCondition: (top, bottom, viewportExtent) =>
          top < viewportExtent && bottom > 0,
      builder: (context, index) {
        counters.listItemBuilds += 1;
        return InViewNotifierWidget(
          key: ValueKey<String>('inview-$index'),
          id: '$index',
          child: _StaticChild(counters),
          builder: (context, isInView, child) {
            counters.reactiveBuilds += 1;
            counters.recordState(index, isInView);
            return child!;
          },
        );
      },
    );
  }

  Widget _buildVisibilityDetector() {
    return ListView.builder(
      controller: scrollController,
      itemCount: _itemCount,
      itemExtent: _itemExtent,
      scrollCacheExtent: ScrollCacheExtent.pixels(profile.cacheExtent),
      itemBuilder: (context, index) {
        counters.listItemBuilds += 1;
        return _VisibilityDetectorConsumer(
          key: ValueKey<String>('consumer-$index'),
          id: index,
          counters: counters,
          child: _StaticChild(counters),
        );
      },
    );
  }

  int mountedItems(WidgetTester tester) => switch (implementation) {
        _Implementation.scrollSpy => tester
            .widgetList<ScrollSpyItemLite<int>>(
              find.byType(
                ScrollSpyItemLite<int>,
                skipOffstage: false,
              ),
            )
            .length,
        _Implementation.inViewNotifier => tester
            .widgetList<InViewNotifierWidget>(
              find.byType(InViewNotifierWidget, skipOffstage: false),
            )
            .length,
        _Implementation.visibilityDetector => tester
            .widgetList<VisibilityDetector>(
              find.byType(VisibilityDetector, skipOffstage: false),
            )
            .length,
      };

  void dispose() {
    scrollSpyController?.dispose();
    scrollController.dispose();
  }
}

Set<int> _expectedVisibleIds(double offset) {
  final first = math.max(0, (offset / _itemExtent).floor());
  final last = math.min(
    _itemCount - 1,
    ((offset + _viewportSize.height) / _itemExtent).ceil() - 1,
  );
  return <int>{for (var id = first; id <= last; id++) id};
}

Future<void> _flushFrame(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
}

Future<_Result> _runCase(
  WidgetTester tester,
  _Implementation implementation,
  _Profile profile,
) async {
  final harness = _Harness(implementation, profile);
  await tester.pumpWidget(harness.build());
  await _flushFrame(tester);
  await _flushFrame(tester);

  // Warm the package code and force an initial semantic calculation.
  for (var step = 0; step < 12; step++) {
    final offset = _initialOffset + ((step.isEven ? 1 : -1) * _stepExtent);
    harness.scrollController.jumpTo(offset);
    await _flushFrame(tester);
  }
  harness.scrollController.jumpTo(_initialOffset);
  await _flushFrame(tester);

  final mountedItems = harness.mountedItems(tester);
  harness.counters.resetMeasuredCounts();

  final timings = <int>[];
  var offset = _initialOffset;
  for (var step = 0; step < _measuredSteps; step++) {
    offset += _stepExtent;
    final stopwatch = Stopwatch()..start();
    harness.scrollController.jumpTo(offset);
    await _flushFrame(tester);
    stopwatch.stop();
    timings.add(stopwatch.elapsedMicroseconds);
  }

  expect(
    harness.counters.visibleIds,
    _expectedVisibleIds(offset),
    reason: '${implementation.label} must report the same final visible set',
  );

  final result = _Result(
    implementation: implementation,
    profile: profile,
    mountedItems: mountedItems,
    counters: harness.counters,
    stepMicros: timings,
  );

  await tester.pumpWidget(const SizedBox.shrink());
  await _flushFrame(tester);
  harness.dispose();
  return result;
}

void _printResults(List<_Result> results) {
  print('');
  print(
    '| implementation | profile | mounted | list item builds | static child '
    'builds | registration builds | reactive builds | callbacks | state '
    'transitions | repeated deliveries | mean step us | p50 us | p95 us |',
  );
  print(
    '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|',
  );
  for (final result in results) {
    final c = result.counters;
    print(
      '| ${result.implementation.label} | ${result.profile.label} | '
      '${result.mountedItems} | ${c.listItemBuilds} | '
      '${c.staticChildBuilds} | ${c.registrationBuilds} | '
      '${c.reactiveBuilds} | ${c.callbacks} | ${c.stateTransitions} | '
      '${c.repeatedStateDeliveries} | ${result.meanStepMicros} | '
      '${result.percentile(0.50)} | ${result.percentile(0.95)} |',
    );
  }
  print('');
  print(
    'Timing is debug-VM wall time for jumpTo plus two widget-test pumps. '
    'It is not profile-device frame, raster, GPU, or FPS data.',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.notifyNow();
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
  });

  testWidgets(
    'compares equivalent viewport visibility delivery at actual mounted counts',
    (tester) async {
      final results = <_Result>[];
      for (final profile in _profiles) {
        for (final implementation in _Implementation.values) {
          results.add(await _runCase(tester, implementation, profile));
        }
      }
      _printResults(results);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
