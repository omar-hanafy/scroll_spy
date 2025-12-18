import 'package:viewport_focus/viewport_focus.dart';

/// Creates a deterministic [ViewportItemFocus<int>] for unit tests.
ViewportItemFocus<int> makeFocusItem({
  required int id,
  bool isVisible = true,
  bool isFocused = false,
  bool isPrimary = false,
  double visibleFraction = 1.0,
  double distanceToAnchorPx = 0.0,
  double focusProgress = 1.0,
  double focusOverlapFraction = 1.0,
}) {
  return ViewportItemFocus<int>(
    id: id,
    isVisible: isVisible,
    isFocused: isFocused,
    isPrimary: isPrimary,
    visibleFraction: visibleFraction,
    distanceToAnchorPx: distanceToAnchorPx,
    focusProgress: focusProgress,
    focusOverlapFraction: focusOverlapFraction,
    itemRectInViewport: null,
    visibleRectInViewport: null,
  );
}

/// Creates a deterministic [ViewportFocusSnapshot<int>] for unit tests.
ViewportFocusSnapshot<int> makeSnapshot({
  DateTime? computedAt,
  int? primaryId,
  Set<int> focusedIds = const <int>{},
  Set<int> visibleIds = const <int>{},
  Map<int, ViewportItemFocus<int>> items =
      const <int, ViewportItemFocus<int>>{},
}) {
  return ViewportFocusSnapshot<int>(
    computedAt: computedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    primaryId: primaryId,
    focusedIds: Set<int>.from(focusedIds),
    visibleIds: Set<int>.from(visibleIds),
    items: Map<int, ViewportItemFocus<int>>.from(items),
  );
}
