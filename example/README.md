# scroll_spy showcase

<p align="center">
  <img src="https://raw.githubusercontent.com/omar-hanafy/scroll_spy/main/screenshots/scroll_spy.png" alt="scroll_spy Primary Rail logo" width="96" />
</p>

A multi-demo showcase app for the [`scroll_spy`](../) package (1.x). Each
screen is a self-contained, real-world use case that exercises a different part
of the public API. Open a demo and tap the ⓘ button in the app bar to see
exactly which APIs it uses.

## Demos

| Demo | What it shows | Key APIs |
| --- | --- | --- |
| **Autoplay feed** | Plays a real bundled video for exactly one primary card. A bounded pool preloads the two neighbors, disposes distant controllers, and pauses for route/app lifecycle changes. | `ScrollSpyScope`, `ScrollSpyItem`, `ScrollSpyRegion.zone`, `closestToAnchor`, `ScrollSpyStability`, `ScrollSpyPrimaryListener`, `video_player` |
| **Playground** | Live-tune every knob (region, anchor, policy, stability, cadence) with the debug overlay on. | `ScrollSpyRegion.line/zone/custom`, `ScrollSpyPolicy.*`, `ScrollSpyUpdatePolicy.*`, `ScrollSpyDebugConfig` |
| **Reading progress** | A line region marks the reading position; the crossing section becomes primary and drives the header + progress bar. | `ScrollSpyCustomScrollView`, `ScrollSpyRegion.line`, `ScrollSpyItemLite`, `ScrollSpyPrimaryBuilder` |
| **Impression tracking** | Fires an analytics impression the first time a card is 60% visible; logs viewport enter/exit. | `visibleFraction`, `ScrollSpyItemVisibleListener`, `snapshot`, `visibleIds` |
| **Carousel** | Horizontal PageView where the centered page is primary and scales up. | `ScrollSpyPageView`, `focusProgress`, `Axis.horizontal` |
| **Gallery grid** | TikTok-style results grid: adaptive column count, staggered so row tiles never tie; the most-visible tile wins, and on wide layouts hover takes over like TikTok desktop. | `ScrollSpyGridView`, `largestVisibleFraction` |
| **Perf lab** | 1,000 items with a live frame-time HUD for DevTools profiling. | `ScrollSpyItemLite`, `ScrollSpyUpdatePolicy.hybrid` |

## Run

```bash
cd example
flutter run
```

Profile the Perf lab with `flutter run --profile` and DevTools' timeline view.

The video is bundled so the autoplay demo does not depend on a remote media
host. Playback is muted to satisfy browser autoplay policy. The player adapter
is injectable, and the pool behavior is covered by fake-backed tests.

## Structure

```
lib/
  main.dart          # app + home gallery
  theme.dart         # dark theme + palette (aligned with the debug overlay)
  common.dart        # DemoInfo, DemoScaffold, shared widgets
  demos/
    demos.dart       # the gallery registry (kDemos)
    feed_video_pool.dart # bounded, serialized player ownership
    *_page.dart       # one file per demo
```
