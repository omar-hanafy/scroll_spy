---
name: convert-visibility-detector-to-scroll-spy
description: "Use when replacing the visibility_detector package with scroll_spy in a Flutter app, when migrating VisibilityDetector, VisibilityInfo, or VisibilityDetectorController code, or when a VisibilityDetector-based feed additionally needs a single stable primary item, per-item focus metrics, or scroll-performance improvements."
license: MIT
---

# Convert visibility_detector to scroll_spy

visibility_detector reports per-widget paint-based visibility anywhere in the
tree. scroll_spy is scoped to one scrollable and adds what VD lacks: a focus
region, a single stable primary with anti-flicker rules, and rich per-item
metrics with rebuild isolation. Convert when the detectors live inside a
scrollable (feeds, lists, grids, pagers). Do NOT convert detectors that are
not inside a scrollable (dialogs, overlays, static layouts) or that rely on
paint-level occlusion (`Opacity(opacity: 0)`, `Offstage`) - scroll_spy
models scroll geometry, not painting; leave those on visibility_detector and
say so.

## API mapping

| visibility_detector | scroll_spy replacement |
|---|---|
| `VisibilityDetector(key:, onVisibilityChanged:, child:)` per item | Wrap the scrollable once (`ScrollSpyListView.builder`, `ScrollSpyGridView.builder`, `ScrollSpyCustomScrollView`, `ScrollSpyPageView.builder`, or raw `ScrollSpyScope<T>`), then per item `ScrollSpyItemLite<T>(id:, ...)` or listener widgets |
| `Key('card-$id')` identity | the typed `id:` on the item (stable, unique per scope); keep any widget `key` separately |
| `VisibilityInfo.visibleFraction` | `ScrollSpyItemFocus.visibleFraction` (0..1, same meaning) via `snapshot.items`, `itemFocusOf(id)`, or `tryGetItemFocus(id)` |
| `onVisibilityChanged` enter/exit (fraction > 0 / == 0) | per item: `ScrollSpyItemVisibleListener(onChanged: (was, is) ...)`; or one screen-level `controller.snapshot` listener diffing `visibleIds` (better when you also need fraction thresholds; absence from `snapshot.items` while unmounted = fraction 0) |
| threshold logic (`fraction >= 0.6`) | scan `snapshot.items.values` in one snapshot listener with your own seen-set (dedup) |
| `VisibilityDetectorController.instance.updateInterval` (global throttle) | `updatePolicy:` on the scope/wrapper: `perFrame` (default; per-scroll precision), `ScrollSpyUpdatePolicy.hybrid(ballisticInterval: ...)` (throttled flings, closest analog), or `onScrollEnd(debounce: ...)` (events only at rest). Non-const; store in a field |
| `VisibilityDetectorController.instance.notifyNow()` / `forget()` | no equivalents needed: computes are scroll-driven; notifiers auto-evict |
| final `0.0` callback on unmount | items leaving tracking flip their boolean listenables to false; a snapshot diff also observes disposal. Flush any pending exits in your `State.dispose` |

What has no VD equivalent (the usual reason to convert): `isPrimary` +
`ScrollSpyStability` (stable winner for autoplay/featuring via
`ScrollSpyPrimaryListener`), `focusProgress`/`distanceToAnchorPx` (effects),
regions/policies, and boolean-only rebuild isolation.

## Behavioral difference you must handle: covered routes

VD (paint-based) reports `visibleFraction: 0` when an opaque route covers
the screen, so VD code often gets exit events "for free" on navigation.
scroll_spy freezes instead: no scrolling means no computes, so
`primaryId`, `focusedIds`, and per-item state keep their last values while
covered (verified behavior). If the analytics contract requires exits on
navigation (or must suppress events while covered):

- Simplest: listen to `TickerMode.getNotifier(context)` from inside the
  route; it flips to disabled exactly when an opaque push transition
  completes and back on pop. Flush exits and set a `_covered` guard there.
- Navigation-explicit alternative: a `RouteObserver` + `RouteAware`
  (`didPushNext` = flush exits and pause; `didPopNext` = resync).

On pop, re-entry events for still-visible items only fire if you emit them
yourself during resync; scroll_spy will not re-notify unchanged state.

## Conversion order (keeps every commit compiling)

1. Add `scroll_spy` to pubspec (keep visibility_detector for now).
2. Introduce the scope: swap the scrollable for its ScrollSpy wrapper (or
   wrap with `ScrollSpyScope<T>`), with a `ScrollSpyController<T>` as a
   `State` field, disposed in `dispose`. Pick `T` = your id type.
3. Move the analytics/side-effect logic to controller listeners (snapshot
   scan or per-item listeners per the mapping) including the covered-route
   guard if required. Delete each `VisibilityDetector` wrapper as its logic
   moves; keep the child subtree in the item's `child:` slot.
4. Add the new capabilities that motivated the conversion (primary
   selection, stability, effects), typically via `ScrollSpyPrimaryListener`.
5. Remove the visibility_detector dependency and its controller tuning.

## Verify

- `flutter analyze`; grep for `visibility_detector` returns nothing.
- Impression parity: scroll the converted screen and compare the event log
  with the pre-conversion behavior for: normal scroll, fast fling, push a
  covering route, pop back, and leave the screen. Fraction thresholds use
  the same 0..1 scale, so logged ids should match (per-frame detection may
  catch fast-fling crossings the old global throttle missed; call that out
  as an improvement, not a regression).
- For widget tests, the two-frame commit pipeline applies: see the
  diagnose-scroll-spy skill.

Report the mapping applied per removed API, the covered-route strategy
chosen, and any detectors you deliberately left on visibility_detector.
