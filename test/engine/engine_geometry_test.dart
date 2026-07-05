import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/src/engine/engine_geometry.dart';
import 'package:scroll_spy/src/engine/item_slot.dart';

class _Probe extends SingleChildRenderObjectWidget {
  const _Probe({required this.onBox, super.child});

  final void Function(RenderBox box) onBox;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final ro = _RenderProbe();
    onBox(ro);
    return ro;
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject ro) {
    onBox(ro as RenderBox);
  }
}

class _RenderProbe extends RenderProxyBox {}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

RenderBox _viewportBoxOf(RenderBox box) =>
    RenderAbstractViewport.of(box) as RenderBox;

/// Measures [slot] and asserts it matches localToGlobal ground truth.
void _expectMatchesGroundTruth(
  EngineGeometry geometry,
  ItemSlot<int> slot, {
  required Axis axis,
}) {
  final box = slot.box!;
  final vpBox = _viewportBoxOf(box);
  geometry.ensureMeasured(slot);

  expect(slot.measurable, isTrue, reason: 'item ${slot.id} measurable');
  final origin = box.localToGlobal(Offset.zero, ancestor: vpBox);
  final mainStart = axis == Axis.vertical ? origin.dy : origin.dx;
  final crossStart = axis == Axis.vertical ? origin.dx : origin.dy;
  final mainExtent = axis == Axis.vertical ? box.size.height : box.size.width;

  expect(slot.mainStart, moreOrLessEquals(mainStart, epsilon: 0.01),
      reason: 'mainStart of item ${slot.id}');
  expect(slot.mainEnd, moreOrLessEquals(mainStart + mainExtent, epsilon: 0.01),
      reason: 'mainEnd of item ${slot.id}');
  expect(slot.crossStartNow, moreOrLessEquals(crossStart, epsilon: 0.01),
      reason: 'crossStart of item ${slot.id}');
}

void main() {
  testWidgets('vertical list: fast tier matches ground truth', (tester) async {
    final boxes = <int, RenderBox>{};
    await tester.pumpWidget(_app(
      ListView.builder(
        itemExtent: 100,
        itemCount: 50,
        itemBuilder: (context, i) => _Probe(
          onBox: (b) => boxes[i] = b,
          child: Text('item $i'),
        ),
      ),
    ));

    final geometry = EngineGeometry();
    final viewport = RenderAbstractViewport.of(boxes[0]!);
    expect(
      geometry.beginPass(viewport: viewport, axisHint: Axis.vertical),
      isTrue,
    );
    expect(geometry.axis, Axis.vertical);
    expect(geometry.dir, 1.0);

    var order = 0;
    for (final entry in boxes.entries) {
      if (!entry.value.attached) continue;
      final slot = ItemSlot<int>(id: entry.key, registrationOrder: order++)
        ..box = entry.value;
      _expectMatchesGroundTruth(geometry, slot, axis: Axis.vertical);
      expect(slot.tier, GeometryTier.fast, reason: 'item ${entry.key}');
    }
  });

  testWidgets('after jumpTo, fast tier derives without full measures',
      (tester) async {
    final boxes = <int, RenderBox>{};
    await tester.pumpWidget(_app(
      ListView.builder(
        itemExtent: 100,
        itemCount: 50,
        itemBuilder: (context, i) => _Probe(
          onBox: (b) => boxes[i] = b,
          child: Text('item $i'),
        ),
      ),
    ));

    final geometry = EngineGeometry();
    final viewport = RenderAbstractViewport.of(boxes[0]!);
    geometry.beginPass(viewport: viewport, axisHint: Axis.vertical);

    final slots = <int, ItemSlot<int>>{};
    var order = 0;
    for (final entry in boxes.entries) {
      if (!entry.value.attached) continue;
      final slot = ItemSlot<int>(id: entry.key, registrationOrder: order++)
        ..box = entry.value;
      geometry.ensureMeasured(slot);
      slots[entry.key] = slot;
    }

    final position =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    position.jumpTo(300);
    await tester.pump();

    final measuresBefore = geometry.fullMeasures;
    geometry.beginPass(viewport: viewport, axisHint: Axis.vertical);
    for (final slot in slots.values) {
      if (!slot.box!.attached) continue;
      _expectMatchesGroundTruth(geometry, slot, axis: Axis.vertical);
      expect(slot.tier, GeometryTier.fast);
    }
    expect(geometry.fullMeasures, measuresBefore,
        reason: 'steady scroll must not trigger full measures');
    expect(geometry.fastHits, greaterThan(0));
  });

  testWidgets('reverse list: dir is negative and positions match',
      (tester) async {
    final boxes = <int, RenderBox>{};
    await tester.pumpWidget(_app(
      ListView.builder(
        reverse: true,
        itemExtent: 100,
        itemCount: 50,
        itemBuilder: (context, i) => _Probe(
          onBox: (b) => boxes[i] = b,
          child: Text('item $i'),
        ),
      ),
    ));

    final geometry = EngineGeometry();
    final viewport = RenderAbstractViewport.of(boxes[0]!);
    geometry.beginPass(viewport: viewport, axisHint: Axis.vertical);
    expect(geometry.dir, -1.0);

    final slots = <int, ItemSlot<int>>{};
    var order = 0;
    for (final entry in boxes.entries) {
      if (!entry.value.attached) continue;
      final slot = ItemSlot<int>(id: entry.key, registrationOrder: order++)
        ..box = entry.value;
      geometry.ensureMeasured(slot);
      slots[entry.key] = slot;
    }

    tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(150);
    await tester.pump();

    geometry.beginPass(viewport: viewport, axisHint: Axis.vertical);
    for (final slot in slots.values) {
      if (!slot.box!.attached) continue;
      _expectMatchesGroundTruth(geometry, slot, axis: Axis.vertical);
    }
  });

  testWidgets('horizontal list matches ground truth', (tester) async {
    final boxes = <int, RenderBox>{};
    await tester.pumpWidget(_app(
      ListView.builder(
        scrollDirection: Axis.horizontal,
        itemExtent: 120,
        itemCount: 50,
        itemBuilder: (context, i) => _Probe(
          onBox: (b) => boxes[i] = b,
          child: Text('item $i'),
        ),
      ),
    ));

    final geometry = EngineGeometry();
    final viewport = RenderAbstractViewport.of(boxes[0]!);
    geometry.beginPass(viewport: viewport, axisHint: Axis.horizontal);
    expect(geometry.axis, Axis.horizontal);
    expect(geometry.dir, 1.0);

    var order = 0;
    for (final entry in boxes.entries) {
      if (!entry.value.attached) continue;
      final slot = ItemSlot<int>(id: entry.key, registrationOrder: order++)
        ..box = entry.value;
      _expectMatchesGroundTruth(geometry, slot, axis: Axis.horizontal);
      expect(slot.tier, GeometryTier.fast);
    }
  });

  testWidgets('resizing an item above invalidates the fast anchor',
      (tester) async {
    final boxes = <int, RenderBox>{};
    double firstHeight = 100;
    late StateSetter rebuild;

    await tester.pumpWidget(_app(
      StatefulBuilder(builder: (context, setState) {
        rebuild = setState;
        return ListView.builder(
          itemCount: 20,
          itemBuilder: (context, i) => SizedBox(
            height: i == 0 ? firstHeight : 100,
            child: _Probe(
              onBox: (b) => boxes[i] = b,
              child: Text('item $i'),
            ),
          ),
        );
      }),
    ));

    final geometry = EngineGeometry();
    final viewport = RenderAbstractViewport.of(boxes[1]!);
    geometry.beginPass(viewport: viewport, axisHint: Axis.vertical);
    final slot = ItemSlot<int>(id: 1, registrationOrder: 0)..box = boxes[1]!;
    geometry.ensureMeasured(slot);
    expect(slot.tier, GeometryTier.fast);
    expect(slot.mainStart, moreOrLessEquals(100, epsilon: 0.01));

    rebuild(() => firstHeight = 40);
    await tester.pump();

    final measuresBefore = geometry.fullMeasures;
    geometry.beginPass(viewport: viewport, axisHint: Axis.vertical);
    _expectMatchesGroundTruth(geometry, slot, axis: Axis.vertical);
    expect(slot.mainStart, moreOrLessEquals(40, epsilon: 0.01));
    expect(geometry.fullMeasures, measuresBefore + 1,
        reason: 'layout shift must force a re-measure');
  });

  testWidgets('transformed item classifies as matrix tier and stays correct',
      (tester) async {
    final boxes = <int, RenderBox>{};
    await tester.pumpWidget(_app(
      ListView.builder(
        itemExtent: 100,
        itemCount: 20,
        itemBuilder: (context, i) => Transform.rotate(
          angle: 0.3,
          child: _Probe(
            onBox: (b) => boxes[i] = b,
            child: Text('item $i'),
          ),
        ),
      ),
    ));

    final geometry = EngineGeometry();
    final viewport = RenderAbstractViewport.of(boxes[0]!);
    final vpBox = viewport as RenderBox;
    geometry.beginPass(viewport: viewport, axisHint: Axis.vertical);

    final box = boxes[2]!;
    final slot = ItemSlot<int>(id: 2, registrationOrder: 0)..box = box;
    geometry.ensureMeasured(slot);
    expect(slot.tier, GeometryTier.matrix);

    final expected = MatrixUtils.transformRect(
      box.getTransformTo(vpBox),
      Offset.zero & box.size,
    );
    expect(slot.mainStart, moreOrLessEquals(expected.top, epsilon: 0.01));
    expect(slot.mainEnd, moreOrLessEquals(expected.bottom, epsilon: 0.01));
    expect(slot.crossStartNow, moreOrLessEquals(expected.left, epsilon: 0.01));

    tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(80);
    await tester.pump();

    geometry.beginPass(viewport: viewport, axisHint: Axis.vertical);
    geometry.ensureMeasured(slot);
    final expected2 = MatrixUtils.transformRect(
      box.getTransformTo(vpBox),
      Offset.zero & box.size,
    );
    expect(slot.mainStart, moreOrLessEquals(expected2.top, epsilon: 0.01));
  });

  testWidgets('SliverToBoxAdapter content uses walk tier and stays correct',
      (tester) async {
    final boxes = <String, RenderBox>{};
    await tester.pumpWidget(_app(
      CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 300,
              child: _Probe(
                onBox: (b) => boxes['header'] = b,
                child: const Text('header'),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => SizedBox(
                height: 100,
                child: _Probe(
                  onBox: (b) => boxes['item$i'] = b,
                  child: Text('item $i'),
                ),
              ),
              childCount: 30,
            ),
          ),
        ],
      ),
    ));

    final geometry = EngineGeometry();
    final viewport = RenderAbstractViewport.of(boxes['header']!);
    geometry.beginPass(viewport: viewport, axisHint: Axis.vertical);

    final headerSlot = ItemSlot<int>(id: 0, registrationOrder: 0)
      ..box = boxes['header']!;
    geometry.ensureMeasured(headerSlot);
    expect(headerSlot.tier, GeometryTier.walk);
    expect(headerSlot.mainStart, moreOrLessEquals(0, epsilon: 0.01));

    // Items in the trailing SliverList still classify fast.
    final itemSlot = ItemSlot<int>(id: 1, registrationOrder: 1)
      ..box = boxes['item0']!;
    geometry.ensureMeasured(itemSlot);
    expect(itemSlot.tier, GeometryTier.fast);
    expect(itemSlot.mainStart, moreOrLessEquals(300, epsilon: 0.01));

    tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(120);
    await tester.pump();

    geometry.beginPass(viewport: viewport, axisHint: Axis.vertical);
    geometry.ensureMeasured(headerSlot);
    expect(headerSlot.tier, GeometryTier.walk);
    expect(headerSlot.mainStart, moreOrLessEquals(-120, epsilon: 0.01));
    geometry.ensureMeasured(itemSlot);
    expect(itemSlot.mainStart, moreOrLessEquals(180, epsilon: 0.01));
  });

  testWidgets('detached box becomes unmeasurable', (tester) async {
    final boxes = <int, RenderBox>{};
    await tester.pumpWidget(_app(
      ListView.builder(
        itemExtent: 100,
        itemCount: 50,
        itemBuilder: (context, i) => _Probe(
          onBox: (b) => boxes[i] = b,
          child: Text('item $i'),
        ),
      ),
    ));

    final geometry = EngineGeometry();
    final viewport = RenderAbstractViewport.of(boxes[0]!);
    geometry.beginPass(viewport: viewport, axisHint: Axis.vertical);
    final slot = ItemSlot<int>(id: 0, registrationOrder: 0)..box = boxes[0]!;
    geometry.ensureMeasured(slot);
    expect(slot.measurable, isTrue);

    // Scroll far so item 0 unmounts and detaches.
    tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .jumpTo(3000);
    await tester.pump();
    expect(boxes[0]!.attached, isFalse);

    geometry.beginPass(viewport: viewport, axisHint: Axis.vertical);
    geometry.ensureMeasured(slot);
    expect(slot.measurable, isFalse);
    expect(slot.distanceToAnchorPx, double.infinity);
  });
}
