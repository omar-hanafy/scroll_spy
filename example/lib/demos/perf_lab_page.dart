import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../common.dart';
import '../theme.dart';

/// A dense-feed stress page for DevTools timeline work.
///
/// - 1,000 items driven by [ScrollSpyItemLite] (booleans-first hot path).
/// - Optional "heavy items" toggle to simulate real feed cards.
/// - A frame-time HUD (avg / worst build+raster over the last 120 frames) so
///   regressions are visible without leaving the app.
class PerfLabPage extends StatefulWidget {
  const PerfLabPage({super.key, required this.info});

  final DemoInfo info;

  @override
  State<PerfLabPage> createState() => _PerfLabPageState();
}

class _PerfLabPageState extends State<PerfLabPage> {
  final ScrollSpyController<int> _spy = ScrollSpyController<int>();
  final ScrollController _scroll = ScrollController();

  // Stable instance: the HUD rebuilds every frame, and this policy has no
  // value equality, so recreating it per build would reconfigure the scope
  // on every frame.
  final ScrollSpyUpdatePolicy _updatePolicy = ScrollSpyUpdatePolicy.hybrid();

  static const int _itemCount = 1000;

  bool _heavyItems = false;

  final Queue<FrameTiming> _timings = Queue<FrameTiming>();
  double _avgMs = 0;
  double _worstMs = 0;
  late final TimingsCallback _timingsCallback;

  @override
  void initState() {
    super.initState();
    _timingsCallback = _onTimings;
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!mounted) return;
    for (final t in timings) {
      _timings.add(t);
      while (_timings.length > 120) {
        _timings.removeFirst();
      }
    }
    double total = 0;
    double worst = 0;
    for (final t in _timings) {
      final ms = t.totalSpan.inMicroseconds / 1000.0;
      total += ms;
      if (ms > worst) worst = ms;
    }
    setState(() {
      _avgMs = _timings.isEmpty ? 0 : total / _timings.length;
      _worstMs = worst;
    });
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
    _spy.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: widget.info.title,
      accent: widget.info.accent,
      description: widget.info.description,
      apis: widget.info.apis,
      actions: [
        IconButton(
          tooltip: 'Toggle heavy items',
          icon: Icon(
            _heavyItems ? Icons.photo_rounded : Icons.crop_square_rounded,
          ),
          onPressed: () => setState(() => _heavyItems = !_heavyItems),
        ),
      ],
      body: Column(
        children: [
          _Hud(avgMs: _avgMs, worstMs: _worstMs, itemCount: _itemCount),
          Expanded(
            child: ScrollSpyScope<int>(
              controller: _spy,
              scrollController: _scroll,
              region: const ScrollSpyRegion.zone(
                anchor: ScrollSpyAnchor.fraction(0.5),
                extentPx: 240,
              ),
              policy: const ScrollSpyPolicy.closestToAnchor(),
              updatePolicy: _updatePolicy,
              stability: const ScrollSpyStability(
                hysteresisPx: 24,
                minPrimaryDuration: Duration(milliseconds: 120),
              ),
              child: ListView.builder(
                controller: _scroll,
                itemExtent: 96,
                itemCount: _itemCount,
                itemBuilder: (context, i) => ScrollSpyItemLite<int>(
                  id: i,
                  child: _heavyItems
                      ? _HeavyCard(index: i)
                      : _LightCard(index: i),
                  builder: (context, isPrimary, isFocused, child) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          width: 2,
                          color: isPrimary
                              ? SpyColors.primary
                              : (isFocused
                                    ? SpyColors.focused
                                    : Colors.transparent),
                        ),
                      ),
                      child: child,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({
    required this.avgMs,
    required this.worstMs,
    required this.itemCount,
  });

  final double avgMs;
  final double worstMs;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SpyColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          _stat('avg frame', avgMs),
          const SizedBox(width: 20),
          _stat('worst frame', worstMs),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SectionLabel('items'),
              const SizedBox(height: 3),
              Text(
                '$itemCount',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, double ms) {
    final bool good = ms < 8.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: 3),
        Text(
          '${ms.toStringAsFixed(1)} ms',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: good ? SpyColors.primary : SpyColors.region,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _LightCard extends StatelessWidget {
  const _LightCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: index.isEven ? const Color(0xFF14141B) : const Color(0xFF101015),
      child: Center(
        child: Text(
          'item $index',
          style: const TextStyle(color: SpyColors.muted),
        ),
      ),
    );
  }
}

class _HeavyCard extends StatelessWidget {
  const _HeavyCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(gradient: demoGradient(index)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white24,
            child: Text('${index % 100}'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User $index',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'A heavier feed card with avatar, gradient and shadows to '
                  'simulate real content.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
