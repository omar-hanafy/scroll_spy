import 'package:flutter/foundation.dart';

import 'package:scroll_spy/src/engine/engine_frame.dart';
import 'package:scroll_spy/src/engine/item_slot.dart';
import 'package:scroll_spy/src/public/scroll_spy_models.dart';
import 'package:scroll_spy/src/utils/equality.dart';

/// The central hub for accessing and listening to focus state.
///
/// This controller bridges the scope's engine (`ScrollSpyScope`) and UI
/// code. It provides reactively updated signals for:
/// - The global "primary" item ([primaryId]).
/// - The set of all focused items ([focusedIds]).
/// - Per-item focus details ([itemFocusOf]).
/// - Per-item boolean status ([itemIsPrimaryOf], [itemIsFocusedOf], [itemIsVisibleOf]).
///
/// **Key Behavior:**
/// - **Diff-Only Updates:** `primaryId` notifies only when the id changes and
///   `focusedIds` only when the unordered membership changes. Per-item
///   listenables use tolerance-aware comparisons so sub-pixel jitter never
///   causes rebuilds.
/// - **Lazy Materialization:** Immutable objects ([ScrollSpySnapshot],
///   [ScrollSpyItemFocus]) are constructed only for state someone actually
///   listens to. With no snapshot listeners, committing a frame allocates no
///   snapshot at all; reading [snapshot]`.value` materializes on demand.
/// - **Lazy Lifecycle:** Per-item notifiers are created on demand and
///   automatically evicted once the item leaves tracking and has no
///   listeners, so infinite feeds cannot leak.
///
/// This controller is UI-agnostic; it doesn't know about Widgets or
/// RenderBoxes, making it safe to use in business logic or ViewModels.
class ScrollSpyController<T> {
  /// Creates a controller.
  ///
  /// [initialSnapshot] can be provided to seed UI state before a
  /// `ScrollSpyScope` attaches and starts publishing real frames.
  ScrollSpyController({ScrollSpySnapshot<T>? initialSnapshot}) {
    final ScrollSpySnapshot<T> initial =
        initialSnapshot ?? ScrollSpySnapshot<T>.empty();
    _snapshot = _LazySnapshotNotifier<T>(initial, _materializeLatest);
    _primaryId = ValueNotifier<T?>(initial.primaryId);
    _focusedIds = ValueNotifier<Set<T>>(Set<T>.unmodifiable(initial.focusedIds));
  }

  late final ValueNotifier<T?> _primaryId;
  late final ValueNotifier<Set<T>> _focusedIds;
  late final _LazySnapshotNotifier<T> _snapshot;

  EngineFrame<T>? _lastFrame;

  final Map<T, _TrackedValueNotifier<ScrollSpyItemFocus<T>>> _itemNotifiers =
      <T, _TrackedValueNotifier<ScrollSpyItemFocus<T>>>{};

  final Map<T, _TrackedValueNotifier<bool>> _itemIsPrimaryNotifiers = {};
  final Map<T, _TrackedValueNotifier<bool>> _itemIsFocusedNotifiers = {};
  final Map<T, _TrackedValueNotifier<bool>> _itemIsVisibleNotifiers = {};

  // Reused scratch to avoid per-frame allocations during eviction.
  final List<T> _evictionScratch = <T>[];

  bool _disposed = false;

  /// Number of full snapshots materialized so far (laziness invariant hook).
  @visibleForTesting
  int debugMaterializedSnapshots = 0;

  /// Number of [ScrollSpyItemFocus] instances materialized for per-item
  /// notifiers so far (laziness invariant hook).
  @visibleForTesting
  int debugMaterializedItemFocus = 0;

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
  /// of the contract). Updates only when the unordered contents change.
  ValueListenable<Set<T>> get focusedIds => _focusedIds;

  /// A listenable that emits the full computed snapshot of the viewport's
  /// focus state.
  ///
  /// **Performance Warning:** With listeners attached, this notifies on every
  /// compute pass. Snapshots are materialized lazily: if nobody listens,
  /// commits cost nothing here and reading `value` builds the snapshot on
  /// demand from the latest engine state. `computedAt` reflects when the
  /// snapshot instance was materialized.
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
  /// Per-item notifications use tolerance-aware equality to avoid noisy
  /// rebuilds from tiny scroll jitter.
  ValueListenable<ScrollSpyItemFocus<T>> itemFocusOf(T id) {
    final existing = _itemNotifiers[id];
    if (existing != null) return existing;

    final notifier =
        _TrackedValueNotifier<ScrollSpyItemFocus<T>>(_currentFocusOf(id));
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

    final notifier = _TrackedValueNotifier<bool>(_primaryId.value == id);
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

    final notifier =
        _TrackedValueNotifier<bool>(_focusedIds.value.contains(id));
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

    final frame = _lastFrame;
    final bool initial = frame != null
        ? (frame.slotOf(id)?.isVisible ?? false)
        : _snapshot.value.visibleIds.contains(id);
    final notifier = _TrackedValueNotifier<bool>(initial);
    _itemIsVisibleNotifiers[id] = notifier;
    return notifier;
  }

  /// Returns the current focus state for [id] without creating a listenable.
  ///
  /// Use this for one-off reads (for example inside a button handler) when you
  /// do not want to allocate and retain a per-item notifier via [itemFocusOf].
  ///
  /// Returns `null` when the item is not tracked and no per-item notifier
  /// exists (meaning the controller has no state to return).
  ScrollSpyItemFocus<T>? tryGetItemFocus(T id) {
    final frame = _lastFrame;
    final slot = frame?.slotOf(id);
    if (slot != null && slot.measurable) {
      return slot.toItemFocus(
        itemRect: slot.itemRectCache,
        visibleRect: slot.visibleRectCache,
      );
    }

    final fromNotifier = _itemNotifiers[id]?.value;
    if (fromNotifier != null) return fromNotifier;

    // Before the first commit, serve reads from the initial snapshot seed.
    if (frame == null) return _snapshot.value.items[id];
    return null;
  }

  /// Disposes the controller and all managed notifiers.
  ///
  /// Call this when the lifecycle that owns the controller ends (e.g.,
  /// `dispose` in a State object).
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

  void _disposeMap(Map<dynamic, ValueNotifier<Object?>> map) {
    for (final notifier in map.values) {
      notifier.dispose();
    }
    map.clear();
  }

  /// Internal entrypoint for the engine to publish the next computed frame.
  ///
  /// Fan-out is diff-only and lazy:
  /// - global listenables update only on change;
  /// - per-item listenables update only past tolerance;
  /// - immutable objects are materialized only for active listeners;
  /// - idle notifiers for untracked items are evicted.
  @internal
  void commit(EngineFrame<T> frame) {
    if (_disposed) return;
    _lastFrame = frame;

    // 1) Per-item focus notifiers.
    if (_itemNotifiers.isNotEmpty) {
      _evictionScratch.clear();
      _itemNotifiers.forEach((id, notifier) {
        final slot = frame.slotOf(id);
        if (slot != null && slot.measurable) {
          if (!_slotMatchesFocus(slot, notifier.value)) {
            debugMaterializedItemFocus++;
            notifier.value = slot.toItemFocus(
              itemRect: slot.itemRectCache,
              visibleRect: slot.visibleRectCache,
            );
          }
        } else if (notifier.listenerCount > 0) {
          if (!_isUnknownFocus(notifier.value)) {
            notifier.value = ScrollSpyItemFocus<T>.unknown(id: id);
          }
        } else {
          _evictionScratch.add(id);
        }
      });
      for (final id in _evictionScratch) {
        _itemNotifiers.remove(id)?.dispose();
      }
      _evictionScratch.clear();
    }

    // 2) Per-item boolean notifiers.
    _syncBoolMap(_itemIsPrimaryNotifiers, frame, _BoolSignal.primary);
    _syncBoolMap(_itemIsFocusedNotifiers, frame, _BoolSignal.focused);
    _syncBoolMap(_itemIsVisibleNotifiers, frame, _BoolSignal.visible);

    // 3) Global signals: update only on change. The focused set is copied
    // only when membership actually changed (the frame set is a reused
    // engine buffer).
    if (_primaryId.value != frame.primaryId) {
      _primaryId.value = frame.primaryId;
    }
    if (!setUnorderedEquals<T>(_focusedIds.value, frame.focusedIds)) {
      _focusedIds.value = Set<T>.unmodifiable(frame.focusedIds);
    }

    // 4) Snapshot: materialize only for active listeners; otherwise leave a
    // stale marker so `.value` materializes on demand.
    if (_snapshot.isListenedTo) {
      debugMaterializedSnapshots++;
      _snapshot.setLive(frame.materializeSnapshot());
    } else {
      _snapshot.markStale();
    }
  }

  void _syncBoolMap(
    Map<T, _TrackedValueNotifier<bool>> notifiers,
    EngineFrame<T> frame,
    _BoolSignal signal,
  ) {
    if (notifiers.isEmpty) return;

    _evictionScratch.clear();
    notifiers.forEach((id, notifier) {
      final slot = frame.slotOf(id);
      if (slot != null && slot.measurable) {
        final bool next = switch (signal) {
          _BoolSignal.primary => slot.isPrimary,
          _BoolSignal.focused => slot.isFocused,
          _BoolSignal.visible => slot.isVisible,
        };
        if (notifier.value != next) notifier.value = next;
      } else if (notifier.listenerCount > 0) {
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

  ScrollSpyItemFocus<T> _currentFocusOf(T id) {
    final frame = _lastFrame;
    final slot = frame?.slotOf(id);
    if (slot != null && slot.measurable) {
      debugMaterializedItemFocus++;
      return slot.toItemFocus(
        itemRect: slot.itemRectCache,
        visibleRect: slot.visibleRectCache,
      );
    }
    if (frame == null) {
      final seeded = _snapshot.value.items[id];
      if (seeded != null) return seeded;
    }
    return ScrollSpyItemFocus<T>.unknown(id: id);
  }

  ScrollSpySnapshot<T> _materializeLatest() {
    debugMaterializedSnapshots++;
    return _lastFrame!.materializeSnapshot();
  }

  bool _slotMatchesFocus(ItemSlot<T> slot, ScrollSpyItemFocus<T> focus) {
    return focus.isVisible == slot.isVisible &&
        focus.isFocused == slot.isFocused &&
        focus.isPrimary == slot.isPrimary &&
        nearlyEqual(
          focus.visibleFraction,
          slot.visibleFraction,
          epsilon: kScrollSpyDefaultEpsilonFraction,
        ) &&
        nearlyEqual(
          focus.distanceToAnchorPx,
          slot.distanceToAnchorPx,
          epsilon: kScrollSpyDefaultEpsilonPx,
        ) &&
        nearlyEqual(
          focus.focusProgress,
          slot.focusProgress,
          epsilon: kScrollSpyDefaultEpsilonFraction,
        ) &&
        nearlyEqual(
          focus.focusOverlapFraction,
          slot.focusOverlapFraction,
          epsilon: kScrollSpyDefaultEpsilonFraction,
        ) &&
        rectNearlyEqual(
          focus.itemRectInViewport,
          slot.itemRectCache,
          epsilon: kScrollSpyDefaultEpsilonPx,
        ) &&
        rectNearlyEqual(
          focus.visibleRectInViewport,
          slot.visibleRectCache,
          epsilon: kScrollSpyDefaultEpsilonPx,
        );
  }

  static bool _isUnknownFocus<T>(ScrollSpyItemFocus<T> f) {
    return !f.isVisible &&
        !f.isFocused &&
        !f.isPrimary &&
        f.visibleFraction == 0.0 &&
        f.distanceToAnchorPx == double.infinity &&
        f.focusProgress == 0.0 &&
        f.focusOverlapFraction == 0.0 &&
        f.itemRectInViewport == null &&
        f.visibleRectInViewport == null;
  }
}

enum _BoolSignal { primary, focused, visible }

/// Snapshot listenable with lazy materialization.
///
/// While listeners exist, commits push live snapshots and notify per pass.
/// Without listeners, commits only mark the value stale; the getter
/// materializes from the latest engine state on demand.
final class _LazySnapshotNotifier<T> extends ChangeNotifier
    implements ValueListenable<ScrollSpySnapshot<T>> {
  _LazySnapshotNotifier(this._value, this._materialize);

  ScrollSpySnapshot<T> _value;
  final ScrollSpySnapshot<T> Function() _materialize;
  bool _stale = false;

  bool get isListenedTo => hasListeners;

  void markStale() => _stale = true;

  void setLive(ScrollSpySnapshot<T> next) {
    _stale = false;
    _value = next;
    notifyListeners();
  }

  @override
  ScrollSpySnapshot<T> get value {
    if (_stale) {
      _stale = false;
      _value = _materialize();
    }
    return _value;
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
