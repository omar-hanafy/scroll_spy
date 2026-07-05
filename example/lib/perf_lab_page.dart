import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:scroll_spy/scroll_spy.dart';

/// A dense-feed stress page for DevTools timeline work.
///
/// - 1000 items driven by [ScrollSpyItemLite] (booleans-first hot path).
/// - Optional "heavy items" toggle to simulate real feed cards.
/// - A frame-time HUD (avg / worst build+raster over the last 120 frames)
///   so regressions are visible without leaving the app.
class PerfLabPage extends StatefulWidget {
  const PerfLabPage({super.key});

  @override
  State<PerfLabPage> createState() => _PerfLabPageState();
}

class _PerfLabPageState extends State<PerfLabPage> {
  final ScrollSpyController<int> _spy = ScrollSpyController();
  final ScrollController _scroll = ScrollController();

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perf lab'),
        actions: [
          IconButton(
            icon: Icon(_heavyItems ? Icons.photo : Icons.crop_square),
            tooltip: 'Toggle heavy items',
            onPressed: () => setState(() => _heavyItems = !_heavyItems),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _Hud(label: 'avg frame', valueMs: _avgMs),
                const SizedBox(width: 16),
                _Hud(label: 'worst frame', valueMs: _worstMs),
                const Spacer(),
                Text(
                  '$_itemCount items',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: ScrollSpyScope<int>(
              controller: _spy,
              scrollController: _scroll,
              region: const ScrollSpyRegion.zone(
                anchor: ScrollSpyAnchor.fraction(0.5),
                extentPx: 240,
              ),
              policy: const ScrollSpyPolicy.closestToAnchor(),
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
                              ? const Color(0xFF34C759)
                              : (isFocused
                                    ? const Color(0xFFFFCC00)
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
  const _Hud({required this.label, required this.valueMs});

  final String label;
  final double valueMs;

  @override
  Widget build(BuildContext context) {
    final good = valueMs < 8.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(
          '${valueMs.toStringAsFixed(1)} ms',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: good ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
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
      color: index.isEven ? const Color(0xFF1A1A1A) : const Color(0xFF141414),
      child: Center(child: Text('item $index')),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.primaries[index % Colors.primaries.length].shade900,
            const Color(0xFF101010),
          ],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(child: Text('${index % 100}')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User $index',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'A heavier feed card with avatar, gradient and shadows '
                  'to simulate real content.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
