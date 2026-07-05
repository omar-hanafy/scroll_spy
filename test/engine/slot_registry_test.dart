import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/src/engine/item_slot.dart';
import 'package:scroll_spy/src/engine/slot_registry.dart';

class _FakeBox extends RenderConstrainedBox {
  _FakeBox()
      : super(additionalConstraints: const BoxConstraints.tightFor(width: 1));
}

class _FakeContext extends Fake implements BuildContext {
  @override
  bool get mounted => true;
}

void main() {
  late SlotRegistry<int> registry;
  late BuildContext context;

  setUp(() {
    registry = SlotRegistry<int>();
    context = _FakeContext();
  });

  group('SlotRegistry', () {
    test('register creates slots with increasing registration order', () {
      registry.register(1, context: context, box: _FakeBox());
      registry.register(2, context: context, box: _FakeBox());

      expect(registry.length, 2);
      expect(registry.slotOf(1)!.registrationOrder, 0);
      expect(registry.slotOf(2)!.registrationOrder, 1);
      expect(registry.slots.map((s) => s.id), [1, 2]);
    });

    test('re-register keeps identity/order; invalidates only on box change',
        () {
      final boxA = _FakeBox();
      registry.register(1, context: context, box: boxA);
      final slot = registry.slotOf(1)!;
      slot.tier = GeometryTier.fast;

      // Same box: geometry stays valid.
      registry.register(1, context: context, box: boxA);
      expect(identical(registry.slotOf(1), slot), isTrue);
      expect(slot.tier, GeometryTier.fast);
      expect(slot.registrationOrder, 0);

      // New box: geometry invalidated.
      registry.register(1, context: context, box: _FakeBox());
      expect(identical(registry.slotOf(1), slot), isTrue);
      expect(slot.tier, GeometryTier.unmeasured);
    });

    test('unregister removes the slot', () {
      registry.register(1, context: context, box: _FakeBox());
      registry.unregister(1);
      expect(registry.slotOf(1), isNull);
      expect(registry.length, 0);
    });

    test('mutations during compute are deferred to endCompute', () {
      registry.register(1, context: context, box: _FakeBox());

      registry.beginCompute();
      registry.register(2, context: context, box: _FakeBox());
      registry.unregister(1);
      // Visible state unchanged while computing.
      expect(registry.slotOf(2), isNull);
      expect(registry.slotOf(1), isNotNull);
      registry.endCompute();

      expect(registry.slotOf(1), isNull);
      expect(registry.slotOf(2), isNotNull);
      expect(registry.slots.map((s) => s.id), [2]);
    });

    test('markDead removes at endCompute', () {
      registry.register(1, context: context, box: _FakeBox());
      registry.register(2, context: context, box: _FakeBox());

      registry.beginCompute();
      registry.markDead(registry.slotOf(1)!);
      registry.endCompute();

      expect(registry.slotOf(1), isNull);
      expect(registry.slots.map((s) => s.id), [2]);
    });

    test('invalidateAllGeometry resets every tier', () {
      registry.register(1, context: context, box: _FakeBox());
      registry.register(2, context: context, box: _FakeBox());
      registry.slotOf(1)!.tier = GeometryTier.fast;
      registry.slotOf(2)!.tier = GeometryTier.matrix;

      registry.invalidateAllGeometry();

      expect(registry.slotOf(1)!.tier, GeometryTier.unmeasured);
      expect(registry.slotOf(2)!.tier, GeometryTier.unmeasured);
    });
  });
}
