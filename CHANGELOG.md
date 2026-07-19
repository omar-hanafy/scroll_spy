## 1.0.5 - 2026-07-19

No public runtime API changes; existing scroll_spy 1.x integrations keep the
same behavior.

### Added
- A prominent README link to the official ScrollSpy Assistant plugin for
  Claude Code and OpenAI Codex.

### Fixed
- Restored the complete 371-frame, 31-second README and pub.dev demo GIF from
  the original optimized recording.
- Versioned the external GIF URL so pub.dev refreshes its cached image instead
  of continuing to serve the shorter replacement.

---

## 1.0.4 - 2026-07-19

No public runtime API changes; existing scroll_spy 1.x integrations keep the
same behavior.

### Fixed
- Slowed the README and pub.dev demo GIF from 11 to 22 seconds so focus
  transitions and primary-item changes are easier to follow.

---

## 1.0.3 - 2026-07-19

No public runtime API changes; existing scroll_spy 1.x integrations keep the
same behavior.

### Added
- The Primary Rail brand system: reproducible SVG masters, light and dark
  marks, launcher-safe compositions, maskable artwork, and a deterministic
  asset-generation script.
- Branded Android adaptive and round icons plus Android 12, iOS, and legacy
  launch-screen artwork for the example app.
- Installable product-site icons and manifest metadata for favicons, Apple
  touch icons, and normal and maskable PWA icons.

### Changed
- Unified the package README, product site, social preview, Flutter example,
  web app, Android, iOS, and macOS around the near-black, signal-green, and
  bone Primary Rail identity.
- Replaced the example's stock Flutter launcher artwork and Material radar
  glyph with the package's own mark.
- Accepted Flutter's current Android Gradle compatibility flags and iOS/macOS
  Swift Package Manager wiring so native showcase builds stay clean on the
  current stable toolchain.
- Removed the standalone branding image from the pub.dev screenshot carousel
  to follow current pub.dev guidance. The logo remains at the top of the
  README rendered on pub.dev, while the real autoplay screenshot remains the
  package thumbnail.
- Updated all package and assistant-plugin version references to 1.0.3.

### Fixed
- Ensured the Pages staging parent exists on clean CI checkouts before
  allocating its temporary build directory.

---

## 1.0.2 - 2026-07-19

No public runtime API changes; existing scroll_spy 1.x integrations keep the
same behavior.

### Added
- A real-video autoplay example with bundled media, exactly one playing item,
  bounded neighbor preloading, lifecycle-safe pausing, controller disposal, and
  focused tests for the player-pool policy.
- A reproducible comparison benchmark for scroll_spy,
  `visibility_detector`, and `inview_notifier_list`, with explicit scenario and
  interpretation guidance rather than a universal performance claim.
- A crawlable product site with semantic HTML, package-specific search
  metadata, structured data, social preview media, `llms.txt`, and a separate
  route for the Flutter demo.
- A reproducible Pages build script and deployment workflow that publishes the
  static product pages with the Wasm Flutter demo under `/scroll-spy/demo/`.

### Changed
- Reworked the package description, topics, homepage, screenshots, and README
  so Flutter developers can find the package by the problems it solves: stable
  primary selection, video autoplay, attention analytics, reading position,
  and prefetching.
- Hardened release automation with tag-only OIDC publishing, actual version
  bump detection, pinned Pana validation, and example-app analysis/tests in CI.
- Resolved the remaining dartdoc reference warnings while keeping the public
  API and runtime behavior unchanged.
- Corrected the GitHub priority-label catalog so all repository YAML parses
  cleanly.

---

## 1.0.1 - 2026-07-18

No runtime changes; the Dart/Flutter API is identical to 1.0.0.

### Added
- AI coding-assistant support: an installable agent plugin for Claude Code
  and OpenAI Codex, distributed from the GitHub repository (see the
  "AI coding-assistant support" section in the README). Six package-specific
  skills: integration, primary-selection stability tuning, symptom-based
  diagnosis, rebuild-pressure/performance optimization, a 0.x to 1.x
  migration workflow, and conversion from `visibility_detector`. The plugin
  is instructions-only (no hooks, MCP servers, executable scripts, or
  network access) and is excluded from the pub.dev archive.
- Repository guidance for coding agents (`AGENTS.md`, `CLAUDE.md`) and a CI
  validator (`tool/validate_ai_plugin.dart`) that keeps plugin manifests,
  marketplace catalogs, skills, and the package version in sync.

---

## 1.0.0 - 2026-07-05

Engine rebuild focused on scroll performance. The public API you use in apps
(widgets, controller listenables, regions, policies, stability, update
policies, wrappers, debug overlay) is unchanged; typical apps upgrade with no
code changes.

### Changed
- The focus engine was rebuilt around a cached linear scroll model: during
  steady scrolling, item positions are derived with O(1) arithmetic per item
  instead of per-frame render-tree walks, and the hot path performs no
  allocations. Items under transforms or custom slivers are detected
  automatically and measured with a general (still allocation-free) path.
- Snapshots and `ScrollSpyItemFocus` objects are now materialized lazily,
  only for state something actually listens to. `ScrollSpySnapshot.computedAt`
  reflects when that snapshot instance was materialized.
- Primary stability timing (`minPrimaryDuration`) is now monotonic; wall-clock
  changes can no longer break or shorten stability windows.
- Debug-frame bookkeeping now runs only when `ScrollSpyScope(debug: true)`;
  a non-debug scope spends nothing on debug support.

### Added
- `ScrollSpyRegion.anchor` is available on the sealed base type.

### Removed (breaking)
- The old engine internals are no longer exported:
  `ScrollSpySelection`, `ScrollSpyGeometry`, `ScrollSpyGeometryResult`,
  `ScrollSpyRegistry`, `ScrollSpyRegistryEntry`, and `ScrollSpyDiff`.
- `ScrollSpyController.commitFrame` was replaced by an internal engine commit
  path; the controller is no longer fed with hand-built snapshots.

---

## 0.2.7 - 2025-12-24

Release automation maintenance (no API changes).

### Changed
- Improved tag-based publishing automation.
- Cleaned up repo workflow documentation (canonical guide).

---

## 0.2.6 - 2025-12-23

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

## 0.2.5 - 2025-12-20

Docs-only release removing the oversize demo screenshot entry.

### Changed
- Removed the demo GIF from pubspec screenshots to satisfy pub.dev limits.

---

## 0.2.4 - 2025-12-20

Docs-only release with header polish and naming update.

### Changed
- Updated the README title to ScrollSpy.
- Refined the README header layout with a linked demo preview.

---

## 0.2.3 - 2025-12-20

Docs-only release with the new package icon screenshot.

### Added
- Added the icon as the primary pub.dev screenshot.

### Changed
- Updated README preview media to include the icon.

---

## 0.2.2 - 2025-12-20

Docs-only release with refreshed preview media.

### Changed
- Updated demo gif.
- Adjusted README preview sizing.

---

## 0.2.1 - 2025-12-20

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

## 0.2.0 - 2025-12-20

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

## 0.1.0 - 2025-12-19

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
