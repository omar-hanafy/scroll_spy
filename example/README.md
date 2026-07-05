# scroll_spy showcase

A multi-demo showcase app for the [`scroll_spy`](../) package (v1.0.0). Each
screen is a self-contained, real-world use case that exercises a different part
of the public API. Open a demo and tap the ⓘ button in the app bar to see
exactly which APIs it uses.

## Demos

| Demo | What it shows | Key APIs |
| --- | --- | --- |
| **Autoplay feed** | One primary card plays; others pause. `focusProgress` drives scale/opacity; a primary listener updates the "now playing" bar. | `ScrollSpyScope`, `ScrollSpyItem`, `ScrollSpyRegion.zone`, `closestToAnchor`, `ScrollSpyStability`, `ScrollSpyPrimaryListener` |
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

## Structure

```
lib/
  main.dart          # app + home gallery
  theme.dart         # dark theme + palette (aligned with the debug overlay)
  common.dart        # DemoInfo, DemoScaffold, shared widgets
  demos/
    demos.dart       # the gallery registry (kDemos)
    *_page.dart       # one file per demo
```
