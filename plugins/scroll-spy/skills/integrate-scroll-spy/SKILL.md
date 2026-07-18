---
name: integrate-scroll-spy
description: "Use when adding the scroll_spy Flutter package to a screen or feature: autoplay video feeds, current-item tracking, reading-position or TOC highlighting, impression analytics, carousels or PageViews, photo grids, prefetching around the focused item, or wiring ScrollSpyScope, ScrollSpyItem, and ScrollSpyController for the first time, including widget tests for that integration. Not for scrolling work unrelated to focus or visibility tracking (saving/restoring scroll offsets, scroll physics, scroll-to-index)."
license: MIT
---

# Integrate scroll_spy

scroll_spy computes, per scroll: which items are visible, which intersect a
configurable focus region, and which single item is the stable primary.
You wire four things: a scope (owns the engine), items (register geometry),
a controller (read side), and a reaction (builder or listener).

Before writing code, inspect the project: confirm `scroll_spy: ^1.x` in
pubspec.yaml (0.x: run migrate-scroll-spy-v0-to-v1 first), find any existing
`ScrollSpyScope`/controller to extend instead of duplicating, and note the
scrollable type you are instrumenting. Exact signatures for everything used
below: [references/api-cheatsheet.md](references/api-cheatsheet.md).

## Decision 1: wrapper or raw scope

Use a wrapper when the scrollable is a plain ListView/GridView/PageView/
CustomScrollView: `ScrollSpyListView.builder`/`.separated`,
`ScrollSpyGridView.builder`, `ScrollSpyPageView.builder`,
`ScrollSpyCustomScrollView`. Wrappers mirror the Flutter constructor and,
critically, wire the scroll/page controller to both the view and the scope.
For any other scrollable, wrap it in `ScrollSpyScope<T>` yourself and pass
the same `ScrollController` to both the scrollable and the scope's
`scrollController:` parameter.

## Decision 2: configuration by use case

| Use case | region | policy | stability | updatePolicy |
|---|---|---|---|---|
| Autoplay feed | `zone(anchor: fraction(0.5), extentPx: ~200)` | `closestToAnchor` | `hysteresisPx: 24, minPrimaryDuration: 150ms` | default `perFrame` |
| Reading position / TOC | `line(anchor: fraction(0.2..0.3), thicknessPx: 0..2)` | `closestToAnchor` | small or none; `allowPrimaryWhenNoItemFocused: false` for strict "nothing under the line" | `perFrame` |
| Impressions / analytics at rest | zone or generous zone | `closestToAnchor` | defaults | `onScrollEnd(debounce: 80ms)` if events should fire only after settling |
| Carousel / PageView | `zone(anchor: fraction(0.5), extentPx: ~page extent)` | `closestToAnchor` or `largestFocusProgress` | small hysteresis | `perFrame` (drives `focusProgress` effects) |
| Photo grid | zone | `largestVisibleFraction` | `minPrimaryDuration: ~120ms` | `perFrame` |

Stability defaults are all-off; feeds must set values or the primary will
chatter. To adjust behavior later, use the tune-scroll-spy-stability skill.

## Decision 3: how items react

| Need | Use |
|---|---|
| Side effects only (play/pause, analytics, haptics) | `ScrollSpyPrimaryListener` / `ScrollSpyItemPrimaryListener` / `...FocusedListener` / `...VisibleListener`: no rebuilds, `onChanged(previous, current)`, no initial call |
| Rebuild on boolean flips only (highlight, badge) | `ScrollSpyItemLite<T>` (builder gets `isPrimary, isFocused`) or `ScrollSpyItem{Primary,Focused,Visible}Builder` |
| Rebuild on live metrics (`focusProgress` scale/parallax) | `ScrollSpyItem<T>` (builder gets full `ScrollSpyItemFocus`) or `ScrollSpyItemFocusBuilder` |
| Screen-level "now playing" header | `ScrollSpyPrimaryBuilder` (controller optional inside the scope subtree; required outside it) |
| Whole-frame view (dashboards, prefetch windows) | `ScrollSpySnapshotBuilder` / `controller.snapshot` (notifies every pass; costliest, use last) |

Always pass the expensive static subtree through the `child:` slot so it is
built once; rebuild only the small reactive part around it.

## Hard rules (each one is a real reported failure)

1. `controller:` on scopes/wrappers is a `ScrollSpyController`, not a
   `ScrollController`. The scroll controller goes in `scrollController:`.
2. One `T` everywhere: scope, items, controller, builders, listeners. A
   mismatch asserts in debug and silently tracks nothing in release.
3. Create the controller as a `State` field and `dispose()` it. Never in
   `build`.
4. `onScrollEnd(...)` and `hybrid(...)` are non-const and have no `==`:
   store them in a field, or every rebuild churns engine config.
5. `ScrollSpyListView.separated` with keyed reordering: use
   `findItemIndexCallback` (item indices), not `findChildIndexCallback`.
6. Item `id`s must be stable and unique within the scope. Index ids are fine
   for static lists; use record ids when items insert/remove/reorder.
7. Pinned headers, tab bars, or bottom overlays covering the viewport:
   pass `viewportInsets` so the region lives in the unobstructed part.

## Edge-centering pattern

With a centered anchor, the first and last items can never reach the anchor
(the list cannot overscroll them to center), so they lose `closestToAnchor`
at the extremes. If the product needs "top card plays when at the top",
add symmetric main-axis list padding of `(viewportExtent - itemExtent) / 2`
(compute via `LayoutBuilder`; this is what the package's own autoplay demo
does), or bias the anchor toward the start (`fraction(0.4)` or
`offsetPx: -x`). Padding keeps true centering mid-feed; anchor bias slightly
shifts the "current" feel everywhere. Say which you chose and why.

## Canonical example (autoplay feed)

```dart
class _FeedState extends State<Feed> {
  final _spy = ScrollSpyController<int>();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _spy.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollSpyPrimaryListener<int>(
      controller: _spy,
      onChanged: (previous, current) => players.playOnly(current),
      child: ScrollSpyListView<int>.builder(
        controller: _spy,
        scrollController: _scroll,
        region: ScrollSpyRegion.zone(
          anchor: const ScrollSpyAnchor.fraction(0.5),
          extentPx: 200,
        ),
        policy: const ScrollSpyPolicy<int>.closestToAnchor(),
        stability: const ScrollSpyStability(
          hysteresisPx: 24,
          minPrimaryDuration: Duration(milliseconds: 150),
        ),
        itemCount: items.length,
        itemExtent: 320,
        itemBuilder: (context, i) => ScrollSpyItemLite<int>(
          id: i,
          child: FeedCardBody(item: items[i]), // static; never rebuilds
          builder: (context, isPrimary, isFocused, child) => PlayFrame(
            playing: isPrimary,
            child: child!,
          ),
        ),
      ),
    );
  }
}
```

## Verify the integration

1. `dart format` changed files; `flutter analyze` clean.
2. Visual: temporarily set `debug: true` on the scope/wrapper; the red
   region, yellow focused outlines, and green primary outline must match
   intent. Remove before committing.
3. Widget test: use the harness and pump discipline in
   [references/test-harness.md](references/test-harness.md). State exists
   only two frames after `pumpWidget`; `onScrollEnd` needs its debounce
   pumped. Assert primary at rest and after a scroll/jump.
4. Report: chosen config with one-line rationale per knob, edge-pattern
   choice, and anything intentionally not handled.

If the integration produces nulls, missed jumps, or offset highlights, stop
guessing and use the diagnose-scroll-spy skill's symptom table.
