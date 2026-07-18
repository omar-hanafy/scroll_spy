---
name: diagnose-scroll-spy
description: "Use when scroll_spy misbehaves in a Flutter app and the cause is unknown: primaryId stays null, focusedIds stays empty, listeners or builders never fire, focus ignores jumpTo or programmatic scrolls, the highlighted item is offset under a pinned header or app bar, state resets on setState, nested scrollables interfere, or a widget test reads null focus state."
license: MIT
---

# Diagnose scroll_spy

Work symptom-first: find the row that matches, verify its cause in the code,
apply the smallest fix, then confirm with the overlay workflow at the end.
Most reports match exactly one row.

## Symptom table

| Symptom | Cause to verify | Fix |
|---|---|---|
| Everything null/empty, never any state | No `ScrollSpyItem`/`ScrollSpyItemLite` in the subtree, or scope not above the scrollable | Wrap items; scope must enclose the scrollable that scrolls them |
| Same, but items exist | Type parameter mismatch: `ScrollSpyScope<String>` with `ScrollSpyItem<int>` (or an omitted `<T>` defaulting to `dynamic`). Items look up the scope by exact `T`; a mismatch throws an assert in debug builds but silently tracks nothing in release | Make every scope, item, controller, builder, and listener share the same concrete `T` |
| Same, only in widget tests | State is committed in post-frame callbacks: registration on frame 1, compute on frame 2 | After `pumpWidget`, `pump()` twice before asserting |
| First frame after mount shows no focus (runtime) | Same post-frame pipeline; initial state lands one frame late by design | Do not read focus in `initState`; listen, or read after the first frames |
| Focus ignores `jumpTo`/programmatic scrolls until the user wiggles | Scope observes notifications only; a bare `jumpTo` on an external `ScrollController` can bypass them | Pass the same controller as `scrollController:` to the scope or wrapper (wrappers wire it to both the view and the scope) |
| Highlight/primary is offset under a pinned `SliverAppBar`, tab bar, safe area, or bottom bar | Region anchored in the full viewport while an overlay covers part of it | `viewportInsets: EdgeInsets.only(top: <overlay px>)` (or `bottom:`); keep `insetsAffectVisibility: true` so covered items also stop counting as visible |
| Highlight resets to null on `setState`; external listeners go dead | `ScrollSpyController` created inside `build`, so each rebuild swaps in a fresh controller and orphans the old one | Make it a `State` field; `dispose()` it; never construct it in `build` |
| Focus updates when an inner carousel scrolls, or not at all in nested scrollables | Notification depth/filtering: default `notificationDepth: 0` targets the immediate child scrollable; nested setups deliver other depths | Set `notificationDepth`, or `notificationPredicate`/`metricsNotificationPredicate` (filter on `n.metrics.axis`) |
| Primary stale while scrolling, corrects after stop | `onScrollEnd`/`hybrid` update policy semantics, not a bug | If per-scroll updates are wanted, use `perFrame` (default); see the tune-scroll-spy-stability skill |
| Primary flickers, sticks, or picks the "wrong" item near boundaries | Selection/stability configuration | Use the tune-scroll-spy-stability skill |
| First/last items never become primary with a centered anchor | Edge geometry: at the list edges those items cannot reach the anchor | Add symmetric list padding of `(viewportExtent - itemExtent) / 2`, bias the anchor, or accept the nearest-fallback behavior |
| Items inside a horizontal pager/second scrollable never focus in the outer scope | Items resolve to their nearest enclosing viewport; the scope tracks the first-registered viewport and skips items from others | Give the inner scrollable its own scope of its own type, or restructure which widget registers |
| Off-screen kept-alive items (`AutomaticKeepAlive`) report nothing | Unlaidout children are unmeasurable that pass by design | Treat absence as "not visible"; do not special-case |
| Debug assert about fast-path geometry mismatch with a custom sliver | A custom sliver's paint transform lies about actual positions | Fix the sliver's `applyPaintTransform`, or file an issue with the assert text |
| `itemRectInViewport`/`visibleRectInViewport` always null | Rects are only populated with `debug: true` + `ScrollSpyDebugConfig(includeItemRectsInFrame: true)` | Enable both while debugging; keep off in release |
| Listener attached but no callback for existing state | Listenables fire on transitions; attaching produces no initial call | Read `.value` for current state; use listeners for changes |

## Instrumentation workflow

When no row matches, or to confirm one:

1. Turn on the overlay: `debug: true` on the scope/wrapper (optionally
   `debugConfig: ScrollSpyDebugConfig(showLabels: true)`). Red = focus
   region, green = primary outline, yellow = focused outlines, blue =
   visible bounds.
   - Region drawn where you did not expect: anchor/insets problem.
   - No item outlines at all: registration problem (rows 1-3).
   - Outlines but never green: selection/stability (tune skill).
2. Log engine events without widgets:
   `ScrollSpyDiagnostics.sink = ScrollSpyDiagnostics.debugPrintSink();`
   (set to `null` when done).
3. Snapshot ground truth at a breakpoint or in a listener:
   `controller.snapshot.value` shows `primaryId`, `focusedIds`,
   `visibleIds`, and per-item metrics for everything measurable this pass.

## Reporting

State the confirmed root cause, the one-line fix, and what you verified
(overlay observation, passing test, or both). If the behavior needed a
config change with product implications (anchor moves, insets, update
policy), say what tradeoff was made.
