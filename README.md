# scroll_spy

<p align="center">
  <img src="https://raw.githubusercontent.com/omar-hanafy/scroll_spy/main/screenshots/scroll_spy.png" alt="scroll_spy icon" width="112" />
</p>

<h3 align="center">Know what is visible. Choose one stable winner.</h3>

<p align="center">
  Viewport focus detection and stable primary item selection for Flutter
  scrollables, built for video autoplay feeds, analytics, reading position,
  carousels, and prefetching.
</p>

<p align="center">
  <a href="https://pub.dev/packages/scroll_spy"><img src="https://img.shields.io/pub/v/scroll_spy.svg" alt="pub package" /></a>
  <a href="https://pub.dev/packages/scroll_spy/score"><img src="https://img.shields.io/pub/points/scroll_spy" alt="pub points" /></a>
  <a href="https://github.com/omar-hanafy/scroll_spy/actions/workflows/ci.yml"><img src="https://github.com/omar-hanafy/scroll_spy/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT license" /></a>
</p>

<p align="center">
  <a href="https://omar-hanafy.github.io/scroll-spy/demo/">
    <img src="https://raw.githubusercontent.com/omar-hanafy/scroll_spy/main/screenshots/scroll_spy.gif" alt="scroll_spy demo" width="360" />
  </a>
</p>
<p align="center">
  <a href="https://omar-hanafy.github.io/scroll-spy/"><b>Product guide</b></a>
  &nbsp;·&nbsp;
  <a href="https://omar-hanafy.github.io/scroll-spy/demo/"><b>Real video feed demo</b></a>
  &nbsp;·&nbsp;
  <a href="https://pub.dev/documentation/scroll_spy/latest/"><b>API docs</b></a>
</p>

---

scroll_spy is the layer between raw Flutter widget visibility and a product
decision. It reports every visible and focused item, then applies an explicit
policy and stability rules to select one `primaryId`. A video engine can pause
the previous ID and play the next without two half-visible cards fighting over
audio.

## What it answers

Every scrolling feed eventually needs to know:

- **Which items are visible right now?** (detach video controllers off-screen)
- **Which items are inside my "attention area"?** (a line or zone in the viewport)
- **Which single item should be *the* one?** (autoplay this card, highlight this
  TOC section, log this impression) - and how do I keep that choice from
  flickering while the user scrolls?

scroll_spy computes all of this for you, every scroll, with a configurable
pipeline and zero manual geometry math:

```
scroll event
    |
    v
 Measure      each registered item's rect in viewport coordinates
    |
    v
 Region       does the item intersect the focus line/zone?  -> isFocused + metrics
    |
    v
 Policy       rank focused items, pick one winner            -> primary candidate
    |
    v
 Stability    hysteresis + min-duration to prevent flicker   -> primaryId
    |
    v
 Controller   ValueListenables: primaryId / focusedIds / snapshot / per-item
```

## Why this package

- **A stable primary, not just visibility.** Visibility detection tells you an
  item is 60% on screen. scroll_spy additionally picks *one* winner using a
  policy (closest to anchor, largest visible fraction, ...) and smooths it with
  hysteresis and minimum-hold-time so autoplay does not stutter between two
  half-visible cards.
- **Rich per-item metrics.** `visibleFraction`, `distanceToAnchorPx`,
  `focusProgress` (0..1 center-closeness, great for scale/parallax effects),
  and `focusOverlapFraction`.
- **Built for scroll performance.** During steady scrolling the engine derives
  each item's position with O(1) arithmetic from a cached scroll model - no
  render-tree walks, no matrix math, no allocations on the hot path. Snapshots
  are materialized lazily, only when something listens. Items under transforms
  or exotic custom slivers are detected automatically and measured with a
  general path, so correctness never depends on your layout being "standard".
- **Granular rebuild control.** Per-item notifiers, boolean-only "lite" items,
  diff-only global signals, and listener widgets for side effects that should
  not rebuild anything.
- **A real debug overlay.** Paint the focus region, item bounds, and
  primary/focused outlines directly over your list while you tune it.

## How it differs from visibility detection

Choose by the decision your screen needs:

| Package | Core job | One primary winner | Built-in anti-flicker |
|---|---|---:|---:|
| **scroll_spy** | Decide which visible item should own attention | Yes | Hysteresis + minimum hold |
| [`visibility_detector`](https://pub.dev/packages/visibility_detector) | Report how much of an individual widget is visible | Application code | Application code |
| [`inview_notifier_list`](https://pub.dev/packages/inview_notifier_list) | Notify an indexed list child when it enters a configured in-view range | Application code | Application code |

Use `visibility_detector` when per-widget visibility information is the whole
job. Use `inview_notifier_list` when simple indexed-list threshold notification
is enough. Use scroll_spy when multiple visible items compete and exactly one
must drive playback, highlighting, reading position, or another attention-based
side effect.

This comparison describes package responsibilities, not a universal speed
ranking. The [comparison benchmark](benchmark/) is reproducible so you can
inspect its scenario and run it on your own hardware.

---

## Install

```yaml
dependencies:
  scroll_spy: ^1.0.2
```

```dart
import 'package:scroll_spy/scroll_spy.dart';
```

---

## Quick start

The fastest path is a drop-in wrapper. `ScrollSpyListView.builder` mirrors
`ListView.builder` and wires the scope for you; you wrap each item in
`ScrollSpyItem` and react to its focus state:

```dart
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final _spy = ScrollSpyController<int>();

  @override
  void dispose() {
    _spy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollSpyListView<int>.builder(
      controller: _spy, // focus controller, NOT a ScrollController
      region: ScrollSpyRegion.zone(
        anchor: const ScrollSpyAnchor.fraction(0.5), // viewport center
        extentPx: 200,                               // 200px attention band
      ),
      policy: const ScrollSpyPolicy<int>.closestToAnchor(),
      stability: const ScrollSpyStability(
        hysteresisPx: 24,
        minPrimaryDuration: Duration(milliseconds: 150),
      ),
      itemCount: 60,
      itemExtent: 220,
      itemBuilder: (context, index) {
        return ScrollSpyItem<int>(
          id: index,
          // `child` is your static subtree; it does NOT rebuild on focus changes.
          child: FeedCardBody(index: index),
          builder: (context, focus, child) {
            return AnimatedScale(
              scale: focus.isPrimary ? 1.0 : 0.95,
              duration: const Duration(milliseconds: 200),
              child: child,
            );
          },
        );
      },
    );
  }
}
```

Then react to the winner anywhere - for example, drive video playback without
rebuilding a single widget:

```dart
ScrollSpyPrimaryListener<int>(
  controller: _spy,
  onChanged: (previousId, currentId) {
    playerFor(previousId)?.pause();
    playerFor(currentId)?.play();
  },
  child: feed,
)
```

That is the whole loop: **region** decides who is focused, **policy** picks the
primary, **stability** keeps it calm, the **controller** tells you about it.

### Bring your own scrollable

The wrappers (`ScrollSpyListView`, `ScrollSpyGridView`,
`ScrollSpyCustomScrollView`, `ScrollSpyPageView`) are conveniences. For any
other scrollable, wrap it in a `ScrollSpyScope` yourself:

```dart
ScrollSpyScope<int>(
  controller: _spy,
  region: ScrollSpyRegion.zone(
    anchor: const ScrollSpyAnchor.fraction(0.5),
    extentPx: 200,
  ),
  policy: const ScrollSpyPolicy<int>.closestToAnchor(),
  child: CustomScrollView(
    slivers: [
      // ... slivers containing ScrollSpyItem<int> descendants ...
    ],
  ),
)
```

The scope listens to scroll notifications bubbling from its child; items
register themselves with the nearest scope of matching type parameter.

---

## Core concepts

### The controller

`ScrollSpyController<T>` is the read side. The scope writes into it; you listen
to it. `T` is your item ID type (int index, String post ID, whatever is stable
and unique within the scope).

| Listenable | Type | Fires when |
|---|---|---|
| `controller.primaryId` | `ValueListenable<T?>` | the primary winner changes |
| `controller.focusedIds` | `ValueListenable<Set<T>>` | the focused set changes |
| `controller.snapshot` | `ValueListenable<ScrollSpySnapshot<T>>` | any tracked state changes (most detail, most updates) |
| `controller.itemFocusOf(id)` | `ValueListenable<ScrollSpyItemFocus<T>>` | that item's focus state or metrics change |
| `controller.itemIsPrimaryOf(id)` | `ValueListenable<bool>` | that item gains/loses primary |
| `controller.itemIsFocusedOf(id)` | `ValueListenable<bool>` | that item enters/leaves the focus region |
| `controller.itemIsVisibleOf(id)` | `ValueListenable<bool>` | that item enters/leaves the viewport |

Per-item notifiers are **lazy** (created on first access), **diff-optimized**
(fire only on real changes), and **auto-evicted** (disposed when the item
leaves and nothing listens). Create the controller in `initState` (or as a
field) and `dispose()` it.

`ScrollSpySnapshot<T>` carries `primaryId`, `focusedIds`, `visibleIds`,
`items` (a `Map<T, ScrollSpyItemFocus<T>>` of everything measured), and
`computedAt`.

### Per-item focus state

`ScrollSpyItemFocus<T>` is what item builders receive:

| Field | Meaning |
|---|---|
| `isVisible` | any part of the item is inside the viewport |
| `isFocused` | the item intersects the focus region (many can be focused) |
| `isPrimary` | this item is the single stable winner |
| `visibleFraction` | 0..1 fraction of the item currently visible |
| `distanceToAnchorPx` | signed px from item center to the anchor (negative = before it) |
| `focusProgress` | 0..1 "how centered on the anchor" - ideal for scale/opacity effects |
| `focusOverlapFraction` | fraction of the region's band this item covers |
| `itemRectInViewport` / `visibleRectInViewport` | geometry, `null` unless debug/rect capture is on |

Note: `isVisible` is about the viewport, `isFocused` is about the region. An
item can be fully visible and not focused.

### Regions and anchors

The region is the "attention area" inside the viewport. It is positioned by an
anchor along the scroll axis:

```dart
const ScrollSpyAnchor.fraction(0.5);              // viewport center
const ScrollSpyAnchor.fraction(0.0, offsetPx: 80); // 80px from the top edge
const ScrollSpyAnchor.pixels(120);                 // fixed 120px from the start
```

Three region shapes:

```dart
// Zone (recommended default): a band centered on the anchor.
// Keeps feed focus from dropping when an item drifts slightly off-center.
ScrollSpyRegion.zone(
  anchor: const ScrollSpyAnchor.fraction(0.5),
  extentPx: 200,
)

// Line: a thin line (or thin band) at the anchor.
// Great for "reading position" UIs - exactly what is under the line is focused.
ScrollSpyRegion.line(
  anchor: const ScrollSpyAnchor.fraction(0.25),
  thicknessPx: 0, // 0 = infinitesimal line
)

// Custom: bring your own evaluator for asymmetric or exotic shapes.
ScrollSpyRegion.custom(
  anchor: const ScrollSpyAnchor.fraction(0.3),
  evaluator: (input) {
    // e.g. focus only items whose start edge is past the anchor
    final focused = input.itemMainAxisStart >= input.anchorOffsetPx;
    return ScrollSpyRegionResult(
      isFocused: focused,
      focusProgress: focused ? 1.0 : 0.0,
      overlapFraction: focused ? 1.0 : 0.0,
    );
  },
)
```

### Primary selection policies

When several items are focused, the policy ranks them and proposes one winner:

```dart
const ScrollSpyPolicy<int>.closestToAnchor();        // smallest |distanceToAnchorPx| (default choice for feeds)
const ScrollSpyPolicy<int>.largestVisibleFraction(); // most on-screen wins
const ScrollSpyPolicy<int>.largestFocusOverlap();    // covers most of the region band
const ScrollSpyPolicy<int>.largestFocusProgress();   // most centered on the anchor

// Or fully custom:
ScrollSpyPolicy<int>.custom(
  compare: (a, b) {
    // < 0 -> a wins, > 0 -> b wins, 0 -> deterministic tie-break rules apply
    return b.visibleFraction.compareTo(a.visibleFraction);
  },
)
```

### Stability (anti-flicker)

Raw per-frame ranking flickers when two items are nearly tied. Stability rules
are applied after ranking:

```dart
const ScrollSpyStability(
  hysteresisPx: 24,          // challenger must beat the incumbent by 24px
  minPrimaryDuration: Duration(milliseconds: 150), // incumbent holds at least 150ms
  preferCurrentPrimary: true,           // bias toward the incumbent (default)
  allowPrimaryWhenNoItemFocused: true,  // keep a "best available" primary when the
                                        // region falls between items (default; key
                                        // for gapless autoplay)
)
```

Defaults are all-off for hysteresis/duration (`hysteresisPx: 0`,
`minPrimaryDuration: zero`); for feeds, `10..50` px and `100..250` ms are good
starting points. `ScrollSpyStability.disabled()` turns off stickiness entirely.

### Update policies (semantics, not CPU lifelines)

The engine's compute pass costs on the order of tens of microseconds even with
hundreds of mounted items, so `perFrame()` is a safe default. Pick a different
policy for *semantic* reasons:

```dart
// Most responsive; computes at most once per rendered frame. (default)
const ScrollSpyUpdatePolicy.perFrame();

// State updates only after scrolling settles - right when reactions should
// fire at rest (impressions, autoplay-on-settle).
ScrollSpyUpdatePolicy.onScrollEnd(debounce: Duration(milliseconds: 80));

// Per-frame while dragging, throttled during fling, guaranteed final settle
// pass. Limits rebuild pressure for UIs listening to continuous metrics.
ScrollSpyUpdatePolicy.hybrid(
  scrollEndDebounce: Duration(milliseconds: 80),
  ballisticInterval: Duration(milliseconds: 50),
  computePerFrameWhileDragging: true,
);
```

> Note: create `onScrollEnd(...)` and `hybrid(...)` **without** `const` (their
> constructors assert on `Duration` values, which the const evaluator cannot
> check). They have no `==`, so build them once and store them in a field
> rather than constructing a fresh instance on every `build`.

---

## Reading focus state

You rarely touch the controller's listenables directly - there is a widget for
each shape of consumer:

| Widget | Rebuilds/fires when | Use for |
|---|---|---|
| `ScrollSpyPrimaryBuilder` | primary changes | "Now playing" headers, dots indicators |
| `ScrollSpyPrimaryListener` | primary changes (no rebuild) | play/pause, analytics, haptics |
| `ScrollSpyFocusedIdsBuilder` | focused set changes | counters, group highlights |
| `ScrollSpySnapshotBuilder` | any tracked state changes | dashboards, debug HUDs |
| `ScrollSpyItemFocusBuilder` | one item's focus/metrics change | metric-driven effects outside the item |
| `ScrollSpyItemPrimaryBuilder` / `ScrollSpyItemFocusedBuilder` / `ScrollSpyItemVisibleBuilder` | one item's boolean toggles | cheapest possible per-item rebuilds |
| `ScrollSpyItemPrimaryListener` / `ScrollSpyItemFocusedListener` / `ScrollSpyItemVisibleListener` | one item's boolean toggles (no rebuild) | per-item side effects (attach/detach players, impressions) |

```dart
// Rebuild a header when the primary changes:
ScrollSpyPrimaryBuilder<int>(
  controller: _spy,
  builder: (context, primaryId, _) => Text('Now playing: ${primaryId ?? "-"}'),
)

// Fire an effect when item 7 enters/leaves the viewport, rebuilding nothing:
ScrollSpyItemVisibleListener<int>(
  controller: _spy,
  id: 7,
  onChanged: (wasVisible, isVisible) {
    if (isVisible) prefetch(7);
  },
  child: itemSubtree,
)
```

---

## Performance: booleans-first items

`ScrollSpyItem`'s builder runs whenever the item's focus *metrics* change,
which during scrolling means often (the metrics drift every frame). That is
what you want for `focusProgress`-driven effects. When you only care about
state toggles, use `ScrollSpyItemLite` - a drop-in variant whose builder runs
**only** when `isPrimary` or `isFocused` flips:

```dart
ScrollSpyItemLite<int>(
  id: index,
  child: const FeedCardBody(), // static; never rebuilds with focus
  builder: (context, isPrimary, isFocused, child) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: isPrimary ? Colors.green : Colors.transparent,
          width: 3,
        ),
      ),
      child: child,
    );
  },
)
```

Guidelines for large feeds:

- Prefer `ScrollSpyItemLite` unless an item genuinely animates from metrics.
- Always pass the static subtree via `child:` so it is built once.
- Use listener widgets (not builders) for side effects.
- Nobody listening to `snapshot` means no snapshot is ever materialized - the
  engine works booleans-first and bills you only for what you consume.

The example app's **Perf lab** (1000 items + frame-time HUD) exists exactly to
let you verify this with DevTools.

---

## Recipes

### Autoplay feed

Zone region at the center, closest-to-anchor policy, moderate stability, and a
primary listener that flips players. See the Quick start above; the full
version (with `focusProgress`-driven scale and a now-playing bar) is the
[Autoplay feed demo](example/lib/demos/feed_autoplay_page.dart).

### Reading position / table of contents

A thin line near the top of the viewport; whatever section is under the line
is "current":

```dart
ScrollSpyCustomScrollView<String>(
  controller: _spy,
  region: ScrollSpyRegion.line(
    anchor: const ScrollSpyAnchor.fraction(0.22),
    thicknessPx: 2,
  ),
  policy: const ScrollSpyPolicy<String>.closestToAnchor(),
  slivers: [
    SliverList.builder(
      itemCount: sections.length,
      itemBuilder: (context, i) => ScrollSpyItemLite<String>(
        id: sections[i].slug,
        builder: (context, isPrimary, isFocused, child) => SectionView(
          section: sections[i],
          highlighted: isPrimary,
        ),
      ),
    ),
  ],
)
```

Full version: [Reading progress demo](example/lib/demos/reading_progress_page.dart).

### Impression analytics

Log an impression the first time an item crosses a visibility threshold, and
enter/exit events as booleans toggle:

```dart
// Threshold crossings: scan the snapshot.
_spy.snapshot.addListener(() {
  for (final item in _spy.snapshot.value.items.values) {
    if (item.visibleFraction >= 0.6 && _impressed.add(item.id)) {
      analytics.logImpression(item.id);
    }
  }
});

// Enter/exit events: per-item boolean listener, zero rebuilds.
ScrollSpyItemVisibleListener<int>(
  controller: _spy,
  id: id,
  onChanged: (prev, curr) => analytics.log(curr ? 'enter' : 'exit', id),
  child: itemSubtree,
)
```

Full version: [Impression tracking demo](example/lib/demos/impressions_page.dart).

### Carousels and PageViews

`ScrollSpyPageView.builder` mirrors `PageView.builder` (including
`viewportFraction`); the centered page becomes primary and `focusProgress`
drives the scale-up effect. Full version:
[Carousel demo](example/lib/demos/carousel_page.dart).

### Pinned headers / obstructed viewport

If pinned headers (`SliverAppBar(pinned: true)`, pinned tabs) or overlays
(SafeArea, bottom nav, a mini player) cover part of the viewport, pass
`viewportInsets` so the focus region lives in the *unobstructed* part:

```dart
ScrollSpyCustomScrollView<int>(
  controller: _spy,
  region: const ScrollSpyRegion.line(anchor: ScrollSpyAnchor.pixels(0)),
  policy: const ScrollSpyPolicy<int>.closestToAnchor(),
  // SliverAppBar (56) + pinned TabBar (48):
  viewportInsets: const EdgeInsets.only(top: 104),
  slivers: [ /* ... */ ],
)
```

By default insets also affect visibility (items fully behind the inset are not
visible/focused). To only offset the anchor while treating the full viewport
as visible, set `insetsAffectVisibility: false`. For bottom overlays:
`EdgeInsets.only(bottom: kBottomNavigationBarHeight + MediaQuery.paddingOf(context).bottom)`.

### Nested scrollables

If items contain their own scrollables (horizontal carousels inside a vertical
feed), make sure only the intended scrollable drives the scope:

```dart
ScrollSpyScope<int>(
  notificationDepth: 0, // 0 = immediate child scrollable (default)
  // or filter precisely:
  notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
  metricsNotificationPredicate: (n) => n.metrics.axis == Axis.vertical,
  // ...
)
```

### Programmatic jumps

Scroll notifications cover gestures and animations, but a bare `jumpTo` on an
external controller can bypass them. If you drive scrolling programmatically,
hand the same `ScrollController` to the scope so it observes those jumps too:

```dart
ScrollSpyScope<int>(
  scrollController: myScrollController,
  // ...
)
```

The wrappers accept `scrollController` (or `pageController`) and wire this for
you.

---

## Debug overlay

Flip one flag to see exactly what the engine sees - the focus region (red),
focused outlines (yellow), the primary outline (green), visible bounds (blue),
and optional labels:

```dart
ScrollSpyScope<int>(
  debug: true,
  debugConfig: const ScrollSpyDebugConfig(
    showFocusRegion: true,
    showPrimaryOutline: true,
    showFocusedOutlines: true,
    showVisibleBounds: true,
    showLabels: true,
  ),
  child: /* ... */,
)
```

All wrappers take the same `debug` / `debugConfig` parameters. Debug
bookkeeping runs **only** when `debug: true`; a non-debug scope spends nothing
on it. `includeItemRectsInFrame` additionally populates
`itemRectInViewport` / `visibleRectInViewport` on focus objects (extra
allocations; keep it for debugging).

---

## Example app

The [example](example/) is a full showcase - a gallery of seven demos, each a
realistic pattern with an in-app list of the APIs it uses:

| Demo | Pattern | Highlights |
|---|---|---|
| Autoplay feed | real bundled video playback | one active player, bounded neighbor pool, lifecycle-safe pause/dispose |
| Playground | interactive lab | every region/policy/stability/update-policy knob, live debug overlay |
| Reading progress | docs / articles | line region, `ScrollSpyCustomScrollView`, TOC highlighting |
| Impression tracking | analytics | `visibleFraction` thresholds, visibility listeners, event log |
| Carousel | horizontal pager | `ScrollSpyPageView`, `viewportFraction`, dots indicator |
| Gallery grid | photo grid | `ScrollSpyGridView`, `largestVisibleFraction` policy |
| Perf lab | profiling | 1000 items, `ScrollSpyItemLite`, frame-time HUD |

```bash
cd example
flutter run
```

Or open the [live web demo](https://omar-hanafy.github.io/scroll-spy/demo/).

The autoplay example uses bundled media, so it is repeatable without depending
on a remote video host. Its small player pool keeps the current item and nearby
items warm while disposing controllers that move outside that window. See
[`feed_autoplay_page.dart`](example/lib/demos/feed_autoplay_page.dart) and
[`feed_video_pool.dart`](example/lib/demos/feed_video_pool.dart).

---

## Reproducible comparison benchmark

The [`benchmark`](benchmark/) app compares complete, documented integration
patterns for scroll_spy, `visibility_detector`, and `inview_notifier_list` under
the same fixed-extent feed and scripted scroll workload. It records mounted
items, normalized visibility transitions, reactive builds, callbacks, and
repeated state deliveries.

One reference run on Flutter 3.44.4 produced these deterministic counts with
201 mounted items and the same 20 normalized visibility transitions:

| Implementation | Reactive builds | Callbacks | Repeated deliveries |
|---|---:|---:|---:|
| `scroll_spy` | 40 | 20 | 10 |
| `inview_notifier_list` | 4,020 | not exposed | 3,990 |
| `visibility_detector` | 30 | 80 | 60 |

Treat the output as a local engineering measurement, not a permanent package
leaderboard. Flutter version, device, build mode, list shape, and application
work all affect the result. A callback and a builder invocation are not equal
units of CPU work. The harness prints debug step timing only for regression
checks and does not present it as device frame time or FPS. Read the methodology
and run it on the hardware and workload that matter to your app.

---

## AI coding-assistant support

scroll_spy ships an installable, instructions-only plugin for Claude Code and
OpenAI Codex. It teaches an assistant the package's integration, stability,
diagnosis, performance, 0.x migration, and `visibility_detector` conversion
workflows. It is development tooling, not part of the Flutter runtime package.

Claude Code:

```
/plugin marketplace add omar-hanafy/scroll_spy
/plugin install scroll-spy@scroll-spy
```

OpenAI Codex:

```
codex plugin marketplace add omar-hanafy/scroll_spy
codex plugin add scroll-spy@scroll-spy
```

Start a new session after installation, then ask for the outcome directly, for
example: "Add scroll_spy autoplay to my feed so exactly one video plays."

The plugin has no hooks, MCP servers, executable scripts, or network access.
See [AI assistant setup and troubleshooting](docs/ai-assistant.md) for the full
capability list and explicit skill names.

---

## API map

Core:
- `ScrollSpyScope<T>` - owns the engine for a scrollable subtree
- `ScrollSpyItem<T>` / `ScrollSpyItemLite<T>` - register items, react to focus
- `ScrollSpyController<T>` - listenables for results

Models:
- `ScrollSpyItemFocus<T>` - per-item state and metrics
- `ScrollSpySnapshot<T>` - full frame: `primaryId`, `focusedIds`, `visibleIds`, `items`

Configuration:
- `ScrollSpyRegion.line / .zone / .custom` + `ScrollSpyAnchor.fraction / .pixels`
- `ScrollSpyPolicy.closestToAnchor / .largestVisibleFraction / .largestFocusOverlap / .largestFocusProgress / .custom`
- `ScrollSpyStability`
- `ScrollSpyUpdatePolicy.perFrame / .onScrollEnd / .hybrid`

Wrappers:
- `ScrollSpyListView.builder / .separated`
- `ScrollSpyGridView.builder`
- `ScrollSpyCustomScrollView`
- `ScrollSpyPageView.builder`

Builders and listeners:
- Scope-level: `ScrollSpyPrimaryBuilder`, `ScrollSpyPrimaryListener`,
  `ScrollSpyFocusedIdsBuilder`, `ScrollSpySnapshotBuilder`
- Per-item: `ScrollSpyItemFocusBuilder`, `ScrollSpyItemPrimaryBuilder`,
  `ScrollSpyItemFocusedBuilder`, `ScrollSpyItemVisibleBuilder`, and the
  matching `...Listener` variants

Debug:
- `ScrollSpyDebugConfig`, `ScrollSpyDebugOverlay`

---

## Contributing

Contributions are welcome. Before opening a PR:

```bash
dart format .
flutter analyze
flutter test
dart run tool/validate_ai_plugin.dart
flutter pub publish --dry-run
```

If you change public behavior or API surface, update the docs and changelog
alongside the code.

## License

MIT. See [LICENSE](LICENSE).
