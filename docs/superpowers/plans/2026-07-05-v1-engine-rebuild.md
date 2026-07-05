# scroll_spy v1 Engine Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild scroll_spy internals so steady-state scrolling costs O(mounted) arithmetic with zero allocations and zero render-tree walks in the common case, behind the unchanged public API, released as 1.0.0.

**Architecture:** Mutable per-item ItemSlots carry cached scroll-space geometry anchors (linear scroll model, validated O(1) per frame). A rebuilt engine computes selection/stability allocation-free into reused buffers and commits an internal EngineFrame to the controller, which fans out diff-only and materializes immutable objects (snapshot, ScrollSpyItemFocus) lazily, only for active listeners.

**Tech Stack:** Flutter (rendering + widgets), flutter_test. No new dependencies.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-05-v1-engine-rebuild-design.md`. Follow it exactly.
- No legacy code paths, no deprecated APIs, no compat shims. Old engine files are deleted, not kept.
- Public API shape preserved (Section 5.8 of spec). All existing public-API widget tests must pass, adapted only where they poked internals.
- Never use the em-dash character in any file content; use '-' or '_'.
- After Dart changes: `dart format .` then `flutter analyze` (zero issues) and `flutter test` (green).
- Commit at the end of every task with a descriptive message; no self-attribution in commits.

---

### Task 1: ItemSlot model

**Files:**
- Create: `lib/src/engine/item_slot.dart`
- Test: `test/engine/item_slot_test.dart`

**Interfaces:**
- Produces:

```dart
enum GeometryTier { unmeasured, fast, walk, matrix }

/// Mutable per-item state, allocated once per registered item.
final class ItemSlot<T> {
  ItemSlot({required this.id, required this.registrationOrder});
  final T id;
  final int registrationOrder;

  BuildContext? context;
  RenderBox? box;

  // Geometry anchor (linear scroll model). Valid when tier != unmeasured.
  GeometryTier tier = GeometryTier.unmeasured;
  double mainStart0 = 0, crossStart = 0, mainExtent = 0, crossExtent = 0;
  double pixels0 = 0;
  RenderSliver? sliver;          // enclosing sliver (fast-tier fingerprint)
  RenderObject? sliverChild;     // direct child of the sliver on the chain
  double layoutOffset0 = 0;      // fast-tier fingerprint
  double precedingExtent0 = 0;   // fast-tier fingerprint
  double boxW0 = 0, boxH0 = 0;   // fast-tier fingerprint

  // Latest computed metrics (valid when measurable == true).
  bool measurable = false;
  bool isVisible = false, isFocused = false, isPrimary = false;
  double visibleFraction = 0, distanceToAnchorPx = 0;
  double focusProgress = 0, focusOverlapFraction = 0;
  // Item rect in viewport coords, main/cross decomposed by the engine axis.
  double mainStart = 0, mainEnd = 0, crossStartNow = 0, crossEndNow = 0;

  void invalidateGeometry();     // tier = unmeasured, clears sliver refs
  void resetMetrics();           // measurable=false, flags false, metrics 0,
                                 // distanceToAnchorPx = double.infinity
}
```

- [ ] **Step 1:** Write `test/engine/item_slot_test.dart`: constructing a slot leaves it unmeasured/unmeasurable; `invalidateGeometry()` clears tier and sliver refs but keeps metrics; `resetMetrics()` zeroes flags/metrics and sets `distanceToAnchorPx` to `double.infinity` but keeps the geometry anchor.
- [ ] **Step 2:** Run: `flutter test test/engine/item_slot_test.dart` - FAIL (file missing).
- [ ] **Step 3:** Implement `item_slot.dart` exactly per the interface above.
- [ ] **Step 4:** Run the test - PASS.
- [ ] **Step 5:** Commit: `feat: add ItemSlot model for v1 engine`

### Task 2: SlotRegistry

**Files:**
- Create: `lib/src/engine/slot_registry.dart`
- Test: `test/engine/slot_registry_test.dart`

**Interfaces:**
- Consumes: `ItemSlot<T>` from Task 1.
- Produces:

```dart
final class SlotRegistry<T> {
  /// Dense list in registration order. Do not mutate; iterate in place.
  List<ItemSlot<T>> get slots;
  ItemSlot<T>? slotOf(T id);
  int get length;

  /// Creates or updates a slot. Updating context/box invalidates geometry
  /// only when the box instance changed. Registration order is stable.
  void register(T id, {required BuildContext context, required RenderBox box});
  void unregister(T id);

  /// Compute-pass guards: mutations between begin and end are deferred and
  /// applied at end (asserted against in debug via an in-compute flag).
  void beginCompute();
  void endCompute();

  /// Marks a slot for removal at endCompute (used for unmounted pruning).
  void markDead(ItemSlot<T> slot);

  /// Clears all geometry anchors (viewport/metrics-level invalidation).
  void invalidateAllGeometry();
}
```

- [ ] **Step 1:** Write tests: register creates slot with increasing registrationOrder; re-register same id keeps order and slot identity, updates box, invalidates geometry only on box change; unregister removes; register during compute is deferred until `endCompute`; `markDead` removes at `endCompute`; `invalidateAllGeometry` resets tiers.
- [ ] **Step 2:** Run - FAIL. **Step 3:** Implement. **Step 4:** Run - PASS.
- [ ] **Step 5:** Commit: `feat: add SlotRegistry with deferred mutation`

### Task 3: Allocation-free region evaluation

**Files:**
- Modify: `lib/src/public/scroll_spy_region.dart`
- Test: `test/public/scroll_spy_region_into_test.dart`

**Interfaces:**
- Produces (added to the sealed `ScrollSpyRegion` and implemented by line/zone/custom):

```dart
/// Reused mutable result for the engine hot path.
final class RegionScratch {
  bool isFocused = false;
  double focusProgress = 0;
  double overlapFraction = 0;
}

// On ScrollSpyRegion (internal use by the engine; annotated @internal):
void evaluateMainAxisInto(
  RegionScratch out, {
  required double itemStart,
  required double itemEnd,
  required double anchorPos,
  // Only ScrollSpyCustomRegion uses these to build ScrollSpyRegionInput:
  required Rect Function() itemRect,
  required Rect viewportRect,
  required Axis axis,
});
```

Line/zone implement it with the same formulas as `evaluate` (no allocation).
Custom builds a `ScrollSpyRegionInput` and delegates to the evaluator (allocation is the documented cost of custom regions).

- [ ] **Step 1:** Write parity tests: for line (thickness 0 and >0) and zone across item positions (before/at/after anchor, spanning, zero-extent item), `evaluateMainAxisInto` matches `evaluate` on isFocused/focusProgress/overlapFraction exactly; custom region receives a correct `ScrollSpyRegionInput` and its result is clamped.
- [ ] **Step 2:** Run - FAIL. **Step 3:** Implement. **Step 4:** Run - PASS. `flutter test test/public/` stays green.
- [ ] **Step 5:** Commit: `feat: add allocation-free region evaluation path`

### Task 4: EngineGeometry (measure walk, tiers, linear model)

**Files:**
- Create: `lib/src/engine/engine_geometry.dart`
- Test: `test/engine/engine_geometry_test.dart` (widget tests with real render trees)

**Interfaces:**
- Consumes: `ItemSlot`, `GeometryTier`.
- Produces:

```dart
final class EngineGeometry {
  /// Tracked viewport state, refreshed once per pass.
  /// Returns false when no usable viewport exists.
  bool beginPass({required RenderAbstractViewport viewport});

  double get pixels;          // viewport.offset.pixels this pass
  Axis get axis;              // from viewport.axisDirection
  double get dir;             // +1 down/right, -1 up/left
  double get viewportMainExtent;
  double get viewportCrossExtent;

  /// Ensures slot.mainStart/mainEnd/crossStartNow/crossEndNow are current for
  /// this pass. Fast tier: O(1) validate + derive. Walk/matrix or invalid
  /// fast anchor: full re-measure + reclassify. Sets slot.measurable.
  void ensureMeasured(ItemSlot slot);

  /// Discovery helper used at registration time.
  static RenderAbstractViewport? viewportOf(RenderBox box);
}
```

Core algorithm (implement exactly):

1. `ensureMeasured` fast path: tier == fast AND fingerprint valid
   (`sliverChild.parentData is SliverMultiBoxAdaptorParentData` with non-null
   `layoutOffset == layoutOffset0`, `sliver.constraints.precedingScrollExtent
   == precedingExtent0`, box size == (boxW0,boxH0), viewport size unchanged)
   -> `mainStart = mainStart0 - dir * (pixels - pixels0)`, cross cached.
2. Otherwise full measure: walk `box` up to the viewport. Per level, reset one
   reused scratch Matrix4 to identity, call `parent.applyPaintTransform(child,
   scratch)`; if scratch is a pure translation (12 non-translation entries at
   identity values) accumulate dx/dy; on the first non-translation entry,
   restart the measure in matrix mode: fill a reused `List<RenderObject>` with
   the chain and compose like `getTransformTo` into a reused Matrix4, then map
   the item rect via `MatrixUtils.transformRect`. Record during the walk the
   first (child, parent-is-RenderSliver) pair as (sliverChild, sliver).
3. Classify: pure translation + sliver is `RenderSliverMultiBoxAdaptor` +
   child `layoutOffset != null` -> fast (capture anchor + fingerprint);
   pure translation otherwise -> walk; else matrix.
4. Not measurable (detached, no size, chain does not reach the tracked
   viewport, kept-alive child with null layoutOffset) -> `slot.measurable =
   false` via `resetMetrics()`.
5. Debug-only rotating cross-check: for one slot per pass, assert fast-tier
   derived mainStart equals a fresh walk result within 0.01px.

- [ ] **Step 1:** Write widget tests using a plain `ListView.builder` with probe render boxes (SizedBox items wrapped in a test probe widget exposing their RenderBox):
  - vertical list: measured rects match `localToGlobal(ancestor: viewport)` ground truth for all mounted items;
  - after `jumpTo(500)`, fast-tier slots derive correct rects with `geometryFullMeasures` unchanged (expose a counter on EngineGeometry for tests);
  - `reverse: true` list and a horizontal list produce correct rects (dir sign);
  - resizing an item above (rebuild with different extent) invalidates via layoutOffset mismatch and re-measures correctly;
  - an item inside `Transform.rotate` classifies as matrix tier and matches ground truth each frame;
  - `SliverToBoxAdapter` content classifies as walk tier and stays correct after scrolling.
- [ ] **Step 2:** Run - FAIL. **Step 3:** Implement `engine_geometry.dart` (single reused Matrix4 + chain list, counters `fullMeasures`, `fastHits` as `@visibleForTesting`). **Step 4:** Run - PASS.
- [ ] **Step 5:** Commit: `feat: add EngineGeometry with linear scroll model and adaptive tiers`

### Task 5: EngineSelection (policy + stability on slots, monotonic time)

**Files:**
- Create: `lib/src/engine/engine_selection.dart`
- Test: `test/engine/engine_selection_test.dart` (pure Dart; port every behavioral case from `test/engine/focus_selection_test.dart`)

**Interfaces:**
- Consumes: `ItemSlot` (metrics fields), `ScrollSpyPolicy`, `ScrollSpyStability`.
- Produces:

```dart
final class SelectionResult<T> { T? primaryId; Duration? primarySince; }

final class EngineSelection {
  /// Iterates measurable slots in registration order, applies the policy
  /// comparator with the deterministic tie-breaks (focusProgress desc,
  /// visibleFraction desc, |distance| asc, registration order), then the
  /// stability rules (minPrimaryDuration, hysteresisPx, preferCurrentPrimary,
  /// allowPrimaryWhenNoItemFocused), and writes slot.isPrimary flags.
  /// `now` is monotonic elapsed time from the engine stopwatch.
  static SelectionResult<T> select<T>({
    required List<ItemSlot<T>> slots,
    required ScrollSpyPolicy<T> policy,
    required ScrollSpyStability stability,
    required T? previousPrimaryId,
    required Duration? previousPrimarySince,
    required Duration now,
  });
}
```

Semantics are identical to 0.2.x `ScrollSpySelection.select` (same comparator
dispatch per policy type, same epsilon constants from `utils/equality.dart`,
same hysteresis rule on |distanceToAnchorPx|, same fallback-to-visible rules)
with DateTime replaced by Duration.

- [ ] **Step 1:** Port all cases from `test/engine/focus_selection_test.dart` to slots + Durations, preserving every behavioral assertion (primary among focused only; keep-primary fallback; min-duration blocks switch; hysteresis margin with tolerant compare; custom comparator with distance fallback; deterministic tie-breaks; exactly one isPrimary flag).
- [ ] **Step 2:** Run - FAIL. **Step 3:** Implement. **Step 4:** Run - PASS.
- [ ] **Step 5:** Commit: `feat: add slot-based selection and stability with monotonic time`

### Task 6: EngineFrame + controller commit rewrite

**Files:**
- Create: `lib/src/engine/engine_frame.dart`
- Modify: `lib/src/public/scroll_spy_controller.dart`
- Test: adapt `test/controller/scroll_spy_controller_diff_test.dart`, `_boolean_test.dart`, `_eviction_test.dart`; add `test/controller/scroll_spy_controller_lazy_test.dart`

**Interfaces:**
- Produces:

```dart
/// Internal engine->controller frame. Sets are reused engine buffers; the
/// controller must not retain them past commit.
final class EngineFrame<T> {
  T? primaryId;
  Set<T> focusedIds;
  Set<T> visibleIds;
  ItemSlot<T>? Function(T id) slotOf;
  Iterable<ItemSlot<T>> measurableSlots;
  ScrollSpySnapshot<T> Function() materializeSnapshot;

  /// Test helper: builds a frame (with backing slots) from a snapshot.
  static EngineFrame<T> fromSnapshot<T>(ScrollSpySnapshot<T> s);
}

// ScrollSpyController changes:
@internal
void commit(EngineFrame<T> frame);   // replaces commitFrame(ScrollSpySnapshot)

@visibleForTesting
int get debugMaterializedSnapshots;
@visibleForTesting
int get debugMaterializedItemFocus;
```

Commit algorithm (implement exactly):

1. primaryId notifier: set only when changed.
2. focusedIds notifier: if `setUnorderedEquals(current, frame.focusedIds)` keep
   the existing instance (no notify); else assign `Set<T>.unmodifiable(copy)`.
3. Per-item boolean notifiers: membership checks against frame sets /
   primaryId, toggling only on change (O(tracked)). Eviction: tracked id whose
   slot is missing or unmeasurable -> reset to false if it has listeners, else
   dispose and remove (same semantics as 0.2.x `_evictBoolNotifiersIfMissing`).
4. itemFocusOf notifiers: for tracked ids with a measurable slot, compare slot
   fields against the notifier value with the tolerances of
   `scrollSpyItemFocusNearlyEqual`; materialize a new `ScrollSpyItemFocus`
   only when different (count it). Missing/unmeasurable -> unknown-reset or
   evict (same rules as 0.2.x).
5. snapshot: lazy notifier. If it has listeners: materialize (count it) and
   notify per pass. Else: store the materializer and mark stale; the `.value`
   getter materializes on demand and caches until the next commit.
6. `tryGetItemFocus`: reads the live slot first (materializing nothing is
   impossible here; construct on demand), falling back to a tracked notifier
   value; returns null when unknown, as today.

`ScrollSpySnapshot` materialization builds unmodifiable sets/map ONCE from the
frame (no double-wrapping, no re-normalization).

- [ ] **Step 1:** Adapt the three controller test files mechanically: build frames via `EngineFrame.fromSnapshot(...)` and call `controller.commit(...)`; every behavioral assertion stays identical. Add lazy tests: with no snapshot listeners, two commits materialize zero snapshots and `snapshot.value` materializes exactly one; with a listener, one per commit; itemFocus materialization count stays 0 for sub-tolerance metric jitter and increments on real change; focusedIds instance is identical across commits with equal membership.
- [ ] **Step 2:** Run controller tests - FAIL. **Step 3:** Implement `engine_frame.dart` and rewrite the controller commit path (delete `commitFrame` and `_normalizeSnapshot`). **Step 4:** Run - PASS.
- [ ] **Step 5:** Commit: `feat: lazy diff-only controller commit via EngineFrame`

### Task 7: New ScrollSpyEngine + scope wiring + old engine deletion

**Files:**
- Create: `lib/src/engine/engine.dart`
- Modify: `lib/src/widgets/scroll_spy_scope.dart` (construct new engine; same widget API), `lib/scroll_spy.dart` (exports unchanged; internal imports updated)
- Delete: `lib/src/engine/focus_engine.dart`, `focus_geometry.dart`, `focus_registry.dart`, `focus_selection.dart`, `focus_diff.dart`
- Test: `test/engine/engine_compute_test.dart` (new; core pass behavior), existing widget tests keep passing in Task 8

**Interfaces:**
- Consumes: everything from Tasks 1-6.
- Produces (same responsibilities as the old `ScrollSpyEngine`, new internals):

```dart
class ScrollSpyEngine<T> {
  ScrollSpyEngine({
    required ScrollSpyController<T> controller,
    required ScrollSpyRegion region,
    required ScrollSpyPolicy<T> policy,
    required ScrollSpyStability stability,
    required ScrollSpyUpdatePolicy updatePolicy,
    required bool debugEnabled,
    required bool includeItemRects,
    EdgeInsets viewportInsets,
    bool insetsAffectVisibility,
  });

  void attach({ScrollController? scrollController});
  void detach();
  void updateScrollController(ScrollController? c);
  void updateConfig({...});                       // same fields as constructor
  void registerItem(T id, {required BuildContext context, required RenderBox box});
  void unregisterItem(T id);
  bool handleScrollNotification(ScrollNotification n);
  bool handleScrollMetricsNotification(ScrollMetricsNotification n);
  void handleMetricsChanged();                    // invalidates all geometry
  ValueListenable<ScrollSpyDebugFrame<T>?> get debugFrame;
  void dispose();
}
```

Compute pass (implement exactly):

1. Guard disposed/attached/dirty; consume dirty flag.
2. Resolve tracked viewport: cached; if null, discover via
   `EngineGeometry.viewportOf` from the first attached slot box; if none,
   commit an empty frame (primary null, empty sets) and return.
3. `geometry.beginPass(viewport)`; on failure (no size / no pixels) commit empty.
4. Effective viewport rect from insets (`insetsAffectVisibility` selects the
   visibility rect exactly as 0.2.x). Resolve anchorOffsetPx on the effective
   rect via `region` anchor.
5. `registry.beginCompute()`. For each slot: unmounted/detached ->
   `registry.markDead(slot)`; else `geometry.ensureMeasured(slot)`; if
   measurable compute visibleFraction (2D intersect with the visibility rect),
   distanceToAnchorPx (main-axis center minus anchor), then
   `region.evaluateMainAxisInto(...)` when visible; write flags and membership
   into the reused focused/visible sets. `registry.endCompute()`.
6. `EngineSelection.select(...)` with the engine Stopwatch elapsed; store
   primaryId/primarySince.
7. `controller.commit(frame)` with the reused frame object.
8. If `debugEnabled`: build and publish the debug frame (allocations allowed
   here only); otherwise skip entirely.

Scheduling/update-policy handling, notification handling, ScrollController
tick handling, and post-frame coalescing keep 0.2.x semantics verbatim
(perFrame / onScrollEnd / hybrid; ScrollMetricsNotification ignored while
scrolling; `ensureVisualUpdate` for timer-driven triggers).

- [ ] **Step 1:** Write `engine_compute_test.dart` (widget test): a scoped ListView produces correct primary/focused for zone+closestToAnchor after pump and after jumpTo; unregistered items disappear from state; empty scope commits empty state; debug frames are null-op when debugEnabled is false (listenable never fires past the initial value).
- [ ] **Step 2:** Run - FAIL. **Step 3:** Implement `engine.dart`; rewire `scroll_spy_scope.dart` (pass `debugEnabled: widget.debug`); delete the five old engine files; fix all remaining internal imports. **Step 4:** Run the new test - PASS. `flutter analyze` - zero issues.
- [ ] **Step 5:** Commit: `feat: rebuild ScrollSpyEngine on slots and linear geometry; delete legacy engine`

### Task 8: Whole-suite migration to green

**Files:**
- Modify: any test under `test/` that imported deleted internals (`focus_fixtures.dart`, `focus_engine_insets_test.dart`, `focus_selection_test.dart` (now superseded by Task 5 file; delete), `widget_harness.dart` if needed)

- [ ] **Step 1:** Run `flutter test`; list failures.
- [ ] **Step 2:** For each failure: if it asserts public behavior, fix the implementation until it passes unchanged; if it pokes deleted internals, rewrite it against the new internals preserving the behavioral assertion; delete only tests that duplicate Task 5's ported coverage.
- [ ] **Step 3:** `flutter test` fully green; `flutter analyze` zero issues; `dart format .` clean.
- [ ] **Step 4:** Commit: `test: migrate suite to v1 engine internals`

### Task 9: Laziness/caching invariants + perf benchmark

**Files:**
- Create: `test/perf/compute_pass_benchmark_test.dart`, `test/engine/engine_invariants_test.dart`

- [ ] **Step 1:** Invariants (using the counters from Tasks 4/6): steady scroll over a 200-item list with itemExtent performs zero full measures after warmup (all fast hits); no snapshot materialization without listeners; no ScrollSpyItemFocus materialization for Lite-only consumers.
- [ ] **Step 2:** Benchmark: pump a 200-item feed, run 300 simulated scroll frames for N in {10, 50, 200} mounted items, print mean/max compute-pass wall time via Stopwatch around the engine pass (expose a `@visibleForTesting` hook or measure via pumping). Not CI-gated; prints results.
- [ ] **Step 3:** Both files pass. Commit: `test: perf invariants and compute-pass benchmark`

### Task 10: Example perf lab page

**Files:**
- Modify: `example/lib/main.dart` (add a "Perf lab" page: 1000-item dense feed with `ScrollSpyItemLite`, optional heavy-item toggle, frame-time HUD via `SchedulerBinding.addTimingsCallback` showing avg/worst build+raster ms)

- [ ] **Step 1:** Implement page + navigation entry. **Step 2:** `flutter analyze example` zero issues; `flutter test example` green.
- [ ] **Step 3:** Commit: `feat(example): add perf lab page`

### Task 11: Release 1.0.0 docs

**Files:**
- Modify: `pubspec.yaml` (version 1.0.0), `CHANGELOG.md` (1.0.0 entry: user-observable changes only), `README.md` (performance section rewritten around the new engine model; update policy guidance updated to "semantic, not perf, controls")

- [ ] **Step 1:** Update the three files. **Step 2:** `dart format .`; `flutter analyze`; `flutter test`; `flutter pub publish --dry-run` - all clean.
- [ ] **Step 3:** Commit: `chore: release 1.0.0`

## Self-review notes

- Spec coverage: 5.2 -> Task 4; 5.3 -> Tasks 1-2; 5.4 -> Task 7; 5.5 -> Task 5; 5.6 -> Task 6; 5.7 -> Task 7; 5.8/5.10 -> Tasks 8-11; edge cases 5.9 -> Tasks 4, 7, 8 tests.
- Type consistency: `ItemSlot`, `SlotRegistry`, `EngineGeometry.ensureMeasured`, `EngineSelection.select`, `EngineFrame`, `controller.commit` names used consistently across tasks.
- Known judgment points left to the executor: exact private helper decomposition inside engine.dart; test harness plumbing for probing RenderBoxes in Task 4.
