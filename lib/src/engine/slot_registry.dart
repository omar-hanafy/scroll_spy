import 'package:flutter/widgets.dart';

import 'package:scroll_spy/src/engine/item_slot.dart';

/// Owns the [ItemSlot]s of a scope.
///
/// The registry keeps a dense list in registration order that the engine
/// iterates in place on every compute pass (no per-pass copies). Mutations
/// requested while a compute pass is running are deferred and applied at
/// [endCompute], so the iteration is never invalidated mid-pass.
final class SlotRegistry<T> {
  final Map<T, ItemSlot<T>> _byId = <T, ItemSlot<T>>{};
  final List<ItemSlot<T>> _slots = <ItemSlot<T>>[];

  int _nextOrder = 0;
  bool _computing = false;

  final List<void Function()> _deferred = <void Function()>[];
  final List<ItemSlot<T>> _dead = <ItemSlot<T>>[];

  /// Dense list in registration order. Iterate in place; do not mutate.
  List<ItemSlot<T>> get slots => _slots;

  /// Number of registered slots.
  int get length => _slots.length;

  /// Returns the slot for [id], or null.
  ItemSlot<T>? slotOf(T id) => _byId[id];

  /// Creates or updates the slot for [id].
  ///
  /// Re-registration preserves slot identity and registration order. Geometry
  /// is invalidated only when the probe [box] instance changed.
  void register(T id, {required BuildContext context, required RenderBox box}) {
    if (_computing) {
      _deferred.add(() => register(id, context: context, box: box));
      return;
    }

    final existing = _byId[id];
    if (existing != null) {
      existing.context = context;
      if (!identical(existing.box, box)) {
        existing.box = box;
        existing.invalidateGeometry();
      }
      return;
    }

    final slot = ItemSlot<T>(id: id, registrationOrder: _nextOrder++)
      ..context = context
      ..box = box;
    _byId[id] = slot;
    _slots.add(slot);
  }

  /// Removes the slot for [id].
  void unregister(T id) {
    if (_computing) {
      _deferred.add(() => unregister(id));
      return;
    }

    final slot = _byId.remove(id);
    if (slot != null) _slots.remove(slot);
  }

  /// Enters compute mode: mutations are deferred until [endCompute].
  void beginCompute() {
    assert(!_computing, 'beginCompute called while already computing');
    _computing = true;
  }

  /// Marks [slot] for removal at [endCompute] (unmounted pruning).
  void markDead(ItemSlot<T> slot) {
    assert(_computing, 'markDead is only valid during a compute pass');
    _dead.add(slot);
  }

  /// Leaves compute mode and applies deferred mutations and pruning.
  void endCompute() {
    assert(_computing, 'endCompute called without beginCompute');
    _computing = false;

    if (_dead.isNotEmpty) {
      for (final slot in _dead) {
        final current = _byId[slot.id];
        if (identical(current, slot)) {
          _byId.remove(slot.id);
          _slots.remove(slot);
        }
      }
      _dead.clear();
    }

    if (_deferred.isNotEmpty) {
      // Applying can enqueue nothing further: we are out of compute mode.
      final actions = List<void Function()>.of(_deferred);
      _deferred.clear();
      for (final action in actions) {
        action();
      }
    }
  }

  /// Drops every geometry anchor (viewport/metrics-level invalidation).
  void invalidateAllGeometry() {
    for (final slot in _slots) {
      slot.invalidateGeometry();
    }
  }
}
