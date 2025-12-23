## 0.2.7-dev.1 — 2025-12-23

Development pre-release for upcoming changes.

### Changed
- Enable manual publish workflow dispatch with a tag input.

---

## 0.2.6 — 2025-12-23

Maintenance release with separated-list index mapping fixes and tooling cleanup.

### Added
- `findItemIndexCallback` support for `ScrollSpyListView.separated`.
- Test coverage for separated list index mapping.

### Fixed
- Correct item-to-child index mapping for separated lists.
- Eliminated deprecated `findChildIndexCallback` warnings on newer Flutter SDKs.

### Changed
- Refreshed the example app.

---

## 0.2.5 — 2025-12-20

Docs-only release removing the oversize demo screenshot entry.

### Changed
- Removed the demo GIF from pubspec screenshots to satisfy pub.dev limits.

---

## 0.2.4 — 2025-12-20

Docs-only release with header polish and naming update.

### Changed
- Updated the README title to ScrollSpy.
- Refined the README header layout with a linked demo preview.

---

## 0.2.3 — 2025-12-20

Docs-only release with the new package icon screenshot.

### Added
- Added the icon as the primary pub.dev screenshot.

### Changed
- Updated README preview media to include the icon.

---

## 0.2.2 — 2025-12-20

Docs-only release with refreshed preview media.

### Changed
- Updated demo gif.
- Adjusted README preview sizing.

---

## 0.2.1 — 2025-12-20

Insets-aware viewport support plus metrics filtering.

### Added
- `viewportInsets` and `insetsAffectVisibility` on `ScrollSpyScope` and all wrapper widgets.
- `metricsNotificationPredicate` to filter `ScrollMetricsNotification` signals.
- Geometry guard to skip entries from mismatched viewports (nested scrollables safety).
- Tests for viewport insets + metrics predicate behavior.

### Changed
- Focus anchor and region evaluation now use the effective (insets-deflated) viewport.
- Debug overlay now visualizes the effective viewport bounds by default.

---

## 0.2.0 — 2025-12-20

Performance-focused release with low-overhead per-item signals for large feeds.

### Highlights
- Per-item boolean notifiers for primary/focused/visible state.
- `ScrollSpyItemLite` to rebuild only when those booleans toggle.
- Builder/listener widgets for boolean signals (no rebuild when unchanged).

### Added
- `ScrollSpyController.itemIsPrimaryOf(id)`.
- `ScrollSpyController.itemIsFocusedOf(id)`.
- `ScrollSpyController.itemIsVisibleOf(id)`.
- `ScrollSpyItemLite<T>`.
- `ScrollSpyItemPrimaryBuilder` / `ScrollSpyItemFocusedBuilder` /
  `ScrollSpyItemVisibleBuilder`.
- `ScrollSpyItemPrimaryListener` / `ScrollSpyItemFocusedListener` /
  `ScrollSpyItemVisibleListener`.

### Changed
- Per-item notifier updates now iterate tracked listeners (O(listeners))
  and use diff-based updates for boolean signals (behavior unchanged).

---

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
