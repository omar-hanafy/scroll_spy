import 'package:flutter/material.dart';

import 'common.dart';
import 'demos/demos.dart';
import 'theme.dart';

void main() {
  runApp(const ShowcaseApp());
}

/// Root of the scroll_spy showcase.
class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'scroll_spy showcase',
      debugShowCheckedModeBanner: false,
      theme: buildShowcaseTheme(),
      home: const HomeGalleryPage(),
    );
  }
}

/// Landing page: a gallery of demos, each showcasing part of the API.
class HomeGalleryPage extends StatelessWidget {
  const HomeGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _Hero()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList.separated(
              itemCount: kDemos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _DemoCard(demo: kDemos[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final double topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(24, topPad + 40, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1330), SpyColors.bg],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [SpyColors.accent, Color(0xFF4423B0)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.radar_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const _VersionPill(),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'scroll_spy',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Viewport-aware focus detection for scrollables. Know which item '
            'is primary, which are focused, and how visible each one is - '
            'derived in O(1) per item on the scroll hot path.',
            style: TextStyle(color: SpyColors.muted, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: const [
              LegendDot(color: SpyColors.primary, label: 'primary'),
              LegendDot(color: SpyColors.focused, label: 'focused'),
              LegendDot(color: SpyColors.visible, label: 'visible'),
              LegendDot(color: SpyColors.region, label: 'region'),
            ],
          ),
        ],
      ),
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: SpyColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SpyColors.accent.withValues(alpha: 0.35)),
      ),
      child: const Text(
        'v1.0.0',
        style: TextStyle(
          color: SpyColors.accent,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.demo});

  final DemoInfo demo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SpyColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (ctx) => demo.builder(ctx, demo)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SpyColors.stroke),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: demo.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: demo.accent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(demo.icon, color: demo.accent, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        demo.title,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        demo.tagline,
                        style: const TextStyle(
                          color: SpyColors.muted,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: SpyColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
