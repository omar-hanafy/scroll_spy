import 'dart:collection';

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

  /// Borrowed read-only view of the measurable focused slots.
  ///
  /// Membership follows the slot flags; no hash storage is rebuilt per pass.
  late final Set<T> focusedIds = _SlotIdSet<T>(this, focused: true);

  /// Borrowed read-only view of the measurable visible slots.
  late final Set<T> visibleIds = _SlotIdSet<T>(this, focused: false);

  /// Dense list in registration order. Iterate in place; do not mutate.
  List<ItemSlot<T>> get slots => _slots;

  /// Number of registered slots.
  int get length => _slots.length;

  /// Returns the slot for [id], or null.
  ItemSlot<T>? slotOf(T id) => _byId[id];

  /// Creates or updates the slot for [id].
  ///
  /// Re-registration preserves slot identity and registration order but
  /// invalidates geometry: a preserved probe may have acquired new ancestors.
  void register(T id, {required BuildContext context, required RenderBox box}) {
    if (_computing) {
      _deferred.add(() => register(id, context: context, box: box));
      return;
    }

    final existing = _byId[id];
    if (existing != null) {
      existing.context = context;
      existing.box = box;
      existing.invalidateGeometry();
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

// Frames borrow these views synchronously. Iterators are needed only when a
// consumer materializes an immutable set/snapshot on the cold path.
final class _SlotIdSet<T> extends SetBase<T> {
  _SlotIdSet(this._registry, {required this._focused});

  final SlotRegistry<T> _registry;
  final bool _focused;

  bool _includes(ItemSlot<T> slot) =>
      slot.measurable && (_focused ? slot.isFocused : slot.isVisible);

  @override
  int get length {
    final slots = _registry.slots;
    var count = 0;
    for (var i = 0; i < slots.length; i++) {
      if (_includes(slots[i])) count++;
    }
    return count;
  }

  @override
  bool contains(Object? element) {
    if (element is! T) return false;
    final slot = _registry.slotOf(element);
    return slot != null && _includes(slot);
  }

  @override
  T? lookup(Object? element) {
    if (element is! T) return null;
    final slot = _registry.slotOf(element);
    return slot != null && _includes(slot) ? slot.id : null;
  }

  @override
  Iterator<T> get iterator => _SlotIdIterator<T>(_registry.slots, _focused);

  @override
  Set<T> toSet() => Set<T>.of(this);

  @override
  bool add(T value) => throw UnsupportedError('Cannot modify slot ID views');

  @override
  bool remove(Object? value) =>
      throw UnsupportedError('Cannot modify slot ID views');

  @override
  void clear() => throw UnsupportedError('Cannot modify slot ID views');
}

final class _SlotIdIterator<T> implements Iterator<T> {
  _SlotIdIterator(this._slots, this._focused);

  final List<ItemSlot<T>> _slots;
  final bool _focused;
  int _index = -1;
  ItemSlot<T>? _current;

  @override
  T get current => _current!.id;

  @override
  bool moveNext() {
    while (++_index < _slots.length) {
      final slot = _slots[_index];
      if (slot.measurable && (_focused ? slot.isFocused : slot.isVisible)) {
        _current = slot;
        return true;
      }
    }
    _current = null;
    return false;
  }
}
