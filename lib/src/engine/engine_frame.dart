import 'package:flutter/foundation.dart';

import 'package:scroll_spy/src/engine/item_slot.dart';
import 'package:scroll_spy/src/public/scroll_spy_models.dart';

/// Internal engine-to-controller frame.
///
/// The engine reuses one instance across passes and mutates it in place; the
/// id sets are reused buffers that the controller must not retain past the
/// commit call (it copies only when membership actually changed). Immutable
/// public objects ([ScrollSpySnapshot], [ScrollSpyItemFocus]) are materialized
/// lazily, only for state someone listens to.
final class EngineFrame<T> {
  EngineFrame({
    required this.slotOf,
    required this.materializeSnapshot,
  });

  /// Builds a frame (with backing slots) from a public snapshot.
  ///
  /// Test seam: lets controller behavior tests express frames in terms of the
  /// public model types.
  @visibleForTesting
  factory EngineFrame.fromSnapshot(ScrollSpySnapshot<T> snapshot) {
    final Map<T, ItemSlot<T>> slots = <T, ItemSlot<T>>{};
    var order = 0;
    for (final entry in snapshot.items.entries) {
      final focus = entry.value;
      slots[entry.key] = ItemSlot<T>(id: entry.key, registrationOrder: order++)
        ..measurable = true
        ..isVisible = focus.isVisible
        ..isFocused = focus.isFocused
        ..isPrimary = focus.isPrimary
        ..visibleFraction = focus.visibleFraction
        ..distanceToAnchorPx = focus.distanceToAnchorPx
        ..focusProgress = focus.focusProgress
        ..focusOverlapFraction = focus.focusOverlapFraction
        ..itemRectCache = focus.itemRectInViewport
        ..visibleRectCache = focus.visibleRectInViewport;
    }
    final frame = EngineFrame<T>(
      slotOf: (id) => slots[id],
      materializeSnapshot: () => snapshot,
    );
    frame.primaryId = snapshot.primaryId;
    frame.focusedIds = snapshot.focusedIds;
    frame.visibleIds = snapshot.visibleIds;
    return frame;
  }

  /// The selected primary id for this pass, or null.
  T? primaryId;

  /// Ids intersecting the focus region this pass. Reused buffer.
  Set<T> focusedIds = const {};

  /// Ids visible in the viewport this pass. Reused buffer.
  Set<T> visibleIds = const {};

  /// Live slot lookup into the engine registry.
  final ItemSlot<T>? Function(T id) slotOf;

  /// Builds a full public snapshot of the latest committed state.
  final ScrollSpySnapshot<T> Function() materializeSnapshot;
}
