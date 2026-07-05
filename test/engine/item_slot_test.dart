import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/src/engine/item_slot.dart';

void main() {
  group('ItemSlot', () {
    test('starts unmeasured and unmeasurable', () {
      final slot = ItemSlot<int>(id: 7, registrationOrder: 3);

      expect(slot.id, 7);
      expect(slot.registrationOrder, 3);
      expect(slot.tier, GeometryTier.unmeasured);
      expect(slot.measurable, isFalse);
      expect(slot.isVisible, isFalse);
      expect(slot.isFocused, isFalse);
      expect(slot.isPrimary, isFalse);
    });

    test('invalidateGeometry clears tier and sliver refs, keeps metrics', () {
      final slot = ItemSlot<int>(id: 1, registrationOrder: 0)
        ..tier = GeometryTier.fast
        ..mainStart0 = 120
        ..pixels0 = 40
        ..measurable = true
        ..isVisible = true
        ..visibleFraction = 0.5;

      slot.invalidateGeometry();

      expect(slot.tier, GeometryTier.unmeasured);
      expect(slot.sliver, isNull);
      expect(slot.sliverChild, isNull);
      // Metrics from the last pass survive; only the anchor is invalidated.
      expect(slot.measurable, isTrue);
      expect(slot.isVisible, isTrue);
      expect(slot.visibleFraction, 0.5);
    });

    test('resetMetrics zeroes state but keeps the geometry anchor', () {
      final slot = ItemSlot<int>(id: 1, registrationOrder: 0)
        ..tier = GeometryTier.fast
        ..mainStart0 = 120
        ..measurable = true
        ..isVisible = true
        ..isFocused = true
        ..isPrimary = true
        ..visibleFraction = 1.0
        ..distanceToAnchorPx = 12
        ..focusProgress = 0.8
        ..focusOverlapFraction = 0.6;

      slot.resetMetrics();

      expect(slot.measurable, isFalse);
      expect(slot.isVisible, isFalse);
      expect(slot.isFocused, isFalse);
      expect(slot.isPrimary, isFalse);
      expect(slot.visibleFraction, 0.0);
      expect(slot.distanceToAnchorPx, double.infinity);
      expect(slot.focusProgress, 0.0);
      expect(slot.focusOverlapFraction, 0.0);
      // Anchor untouched.
      expect(slot.tier, GeometryTier.fast);
      expect(slot.mainStart0, 120);
    });
  });
}
