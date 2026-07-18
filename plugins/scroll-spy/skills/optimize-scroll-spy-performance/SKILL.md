---
name: optimize-scroll-spy-performance
description: "Use when a Flutter screen whose code uses scroll_spy (ScrollSpyScope, ScrollSpyItem, ScrollSpyController) shows jank, dropped frames, high CPU, or rebuild storms, or when choosing between ScrollSpyItem, ScrollSpyItemLite, focus builders, listeners, and snapshot listening in large scroll_spy feeds. Not for general Flutter list or image scrolling performance where scroll_spy is not involved."
license: MIT
---

# Optimize scroll_spy performance

Get the cost model right first: the engine's compute pass is tens of
microseconds even with hundreds of mounted items (O(1) cached arithmetic per
item on the hot path, allocation-free, no render-tree walks). Measurable
scroll cost in an app almost always comes from **widget rebuilds you
subscribed to**, not from the engine. Optimize subscriptions, not the
engine.

## The subscription ladder (cheapest first)

1. **Listeners** (`ScrollSpyPrimaryListener`, `ScrollSpyItem*Listener`):
   side effects with zero rebuilds. Correct for play/pause, analytics,
   haptics, prefetch.
2. **Boolean subscriptions** (`ScrollSpyItemLite`,
   `ScrollSpyItem{Primary,Focused,Visible}Builder`): rebuild only when a
   flag flips. Correct for highlights, badges, borders.
3. **Metric subscriptions** (`ScrollSpyItem`, `ScrollSpyItemFocusBuilder`):
   rebuild whenever metrics drift past tolerance, which during scrolling
   means nearly every frame. Reserve for items that genuinely animate from
   `focusProgress`/`visibleFraction`.
4. **Snapshot** (`controller.snapshot`, `ScrollSpySnapshotBuilder`):
   notifies every compute pass and materializes the full immutable frame.
   One dashboard-style consumer at most; never one per item.

The engine bills only for what is consumed: with no snapshot listeners no
snapshot is materialized; per-item notifiers are created lazily, updated
diff-only, and auto-evicted. An unheard signal costs nothing, so the win
comes from moving consumers down this ladder, not from removing scroll_spy.

## Checklist for a janky scroll_spy screen

- Demote every `ScrollSpyItem` whose builder only uses `isPrimary`/
  `isFocused` to `ScrollSpyItemLite`.
- Every item passes its static subtree via `child:`; the builder wraps
  `child` and never reconstructs the card. Confirm the static part is
  genuinely const/stable.
- Side effects run in listeners, not builders with `setState`.
- No per-item `snapshot` listeners; threshold scans (impressions) use one
  snapshot listener for the whole screen, or per-item boolean listeners.
- `debug: false` and `includeItemRectsInFrame` unset in release paths
  (rect capture allocates per item per pass; debug frames are gated but the
  overlay itself repaints).
- Update policy: `perFrame` is not a CPU problem; but if metric
  subscriptions (ladder rung 3) must exist and flings rebuild too much, use
  `ScrollSpyUpdatePolicy.hybrid(ballisticInterval: 50ms)` to throttle
  ballistic recomputes, or `onScrollEnd` when only settled state matters.
  These change semantics (staleness mid-scroll), so state the tradeoff.
  Store non-const policies in fields (no `==`; inline construction churns
  engine config every rebuild).
- Custom regions/policies: evaluators and comparators run per focused/
  visible item per pass; keep them allocation-free and pure. Built-in
  regions never allocate on the hot path; `ScrollSpyRegion.custom` allocates
  by design.

## Verify with measurements, not vibes

1. Profile mode on a real device (`flutter run --profile`).
2. DevTools Performance: record slow and fast scrolling; look at build
   times of item widgets, not the engine (it will not show up).
3. Rebuild accounting: add a `debugPrint` in one item builder or use
   DevTools "Track widget builds"; with the ladder applied, boolean items
   rebuild only on flips (a handful per scroll), never per frame.
4. The package's example app has a Perf lab page (1000 items + frame-time
   HUD) demonstrating the target: steady 60/120fps with `ScrollSpyItemLite`.
   Its own perf regression test (`test/perf/compute_pass_benchmark_test.dart`
   in the package repo) documents expected compute-pass magnitudes.

Report what moved down the ladder, before/after frame times or rebuild
counts, and any semantic tradeoffs (update policy changes).
