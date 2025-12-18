import 'dart:ui' show Rect;

import 'package:flutter/widgets.dart' show Axis;
import 'package:flutter_test/flutter_test.dart';
import 'package:viewport_focus/viewport_focus.dart';

void main() {
  group('ViewportAnchor', () {
    test('fraction resolves from start and includes offsetPx', () {
      const a = ViewportAnchor.fraction(0.5, offsetPx: 10);
      expect(a.resolveFromStart(200), 110);
    });

    test('pixels resolves from start and includes offsetPx', () {
      const a = ViewportAnchor.pixels(40, offsetPx: 12);
      expect(a.resolveFromStart(999), 52);
    });

    test('fraction asserts when out of range', () {
      expect(() => ViewportAnchor.fraction(-0.1), throwsAssertionError);
      expect(() => ViewportAnchor.fraction(1.1), throwsAssertionError);
    });
  });

  group('ViewportFocusRegion.line', () {
    test('thickness=0 focuses when anchor lies within item (inclusive)', () {
      const region = ViewportFocusRegion.line(
        anchor: ViewportAnchor.fraction(0.5),
        thicknessPx: 0.0,
      );

      final viewport = const Rect.fromLTWH(0, 0, 100, 300);
      const axis = Axis.vertical;
      const anchorOffsetPx = 150.0;

      // Item spans 100..200 so anchor 150 is inside => focused.
      const itemRect = Rect.fromLTWH(0, 100, 100, 100);

      final input = ViewportRegionInput(
        itemRectInViewport: itemRect,
        viewportRect: viewport,
        axis: axis,
        anchorOffsetPx: anchorOffsetPx,
      );

      final r = region.evaluate(input);
      expect(r.isFocused, isTrue);
      expect(r.overlapFraction, closeTo(1.0, 1e-9));
      expect(r.focusProgress, closeTo(1.0, 1e-9));
    });

    test('thickness=0 progress hits 0 at item edge', () {
      const region = ViewportFocusRegion.line(
        anchor: ViewportAnchor.fraction(0.5),
        thicknessPx: 0.0,
      );

      final viewport = const Rect.fromLTWH(0, 0, 100, 300);
      const axis = Axis.vertical;
      const anchorOffsetPx = 150.0;

      // Item starts exactly at anchor (150..250) => focused, progress 0.
      const itemRect = Rect.fromLTWH(0, 150, 100, 100);

      final input = ViewportRegionInput(
        itemRectInViewport: itemRect,
        viewportRect: viewport,
        axis: axis,
        anchorOffsetPx: anchorOffsetPx,
      );

      final r = region.evaluate(input);
      expect(r.isFocused, isTrue);
      expect(r.focusProgress, closeTo(0.0, 1e-9));
    });

    test('thickness>0 uses overlap and returns overlapFraction normalized', () {
      const region = ViewportFocusRegion.line(
        anchor: ViewportAnchor.fraction(0.5),
        thicknessPx: 20.0,
      );

      final viewport = const Rect.fromLTWH(0, 0, 100, 300);
      const axis = Axis.vertical;
      const anchorOffsetPx = 150.0;

      // Region is 140..160 (20px thick). Item is 151..251 => overlap 9px.
      const itemRect = Rect.fromLTWH(0, 151, 100, 100);

      final input = ViewportRegionInput(
        itemRectInViewport: itemRect,
        viewportRect: viewport,
        axis: axis,
        anchorOffsetPx: anchorOffsetPx,
      );

      final r = region.evaluate(input);
      expect(r.isFocused, isTrue);
      expect(r.overlapFraction, closeTo(9 / 20, 1e-9));
    });

    test('asserts thicknessPx >= 0', () {
      expect(
        () => ViewportFocusRegion.line(
          anchor: const ViewportAnchor.fraction(0.5),
          thicknessPx: -1,
        ),
        throwsAssertionError,
      );
    });
  });

  group('ViewportFocusRegion.zone', () {
    test('focus + overlapFraction + progress behave as expected', () {
      const region = ViewportFocusRegion.zone(
        anchor: ViewportAnchor.fraction(0.5),
        extentPx: 100.0,
      );

      final viewport = const Rect.fromLTWH(0, 0, 100, 300);
      const axis = Axis.vertical;
      const anchorOffsetPx = 150.0;

      // Zone is 100..200. Item is 125..225 => overlap 75 => fraction 0.75.
      // Item center is 175 => distance 25 => progress 1 - (25/50) = 0.5.
      const itemRect = Rect.fromLTWH(0, 125, 100, 100);

      final input = ViewportRegionInput(
        itemRectInViewport: itemRect,
        viewportRect: viewport,
        axis: axis,
        anchorOffsetPx: anchorOffsetPx,
      );

      final r = region.evaluate(input);
      expect(r.isFocused, isTrue);
      expect(r.overlapFraction, closeTo(0.75, 1e-9));
      expect(r.focusProgress, closeTo(0.5, 1e-9));
    });

    test('asserts extentPx > 0', () {
      expect(
        () => ViewportFocusRegion.zone(
          anchor: const ViewportAnchor.fraction(0.5),
          extentPx: 0,
        ),
        throwsAssertionError,
      );
    });
  });
}
