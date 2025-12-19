import 'dart:collection';

import 'package:flutter/widgets.dart';

/// Registry for focus items inside a `ScrollSpyScope`.
///
/// Stores:
/// - item id
/// - a [RenderBox] (probe) used for geometry.
/// - a [BuildContext] for axis inference (via [Scrollable.maybeOf]).
/// - a stable registration order for deterministic tie-breaking.
class ScrollSpyRegistry<T> {
  /// Creates an empty registry with deterministic insertion order.
  ScrollSpyRegistry() : _entries = LinkedHashMap<T, ScrollSpyRegistryEntry<T>>();

  final LinkedHashMap<T, ScrollSpyRegistryEntry<T>> _entries;

  int _nextOrder = 0;

  /// Registers (or updates) an item entry.
  ///
  /// If [id] is already registered, the existing entry is updated with the new
  /// [context] and [box] **without** changing its original [registrationOrder].
  /// Keeping the order stable ensures deterministic selection when multiple
  /// candidates tie on the configured policy metrics.
  void register(T id, {required BuildContext context, required RenderBox box}) {
    final existing = _entries[id];
    if (existing != null) {
      // Preserve registration order for determinism; update context.
      _entries[id] = existing.copyWith(context: context, box: box);
      return;
    }

    _entries[id] = ScrollSpyRegistryEntry<T>(
      id: id,
      context: context,
      box: box,
      registrationOrder: _nextOrder++,
    );
  }

  /// Unregisters an item entry.
  ///
  /// After removal, the engine will no longer attempt to measure or select this
  /// item in subsequent compute passes.
  void unregister(T id) {
    _entries.remove(id);
  }

  /// Returns the current registry entry for [id], or `null` if not registered.
  ScrollSpyRegistryEntry<T>? entryOf(T id) => _entries[id];

  /// Stable snapshot in registration order.
  List<ScrollSpyRegistryEntry<T>> entriesSnapshot() =>
      _entries.values.toList(growable: false);

  /// Removes entries whose contexts are unmounted or whose render objects are
  /// detached.
  ///
  /// This is called by the engine as a safety net to prevent stale entries from
  /// accumulating in long/infinite scrolling lists.
  void pruneUnmounted() {
    if (_entries.isEmpty) return;

    final List<T> toRemove = <T>[];
    _entries.forEach((key, entry) {
      if (!entry.context.mounted || !entry.box.attached) toRemove.add(key);
    });

    for (final key in toRemove) {
      _entries.remove(key);
    }
  }
}

/// A single registered focus entry (ID + geometry probe).
class ScrollSpyRegistryEntry<T> {
  /// Creates a registry entry for a single item probe.
  const ScrollSpyRegistryEntry({
    required this.id,
    required this.context,
    required this.box,
    required this.registrationOrder,
  });

  /// The item identifier used by the focus scope/controller.
  final T id;

  /// A context associated with the item subtree.
  ///
  /// The engine uses this for `mounted` checks and to infer axis information
  /// when scroll notifications are not available.
  final BuildContext context;

  /// The render object used for measuring geometry.
  final RenderBox box;

  /// Stable monotonic order assigned on first registration.
  ///
  /// This is used as a deterministic tie-breaker in selection logic.
  final int registrationOrder;

  /// Creates a copy with updated [context]/[box] while preserving identity and
  /// [registrationOrder].
  ScrollSpyRegistryEntry<T> copyWith({BuildContext? context, RenderBox? box}) {
    return ScrollSpyRegistryEntry<T>(
      id: id,
      context: context ?? this.context,
      box: box ?? this.box,
      registrationOrder: registrationOrder,
    );
  }
}
