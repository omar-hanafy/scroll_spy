# scroll_spy 1.0.0: engine rebuild for maximum viewport-tracking performance

Date: 2026-07-05
Status: approved for implementation (autonomous session; user delegated remaining decisions)

## 1. Goal

Make scroll_spy the fastest viewport/focus tracking package Flutter allows, so that
a feed built on it (X.com-style, autoplay video, focus highlighting) never has to
suspect this package when chasing a performance problem. Steady-state scrolling
cost must be near zero: O(mounted items) arithmetic, zero allocations, zero
render-tree walks in the common case, and no work at all for signals nobody
listens to.

This is a from-scratch rebuild of the internals on a clean slate. There are no
external consumers and no migration concerns. Rules enforced strictly:

- No legacy code paths, no dead branches, no "kept for reference" copies.
- No deprecated APIs, no compatibility shims, no version checks.
- The clean version is written as if the old internals never existed.

## 2. Non-goals

- Paint-level (same-frame, rebuild-free) visual effects. Deferred; see Future work.
- Changing the public mental model (region / policy / stability / update policy /
  controller with diff-only listenables). That model is good and stays.
- Web/desktop-specific tuning beyond what the general design gives for free.

## 3. What is slow today (measured by inspection of the hot path)

Per compute pass with N mounted items, the 0.2.x engine does:

1. Render-tree walks: `RenderAbstractViewport.of()` once for discovery plus once
   per item as a guard, then 4x `localToGlobal(ancestor:)` per item. Each of
   those collects the ancestor chain into a list and multiplies 4x4 matrices.
   All of it is recomputed every frame, although during pure scrolling the only
   changing input is the scroll offset (a single double).
2. Allocation storm: `entriesSnapshot()` list up to 3x per pass, ~7 collections
   plus unmodifiable wrappers in selection, then `_normalizeSnapshot` performs
   full `Set.unmodifiable` / `Map.unmodifiable` deep copies on every commit.
   One `ScrollSpyItemFocus` per item per pass regardless of listeners. One
   `ScrollSpyDebugFrame` per pass even with debug off.
3. The snapshot notifier fires every pass (fresh `computedAt`), listeners or not.
4. `DateTime.now()` wall clock drives stability timing (not monotonic).
5. Axis inference can loop registry entries and call `Scrollable.maybeOf` per entry.

## 4. Approaches considered

### A. Surgical optimization of the existing engine

Keep structure; cache viewport discovery, replace 4x localToGlobal with one
getTransformTo, pool collections, gate debug frames.

- Pros: small diff, low risk.
- Cons: keeps the fundamental per-frame re-measurement model; still O(depth)
  matrix work per item per frame; the allocation model (immutable snapshot
  through every layer every pass) stays. Leaves the biggest win on the table.

### B. Render-first rewrite

Move tracking entirely into render objects: engine attaches to the viewport
render object, probes self-report, signals update at paint time.

- Pros: theoretical maximum, enables same-frame effects.
- Cons: large new surface (custom render protocol), hard to keep the clean
  widget-facing API, high risk in one pass, and most of the win comes from the
  geometry/allocation model rather than from paint-time delivery.

### C. Full internal engine rebuild behind the existing public API (CHOSEN)

Rebuild geometry, registry, scheduling, selection, and the controller commit
path around two ideas: (1) scroll motion is a rigid translation, so per-frame
positions are derivable by one subtraction from a cached scroll-space anchor,
and (2) nothing is materialized unless a listener exists. The public API keeps
its shape; internals share nothing with 0.2.x.

- Pros: captures ~all of the available win; preserves the proven API and test
  suite as a behavioral safety net; risk contained to internals.
- Cons: bigger than A. Accepted.

## 5. Design

### 5.1 Data flow overview

```
scroll signals (notifications, optional ScrollController)
        |
   ScrollSpyEngine (scheduling per ScrollSpyUpdatePolicy, <=1 compute/frame)
        |
   compute pass over ItemSlots (mutable, pooled, one per registered item)
        |  geometry: O(1) cached linear model per item (fast tier)
        |  region evaluate + selection + stability (allocation-free scratch)
        |
   EngineFrame (internal, reused buffers; NOT the public snapshot)
        |
   ScrollSpyController.commit (diff-only fan-out, lazy materialization)
        |
   listeners: primaryId / focusedIds / per-item booleans / itemFocusOf /
   snapshot (each materialized only if someone listens)
```

### 5.2 Geometry: the linear scroll model

Key fact: scrolling translates painted content rigidly along the main axis.
For any item whose chain to the viewport contains no transform, its main-axis
position in viewport coordinates is linear in the scroll offset:

```
mainStart(pixels) = anchorMainStart - dir * (pixels - anchorPixels)
```

where `dir` is +1 for AxisDirection.down/right and -1 for up/left, and
(anchorMainStart, anchorPixels) were captured by one full measurement.

Per item the engine caches a GeometryAnchor:

- `mainStart0`, `crossStart`, `mainExtent`, `crossExtent` (viewport space at capture)
- `pixels0` (scroll offset at capture)
- validation fingerprint:
  - enclosing `RenderSliver` reference
  - for children of `RenderSliverMultiBoxAdaptor` (SliverList, SliverGrid,
    SliverFillViewport, SliverPrototypeExtentList; covers ListView, GridView,
    PageView, CustomScrollView lists): the sliver child ancestor reference and
    its `SliverMultiBoxAdaptorParentData.layoutOffset` (scroll-invariant; it
    changes only when real layout shifts the item)
  - the sliver's `constraints.precedingScrollExtent`
  - item box size, viewport size

Per frame, per item (fast tier): read `viewport.offset.pixels` (once per pass),
validate the fingerprint with a handful of double/identity compares, then one
subtraction gives the rect. Zero allocation, zero tree walks.

Tiers, classified at measure time:

- Tier FAST: chain is pure translation AND enclosing sliver is a
  RenderSliverMultiBoxAdaptor. Cached linear model + O(1) validation.
- Tier WALK: pure translation chain but any other enclosing sliver type
  (SliverToBoxAdapter, persistent headers, unknown custom slivers). Re-measured
  each pass with the zero-allocation walk (below). Always correct, still far
  cheaper than 0.2.x.
- Tier MATRIX: chain contains a non-translation segment (RenderTransform with
  rotation/scale, RenderFittedBox, ...). Re-measured each pass in matrix mode
  with reused Matrix4 storage.

The zero-allocation walk: from probe up to the viewport, per level reset a
single scratch Matrix4 to identity, call `parent.applyPaintTransform(child, m)`,
check whether m is a pure translation (compare the 12 non-translation entries);
if yes accumulate dx/dy doubles, if no switch this item to matrix mode for the
pass and multiply into a second scratch matrix. This is fully general (it uses
the same applyPaintTransform contract as getTransformTo) with no allocation.

Any fingerprint mismatch, viewport size change, metrics change, scope
notification (SizeChangedLayoutNotification, didChangeMetrics), or registry
structural change invalidates affected anchors and re-measures on the next pass.
Re-measure means: run the walk once, reclassify the tier, capture a new anchor.

Correctness guard: in debug builds, a sampled cross-check asserts that the fast
tier position equals the walk position (one item per pass, rotating index, so
runs stay deterministic). A violation
indicates a non-rigid custom sliver; the assert message tells the developer what
happened. Release builds never pay for this.

Viewport discovery: `RenderAbstractViewport.of(probe)` once per item at
registration (not per pass). The first discovered viewport becomes the scope's
tracked viewport; items resolving to a different viewport are skipped, matching
0.2.x semantics. Axis and `dir` come from `viewport.axisDirection`; the axis
fallback loop is deleted.

Visibility and region inputs are derived from the same rect arithmetic,
respecting `viewportInsets` / `insetsAffectVisibility` exactly as today.

### 5.3 Registry and ItemSlots

The registry maps id -> ItemSlot and keeps a dense internal `List<ItemSlot>`
iterated in place (no per-pass copy). An ItemSlot is a mutable object allocated
once per registered item holding: id, probe RenderBox, BuildContext, geometry
anchor + tier, and the latest computed metrics as plain fields (isVisible,
isFocused, isPrimary, visibleFraction, distanceToAnchorPx, focusProgress,
focusOverlapFraction, main/cross rect doubles).

- Registration order is preserved for deterministic tie-breaks.
- Pruning of unmounted entries happens inline during the compute loop into a
  reused scratch list.
- Register/unregister during an active compute pass is deferred to pass end and
  asserted against in debug (compute never runs user code that can mutate the
  registry synchronously except custom region evaluators, which must be pure).

### 5.4 Scheduling and update policies

Unchanged semantics, cleaner implementation:

- All computes run in one coalesced post-frame callback (<=1 per frame).
- `perFrame`: compute every frame with scroll signals.
- `onScrollEnd(debounce)`: compute only after settle.
- `hybrid(...)`: per-frame during drag (configurable), throttled during
  ballistic, always a final settle compute.

These are semantic rate controls now (analytics-at-rest, rebuild pressure for
metric listeners), not CPU lifelines. `Debouncer`/`Throttler` utilities stay.

Triggers: ScrollNotification / ScrollMetricsNotification via the scope's
NotificationListeners with depth + predicates (unchanged), optional
ScrollController listener for programmatic jumps (unchanged), metrics/size
change hooks (unchanged, now also invalidate geometry anchors).

### 5.5 Selection and stability

Same rules, allocation-free implementation:

- Selection iterates the slot list once, tracking best focused / best visible
  candidates with the existing policy comparators and deterministic tie-breaks
  (focusProgress, visibleFraction, distance, registration order).
- Stability (minPrimaryDuration, hysteresisPx, preferCurrentPrimary,
  allowPrimaryWhenNoItemFocused) behaves identically but timing uses a
  monotonic clock (engine Stopwatch) instead of `DateTime.now()`. The public
  `ScrollSpySnapshot.computedAt` DateTime remains, stamped only when a snapshot
  is materialized.
- Focused/visible membership is written into two reused id sets (ping-pong
  buffers) so the controller can diff prev vs next without copies.

### 5.6 Controller commit: lazy, diff-only fan-out

The engine hands the controller an internal EngineFrame view over its reused
buffers (not a public snapshot). The controller then:

1. Primary: updates the `primaryId` ValueNotifier only on change (as today).
2. `focusedIds`: diffs prev/next reused sets; allocates a new unmodifiable Set
   ONLY when membership actually changed, otherwise keeps the previous instance
   and emits nothing.
3. Boolean per-item notifiers: diff-driven updates exactly as today (O(changed)
   plus O(tracked) eviction checks), including eviction semantics (evict when
   untracked by engine and listener count is zero; reset to false when still
   listened to but gone).
4. `itemFocusOf` notifiers: for each tracked id, compare slot fields against the
   notifier's current value with the existing tolerance rules WITHOUT
   materializing; construct a new `ScrollSpyItemFocus` only when the comparison
   fails. Eviction unchanged.
5. `snapshot`: materialized ONLY when the snapshot listenable has listeners;
   otherwise the controller marks it stale and the `.value` getter materializes
   on demand from the engine's latest state. Listeners opting into the snapshot
   accept per-pass notifications (unchanged contract).

`commitFrame(ScrollSpySnapshot)` as the engine->controller seam is replaced by
the EngineFrame path. A test-facing internal constructor builds an EngineFrame
from a snapshot so controller behavior tests stay expressible.

Internal counters (`@visibleForTesting`): materializedSnapshots,
materializedItemFocus, geometryFullMeasures, geometryFastHits. Tests assert the
laziness and caching invariants with them.

### 5.7 Debug pipeline

Zero cost when off:

- The engine builds `ScrollSpyDebugFrame`s only when debug mode was enabled by
  the scope (flag set at construction/updateConfig, driven by `debug: true`).
- Rect fields on materialized `ScrollSpyItemFocus` follow `includeItemRects`
  as today (null outside debug).
- Overlay/painter/config public API unchanged.

### 5.8 Public API in 1.0.0

Unchanged (shape and semantics): ScrollSpyScope, ScrollSpyItem,
ScrollSpyItemLite, ScrollSpyController and all its listenables, ScrollSpyRegion
(line/zone/custom) + ScrollSpyAnchor, ScrollSpyPolicy (all five),
ScrollSpyStability, ScrollSpyUpdatePolicy (all three), viewportInsets +
insetsAffectVisibility, notificationDepth + predicates, debug overlay API, all
builders/listeners, all convenience wrappers (ListView/GridView/PageView/
CustomScrollView), per-item boolean notifier accessors, tryGetItemFocus.

Changed:

- Version 1.0.0.
- `ScrollSpySnapshot` keeps its shape but is documented as lazily produced;
  `computedAt` reflects materialization time of that snapshot instance.
- Stability timing is monotonic (behavioral fix: wall-clock jumps no longer
  break minPrimaryDuration).
- Engine/registry/geometry internals are new types; anything that imported
  `src/engine/*` directly (internal-only by convention) is rewritten.

### 5.9 Edge cases

- Reverse lists (AxisDirection.up/left) and RTL horizontal: handled by `dir`.
- Overscroll (bouncing physics): linear model holds (rigid translation).
- Pinned/floating headers: items under them stay linear (headers overlay,
  layoutExtent collapses); items INSIDE persistent headers classify as WALK
  tier and re-measure per pass, so they are always correct.
- Kept-alive children with null layoutOffset: treated as not measurable this
  pass (not visible), like unmounted.
- CustomScrollView with center/anchor: linearity is unaffected; fingerprint
  validation catches preceding-extent changes.
- Nested scrollables: nearest-viewport discovery + depth/predicates, as today.
- Transforms between item and viewport: MATRIX tier, correct every frame.
- Items in a different viewport than the scope's tracked one: skipped (as today).
- Empty scope / no measurable items: empty commit, primary null (as today).
- Viewport replaced (scrollable rebuilt with different render objects):
  discovery reruns via registration/invalidations.

### 5.10 Testing and benchmarks

- The existing behavioral test suite keeps passing (public-API tests unchanged;
  engine-internal tests rewritten against the new internals with the same
  behavioral assertions).
- New tests: geometry tier classification, linear-model validation and
  invalidation (item resize, insertion above, preceding sliver change,
  viewport resize, transform ancestor), laziness invariants via counters,
  monotonic stability timing, deferred registry mutation.
- Perf: `test/perf/compute_pass_benchmark_test.dart` times compute passes for
  N in {10, 50, 200} mounted items and prints results (indicative, not CI-gated);
  example app gains a "perf lab" page (dense feed + metrics HUD) for DevTools
  timeline work.

## 6. Decision log (autonomous decisions, user pre-authorized)

1. Booleans-first hot path (user-confirmed choice).
2. Adaptive geometry with fast/walk/matrix tiers (user-confirmed choice).
3. 1.0.0 full internal rebuild; public API preserved in shape (self-decided).
4. Keep all three update policies; they are semantic controls (self-decided).
5. Monotonic clock for stability; DateTime only in materialized snapshots
   (self-decided).
6. Debug frames gated by debug flag; zero release cost (self-decided).
7. Lazy snapshot + lazy ScrollSpyItemFocus materialization (self-decided).
8. Set allocations only on membership change (self-decided).
9. Registry iterated in place; mutations during compute deferred + asserted
   (self-decided).
10. Paint-level same-frame effects deferred to a future minor (self-decided).
11. Benchmarks lean: timing tests + counters + example perf page (self-decided).
12. Branch `rebuild/v1-engine`; spec committed there (self-decided).

## 7. Future work

- Paint-level focus effects: a render widget driving progress-based visuals via
  markNeedsPaint (same frame, zero rebuild).
- Optional struct-of-arrays metric storage if profiling ever shows slot-object
  field access dominating (not expected).
