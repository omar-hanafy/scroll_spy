## 0.1.0 — 2025-12-19

Initial public release of **scroll_spy**.

### Highlights
- Compute focused items plus a single stable primary winner.
- Configurable focus region, selection policy, stability, and update cadence.
- Debug overlay for visualizing region, bounds, and per-item metrics.
- Convenience wrappers and builders for rapid integration.

### Added
- Focus engine that computes focused items and a single stable primary item.
- `ScrollSpyScope<T>` to observe a scrollable subtree.
- `ScrollSpyItem<T>` for per-item registration + focused/primary rebuild isolation.
- `ScrollSpyController<T>` exposing `primaryId`, `focusedIds`, `snapshot`,
  and `itemFocusOf(id)`.
- Focus regions:
  - `line` (anchor + optional thickness)
  - `zone` (anchor + `extentPx`)
  - `custom` (anchor + evaluator)
- Primary selection policies:
  - `closestToAnchor`
  - `largestVisibleFraction`
  - `largestFocusOverlap`
  - `largestFocusProgress`
  - `custom` comparator
- Stability controls:
  - `hysteresisPx`
  - `minPrimaryDuration`
  - `preferCurrentPrimary`
  - `allowPrimaryWhenNoItemFocused`
- Update policies:
  - `perFrame`
  - `onScrollEnd` (debounced)
  - `hybrid` (drag per-frame + throttled ballistic + final settle)
- Debug overlay (optional):
  - focus region visualization
  - primary/focused outlines
  - optional labels
  - optional rect inclusion (debug-only)
- Diagnostics hook: `ScrollSpyDiagnostics`.
- Convenience wrappers:
  - `ScrollSpyListView` / `ScrollSpyGridView` /
    `ScrollSpyCustomScrollView` / `ScrollSpyPageView`
- Builder/listener utilities:
  - `ScrollSpyPrimaryBuilder` / `ScrollSpyPrimaryListener`
  - `ScrollSpyFocusedIdsBuilder`
  - `ScrollSpySnapshotBuilder`
  - `ScrollSpyItemFocusBuilder`

### Notes
- For best performance, keep the debug overlay disabled in release builds.
- When using nested scrollables, configure `notificationDepth` /
  `notificationPredicate` to filter signals.
