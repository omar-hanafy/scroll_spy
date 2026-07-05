import 'package:flutter/material.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../common.dart';
import '../theme.dart';

/// Grid demo: a TikTok-search-style results grid.
///
/// On narrow layouts (2 columns) the most-visible tile wins (the
/// largestVisibleFraction policy) and lifts; a hero strip mirrors it.
/// On wide layouts (3+ columns) the mouse takes over, like TikTok on
/// desktop: hovering a tile makes it the active one, and scroll_spy's
/// primary is the fallback when nothing is hovered.
class GalleryGridPage extends StatefulWidget {
  const GalleryGridPage({super.key, required this.info});

  final DemoInfo info;

  @override
  State<GalleryGridPage> createState() => _GalleryGridPageState();
}

class _GalleryGridPageState extends State<GalleryGridPage> {
  final ScrollSpyController<int> _spy = ScrollSpyController<int>();

  static const int _itemCount = 60;

  /// Target tile width; the column count adapts to the viewport
  /// (2 on phones, up to 6 on desktop/web), TikTok-search style.
  static const double _maxTileWidth = 200;

  /// Base vertical offset between adjacent columns.
  ///
  /// In a uniform grid all tiles of a row share the exact same main-axis
  /// geometry, so every metric (visibleFraction, focusProgress, distance to
  /// anchor) ties and the first tile would always win. Staggering the columns
  /// gives each tile distinct geometry, so the primary can travel through
  /// every tile as you scroll.
  static const double _stagger = 26;

  /// Extra per-column skew so no two columns ever share geometry.
  ///
  /// A plain odd/even stagger would still tie same-parity columns (0 and 2,
  /// 1 and 3, ...) once the grid has more than two columns.
  static const double _skew = 3;

  /// Top offset for a column: alternating stagger plus a tiny unique skew.
  static double _columnOffset(int col) =>
      (col.isOdd ? _stagger : 0) + col * _skew;

  /// Hovered tile id. Only honored on wide layouts (3+ columns), mirroring
  /// TikTok on desktop: many columns -> the mouse decides what plays; two
  /// columns -> scroll position decides.
  final ValueNotifier<int?> _hover = ValueNotifier<int?>(null);

  @override
  void dispose() {
    _spy.dispose();
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: widget.info.title,
      accent: widget.info.accent,
      description: widget.info.description,
      apis: widget.info.apis,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final int cols = (constraints.maxWidth / _maxTileWidth).ceil().clamp(
            2,
            6,
          );
          // TikTok-desktop behavior: with many columns the mouse decides.
          final bool hoverDrives = cols > 2;
          final double maxOffset = _columnOffset(
            cols.isEven ? cols - 1 : cols - 2,
          );
          return Column(
            children: [
              _HeroStrip(
                controller: _spy,
                hover: _hover,
                hoverEnabled: hoverDrives,
                accent: widget.info.accent,
              ),
              Expanded(
                child: ScrollSpyGridView<int>.builder(
                  controller: _spy,
                  region: const ScrollSpyRegion.zone(
                    anchor: ScrollSpyAnchor.fraction(0.42),
                    extentPx: 260,
                  ),
                  policy: const ScrollSpyPolicy.largestVisibleFraction(),
                  stability: const ScrollSpyStability(hysteresisPx: 6),
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: _itemCount,
                  itemBuilder: (context, index) {
                    // Each column sits at its own offset (see _columnOffset).
                    final double top = _columnOffset(index % cols);
                    return Padding(
                      padding: EdgeInsets.only(
                        top: top,
                        bottom: maxOffset - top,
                      ),
                      child: MouseRegion(
                        onEnter: hoverDrives
                            ? (_) => _hover.value = index
                            : null,
                        onExit: hoverDrives
                            ? (_) {
                                if (_hover.value == index) _hover.value = null;
                              }
                            : null,
                        child: ScrollSpyItem<int>(
                          id: index,
                          builder: (context, focus, _) =>
                              ValueListenableBuilder<int?>(
                                valueListenable: _hover,
                                builder: (context, hoverId, _) => _Tile(
                                  index: index,
                                  focus: focus,
                                  hoverId: hoverDrives ? hoverId : null,
                                ),
                              ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroStrip extends StatelessWidget {
  const _HeroStrip({
    required this.controller,
    required this.hover,
    required this.hoverEnabled,
    required this.accent,
  });

  final ScrollSpyController<int> controller;
  final ValueNotifier<int?> hover;
  final bool hoverEnabled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SpyColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: ValueListenableBuilder<int?>(
        valueListenable: hover,
        builder: (context, hoverId, _) => ScrollSpyPrimaryBuilder<int>(
          controller: controller,
          builder: (context, primaryId, _) {
            final int? hovered = hoverEnabled ? hoverId : null;
            final int idx = hovered ?? primaryId ?? 0;
            return Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: demoGradient(idx),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${idx + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(hovered != null ? 'Hovering' : 'In focus'),
                    const SizedBox(height: 3),
                    Text(
                      'Tile #${idx + 1}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                CodeChip(
                  hovered != null ? 'hover override' : 'largestVisibleFraction',
                  accent: const Color(0xFFFFB020),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.index, required this.focus, this.hoverId});

  final int index;
  final ScrollSpyItemFocus<int> focus;

  /// Currently hovered tile id, or null when hover does not drive selection.
  final int? hoverId;

  @override
  Widget build(BuildContext context) {
    // While a tile is hovered, the mouse decides; otherwise scroll_spy does.
    final bool isPrimary = hoverId != null ? hoverId == index : focus.isPrimary;
    return AnimatedScale(
      scale: isPrimary ? 1.0 : 0.95,
      duration: const Duration(milliseconds: 220),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        // The border lives in the foreground so it paints on top of the
        // full-bleed gradient and stays rounded (a border in `decoration`
        // insets the child, whose square corners then poke into the ring).
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary
                ? Colors.white
                : Colors.white.withValues(alpha: 0.08),
            width: isPrimary ? 2 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(gradient: demoGradient(index)),
            ),
            Positioned(
              left: 10,
              bottom: 8,
              child: Text(
                '#${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${(focus.visibleFraction * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
