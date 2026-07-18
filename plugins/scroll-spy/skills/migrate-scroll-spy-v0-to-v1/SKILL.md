---
name: migrate-scroll-spy-v0-to-v1
description: "Use when upgrading a Flutter project from scroll_spy 0.1.x or 0.2.x to 1.x, when a build breaks after a scroll_spy upgrade with unresolved names such as ScrollSpyRegistry, ScrollSpyGeometry, ScrollSpySelection, ScrollSpyDiff, or commitFrame, or when estimating how much work the 0.x to 1.x upgrade needs."
license: MIT
---

# Migrate scroll_spy 0.x to 1.x

1.0.0 rebuilt the engine internals for performance. The app-facing API is
unchanged; only code that touched engine internals or fed the controller by
hand needs work. Source versions supported here: 0.1.x and 0.2.x (0.1 to 0.2
was additive, so both migrate in one hop). Target: any 1.x.

## Step 1: Detect the current state

Read the project's pubspec.yaml (`scroll_spy:` constraint) and pubspec.lock
(resolved version). Then search for the only symbols that break:

```bash
grep -rnE "commitFrame|ScrollSpyDiff|ScrollSpyRegistry|ScrollSpyGeometry|ScrollSpySelection|scroll_spy/src/" lib test
```

- Constraint already `^1.x` and the grep is empty: the project is migrated;
  report that and stop.
- Resolved version below 0.1.0: unsupported here; ask the user.
- Grep hits: classify each hit using the table in Step 4 before editing.

## Step 2: Preconditions

Confirm a clean VCS state and a passing `flutter test` baseline first, so
migration failures are attributable. 1.x requires Dart SDK `^3.6.0` and
Flutter `>=3.27.0`; check the project's `environment:` allows that.

## Step 3: Bump the dependency

In pubspec.yaml set `scroll_spy: ^1.0.0`, run `flutter pub get`.

## Step 4: Fix what the compiler reports

Everything in the public app surface is unchanged: scope, items (`ScrollSpyItem`,
`ScrollSpyItemLite`), all wrappers, all builders/listeners, regions, anchors,
policies, stability, update policies, `viewportInsets`, notification filters,
debug overlay, diagnostics, and every `ScrollSpyController` read API
(`primaryId`, `focusedIds`, `snapshot`, `itemFocusOf`, `itemIsPrimaryOf`,
`itemIsFocusedOf`, `itemIsVisibleOf`, `tryGetItemFocus`). Files that only use
these need zero changes; do not churn them.

Removed in 1.0.0, with replacements:

| Removed | Was used for | Replacement |
|---|---|---|
| `ScrollSpyController.commitFrame(snapshot)` | feeding hand-built snapshots into a controller | see decision list below |
| `ScrollSpyDiff.commitToController(...)` | same, via the engine seam | same decision list |
| `ScrollSpyRegistry`, `ScrollSpyRegistryEntry` | inspecting registered items | `controller.snapshot.value.items` (all measurable items) or `tryGetItemFocus(id)` |
| `ScrollSpyGeometry`, `ScrollSpyGeometryResult` | manual geometry math | no public equivalent; app code should consume per-item metrics (`visibleFraction`, `distanceToAnchorPx`, rects in debug) instead |
| `ScrollSpySelection`, `ScrollSpySelectionResult` | manual primary ranking | express the ranking as `ScrollSpyPolicy.custom(compare: ...)` |
| imports of `package:scroll_spy/src/...` | reaching internals | import `package:scroll_spy/scroll_spy.dart` only |

Choosing a `commitFrame` replacement:

1. **Test only needs a seeded read state** (asserts on `.value` getters,
   never needs a second frame): construct the controller with
   `ScrollSpyController(initialSnapshot: ScrollSpySnapshot(...))`. The seed
   serves all reads until a real scope commits. This is the smallest change
   and keeps the test widget-free.
2. **Test asserts on notification behavior across frames** (like "listener
   fired once per change"): drive a real scope in a widget test. Use the
   harness template in [references/test-harness.md](references/test-harness.md);
   it encodes the required pump discipline (item registration and engine
   compute each happen in post-frame callbacks, so state exists only after
   two extra `pump()`s) and the scroll patterns per update policy.
3. **Non-test injection pipelines** (snapshot replayers, demo recorders):
   1.x has no public injection path, deliberately. Options, in order of
   preference: (a) refactor the consumer to accept `ValueListenable`s and
   back them with plain `ValueNotifier`s the replayer owns; (b) keep the
   tool pinned to 0.2.7. Do not fake a controller subclass; its commit path
   is `@internal`. This choice affects call sites, so surface it to the user
   before rewriting.

## Step 5: Re-verify behavior that changed semantics

- `ScrollSpyStability.minPrimaryDuration` now uses a monotonic clock. Tests
  that manipulated wall-clock time to expire hold windows must use pumped
  test time instead.
- `ScrollSpySnapshot.computedAt` is stamped when the snapshot instance is
  materialized (lazily), not when the engine computed. Do not assert exact
  timestamps or cross-snapshot time deltas.
- Debug-frame bookkeeping only runs under `ScrollSpyScope(debug: true)`;
  tests inspecting the debug overlay or engine debug stream must set it.

## Step 6: Validate

```bash
dart format <changed files>
flutter analyze
flutter test
grep -rnE "commitFrame|ScrollSpyDiff|ScrollSpyRegistry|ScrollSpyGeometry|ScrollSpySelection|scroll_spy/src/" lib test
```

The grep must come back empty. Expect no new analyzer warnings from this
migration; if `flutter analyze` reports deprecations, they are unrelated.
Report any Step 4 case-3 decisions you made and every file you changed.

## Rollback

Restore pubspec.yaml (and pubspec.lock if committed) to the previous
constraint and run `flutter pub get`; 0.2.7 remains published.

## Example: the common test migration

Before (0.2.x):

```dart
final controller = ScrollSpyController<int>();
controller.commitFrame(snapshotWithPrimary(1));
expect(controller.primaryId.value, 1);
```

After (1.x, seeding path):

```dart
final controller = ScrollSpyController<int>(
  initialSnapshot: snapshotWithPrimary(1),
);
expect(controller.primaryId.value, 1);
```

After (1.x, behavior path): see the full harness in
[references/test-harness.md](references/test-harness.md).
