# Visibility comparison benchmark

This subpackage compares `scroll_spy` with `inview_notifier_list` and
`visibility_detector` under one deliberately narrow scenario that all three
packages support: report whether fixed-extent `ListView` items intersect the
painted viewport.

It is not a general ranking and does not establish that one package is always
faster. The packages have different semantics and public APIs.

## Versions

`pubspec.lock` pins the full environment. The direct comparison versions are:

- local `scroll_spy` 1.x through `path: ..`
- `inview_notifier_list` 4.1.0
- `visibility_detector` 0.4.0+2

Run the benchmark from this directory:

```sh
flutter pub get
flutter --version
flutter test test/visibility_comparison_benchmark_test.dart -r expanded
```

The test asserts that every implementation reports the same final visible item
set before it prints a Markdown table.

## Scenario

Every case uses the same inputs:

- 400 x 600 logical-pixel viewport
- 3,000 fixed-extent items, each 100 logical pixels tall
- the same `ScrollController`, start offset, 25-pixel jump steps, and two test
  pumps per step
- three cache extents, with the actual mounted count read from the widget tree
- static item content passed through each package's supported child path

Cadence is aligned for semantic equivalence:

- `scroll_spy`: per-frame updates
- `inview_notifier_list`: `throttleDuration: Duration.zero`
- `visibility_detector`: `updateInterval: Duration.zero`

The zero intervals are intentional. The competitor defaults are 200 ms and
500 ms respectively, which reduce work by delaying/coalescing delivery and are
not equivalent to per-frame visibility.

ScrollSpy's focus line is placed outside the viewport, disabling focused and
primary selection. This makes the case visibility-only. It also means the
benchmark does not measure ScrollSpy's differentiating selection and stability
features.

## Counters

The output separates work that otherwise looks deceptively similar:

- `mounted`: cached plus painted tracked items, including offstage elements
- `list item builds`: new `ListView.itemBuilder` invocations during measured
  scrolling
- `static child builds`: builds of the content passed through the package API
- `registration builds`: `ScrollSpyItemLite` registration/boolean wrapper
  builder invocations; not applicable to the other APIs
- `reactive builds`: visibility-dependent UI consumer builds
- `callbacks`: ScrollSpy boolean-change listener calls or raw
  `VisibilityDetector` callback calls; `inview_notifier_list` exposes its state
  through the item builder rather than a per-item callback
- `state transitions`: normalized hidden/visible changes observed by the
  consumer
- `repeated deliveries`: reactive deliveries whose boolean value did not
  change

`VisibilityDetector` callbacks can report visible-fraction changes while the
normalized boolean remains true. The harness rebuilds its example consumer only
when `visibleFraction > 0` changes, while retaining the raw callback count.

## Reference deterministic counters

A repeated run on Flutter 3.44.4 and Dart 3.12.2 produced the same counters
both times. Timing values are omitted here because they varied between runs.

| implementation | mounted | reactive builds | callbacks | state transitions | repeated deliveries |
|---|---:|---:|---:|---:|---:|
| `scroll_spy` | 11 | 40 | 20 | 20 | 10 |
| `inview_notifier_list` | 11 | 220 | not exposed | 20 | 190 |
| `visibility_detector` | 11 | 30 | 80 | 20 | 60 |
| `scroll_spy` | 51 | 40 | 20 | 20 | 10 |
| `inview_notifier_list` | 51 | 1,020 | not exposed | 20 | 990 |
| `visibility_detector` | 51 | 30 | 80 | 20 | 60 |
| `scroll_spy` | 201 | 40 | 20 | 20 | 10 |
| `inview_notifier_list` | 201 | 4,020 | not exposed | 20 | 3,990 |
| `visibility_detector` | 201 | 30 | 80 | 20 | 60 |

These are API-delivery counts for this scenario, not relative speedups. In
particular, a raw `VisibilityDetector` callback is not the same unit of work as
an item builder invocation, and the ScrollSpy registration builder is reported
separately in live output.

## Timing field

`mean step us`, `p50 us`, and `p95 us` are debug-VM wall time around one
`jumpTo` plus two `flutter_test` pumps. They help detect major harness
regressions on the same machine, but they are not device frame timing, raster
time, GPU time, release-mode throughput, or FPS. Do not use small differences
in these columns as package-performance conclusions.

Valid end-to-end frame analysis still requires the same app and scroll gesture
on the same physical device in profile mode, with Flutter DevTools or a
`FrameTiming` integration harness. Paint-aware detection, scroll-geometry
detection, throttling, and the consumer's own rebuild work should be inspected
separately.

## Source-informed limitations

The harness was designed after inspecting the pinned package source from the
pub cache:

- `inview_notifier_list` 4.1.0 stores mounted item contexts in one
  `InViewState`. On an audited scroll event it calls
  `RenderAbstractViewport.getOffsetToReveal` for each stored context. Its item
  widgets use `AnimatedBuilder` on that shared `ChangeNotifier`.
- `visibility_detector` 0.4.0+2 performs paint/composition-layer visibility
  calculation and coalesces callbacks through its controller. It does not
  rebuild application widgets unless the callback consumer chooses to do so.
- `scroll_spy` 1.x models scroll geometry, exposes diffed per-item boolean
  listenables, and also performs focus/primary selection when configured to do
  so. Those extra semantics are intentionally inactive here.

Consequences:

- A geometry-only viewport benchmark cannot cover overlapping paint, ancestor
  paint suppression, transforms, opacity, or every custom sliver. The packages
  intentionally support different subsets of these cases.
- Mounted counts depend on Flutter's sliver/cache behavior and can change
  between Flutter versions. The benchmark reports actual counts instead of
  assuming the configured cache extent maps to a fixed number.
- Callback counts and rebuild counts are not interchangeable. Both are printed
  because collapsing them into one number would favor a particular API style.
- No allocation count is claimed. Reliable allocation profiling requires VM
  service/profile tooling, and debug widget-test object counts are not a valid
  substitute.
- Results should be compared only from one run/environment. The lockfile and
  printed Flutter version should accompany any published measurements.
