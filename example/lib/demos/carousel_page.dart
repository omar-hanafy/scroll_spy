import 'package:flutter/material.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../common.dart';
import '../theme.dart';

/// Horizontal carousel: the centered page is primary and scales up, while
/// neighbours peek, shrink, and dim. Shows scroll_spy on the horizontal axis.
class CarouselPage extends StatefulWidget {
  const CarouselPage({super.key, required this.info});

  final DemoInfo info;

  @override
  State<CarouselPage> createState() => _CarouselPageState();
}

class _CarouselPageState extends State<CarouselPage> {
  final ScrollSpyController<int> _spy = ScrollSpyController<int>();
  final PageController _page = PageController(viewportFraction: 0.76);

  static const int _itemCount = 8;
  static const List<String> _titles = [
    'Aurora',
    'Nebula',
    'Cascade',
    'Prism',
    'Vertex',
    'Halcyon',
    'Zenith',
    'Lumen',
  ];

  @override
  void dispose() {
    _spy.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: widget.info.title,
      accent: widget.info.accent,
      description: widget.info.description,
      apis: widget.info.apis,
      body: Column(
        children: [
          const Spacer(),
          SizedBox(
            height: 420,
            child: ScrollSpyPageView<int>.builder(
              controller: _spy,
              pageController: _page,
              scrollDirection: Axis.horizontal,
              region: const ScrollSpyRegion.zone(
                anchor: ScrollSpyAnchor.fraction(0.5),
                extentPx: 240,
              ),
              policy: const ScrollSpyPolicy.closestToAnchor(),
              stability: const ScrollSpyStability(hysteresisPx: 8),
              itemCount: _itemCount,
              itemBuilder: (context, index) {
                return ScrollSpyItem<int>(
                  id: index,
                  builder: (context, focus, _) => _PosterCard(
                    index: index,
                    title: _titles[index],
                    focus: focus,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _Dots(
            controller: _spy,
            count: _itemCount,
            accent: widget.info.accent,
          ),
          const SizedBox(height: 20),
          ScrollSpyPrimaryBuilder<int>(
            controller: _spy,
            builder: (context, primaryId, _) {
              final int idx = primaryId ?? 0;
              return Column(
                children: [
                  Text(
                    _titles[idx],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Featured page ${idx + 1} of $_itemCount',
                    style: const TextStyle(color: SpyColors.muted),
                  ),
                ],
              );
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.index,
    required this.title,
    required this.focus,
  });

  final int index;
  final String title;
  final ScrollSpyItemFocus<int> focus;

  @override
  Widget build(BuildContext context) {
    final double p = focus.focusProgress;
    final double scale = 0.84 + 0.16 * p;
    final double opacity = 0.45 + 0.55 * p;
    final bool isPrimary = focus.isPrimary;

    return Center(
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 18),
                      ),
                    ]
                  : const [],
            ),
            // Border in the foreground: painted over the full-bleed content,
            // so the ring stays rounded instead of being squared off by the
            // inset child's corners.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isPrimary
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.1),
                width: isPrimary ? 2 : 1,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(gradient: demoGradient(index)),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  bottom: 22,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Poster #${index + 1}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPrimary)
                  const Positioned(
                    top: 16,
                    left: 16,
                    child: StatusPill(
                      label: 'PRIMARY',
                      color: SpyColors.primary,
                      icon: Icons.star_rounded,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.controller,
    required this.count,
    required this.accent,
  });

  final ScrollSpyController<int> controller;
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ScrollSpyPrimaryBuilder<int>(
      controller: controller,
      builder: (context, primaryId, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (i) {
            final bool active = i == (primaryId ?? 0);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active ? accent : SpyColors.surfaceHigh,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        );
      },
    );
  }
}
