import 'dart:ui' show Rect;

import 'package:flutter/widgets.dart' show Axis;
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';
import 'package:scroll_spy/src/public/scroll_spy_region.dart'
    show RegionScratch;

const _viewport = Rect.fromLTWH(0, 0, 400, 800);

/// Runs both evaluation paths and asserts identical results.
void _expectParity(
  ScrollSpyRegion region, {
  required double itemStart,
  required double itemEnd,
  required double anchorPos,
}) {
  final itemRect = Rect.fromLTRB(0, itemStart, 400, itemEnd);
  final expected = region.evaluate(
    ScrollSpyRegionInput(
      itemRectInViewport: itemRect,
      viewportRect: _viewport,
      axis: Axis.vertical,
      anchorOffsetPx: anchorPos,
    ),
  );

  final out = RegionScratch();
  region.evaluateMainAxisInto(
    out,
    itemStart: itemStart,
    itemEnd: itemEnd,
    anchorPos: anchorPos,
    input: () => ScrollSpyRegionInput(
      itemRectInViewport: itemRect,
      viewportRect: _viewport,
      axis: Axis.vertical,
      anchorOffsetPx: anchorPos,
    ),
  );

  expect(out.isFocused, expected.isFocused,
      reason: 'isFocused for $region item($itemStart..$itemEnd) @$anchorPos');
  expect(out.focusProgress, moreOrLessEquals(expected.focusProgress),
      reason: 'progress for $region item($itemStart..$itemEnd) @$anchorPos');
  expect(out.overlapFraction, moreOrLessEquals(expected.overlapFraction),
      reason: 'overlap for $region item($itemStart..$itemEnd) @$anchorPos');
}

void main() {
  const anchor = ScrollSpyAnchor.fraction(0.5);

  final cases = <({double start, double end})>[
    (start: 0, end: 100), // far before anchor
    (start: 300, end: 500), // spanning the anchor (400)
    (start: 380, end: 420), // small item at anchor
    (start: 395, end: 405), // tiny item at anchor
    (start: 500, end: 700), // after anchor
    (start: 340, end: 360), // near zone edge
    (start: 400, end: 400), // zero-extent item
    (start: 100, end: 900), // larger than viewport, spanning
  ];

  group('evaluateMainAxisInto parity', () {
    test('line thickness 0', () {
      const region = ScrollSpyRegion.line(anchor: anchor);
      for (final c in cases) {
        _expectParity(region,
            itemStart: c.start, itemEnd: c.end, anchorPos: 400);
      }
    });

    test('line thickness 24', () {
      const region = ScrollSpyRegion.line(anchor: anchor, thicknessPx: 24);
      for (final c in cases) {
        _expectParity(region,
            itemStart: c.start, itemEnd: c.end, anchorPos: 400);
      }
    });

    test('zone extent 180', () {
      const region = ScrollSpyRegion.zone(anchor: anchor, extentPx: 180);
      for (final c in cases) {
        _expectParity(region,
            itemStart: c.start, itemEnd: c.end, anchorPos: 400);
      }
    });

    test('custom region receives correct input and results are clamped', () {
      ScrollSpyRegionInput? seen;
      final region = ScrollSpyRegion.custom(
        anchor: anchor,
        evaluator: (input) {
          seen = input;
          return const ScrollSpyRegionResult(
            isFocused: true,
            focusProgress: 1.0,
            overlapFraction: 1.0,
          );
        },
      );

      final out = RegionScratch();
      region.evaluateMainAxisInto(
        out,
        itemStart: 100,
        itemEnd: 200,
        anchorPos: 400,
        input: () => const ScrollSpyRegionInput(
          itemRectInViewport: Rect.fromLTRB(0, 100, 400, 200),
          viewportRect: _viewport,
          axis: Axis.vertical,
          anchorOffsetPx: 400,
        ),
      );

      expect(seen, isNotNull);
      expect(seen!.itemRectInViewport, const Rect.fromLTRB(0, 100, 400, 200));
      expect(seen!.viewportRect, _viewport);
      expect(seen!.anchorOffsetPx, 400);
      expect(out.isFocused, isTrue);
      expect(out.focusProgress, 1.0);
      expect(out.overlapFraction, 1.0);
    });
  });
}
