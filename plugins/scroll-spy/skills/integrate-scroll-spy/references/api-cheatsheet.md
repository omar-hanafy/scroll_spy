# scroll_spy 1.x API cheatsheet

Verified against scroll_spy 1.0.x source. Import: `package:scroll_spy/scroll_spy.dart`.

## Scope

```dart
ScrollSpyScope<T>({
  required ScrollSpyController<T> controller,   // focus controller (read side)
  required ScrollSpyRegion region,
  required ScrollSpyPolicy<T> policy,
  ScrollSpyStability stability = const ScrollSpyStability(),
  ScrollSpyUpdatePolicy updatePolicy = const ScrollSpyUpdatePolicy.perFrame(),
  EdgeInsets viewportInsets = EdgeInsets.zero,  // deflate for pinned headers/overlays
  bool insetsAffectVisibility = true,           // covered items not visible/focused
  ScrollController? scrollController,           // observe programmatic jumps
  int notificationDepth = 0,                    // 0 = immediate child scrollable
  bool Function(ScrollNotification)? notificationPredicate,
  bool Function(ScrollMetricsNotification)? metricsNotificationPredicate,
  bool debug = false,                           // paints overlay + enables debug frames
  ScrollSpyDebugConfig? debugConfig,
  required Widget child,
})
```

Wrappers `ScrollSpyListView.builder/.separated`, `ScrollSpyGridView.builder`,
`ScrollSpyCustomScrollView`, `ScrollSpyPageView.builder` take all scope
params plus the mirrored Flutter-constructor params, and wire
`scrollController`/`pageController` to both the view and the scope.
`.separated` adds `findItemIndexCallback` (item indices; do not combine with
`findChildIndexCallback`). `ScrollSpyPageView.builder` supports
`viewportFraction`.

## Items

```dart
ScrollSpyItem<T>({ required T id,
  required Widget Function(BuildContext, ScrollSpyItemFocus<T>, Widget?) builder,
  Widget? child })                    // rebuilds on metric changes (tolerance-gated)

ScrollSpyItemLite<T>({ required T id,
  required Widget Function(BuildContext, bool isPrimary, bool isFocused, Widget?) builder,
  Widget? child })                    // rebuilds only on boolean flips
```

Both are widgets with `key` params, register in a post-frame callback, and
must sit under a `ScrollSpyScope<T>` with the same `T` (debug assert;
release: silent no-op).

## Controller (read side)

```dart
final spy = ScrollSpyController<T>({ScrollSpySnapshot<T>? initialSnapshot});
spy.primaryId;          // ValueListenable<T?>            fires on id change
spy.focusedIds;         // ValueListenable<Set<T>>        fires on membership change
spy.snapshot;           // ValueListenable<ScrollSpySnapshot<T>>  fires EVERY pass (lazy when unheard)
spy.itemFocusOf(id);    // ValueListenable<ScrollSpyItemFocus<T>> tolerance-gated
spy.itemIsPrimaryOf(id) / itemIsFocusedOf(id) / itemIsVisibleOf(id); // ValueListenable<bool>
spy.tryGetItemFocus(id);// one-off read; no notifier allocated; null if untracked
spy.dispose();          // required
```

Per-item notifiers are lazy, diff-only, and auto-evicted when the item is
untracked and unheard. Listeners fire on transitions only (no initial call).

## Per-item state: ScrollSpyItemFocus<T>

`id`, `isVisible` (in viewport), `isFocused` (intersects region),
`isPrimary` (the single winner), `visibleFraction` 0..1,
`distanceToAnchorPx` (signed; negative = before anchor;
`absDistanceToAnchorPx` helper), `focusProgress` 0..1 (center-closeness;
drive scale/opacity), `focusOverlapFraction` 0..1 (region-band coverage),
`itemRectInViewport`/`visibleRectInViewport` (null unless debug rect
capture), `nearlyEquals(other)`.

`ScrollSpySnapshot<T>`: `computedAt` (materialization time), `primaryId`,
`focusedIds`, `visibleIds`, `items: Map<T, ScrollSpyItemFocus<T>>` (every
measurable item), `itemOf(id)`, `hasPrimary`.

## Regions and anchors

```dart
ScrollSpyAnchor.fraction(0.5)                  // 0=start 1=end; optional offsetPx
ScrollSpyAnchor.pixels(120)                    // px from viewport start; optional offsetPx
ScrollSpyRegion.zone({required anchor, required double extentPx})   // band; extentPx > 0
ScrollSpyRegion.line({required anchor, double thicknessPx = 0})     // 0 = infinitesimal
ScrollSpyRegion.custom({required anchor, required ScrollSpyRegionResult Function(ScrollSpyRegionInput) evaluator})
```

Custom evaluators must be pure and fast; results are clamped to 0..1;
allocation in them is the documented cost of custom regions.
`ScrollSpyRegionInput` exposes `itemMainAxisStart/End/Center/Extent`,
`viewportMainAxis*`, `anchorOffsetPx`, raw rects, `axis`.

## Policies

`closestToAnchor()` (smallest |distance|), `largestVisibleFraction()`,
`largestFocusOverlap()`, `largestFocusProgress()`,
`custom(compare: (a, b) => int)` (negative = a wins). All const-able.
Deterministic tie-breakers after `0`: focusProgress, visibleFraction,
distance, registration order.

## Stability

```dart
ScrollSpyStability({
  double hysteresisPx = 0,                    // challenger must beat incumbent by this
  Duration minPrimaryDuration = Duration.zero,// monotonic hold while still focused
  bool preferCurrentPrimary = true,
  bool allowPrimaryWhenNoItemFocused = true,  // gapless best-available fallback
})
ScrollSpyStability.disabled()                 // stickiness off; fallback stays on
```

## Update policies

```dart
const ScrollSpyUpdatePolicy.perFrame()                        // default; <=1 compute/frame
ScrollSpyUpdatePolicy.onScrollEnd({debounce = 80ms})          // NOT const; stale mid-scroll by design
ScrollSpyUpdatePolicy.hybrid({scrollEndDebounce = 80ms,
  ballisticInterval = 50ms, computePerFrameWhileDragging = true}) // NOT const
```

Non-const ones have no `==`: store in a field, never construct inline in
`build`.

## Builders / listeners

All take an optional `controller`; when omitted they resolve the nearest
`ScrollSpyScope<T>`'s controller (FlutterError if neither exists).
Scope-level: `ScrollSpyPrimaryBuilder`, `ScrollSpyPrimaryListener`
(`onChanged(T? previous, T? current)`), `ScrollSpyFocusedIdsBuilder`,
`ScrollSpySnapshotBuilder`. Per-item: `ScrollSpyItemFocusBuilder`,
`ScrollSpyItem{Primary,Focused,Visible}Builder`,
`ScrollSpyItem{Primary,Focused,Visible}Listener`
(`onChanged(bool previous, bool current)`). Builders take `child:`
pass-through; listeners never rebuild.

## Debug and diagnostics

`ScrollSpyScope(debug: true, debugConfig: ScrollSpyDebugConfig(...))`:
overlay colors red = region, green = primary, yellow = focused, blue =
visible bounds; `showLabels: true` adds id/metric labels;
`includeItemRectsInFrame: true` populates focus rects (extra allocations,
debug only). Zero cost when `debug: false`.
`ScrollSpyDiagnostics.sink = ScrollSpyDiagnostics.debugPrintSink();` for
engine logs; set `null` to disable.

## Requirements

Dart `^3.6.0`, Flutter `>=3.27.0`. Pure Dart; all six platforms.
