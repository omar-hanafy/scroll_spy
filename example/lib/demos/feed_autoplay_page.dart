import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../common.dart';
import '../theme.dart';

/// Flagship demo: a vertical feed where exactly one card is "primary" and
/// auto-plays, mirroring how a social video feed decides what to play.
class FeedAutoplayPage extends StatefulWidget {
  const FeedAutoplayPage({super.key, required this.info});

  final DemoInfo info;

  @override
  State<FeedAutoplayPage> createState() => _FeedAutoplayPageState();
}

class _FeedAutoplayPageState extends State<FeedAutoplayPage> {
  final ScrollSpyController<int> _spy = ScrollSpyController<int>();
  final ScrollController _scroll = ScrollController();

  /// The current "playing" clip, updated by a primary listener (a side effect,
  /// not a rebuild of the list).
  final ValueNotifier<int?> _nowPlaying = ValueNotifier<int?>(null);

  static const int _itemCount = 24;
  static const double _itemExtent = 440;

  bool _debug = false;
  bool _autoScrolling = false;
  Timer? _autoTimer;

  @override
  void dispose() {
    _autoTimer?.cancel();
    _spy.dispose();
    _scroll.dispose();
    _nowPlaying.dispose();
    super.dispose();
  }

  void _toggleAutoScroll() {
    setState(() => _autoScrolling = !_autoScrolling);
    _autoTimer?.cancel();
    if (_autoScrolling) {
      _autoTimer = Timer.periodic(
        const Duration(milliseconds: 1400),
        (_) => _stepAutoScroll(),
      );
    }
  }

  void _stepAutoScroll() {
    if (!mounted || !_scroll.hasClients) return;
    final int current = _spy.primaryId.value ?? 0;
    int next = current + 1;
    if (next >= _itemCount) next = 0;
    final double max = _scroll.position.maxScrollExtent;
    final double target = (next * _itemExtent).clamp(0.0, max);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
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
          tooltip: _debug ? 'Hide overlay' : 'Show overlay',
          icon: Icon(_debug ? Icons.layers_rounded : Icons.layers_outlined),
          onPressed: () => setState(() => _debug = !_debug),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleAutoScroll,
        backgroundColor: widget.info.accent,
        foregroundColor: Colors.black,
        icon: Icon(
          _autoScrolling ? Icons.stop_rounded : Icons.play_arrow_rounded,
        ),
        label: Text(_autoScrolling ? 'Stop' : 'Auto-scroll'),
      ),
      bottomBar: _NowPlayingBar(nowPlaying: _nowPlaying),
      // The listener fires only when the primary id changes: the ideal place to
      // start/stop real playback. Here it just updates the now-playing bar.
      body: ScrollSpyPrimaryListener<int>(
        controller: _spy,
        onChanged: (prev, curr) => _nowPlaying.value = curr,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double pad = ((constraints.maxHeight - _itemExtent) / 2)
                .clamp(0, 400);
            return ScrollSpyScope<int>(
              controller: _spy,
              scrollController: _scroll,
              region: const ScrollSpyRegion.zone(
                anchor: ScrollSpyAnchor.fraction(0.5),
                extentPx: 220,
              ),
              policy: const ScrollSpyPolicy.closestToAnchor(),
              stability: const ScrollSpyStability(
                hysteresisPx: 24,
                minPrimaryDuration: Duration(milliseconds: 150),
              ),
              debug: _debug,
              debugConfig: const ScrollSpyDebugConfig(
                showFocusRegion: true,
                showPrimaryOutline: true,
                showLabels: true,
                visibleFillOpacity: 0.0,
              ),
              child: ListView.builder(
                controller: _scroll,
                itemCount: _itemCount,
                itemExtent: _itemExtent,
                padding: EdgeInsets.symmetric(vertical: pad),
                itemBuilder: (context, index) {
                  return ScrollSpyItem<int>(
                    id: index,
                    builder: (context, focus, _) =>
                        _FeedCard(index: index, focus: focus),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.index, required this.focus});

  final int index;
  final ScrollSpyItemFocus<int> focus;

  @override
  Widget build(BuildContext context) {
    // focusProgress (1.0 at the anchor, 0.0 at the zone edge) drives the "come
    // into focus" animation without any per-frame setState on our side.
    final double p = focus.focusProgress;
    final double scale = 0.93 + 0.07 * p;
    final double opacity = 0.5 + 0.5 * p;
    final bool isPrimary = focus.isPrimary;

    return Center(
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: SpyColors.primary.withValues(alpha: 0.28),
                        blurRadius: 34,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            // Border in the foreground: painted over the full-bleed content,
            // so the ring stays rounded instead of being squared off by the
            // inset child's corners.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isPrimary
                    ? SpyColors.primary
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
                // Darken toward the bottom for legible text.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                ),
                Center(child: _PlayGlyph(playing: isPrimary)),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white24,
                            child: Text(
                              '${index % 9}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '@creator_$index',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(),
                          StatusPill(
                            label: isPrimary
                                ? 'PLAYING'
                                : (focus.isFocused ? 'READY' : 'PAUSED'),
                            color: isPrimary
                                ? SpyColors.primary
                                : (focus.isFocused
                                      ? SpyColors.focused
                                      : SpyColors.muted),
                            icon: isPrimary
                                ? Icons.graphic_eq_rounded
                                : Icons.pause_rounded,
                            active: isPrimary || focus.isFocused,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Clip #${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: MetricBar(
                              label: 'visible',
                              value: focus.visibleFraction,
                              color: SpyColors.visible,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: MetricBar(
                              label: 'focus',
                              value: p,
                              color: SpyColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// Central play/pause glyph, with an animated equalizer while playing.
class _PlayGlyph extends StatelessWidget {
  const _PlayGlyph({required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: playing ? SpyColors.primary : Colors.black38,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: playing
          ? const Padding(padding: EdgeInsets.all(18), child: _Equalizer())
          : const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
    );
  }
}

class _Equalizer extends StatefulWidget {
  const _Equalizer();

  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (i) {
            final double phase = (i * 0.25 + _c.value) % 1.0;
            final double h = 6 + 22 * (0.5 + 0.5 * (phase - 0.5).abs() * 2);
            return Container(
              width: 4,
              height: h.clamp(6, 28),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Bottom "now playing" bar, rebuilt only when the primary clip changes.
class _NowPlayingBar extends StatelessWidget {
  const _NowPlayingBar({required this.nowPlaying});

  final ValueListenable<int?> nowPlaying;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SpyColors.surface,
        border: Border(top: BorderSide(color: SpyColors.stroke)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: ValueListenableBuilder<int?>(
            valueListenable: nowPlaying,
            builder: (context, id, _) {
              return Row(
                children: [
                  Icon(
                    id == null ? Icons.pause_rounded : Icons.graphic_eq_rounded,
                    color: id == null ? SpyColors.muted : SpyColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    id == null
                        ? 'Nothing playing'
                        : 'Now playing - Clip #${id + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const Spacer(),
                  const CodeChip('primaryId', accent: SpyColors.primary),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
