import 'package:flutter/material.dart';

import '../common.dart';
import '../theme.dart';
import 'carousel_page.dart';
import 'feed_autoplay_page.dart';
import 'gallery_grid_page.dart';
import 'impressions_page.dart';
import 'perf_lab_page.dart';
import 'playground_page.dart';
import 'reading_progress_page.dart';

/// The ordered list of demos shown on the home gallery.
final List<DemoInfo> kDemos = <DemoInfo>[
  DemoInfo(
    title: 'Autoplay feed',
    tagline: 'One real video plays; nearby controllers stay preloaded.',
    description:
        'A vertical feed with bundled video playback. The center-zone winner '
        'owns the only playing controller while a bounded pool preloads its '
        'neighbors and disposes distant players. Stability keeps ownership '
        'from flickering, focusProgress drives scale and opacity, and route or '
        'app lifecycle changes pause playback.',
    apis: const [
      'ScrollSpyScope',
      'ScrollSpyItem',
      'ScrollSpyRegion.zone',
      'ScrollSpyPolicy.closestToAnchor',
      'ScrollSpyStability',
      'ScrollSpyPrimaryListener',
      'focusProgress',
    ],
    icon: Icons.play_circle_fill_rounded,
    accent: SpyColors.primary,
    builder: (_, info) => FeedAutoplayPage(info: info),
  ),
  DemoInfo(
    title: 'Playground',
    tagline: 'Tune region, policy, stability and cadence with the overlay on.',
    description:
        'An interactive lab for every knob scroll_spy exposes. Switch the '
        'region between line / zone / a custom asymmetric band, move the '
        'anchor, change the selection policy, dial in hysteresis and minimum '
        'primary duration, and pick an update cadence - all while the built-in '
        'debug overlay draws the region, item bounds and live labels.',
    apis: const [
      'ScrollSpyRegion.line/zone/custom',
      'ScrollSpyAnchor',
      'ScrollSpyPolicy.*',
      'ScrollSpyStability',
      'ScrollSpyUpdatePolicy.*',
      'ScrollSpyScope(debug: true)',
      'ScrollSpyDebugConfig',
    ],
    icon: Icons.tune_rounded,
    accent: SpyColors.accent,
    builder: (_, info) => PlaygroundPage(info: info),
  ),
  DemoInfo(
    title: 'Reading progress',
    tagline: 'Highlight the section you are reading in a long article.',
    description:
        'A long-form article built from slivers. A thin line region near the '
        'top marks the "reading line"; whichever section crosses it becomes '
        'primary. The header shows the current section and a progress bar, and '
        'the table-of-contents sheet lets you jump. Sections use the '
        'booleans-first ScrollSpyItemLite so they only rebuild when their '
        'focused state toggles.',
    apis: const [
      'ScrollSpyCustomScrollView',
      'ScrollSpyRegion.line',
      'ScrollSpyItemLite',
      'ScrollSpyPrimaryBuilder',
      'ScrollSpyController.primaryId',
    ],
    icon: Icons.menu_book_rounded,
    accent: SpyColors.accent2,
    builder: (_, info) => ReadingProgressPage(info: info),
  ),
  DemoInfo(
    title: 'Impression tracking',
    tagline: 'Log an analytics event when a card is 60% seen.',
    description:
        'A feed that fires an impression the first time each card crosses a '
        'visibility threshold, exactly like a real analytics pipeline. Each '
        'card reports its visibleFraction; a visible-status listener records '
        'the event once, and the header keeps a running count plus a live set '
        'of currently on-screen ids.',
    apis: const [
      'ScrollSpyItem',
      'visibleFraction',
      'ScrollSpyItemVisibleListener',
      'ScrollSpyController.snapshot',
      'visibleIds',
    ],
    icon: Icons.analytics_rounded,
    accent: SpyColors.visible,
    builder: (_, info) => ImpressionsPage(info: info),
  ),
  DemoInfo(
    title: 'Carousel',
    tagline: 'A horizontal PageView where the centered card is primary.',
    description:
        'A peeking horizontal carousel. The centered page is the primary '
        'winner and scales up via focusProgress while its neighbours shrink '
        'and dim. A dots indicator tracks the primary id. Shows scroll_spy '
        'working on the horizontal axis through the PageView wrapper.',
    apis: const [
      'ScrollSpyPageView',
      'ScrollSpyItem',
      'focusProgress',
      'ScrollSpyPolicy.closestToAnchor',
      'Axis.horizontal',
    ],
    icon: Icons.view_carousel_rounded,
    accent: const Color(0xFFFF5CA8),
    builder: (_, info) => CarouselPage(info: info),
  ),
  DemoInfo(
    title: 'Gallery grid',
    tagline: 'A TikTok-style results grid; the most-visible tile wins.',
    description:
        'A search-results grid (column count adapts to the viewport) using '
        'the largestVisibleFraction policy: the tile with the most of itself '
        'on screen becomes primary and lifts. A hero strip at the top mirrors '
        'the current winner. Like TikTok on desktop, wide layouts (3+ '
        'columns) let the mouse take over: hovering a tile makes it the '
        'active one, with the scroll-derived primary as the fallback. The '
        'columns are staggered on purpose: in a uniform grid all tiles of a '
        'row share the same main-axis geometry, so every metric ties and the '
        'first tile would always win. Distinct geometry per tile lets the '
        'primary travel through the whole grid.',
    apis: const [
      'ScrollSpyGridView',
      'ScrollSpyItem',
      'ScrollSpyPolicy.largestVisibleFraction',
      'ScrollSpyPrimaryBuilder',
    ],
    icon: Icons.grid_view_rounded,
    accent: const Color(0xFFFFB020),
    builder: (_, info) => GalleryGridPage(info: info),
  ),
  DemoInfo(
    title: 'Perf lab',
    tagline: '1,000 items with a live frame-time HUD for profiling.',
    description:
        'A dense stress feed for DevTools timeline work. 1,000 items driven by '
        'the booleans-first ScrollSpyItemLite hot path, an optional heavy-item '
        'toggle to simulate real cards, and a HUD showing average / worst '
        'frame time over the last 120 frames so regressions are visible '
        'without leaving the app.',
    apis: const [
      'ScrollSpyScope',
      'ScrollSpyItemLite',
      'ScrollSpyUpdatePolicy',
      'SchedulerBinding timings',
    ],
    icon: Icons.speed_rounded,
    accent: const Color(0xFF34C759),
    builder: (_, info) => PerfLabPage(info: info),
  ),
];
