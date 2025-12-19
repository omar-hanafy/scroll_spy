import 'package:flutter/foundation.dart';

import 'package:scroll_spy/src/utils/equality.dart';
import 'package:scroll_spy/src/public/scroll_spy_models.dart';

/// The central hub for accessing and listening to focus state.
///
/// This controller bridges the scope’s engine (`ScrollSpyScope`) and UI
/// code. It provides reactively updated signals for:
/// - The global "primary" item ([primaryId]).
/// - The set of all focused items ([focusedIds]).
/// - Per-item focus details ([itemFocusOf]).
/// - Per-item boolean status ([itemIsPrimaryOf], [itemIsFocusedOf], [itemIsVisibleOf]).
///
/// **Key Behavior:**
/// - **Diff-Only Updates:** The controller receives raw snapshots from the
///   engine but only notifies `primaryId` listeners when the ID actually
///   changes, and `focusedIds` listeners when the set changes (unordered).
///   Per-item listenables are updated using tolerance-aware comparisons to
///   avoid churn from sub-pixel jitter.
/// - **Lazy Lifecycle:** Per-item notifiers are created on demand via
///   [itemFocusOf] or the boolean variants.
/// - **Automatic Eviction:** To prevent memory leaks in infinite scrolling
///   lists, notifiers for items that are no longer tracked by the engine and
///   have no active listeners are automatically disposed/evicted.
///
/// This controller is UI-agnostic; it doesn't know about Widgets or RenderBoxes,
/// making it safe to use in business logic or ViewModels.
class ScrollSpyController<T> {
  /// Creates a controller.
  ///
  /// [initialSnapshot] can be provided to seed UI state before a
  /// `ScrollSpyScope` attaches and starts publishing real frames.
  ScrollSpyController({ScrollSpySnapshot<T>? initialSnapshot})
      : _snapshot = ValueNotifier<ScrollSpySnapshot<T>>(
          initialSnapshot ?? _emptySnapshot<T>(),
        ),
        _primaryId = ValueNotifier<T?>(initialSnapshot?.primaryId),
        _focusedIds = ValueNotifier<Set<T>>(
          Set<T>.unmodifiable(initialSnapshot?.focusedIds ?? const {}),
        ) {
    // Ensure we start with frozen/defensive copies.
    final normalized = _normalizeSnapshot<T>(
      initialSnapshot ?? _emptySnapshot<T>(),
    );

    _snapshot.value = normalized;
    _primaryId.value = normalized.primaryId;
    _focusedIds.value = normalized.focusedIds;
  }

  final ValueNotifier<T?> _primaryId;
  final ValueNotifier<Set<T>> _focusedIds;
  final ValueNotifier<ScrollSpySnapshot<T>> _snapshot;

  final Map<T, _TrackedValueNotifier<ScrollSpyItemFocus<T>>> _itemNotifiers =
      <T, _TrackedValueNotifier<ScrollSpyItemFocus<T>>>{};

  final Map<T, _TrackedValueNotifier<bool>> _itemIsPrimaryNotifiers = {};
  final Map<T, _TrackedValueNotifier<bool>> _itemIsFocusedNotifiers = {};
  final Map<T, _TrackedValueNotifier<bool>> _itemIsVisibleNotifiers = {};

  // Reused scratch to avoid per-frame allocations during eviction.
  final List<T> _evictionScratch = <T>[];

  bool _disposed = false;

  /// A listenable that emits the ID of the current "primary" item.
  ///
  /// The primary item is the single "winner" of the focus selection process,
  /// determined by the active policy (see `ScrollSpyPolicy`).
  ///
  /// This updates only when the ID changes. Returns `null` if no primary is
  /// selected (e.g., empty list, or stability configured to disallow a fallback
  /// primary when no item is focused).
  ValueListenable<T?> get primaryId => _primaryId;

  /// A listenable that emits the set of IDs for all items currently
  /// intersecting the focus region.
  ///
  /// This set is always unmodifiable. Treat it as a set (ordering is not part
  /// of the contract). Use this to highlight multiple items (e.g., "all items
  /// in the center zone"). Updates only when the unordered contents change.
  ValueListenable<Set<T>> get focusedIds => _focusedIds;

  /// A listenable that emits the full computed snapshot of the viewport's focus
  /// state.
  ///
  /// **Performance Warning:** This notifier updates more frequently than
  /// [primaryId]. It may emit new values whenever scroll metrics change (if the
  /// engine is updating per-frame), even if the primary ID hasn't changed. Use
  /// only when you need access to the full state of multiple items
  /// simultaneously.
  ///
  /// In the default engine, a new snapshot is produced on every compute pass
  /// and includes an updated `computedAt` timestamp, so snapshot listeners
  /// should expect frequent notifications.
  ValueListenable<ScrollSpySnapshot<T>> get snapshot => _snapshot;

  /// Returns a listenable for the focus state of a specific item [id].
  ///
  /// - If the item is currently tracked by the engine, the listener will emit
  ///   its live state.
  /// - If the item is unknown (off-screen/unregistered), it will emit
  ///   [ScrollSpyItemFocus.unknown].
  /// - **Memory Management:** The controller tracks the listener count. If an
  ///   item moves off-screen and loses all listeners, its notifier is
  ///   eventually evicted to free memory.
  ///
  /// Per-item notifications use tolerance-aware equality to avoid noisy rebuilds
  /// from tiny scroll jitter.
  ValueListenable<ScrollSpyItemFocus<T>> itemFocusOf(T id) {
    final existing = _itemNotifiers[id];
    if (existing != null) return existing;

    final initial = _snapshot.value.items[id] ?? _initialItemFocus(id);
    final notifier = _TrackedValueNotifier<ScrollSpyItemFocus<T>>(initial);
    _itemNotifiers[id] = notifier;
    return notifier;
  }

  /// Returns a listenable that emits true iff [id] is the current primary item.
  ///
  /// This notifier updates ONLY when the boolean state toggles. It ignores
  /// changes to scroll metrics (e.g., visibleFraction, distanceToAnchor).
  ///
  /// Use this for high-performance widgets that only need to know "am I primary?".
  ValueListenable<bool> itemIsPrimaryOf(T id) {
    final existing = _itemIsPrimaryNotifiers[id];
    if (existing != null) return existing;

    final initial = _snapshot.value.primaryId == id;
    final notifier = _TrackedValueNotifier<bool>(initial);
    _itemIsPrimaryNotifiers[id] = notifier;
    return notifier;
  }

  /// Returns a listenable that emits true iff [id] is currently focused.
  ///
  /// This notifier updates ONLY when the boolean state toggles. It ignores
  /// changes to scroll metrics.
  ///
  /// Use this for high-performance widgets that only need to know "am I focused?".
  ValueListenable<bool> itemIsFocusedOf(T id) {
    final existing = _itemIsFocusedNotifiers[id];
    if (existing != null) return existing;

    final initial = _snapshot.value.focusedIds.contains(id);
    final notifier = _TrackedValueNotifier<bool>(initial);
    _itemIsFocusedNotifiers[id] = notifier;
    return notifier;
  }

  /// Returns a listenable that emits true iff [id] is currently visible.
  ///
  /// This notifier updates ONLY when the boolean state toggles. It ignores
  /// changes to scroll metrics.
  ///
  /// Use this for high-performance widgets that only need to know "am I visible?".
  ValueListenable<bool> itemIsVisibleOf(T id) {
    final existing = _itemIsVisibleNotifiers[id];
    if (existing != null) return existing;

    final initial = _snapshot.value.visibleIds.contains(id);
    final notifier = _TrackedValueNotifier<bool>(initial);
    _itemIsVisibleNotifiers[id] = notifier;
    return notifier;
  }

  /// Returns the current focus state for [id] without creating a new listenable.
  ///
  /// Use this for one-off reads (for example inside a button handler) when you
  /// do not want to allocate and retain a per-item notifier via [itemFocusOf].
  ///
  /// Returns `null` when the item is not present in the latest snapshot and no
  /// per-item notifier exists (meaning the controller has no state to return).
  ScrollSpyItemFocus<T>? tryGetItemFocus(T id) {
    final fromSnapshot = _snapshot.value.items[id];
    if (fromSnapshot != null) return fromSnapshot;

    final fromNotifier = _itemNotifiers[id]?.value;
    return fromNotifier;
  }

  /// Disposes the controller and all managed notifiers.
  ///
  /// Call this when the lifecycle that owns the controller ends (e.g., `dispose` in a State object).
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _primaryId.dispose();
    _focusedIds.dispose();
    _snapshot.dispose();

    _disposeMap(_itemNotifiers);
    _disposeMap(_itemIsPrimaryNotifiers);
    _disposeMap(_itemIsFocusedNotifiers);
    _disposeMap(_itemIsVisibleNotifiers);
  }

  void _disposeMap(Map<dynamic, ValueNotifier> map) {
    for (final notifier in map.values) {
      notifier.dispose();
    }
    map.clear();
  }

  /// Internal entrypoint for the engine to publish the next computed frame.
  ///
  /// This method:
  /// - Freezes/normalizes incoming collections (unmodifiable)
  /// - Updates global listenables only if changed
  /// - Updates per-item listenables only if changed
  /// - Evicts idle notifiers (not active + no listeners) to limit memory growth
  @internal
  void commitFrame(ScrollSpySnapshot<T> nextFrame) {
    if (_disposed) return;

    final next = _normalizeSnapshot<T>(nextFrame);
    final prev = _snapshot.value;

    final nextItems = next.items;

    // 1) Per-item focus notifiers: iterate only tracked listeners (O(listeners)).
    if (_itemNotifiers.isNotEmpty) {
      _evictionScratch.clear();

      _itemNotifiers.forEach((id, notifier) {
        final nextFocus = nextItems[id];
        if (nextFocus != null) {
          if (!scrollSpyItemFocusNearlyEqual<T>(notifier.value, nextFocus)) {
            notifier.value = nextFocus;
          }
        } else {
          // Missing from engine snapshot.
          if (notifier.listenerCount > 0) {
            final unknown = _initialItemFocus(id);
            if (!scrollSpyItemFocusNearlyEqual<T>(notifier.value, unknown)) {
              notifier.value = unknown;
            }
          } else {
            _evictionScratch.add(id);
          }
        }
      });

      for (final id in _evictionScratch) {
        _itemNotifiers.remove(id)?.dispose();
      }
      _evictionScratch.clear();
    }

    // 2) Boolean diffs (O(changed) updates).
    _updateBooleanDiffs(prev, next);

    // 3) Evict boolean notifiers (check usage).
    _evictBoolNotifiersIfMissing(_itemIsPrimaryNotifiers, nextItems);
    _evictBoolNotifiersIfMissing(_itemIsFocusedNotifiers, nextItems);
    _evictBoolNotifiersIfMissing(_itemIsVisibleNotifiers, nextItems);

    // 4) Global primaries/sets: update only if changed.
    if (prev.primaryId != next.primaryId) {
      _primaryId.value = next.primaryId;
    }

    if (!setUnorderedEquals<T>(prev.focusedIds, next.focusedIds)) {
      _focusedIds.value = next.focusedIds;
    }

    // 5) Snapshot: always set (but avoid redundant notifications if equal).
    //
    // Note: Snapshot contains rich, potentially changing metrics (distance/progress).
    // Users opting into snapshot should expect frequent updates.
    _snapshot.value = next;
  }

  void _updateBooleanDiffs(
    ScrollSpySnapshot<T> prev,
    ScrollSpySnapshot<T> next,
  ) {
    // A) Primary Diff
    final prevPrimary = prev.primaryId;
    final nextPrimary = next.primaryId;

    if (prevPrimary != nextPrimary) {
      if (prevPrimary != null) {
        final n = _itemIsPrimaryNotifiers[prevPrimary];
        if (n != null && n.value != false) n.value = false;
      }
      if (nextPrimary != null) {
        final n = _itemIsPrimaryNotifiers[nextPrimary];
        if (n != null && n.value != true) n.value = true;
      }
    }

    // B) Focused Diff
    // Only process diff if we actually track focused listeners.
    if (_itemIsFocusedNotifiers.isNotEmpty) {
      final prevFocused = prev.focusedIds;
      final nextFocused = next.focusedIds;

      if (!identical(prevFocused, nextFocused)) {
        // removed
        for (final id in prevFocused) {
          if (nextFocused.contains(id)) continue;
          final n = _itemIsFocusedNotifiers[id];
          if (n != null && n.value != false) n.value = false;
        }
        // added
        for (final id in nextFocused) {
          if (prevFocused.contains(id)) continue;
          final n = _itemIsFocusedNotifiers[id];
          if (n != null && n.value != true) n.value = true;
        }
      }
    }

    // C) Visible Diff
    if (_itemIsVisibleNotifiers.isNotEmpty) {
      final prevVisible = prev.visibleIds;
      final nextVisible = next.visibleIds;

      if (!identical(prevVisible, nextVisible)) {
        // removed
        for (final id in prevVisible) {
          if (nextVisible.contains(id)) continue;
          final n = _itemIsVisibleNotifiers[id];
          if (n != null && n.value != false) n.value = false;
        }
        // added
        for (final id in nextVisible) {
          if (prevVisible.contains(id)) continue;
          final n = _itemIsVisibleNotifiers[id];
          if (n != null && n.value != true) n.value = true;
        }
      }
    }
  }

  void _evictBoolNotifiersIfMissing(
    Map<T, _TrackedValueNotifier<bool>> notifiers,
    Map<T, ScrollSpyItemFocus<T>> nextItems,
  ) {
    if (notifiers.isEmpty) return;

    _evictionScratch.clear();

    notifiers.forEach((id, notifier) {
      // If the item exists in the current snapshot, keep the notifier alive.
      if (nextItems.containsKey(id)) return;

      if (notifier.listenerCount > 0) {
        // Still listened to, but gone from engine. Reset to "false" (unknown).
        if (notifier.value != false) notifier.value = false;
      } else {
        _evictionScratch.add(id);
      }
    });

    for (final id in _evictionScratch) {
      notifiers.remove(id)?.dispose();
    }
    _evictionScratch.clear();
  }

  static ScrollSpyItemFocus<T> _initialItemFocus<T>(T id) {
    // Default "unknown/offscreen" state.
    return ScrollSpyItemFocus<T>(
      id: id,
      isVisible: false,
      isFocused: false,
      isPrimary: false,
      visibleFraction: 0.0,
      distanceToAnchorPx: double.infinity,
      focusProgress: 0.0,
      focusOverlapFraction: 0.0,
      itemRectInViewport: null,
      visibleRectInViewport: null,
    );
  }

  static ScrollSpySnapshot<T> _emptySnapshot<T>() {
    return ScrollSpySnapshot<T>(
      computedAt: DateTime.fromMillisecondsSinceEpoch(0),
      primaryId: null,
      focusedIds: const {},
      visibleIds: const {},
      items: const {},
    );
  }

  static ScrollSpySnapshot<T> _normalizeSnapshot<T>(
    ScrollSpySnapshot<T> s,
  ) {
    // Freeze sets/maps to avoid accidental external mutation.
    final focused = Set<T>.unmodifiable(s.focusedIds);
    final visible = Set<T>.unmodifiable(s.visibleIds);

    // Ensure items is unmodifiable AND that the map values are trusted immutable.
    final items = Map<T, ScrollSpyItemFocus<T>>.unmodifiable(s.items);

    return ScrollSpySnapshot<T>(
      computedAt: s.computedAt,
      primaryId: s.primaryId,
      focusedIds: focused,
      visibleIds: visible,
      items: items,
    );
  }
}

/// A small [ValueNotifier] variant that tracks how many listeners are attached.
///
/// This is used internally to support safe-ish eviction of per-item notifiers
/// in infinite feeds.
final class _TrackedValueNotifier<T> extends ValueNotifier<T> {
  _TrackedValueNotifier(super.value);

  int _listenerCount = 0;
  int get listenerCount => _listenerCount;

  @override
  void addListener(VoidCallback listener) {
    _listenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listenerCount = (_listenerCount - 1).clamp(0, 1 << 30);
    super.removeListener(listener);
  }
}
