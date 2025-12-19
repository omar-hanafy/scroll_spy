# viewport_focus

Viewport-aware focus detection for scrollables. Compute focused items and a
stable primary item for feeds, autoplay, analytics, and prefetching.

![viewport_focus demo](https://raw.githubusercontent.com/omar-hanafy/viewport_focus/main/screenshots/viewport_focus.gif)

---

## Features

- **Primary + focused selection**
  - `primaryId`: one winner
  - `focusedIds`: all items intersecting the focus region
  - `snapshot`: full per-item metrics
- **Configurable focus region**
  - `ViewportFocusRegion.zone(...)` (recommended default)
  - `ViewportFocusRegion.line(...)`
  - `ViewportFocusRegion.custom(...)`
- **Multiple primary selection policies**
  - closest to anchor
  - largest visible fraction
  - largest overlap with focus region
  - largest focus progress
  - fully custom comparator
- **Anti-flicker stability**
  - hysteresis (px)
  - minimum primary duration
  - optional keep-primary fallback when no item is focused
- **Update policy (performance control)**
  - per-frame
  - scroll-end only (debounced)
  - hybrid (per-frame drag + throttled ballistic + final settle)
- Built for scroll performance: O(N mounted) focus computation + O(1) targeted
  updates. ViewportFocus minimizes rebuild fan-out with per-item notifiers and
  diff-only global signals, and offers tunable focus detection. Often faster in
  real feeds; choose the right update policy and listeners for your use case.
- **Debug overlay**
  - paints focus region + primary/focused outlines + optional labels

---

## Install

Add to `pubspec.yaml`:

```yaml
dependencies:
  viewport_focus: ^0.1.0
```

Then:

```dart
import 'package:viewport_focus/viewport_focus.dart';
```

---

## Quick mental model

- Scope measures each registered item in viewport coordinates.
- Region decides `isFocused` and computes focus metrics.
- Policy picks a primary candidate from the focused set.
- Stability smooths primary changes to avoid flicker.
- Controller exposes the results as listenables.

---

## Quick start (Scope + Item)

Use this form if you already have a custom scrollable and do not want the
convenience wrappers.

```dart
final focus = ViewportFocusController<int>();

@override
void dispose() {
  focus.dispose();
  super.dispose();
}

@override
Widget build(BuildContext context) {
  return ViewportFocusScope<int>(
    controller: focus,
    region: ViewportFocusRegion.zone(
      anchor: const ViewportAnchor.fraction(0.5),
      extentPx: 180,
    ),
    policy: const ViewportFocusPolicy<int>.closestToAnchor(),
    stability: const ViewportFocusStability(
      hysteresisPx: 24,
      minPrimaryDuration: Duration(milliseconds: 120),
      preferCurrentPrimary: true,
      allowPrimaryWhenNoItemFocused: true,
    ),
    updatePolicy: const ViewportUpdatePolicy.perFrame(),
    child: ListView.builder(
      itemExtent: 220,
      itemCount: 60,
      itemBuilder: (context, index) {
        return ViewportFocusItem<int>(
          id: index,
          child: /* static subtree (optional) */ null,
          builder: (context, itemFocus, child) {
            return DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  width: 2,
                  color: itemFocus.isPrimary
                      ? const Color(0xFF34C759)
                      : (itemFocus.isFocused
                          ? const Color(0xFFFFCC00)
                          : const Color(0xFF8E8E93)),
                ),
              ),
              child: SizedBox.expand(child: child),
            );
          },
        );
      },
    ),
  );
}
```

---

## Listening to focus state

### 1) Primary changes (cheap)

```dart
ViewportPrimaryBuilder<int>(
  builder: (context, primaryId, _) {
    return Text('Primary: ${primaryId ?? "-"}');
  },
);
```

Or listen without rebuilding:

```dart
ViewportPrimaryListener<int>(
  onChanged: (prev, curr) {
    // start/stop video playback, log analytics, etc.
  },
  child: const SizedBox.shrink(),
);
```

### 2) Focused set changes

```dart
ViewportFocusedIdsBuilder<int>(
  builder: (context, focusedIds, _) {
    return Text('Focused: ${focusedIds.length}');
  },
);
```

### 3) Per-item focus (only rebuild that item)

`ViewportFocusItem` already does this via `controller.itemFocusOf(id)`.

You can also manually wire:

```dart
ViewportItemFocusBuilder<int>(
  id: 7,
  builder: (context, itemFocus, _) => Text('${itemFocus.isPrimary}'),
);
```

### 4) Full snapshot (most detail, most updates)

```dart
ViewportSnapshotBuilder<int>(
  builder: (context, snapshot, _) {
    return Text('Items in snapshot: ${snapshot.items.length}');
  },
);
```

---

## Focus regions

### Zone (recommended default)

A band centered on the anchor; items intersecting the band are focused.

```dart
ViewportFocusRegion.zone(
  anchor: const ViewportAnchor.fraction(0.5),
  extentPx: 180,
)
```

### Line

A thin line at the anchor (optionally with thickness).

```dart
ViewportFocusRegion.line(
  anchor: const ViewportAnchor.fraction(0.5),
  thicknessPx: 0, // infinitesimal line
)
```

### Custom region

Bring your own evaluator:

```dart
ViewportFocusRegion.custom(
  anchor: const ViewportAnchor.fraction(0.5),
  evaluator: (input) {
    return const ViewportRegionResult(
      isFocused: true,
      focusProgress: 1.0,
      overlapFraction: 1.0,
    );
  },
)
```

---

## Primary selection policies

Built-ins:

```dart
const ViewportFocusPolicy<int>.closestToAnchor();
const ViewportFocusPolicy<int>.largestVisibleFraction();
const ViewportFocusPolicy<int>.largestFocusOverlap();
const ViewportFocusPolicy<int>.largestFocusProgress();
```

Custom comparator:

```dart
ViewportFocusPolicy<int>.custom(
  compare: (a, b) {
    // return < 0 when a is better than b
    // return > 0 when b is better
    // return 0 to fall back to deterministic tie-break rules
    return b.visibleFraction.compareTo(a.visibleFraction);
  },
);
```

---

## Update policies (performance)

- `perFrame()`
  Most responsive. Computes at most once per frame while scrolling.
- `onScrollEnd(debounce: ...)`
  Cheapest CPU. Computes only after scroll settles.
- `hybrid(...)` (recommended for many feeds)
  Per-frame while dragging, throttled during ballistic fling, always compute on
  scroll end.

```dart
ViewportUpdatePolicy.hybrid(
  scrollEndDebounce: const Duration(milliseconds: 80),
  ballisticInterval: const Duration(milliseconds: 50),
  computePerFrameWhileDragging: true,
);
```

---

## Nested scrollables (important)

If your list items contain nested scrollables (horizontal carousels, etc.), use
`notificationDepth` (and/or `notificationPredicate`) so only the correct
scrollable drives focus:

```dart
ViewportFocusScope<int>(
  notificationDepth: 0, // default
  child: ...
)
```

---

## Debug overlay

Enable the overlay:

```dart
ViewportFocusScope<int>(
  debug: true,
  debugConfig: const ViewportFocusDebugConfig(
    enabled: true,
    includeItemRectsInFrame: true, // more allocations (debug-only)
    showFocusRegion: true,
    showPrimaryOutline: true,
    showFocusedOutlines: true,
    showLabels: false,
  ),
  child: ...
)
```

Tip: Keep `includeItemRectsInFrame = false` in release builds to avoid extra
allocations.

---

## What is in the box (API map)

Core:
- `ViewportFocusScope<T>`
- `ViewportFocusItem<T>`
- `ViewportFocusController<T>`

Models:
- `ViewportItemFocus<T>`
- `ViewportFocusSnapshot<T>`

Configuration:
- `ViewportFocusRegion` + `ViewportAnchor`
- `ViewportFocusPolicy`
- `ViewportFocusStability`
- `ViewportUpdatePolicy`

Extras:
- Debug overlay (`ViewportFocusDebugOverlay`, `ViewportFocusDebugConfig`)
- Convenience wrappers (`ViewportFocusListView`, `ViewportFocusGridView`,
  `ViewportFocusPageView`, `ViewportFocusCustomScrollView`)
- Builders/listeners (`ViewportPrimaryBuilder`, `ViewportPrimaryListener`, etc.)

---

## Contributing / Development
Thank you for your interest in contributing in this package. Make sure before you open up PR to do this:

1- run those and make sure tests are green.
```bash
dart format .
flutter analyze
flutter test
flutter pub publish --dry-run
```
2- If you change public behavior or API surface, update the docs and changelog
alongside the code.

---

## License

MIT. See `LICENSE`.
