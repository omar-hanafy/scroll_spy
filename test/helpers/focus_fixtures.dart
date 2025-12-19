import 'package:scroll_spy/scroll_spy.dart';

/// Creates a deterministic [ScrollSpyItemFocus<int>] for unit tests.
ScrollSpyItemFocus<int> makeFocusItem({
  required int id,
  bool isVisible = true,
  bool isFocused = false,
  bool isPrimary = false,
  double visibleFraction = 1.0,
  double distanceToAnchorPx = 0.0,
  double focusProgress = 1.0,
  double focusOverlapFraction = 1.0,
}) {
  return ScrollSpyItemFocus<int>(
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

/// Creates a deterministic [ScrollSpySnapshot<int>] for unit tests.
ScrollSpySnapshot<int> makeSnapshot({
  DateTime? computedAt,
  int? primaryId,
  Set<int> focusedIds = const <int>{},
  Set<int> visibleIds = const <int>{},
  Map<int, ScrollSpyItemFocus<int>> items =
      const <int, ScrollSpyItemFocus<int>>{},
}) {
  return ScrollSpySnapshot<int>(
    computedAt: computedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    primaryId: primaryId,
    focusedIds: Set<int>.from(focusedIds),
    visibleIds: Set<int>.from(visibleIds),
    items: Map<int, ScrollSpyItemFocus<int>>.from(items),
  );
}
