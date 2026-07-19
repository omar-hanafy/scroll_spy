import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../common.dart';
import '../theme.dart';
import 'feed_video_pool.dart';

/// Flagship demo: a vertical feed where scroll_spy chooses exactly one real
/// bundled video to play while nearby controllers remain preloaded.
class FeedAutoplayPage extends StatefulWidget {
  const FeedAutoplayPage({super.key, required this.info, this.videoFactory});

  final DemoInfo info;

  /// Injectable so lifecycle and resource behavior can be tested without a
  /// platform video backend.
  final FeedVideoHandleFactory? videoFactory;

  @override
  State<FeedAutoplayPage> createState() => _FeedAutoplayPageState();
}

class _FeedAutoplayPageState extends State<FeedAutoplayPage>
    with WidgetsBindingObserver {
  final ScrollSpyController<int> _spy = ScrollSpyController<int>();
  final ScrollController _scroll = ScrollController();

  final ValueNotifier<int?> _nowPlaying = ValueNotifier<int?>(null);

  static const int _itemCount = 24;
  static const double _itemExtent = 440;

  late final FeedVideoPool _videoPool;
  bool _appIsActive = true;
  bool _routeIsActive = true;
  bool _debug = false;
  bool _autoScrolling = false;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final AppLifecycleState? lifecycleState =
        WidgetsBinding.instance.lifecycleState;
    _appIsActive =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    _videoPool = FeedVideoPool(
      factory: widget.videoFactory ?? createBundledFeedVideo,
      itemCount: _itemCount,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This dependency updates whenever another modal route covers or reveals
    // the feed, including dialogs and bottom sheets.
    _routeIsActive = ModalRoute.isCurrentOf(context) ?? true;
    _syncPlaybackActivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    _syncPlaybackActivity();
  }

  void _syncPlaybackActivity() {
    unawaited(_videoPool.setActive(_appIsActive && _routeIsActive));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoTimer?.cancel();
    unawaited(_videoPool.close());
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

  void _handlePrimaryChanged(int? previous, int? current) {
    _nowPlaying.value = current;
    unawaited(_videoPool.setPrimary(current));
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
      bottomBar: _NowPlayingBar(nowPlaying: _nowPlaying, videoPool: _videoPool),
      // The primary listener is the ownership boundary: pause the outgoing
      // player, preload neighbors, then play only the incoming primary.
      body: ScrollSpyPrimaryListener<int>(
        controller: _spy,
        onChanged: _handlePrimaryChanged,
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
                    builder: (context, focus, _) => _FeedCard(
                      key: ValueKey<String>('feed-card-$index'),
                      index: index,
                      focus: focus,
                      videoPool: _videoPool,
                    ),
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
  const _FeedCard({
    super.key,
    required this.index,
    required this.focus,
    required this.videoPool,
  });

  final int index;
  final ScrollSpyItemFocus<int> focus;
  final FeedVideoPool videoPool;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: videoPool.revision,
      builder: (context, _, _) {
        final FeedVideoHandle? handle = videoPool.handleFor(index);
        if (handle == null) return _buildCard(null, null);
        return ValueListenableBuilder<FeedVideoState>(
          valueListenable: handle.state,
          builder: (context, state, _) => _buildCard(handle, state),
        );
      },
    );
  }

  Widget _buildCard(FeedVideoHandle? handle, FeedVideoState? videoState) {
    // focusProgress (1.0 at the anchor, 0.0 at the zone edge) drives the
    // visual effect. Playback itself changes only when primaryId changes.
    final double progress = focus.focusProgress;
    final double scale = 0.93 + 0.07 * progress;
    final double opacity = 0.5 + 0.5 * progress;
    final bool isPrimary = focus.isPrimary;
    final bool isPlaying = videoState?.isPlaying ?? false;

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
                _VideoBackdrop(index: index, handle: handle, state: videoState),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                Center(
                  child: _PlayGlyph(
                    hasHandle: handle != null,
                    state: videoState,
                  ),
                ),
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
                            label: _statusLabel(videoState),
                            color: isPlaying
                                ? SpyColors.primary
                                : (focus.isFocused
                                      ? SpyColors.focused
                                      : SpyColors.muted),
                            icon: isPlaying
                                ? Icons.graphic_eq_rounded
                                : Icons.pause_rounded,
                            active: isPlaying || focus.isFocused,
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
                              value: progress,
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

  String _statusLabel(FeedVideoState? state) {
    if (state?.errorDescription != null) return 'UNAVAILABLE';
    if (state?.isPlaying ?? false) return 'PLAYING';
    if (state?.isBuffering ?? false) return 'BUFFERING';
    if (state?.isInitialized ?? false) return 'PRELOADED';
    if (state != null) return 'LOADING';
    return focus.isFocused ? 'READY' : 'PAUSED';
  }
}

class _VideoBackdrop extends StatelessWidget {
  const _VideoBackdrop({
    required this.index,
    required this.handle,
    required this.state,
  });

  final int index;
  final FeedVideoHandle? handle;
  final FeedVideoState? state;

  @override
  Widget build(BuildContext context) {
    if (handle == null || !(state?.isInitialized ?? false)) {
      return DecoratedBox(
        decoration: BoxDecoration(gradient: demoGradient(index)),
      );
    }

    final double aspectRatio = state!.aspectRatio <= 0 ? 1 : state!.aspectRatio;
    return ColoredBox(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: 1000 * aspectRatio,
          height: 1000,
          child: handle!.buildView(),
        ),
      ),
    );
  }
}

/// Central player state glyph, with an animated equalizer only while the
/// platform controller reports actual playback.
class _PlayGlyph extends StatelessWidget {
  const _PlayGlyph({required this.hasHandle, required this.state});

  final bool hasHandle;
  final FeedVideoState? state;

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = state?.isPlaying ?? false;
    final bool isLoading =
        hasHandle &&
        !(state?.isInitialized ?? false) &&
        state?.errorDescription == null;

    Widget child;
    if (state?.errorDescription != null) {
      child = const Icon(Icons.videocam_off_rounded, color: Colors.white);
    } else if (isLoading || (state?.isBuffering ?? false)) {
      child = const Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
      );
    } else if (isPlaying) {
      child = const Padding(padding: EdgeInsets.all(18), child: _Equalizer());
    } else {
      child = const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 34,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: isPlaying ? SpyColors.primary : Colors.black54,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: child,
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
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List<Widget>.generate(4, (index) {
            final double phase = (index * 0.25 + _controller.value) % 1.0;
            final double height =
                6 + 22 * (0.5 + 0.5 * (phase - 0.5).abs() * 2);
            return Container(
              width: 4,
              height: height.clamp(6, 28),
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

/// Bottom resource HUD. It exposes the important production invariant in the
/// live demo: at most three warm controllers and exactly one playing.
class _NowPlayingBar extends StatelessWidget {
  const _NowPlayingBar({required this.nowPlaying, required this.videoPool});

  final ValueListenable<int?> nowPlaying;
  final FeedVideoPool videoPool;

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: ValueListenableBuilder<int?>(
            valueListenable: nowPlaying,
            builder: (context, id, _) {
              return ValueListenableBuilder<int>(
                valueListenable: videoPool.revision,
                builder: (context, _, _) {
                  final int playing = videoPool.playingIndices.length;
                  return Row(
                    children: [
                      Icon(
                        playing == 1
                            ? Icons.graphic_eq_rounded
                            : Icons.pause_rounded,
                        color: playing == 1
                            ? SpyColors.primary
                            : SpyColors.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              id == null
                                  ? 'Nothing playing'
                                  : 'Primary - Clip #${id + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${videoPool.controllerCount}/'
                              '${videoPool.maxControllerCount} controllers '
                              'warm - $playing playing',
                              style: const TextStyle(
                                color: SpyColors.muted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const CodeChip('primaryId', accent: SpyColors.primary),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
