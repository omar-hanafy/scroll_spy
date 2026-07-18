---
name: tune-scroll-spy-stability
description: "Use when scroll_spy selects the right things but behaves badly over time: the primary item flickers or alternates between two items, switches too eagerly or too sluggishly, stutters at card boundaries in autoplay, goes null between items or during fast scrolls, sticks to an old item too long, or updates at the wrong moments (mid-drag versus after settling)."
license: MIT
---

# Tune scroll_spy primary selection

The pipeline is: region decides who is focused, policy ranks them, stability
decides when the winner may change, update policy decides when any of it
recomputes. Match the symptom to the stage; change one knob at a time and
re-test, because several symptoms have look-alike causes in different stages.

## Symptom to knob

| Symptom | Stage | Change |
|---|---|---|
| Primary alternates rapidly between two adjacent items while scrolling slowly | stability | Raise `hysteresisPx` (start 24, range 10-50): a challenger must be closer to the anchor than the incumbent by this many px |
| Fast fling fires a barrage of primary changes | stability | Set `minPrimaryDuration` (start 150ms, range 100-250): incumbent holds at least this long while it stays focused |
| Primary switches feel sluggish/sticky after tuning | stability | Lower the two values above; or set `preferCurrentPrimary: false` to always take the best candidate each pass (subject only to min duration) |
| Autoplay pauses between cards; primary goes null when the region falls in a gap | stability | Keep `allowPrimaryWhenNoItemFocused: true` (default): keeps a best-available primary for gapless playback |
| TOC/reading UI highlights a section when nothing is truly under the line | stability | Set `allowPrimaryWhenNoItemFocused: false`: primary becomes null the moment nothing intersects the region (strict semantics) |
| Focus drops out between items even while one is clearly nearby | region | Zone too thin: raise `extentPx` (item-extent-sized zones behave well); or switch a `line` to a `zone` |
| Two items both "look focused" and the winner feels arbitrary | policy | Pick the policy that matches intent: `closestToAnchor` (feeds), `largestVisibleFraction` (galleries), `largestFocusOverlap`, `largestFocusProgress`; ties break deterministically by focusProgress, then visibleFraction, then distance, then registration order |
| Primary lags the finger during drag, corrects on settle | update policy | That is `onScrollEnd`/`hybrid` semantics; use `perFrame` (default) for live tracking |
| Updates during scroll are wanted only at rest (impressions, autoplay-on-settle) | update policy | `onScrollEnd(debounce: 80ms)`; state is intentionally stale mid-scroll |
| Rebuild pressure from metric listeners during flings | update policy | `hybrid(ballisticInterval: 50ms)`: per-frame while dragging, throttled ballistic, guaranteed settle pass |
| First/last items can never win with a centered anchor | geometry | Symmetric list padding of `(viewportExtent - itemExtent) / 2` (the official demo technique), or bias the anchor (`fraction(0.4)`, or `offsetPx`) |
| Tuning "randomly resets" while scrolling | config churn | `onScrollEnd(...)`/`hybrid(...)` have no `const` constructors and no `==`; constructing them inline in `build` makes every rebuild a config change. Build once, store in a field |

## Mechanics you must not misstate

- `hysteresisPx` compares absolute distance-to-anchor: the challenger wins
  only when `challenger.absDistance + hysteresisPx < incumbent.absDistance`
  style dominance holds, after `minPrimaryDuration` is satisfied, and only
  while `preferCurrentPrimary` is true.
- `minPrimaryDuration` is monotonic-clock based (1.x); wall-clock changes
  cannot shorten or break the hold. The hold applies only while the current
  primary remains focused; when it leaves the region, replacement is
  immediate (or falls back per `allowPrimaryWhenNoItemFocused`).
- Defaults are `hysteresisPx: 0`, `minPrimaryDuration: zero`: stability is
  OFF until you set values. Feeds should set both.
- `ScrollSpyStability.disabled()` disables stickiness but still keeps
  `allowPrimaryWhenNoItemFocused: true`.
- Stability never changes who is focused, only when primary may switch.
- Custom policy comparators must be pure, fast, deterministic; return
  negative when `a` should win. Non-deterministic comparators cause churn no
  stability setting can hide.

## Recommended starting points

| Use case | Region | Policy | Stability |
|---|---|---|---|
| Autoplay feed | zone(fraction(0.5), extentPx ~ 200 or itemExtent) | closestToAnchor | 24px, 150ms, both flags true |
| Reading position / TOC | line(fraction(0.2..0.3), thickness 0-2) | closestToAnchor | 0-8px, 0-100ms, `allowPrimaryWhenNoItemFocused` per strictness |
| Carousel/pager | zone at center, extent ~ page | closestToAnchor or largestFocusProgress | small hysteresis; pager snapping already stabilizes |
| Gallery grid | zone or whole-viewport zone | largestVisibleFraction | 100-150ms duration; hysteresis less relevant |

## Verify

Reproduce the original gesture (slow boundary scroll for flicker, fling for
barrage). Confirm with `debug: true` overlay (green outline = primary) or by
counting transitions in a `ScrollSpyPrimaryListener` log. In widget tests,
drive real gestures and pump per the policy's timing (see the
diagnose-scroll-spy skill for the two-frame commit pipeline). State which
knob changed, why that stage, and what you observed before/after.
