import 'package:flutter/foundation.dart';

import 'package:viewport_focus/src/utils/equality.dart';
import 'package:viewport_focus/src/public/viewport_focus_models.dart';

/// The central hub for accessing and listening to focus state.
///
/// This controller bridges the scope’s engine (`ViewportFocusScope`) and UI
/// code. It provides reactively updated signals for:
/// - The global "primary" item ([primaryId]).
/// - The set of all focused items ([focusedIds]).
/// - Per-item focus details ([itemFocusOf]).
///
/// **Key Behavior:**
/// - **Diff-Only Updates:** The controller receives raw snapshots from the
///   engine but only notifies `primaryId` listeners when the ID actually
///   changes, and `focusedIds` listeners when the set changes (unordered).
///   Per-item listenables are updated using tolerance-aware comparisons to
///   avoid churn from sub-pixel jitter.
/// - **Lazy Lifecycle:** Per-item notifiers are created on demand via
///   [itemFocusOf].
/// - **Automatic Eviction:** To prevent memory leaks in infinite scrolling
///   lists, notifiers for items that are no longer tracked by the engine and
///   have no active listeners are automatically disposed/evicted.
///
/// This controller is UI-agnostic; it doesn't know about Widgets or RenderBoxes,
/// making it safe to use in business logic or ViewModels.
class ViewportFocusController<T> {
  /// Creates a controller.
  ///
  /// [initialSnapshot] can be provided to seed UI state before a
  /// `ViewportFocusScope` attaches and starts publishing real frames.
  ViewportFocusController({ViewportFocusSnapshot<T>? initialSnapshot})
      : _snapshot = ValueNotifier<ViewportFocusSnapshot<T>>(
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
  final ValueNotifier<ViewportFocusSnapshot<T>> _snapshot;

  final Map<T, _TrackedValueNotifier<ViewportItemFocus<T>>> _itemNotifiers =
      <T, _TrackedValueNotifier<ViewportItemFocus<T>>>{};

  bool _disposed = false;

  /// A listenable that emits the ID of the current "primary" item.
  ///
  /// The primary item is the single "winner" of the focus selection process,
  /// determined by the active policy (see `ViewportFocusPolicy`).
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
  ValueListenable<ViewportFocusSnapshot<T>> get snapshot => _snapshot;

  /// Returns a listenable for the focus state of a specific item [id].
  ///
  /// - If the item is currently tracked by the engine, the listener will emit
  ///   its live state.
  /// - If the item is unknown (off-screen/unregistered), it will emit
  ///   [ViewportItemFocus.unknown].
  /// - **Memory Management:** The controller tracks the listener count. If an
  ///   item moves off-screen and loses all listeners, its notifier is
  ///   eventually evicted to free memory.
  ///
  /// Per-item notifications use tolerance-aware equality to avoid noisy rebuilds
  /// from tiny scroll jitter.
  ValueListenable<ViewportItemFocus<T>> itemFocusOf(T id) {
    final existing = _itemNotifiers[id];
    if (existing != null) return existing;

    final initial = _snapshot.value.items[id] ?? _initialItemFocus(id);
    final notifier = _TrackedValueNotifier<ViewportItemFocus<T>>(initial);
    _itemNotifiers[id] = notifier;
    return notifier;
  }

  /// Returns the current focus state for [id] without creating a new listenable.
  ///
  /// Use this for one-off reads (for example inside a button handler) when you
  /// do not want to allocate and retain a per-item notifier via [itemFocusOf].
  ///
  /// Returns `null` when the item is not present in the latest snapshot and no
  /// per-item notifier exists (meaning the controller has no state to return).
  ViewportItemFocus<T>? tryGetItemFocus(T id) {
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

    for (final notifier in _itemNotifiers.values) {
      notifier.dispose();
    }
    _itemNotifiers.clear();
  }

  /// Internal entrypoint for the engine to publish the next computed frame.
  ///
  /// This method:
  /// - Freezes/normalizes incoming collections (unmodifiable)
  /// - Updates global listenables only if changed
  /// - Updates per-item listenables only if changed
  /// - Evicts idle notifiers (not active + no listeners) to limit memory growth
  @internal
  void commitFrame(ViewportFocusSnapshot<T> nextFrame) {
    if (_disposed) return;

    final next = _normalizeSnapshot<T>(nextFrame);
    final prev = _snapshot.value;

    // 1) Per-item notifiers: update only changed.
    final nextItems = next.items;
    for (final entry in nextItems.entries) {
      final notifier = _itemNotifiers[entry.key];
      if (notifier == null) continue;

      final nextFocus = entry.value;
      final prevFocus = notifier.value;
      if (!viewportItemFocusNearlyEqual<T>(prevFocus, nextFocus)) {
        notifier.value = nextFocus;
      }
    }

    // 1b) Handle ids that are no longer tracked by the engine.
    //
    // - If there are still listeners, publish an "unknown" state.
    // - If there are no listeners, evict the notifier to keep memory bounded.
    if (_itemNotifiers.isNotEmpty) {
      final List<T> toEvict = <T>[];

      _itemNotifiers.forEach((id, notifier) {
        if (nextItems.containsKey(id)) return;

        if (notifier.listenerCount > 0) {
          final unknown = _initialItemFocus(id);
          if (!viewportItemFocusNearlyEqual<T>(notifier.value, unknown)) {
            notifier.value = unknown;
          }
        } else {
          toEvict.add(id);
        }
      });

      for (final id in toEvict) {
        _itemNotifiers.remove(id)?.dispose();
      }
    }

    // 2) Global primaries/sets: update only if changed.
    if (prev.primaryId != next.primaryId) {
      _primaryId.value = next.primaryId;
    }

    if (!setUnorderedEquals<T>(prev.focusedIds, next.focusedIds)) {
      _focusedIds.value = next.focusedIds;
    }

    // 3) Snapshot: always set (but avoid redundant notifications if equal).
    //
    // Note: Snapshot contains rich, potentially changing metrics (distance/progress).
    // Users opting into snapshot should expect frequent updates.
    _snapshot.value = next;
  }

  static ViewportItemFocus<T> _initialItemFocus<T>(T id) {
    // Default "unknown/offscreen" state.
    return ViewportItemFocus<T>(
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

  static ViewportFocusSnapshot<T> _emptySnapshot<T>() {
    return ViewportFocusSnapshot<T>(
      computedAt: DateTime.fromMillisecondsSinceEpoch(0),
      primaryId: null,
      focusedIds: const {},
      visibleIds: const {},
      items: const {},
    );
  }

  static ViewportFocusSnapshot<T> _normalizeSnapshot<T>(
    ViewportFocusSnapshot<T> s,
  ) {
    // Freeze sets/maps to avoid accidental external mutation.
    final focused = Set<T>.unmodifiable(s.focusedIds);
    final visible = Set<T>.unmodifiable(s.visibleIds);

    // Ensure items is unmodifiable AND that the map values are trusted immutable.
    final items = Map<T, ViewportItemFocus<T>>.unmodifiable(s.items);

    return ViewportFocusSnapshot<T>(
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
