import 'package:flutter/material.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../common.dart';
import '../theme.dart';

/// A section of the mock article.
class _Section {
  const _Section(this.title, this.body);
  final String title;
  final String body;
}

const List<_Section> _sections = [
  _Section(
    'What scroll_spy answers',
    'Feeds, readers, and galleries all need to know the same thing: given a '
        'scrolling list, which item currently has the user\'s attention? '
        'scroll_spy turns raw scroll geometry into three clear signals - which '
        'items are visible, which intersect a focus region, and which single '
        'item is the primary winner - so you never wire scroll listeners and '
        'rect math by hand again.',
  ),
  _Section(
    'The focus region',
    'Attention is rarely "the whole screen". A focus region narrows it down: a '
        'thin line for strict trigger points, or a zone band for feeds where an '
        'item should stay focused while it drifts near the center. Here, a line '
        'near the top acts as a reading line - whichever heading crosses it is '
        'the section you are reading.',
  ),
  _Section(
    'Primary selection',
    'Many items can be focused at once, but exactly one is primary. A policy '
        'decides the winner: closest to the anchor, most visible, largest '
        'overlap, or your own comparator. For reading, closest-to-anchor maps '
        'cleanly onto "the heading nearest the reading line".',
  ),
  _Section(
    'Stability',
    'Without smoothing, two neighbouring sections near the line would trade the '
        'primary crown on every sub-pixel scroll. Hysteresis makes a challenger '
        'earn the switch, and a minimum primary duration keeps a section '
        'current long enough to read. The result is a progress indicator that '
        'moves deliberately, not one that jitters.',
  ),
  _Section(
    'Booleans first',
    'This article\'s sections use ScrollSpyItemLite, which rebuilds only when a '
        'section\'s primary or focused flag flips - not on every scroll frame. '
        'That is the booleans-first hot path: the cheapest way to react to '
        '"am I the current section?" without paying for full per-item metrics.',
  ),
  _Section(
    'Lazy metrics',
    'When you do need the numbers - visibleFraction, distanceToAnchor, '
        'focusProgress - scroll_spy materializes them lazily, only for the '
        'items something actually listens to. Nobody listening means nothing '
        'allocated. That is why a reader like this one stays smooth even with '
        'long sections.',
  ),
  _Section(
    'Update cadence',
    'You choose how often the engine recomputes: every frame for buttery '
        'progress, only on settle for the cheapest possible cost, or a hybrid '
        'that is responsive while dragging and throttled during a fling. The '
        'reading line updates continuously here because it uses the per-frame '
        'cadence.',
  ),
  _Section(
    'Jump anywhere',
    'The table-of-contents button in the app bar lists every section and '
        'scrolls to it. The current-section highlight and the progress bar keep '
        'up automatically, because they are derived from the same engine state '
        'rather than tracked separately.',
  ),
  _Section(
    'Built for scale',
    'The same machinery that powers this short article powers a thousand-item '
        'feed. During steady scrolling each item\'s position is derived with '
        'O(1) arithmetic from a cached anchor - no render-tree walks, no matrix '
        'math, no allocations on the hot path.',
  ),
  _Section(
    'Wrap up',
    'You have now scrolled through the whole thing. The progress bar should '
        'read close to 100%, and the header should show this final section as '
        'current. Head back to the gallery to see the same primitives applied '
        'to feeds, carousels, grids, and analytics.',
  ),
];

/// Reading demo: a line region marks the reading position; the crossing
/// section becomes primary and drives the header + progress bar.
class ReadingProgressPage extends StatefulWidget {
  const ReadingProgressPage({super.key, required this.info});

  final DemoInfo info;

  @override
  State<ReadingProgressPage> createState() => _ReadingProgressPageState();
}

class _ReadingProgressPageState extends State<ReadingProgressPage> {
  final ScrollSpyController<int> _spy = ScrollSpyController<int>();
  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _keys = List.generate(
    _sections.length,
    (_) => GlobalKey(),
  );

  @override
  void dispose() {
    _spy.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _openToc() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SpyColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _sections.length,
            itemBuilder: (context, i) {
              return ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: SpyColors.accent2.withValues(alpha: 0.18),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: SpyColors.accent2,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(_sections[i].title),
                onTap: () {
                  Navigator.of(context).pop();
                  final ctx = _keys[i].currentContext;
                  if (ctx != null) {
                    Scrollable.ensureVisible(
                      ctx,
                      alignment: 0.12,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              );
            },
          ),
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
          tooltip: 'Table of contents',
          icon: const Icon(Icons.list_rounded),
          onPressed: _openToc,
        ),
      ],
      body: Column(
        children: [
          _ReadingHeader(controller: _spy, scroll: _scroll),
          Expanded(
            child: ScrollSpyCustomScrollView<int>(
              controller: _spy,
              scrollController: _scroll,
              region: const ScrollSpyRegion.line(
                anchor: ScrollSpyAnchor.fraction(0.22),
                thicknessPx: 2,
              ),
              policy: const ScrollSpyPolicy.closestToAnchor(),
              stability: const ScrollSpyStability(
                hysteresisPx: 12,
                minPrimaryDuration: Duration(milliseconds: 80),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverList.builder(
                    itemCount: _sections.length,
                    itemBuilder: (context, i) {
                      return ScrollSpyItemLite<int>(
                        id: i,
                        key: _keys[i],
                        builder: (context, isPrimary, isFocused, _) {
                          return _SectionBlock(
                            index: i,
                            section: _sections[i],
                            isPrimary: isPrimary,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingHeader extends StatelessWidget {
  const _ReadingHeader({required this.controller, required this.scroll});

  final ScrollSpyController<int> controller;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SpyColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScrollSpyPrimaryBuilder<int>(
            controller: controller,
            builder: (context, primaryId, _) {
              final int idx = primaryId ?? 0;
              return Row(
                children: [
                  const SectionLabel('Reading'),
                  const SizedBox(width: 8),
                  Text(
                    'Section ${idx + 1} of ${_sections.length}',
                    style: const TextStyle(
                      color: SpyColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const CodeChip('primaryId', accent: SpyColors.accent2),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          ScrollSpyPrimaryBuilder<int>(
            controller: controller,
            builder: (context, primaryId, _) {
              return Text(
                _sections[primaryId ?? 0].title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Reading progress derived from the raw scroll offset.
          AnimatedBuilder(
            animation: scroll,
            builder: (context, _) {
              double frac = 0;
              if (scroll.hasClients && scroll.position.maxScrollExtent > 0) {
                frac = (scroll.offset / scroll.position.maxScrollExtent).clamp(
                  0.0,
                  1.0,
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 5,
                  backgroundColor: SpyColors.surfaceHigh,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    SpyColors.accent2,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.index,
    required this.section,
    required this.isPrimary,
  });

  final int index;
  final _Section section;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: isPrimary ? SpyColors.accent2 : SpyColors.stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isPrimary ? Colors.white : SpyColors.muted,
                  ),
                  child: Text('${index + 1}. ${section.title}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            section.body,
            style: TextStyle(
              fontSize: 15.5,
              height: 1.65,
              color: Colors.white.withValues(alpha: isPrimary ? 0.92 : 0.62),
            ),
          ),
        ],
      ),
    );
  }
}
