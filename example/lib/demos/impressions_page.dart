import 'package:flutter/material.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../common.dart';
import '../theme.dart';

enum _EventKind { enter, exit, impression }

class _LogEvent {
  const _LogEvent(this.id, this.kind);
  final int id;
  final _EventKind kind;
}

/// Analytics demo: fire an impression the first time a card is [_threshold]
/// visible, and log viewport enter/exit events - all from scroll_spy signals.
class ImpressionsPage extends StatefulWidget {
  const ImpressionsPage({super.key, required this.info});

  final DemoInfo info;

  @override
  State<ImpressionsPage> createState() => _ImpressionsPageState();
}

class _ImpressionsPageState extends State<ImpressionsPage> {
  final ScrollSpyController<int> _spy = ScrollSpyController<int>();
  final ScrollController _scroll = ScrollController();

  static const int _itemCount = 30;
  static const double _threshold = 0.6;

  final Set<int> _impressed = <int>{};
  final List<_LogEvent> _log = <_LogEvent>[];

  @override
  void initState() {
    super.initState();
    // The snapshot exposes every measurable item's visibleFraction; scan it for
    // first-time threshold crossings. Real code would send these to analytics.
    _spy.snapshot.addListener(_scanImpressions);
  }

  @override
  void dispose() {
    _spy.snapshot.removeListener(_scanImpressions);
    _spy.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scanImpressions() {
    final items = _spy.snapshot.value.items;
    var changed = false;
    for (final focus in items.values) {
      if (focus.visibleFraction >= _threshold && _impressed.add(focus.id)) {
        _log.insert(0, _LogEvent(focus.id, _EventKind.impression));
        changed = true;
      }
    }
    if (changed) {
      _trimLog();
      setState(() {});
    }
  }

  void _onVisibility(int id, bool visible) {
    setState(() {
      _log.insert(
        0,
        _LogEvent(id, visible ? _EventKind.enter : _EventKind.exit),
      );
      _trimLog();
    });
  }

  void _trimLog() {
    if (_log.length > 80) _log.removeRange(80, _log.length);
  }

  void _openLog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SpyColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                const SectionLabel('Event log (newest first)'),
                const SizedBox(height: 12),
                if (_log.isEmpty)
                  const Text(
                    'Scroll the feed to generate events.',
                    style: TextStyle(color: SpyColors.muted),
                  ),
                for (final e in _log) _LogRow(event: e),
              ],
            );
          },
        );
      },
    );
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
          tooltip: 'Event log',
          icon: const Icon(Icons.receipt_long_rounded),
          onPressed: _openLog,
        ),
      ],
      body: Column(
        children: [
          _StatsBar(
            controller: _spy,
            impressed: _impressed.length,
            total: _itemCount,
          ),
          Expanded(
            child: ScrollSpyScope<int>(
              controller: _spy,
              scrollController: _scroll,
              // Full viewport is the "visible" region; a zone would only report
              // the center. For impressions we care about any visibility.
              region: const ScrollSpyRegion.zone(
                anchor: ScrollSpyAnchor.fraction(0.5),
                extentPx: 1,
              ),
              policy: const ScrollSpyPolicy.largestVisibleFraction(),
              child: ListView.builder(
                controller: _scroll,
                itemCount: _itemCount,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  return ScrollSpyItemVisibleListener<int>(
                    id: index,
                    onChanged: (prev, curr) => _onVisibility(index, curr),
                    child: ScrollSpyItem<int>(
                      id: index,
                      builder: (context, focus, _) => _ContentCard(
                        index: index,
                        focus: focus,
                        impressed: _impressed.contains(index),
                        threshold: _threshold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.controller,
    required this.impressed,
    required this.total,
  });

  final ScrollSpyController<int> controller;
  final int impressed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SpyColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: _stat(
              'impressions',
              '$impressed / $total',
              SpyColors.visible,
              Icons.visibility_rounded,
            ),
          ),
          // visibleIds updates live via the snapshot listenable.
          Expanded(
            child: ScrollSpySnapshotBuilder<int>(
              controller: controller,
              builder: (context, snap, _) => _stat(
                'visible now',
                '${snap.visibleIds.length}',
                SpyColors.primary,
                Icons.center_focus_strong_rounded,
              ),
            ),
          ),
          Expanded(
            child: _stat(
              'threshold',
              '60%',
              SpyColors.muted,
              Icons.percent_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            SectionLabel(label, color: color),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.index,
    required this.focus,
    required this.impressed,
    required this.threshold,
  });

  final int index;
  final ScrollSpyItemFocus<int> focus;
  final bool impressed;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final bool over = focus.visibleFraction >= threshold;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderColor: over ? SpyColors.visible : SpyColors.stroke,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: SizedBox(
                height: 130,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(gradient: demoGradient(index)),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: AnimatedOpacity(
                        opacity: impressed ? 1 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: const StatusPill(
                          label: 'IMPRESSION',
                          color: SpyColors.visible,
                          icon: Icons.check_circle_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sponsored post #${index + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  MetricBar(
                    label: 'visibleFraction',
                    value: focus.visibleFraction,
                    color: over ? SpyColors.visible : SpyColors.muted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.event});

  final _LogEvent event;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final IconData icon;
    late final String label;
    switch (event.kind) {
      case _EventKind.enter:
        color = SpyColors.primary;
        icon = Icons.login_rounded;
        label = 'entered viewport';
      case _EventKind.exit:
        color = SpyColors.muted;
        icon = Icons.logout_rounded;
        label = 'left viewport';
      case _EventKind.impression:
        color = SpyColors.visible;
        icon = Icons.visibility_rounded;
        label = 'impression (>=60%)';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            'post #${event.id + 1}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: SpyColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
