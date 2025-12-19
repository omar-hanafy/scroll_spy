import 'package:flutter/material.dart';
import 'package:viewport_focus/viewport_focus.dart';

void main() {
  runApp(const ShowcaseApp());
}

class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viewport Focus Showcase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigoAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
      ),
      home: const FeedPage(),
    );
  }
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  // 1. Create a Focus Controller
  final ViewportFocusController<int> _focusController =
      ViewportFocusController();
  final ScrollController _scrollController = ScrollController();

  bool _autoScrolling = false;
  bool _showDebug = true;

  @override
  void dispose() {
    _focusController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleAutoScroll() {
    if (_autoScrolling) {
      setState(() => _autoScrolling = false);
      // Stop scrolling
      _scrollController.position.hold(() {});
      return;
    }

    setState(() => _autoScrolling = true);
    _startAutoScroll();
  }

  Future<void> _startAutoScroll() async {
    while (_autoScrolling && mounted) {
      if (!_scrollController.hasClients) break;
      final max = _scrollController.position.maxScrollExtent;
      final current = _scrollController.offset;

      if (current >= max) {
        _scrollController.jumpTo(0);
      }

      // Smooth auto scroll to next item approx
      await _scrollController.animateTo(
        current + 400,
        duration: const Duration(seconds: 2),
        curve: Curves.easeInOutSine,
      );
      if (!mounted) break;
      // Pause briefly on the item
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Viewport Focus'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_showDebug ? Icons.layers_clear : Icons.layers),
            tooltip: 'Toggle Focus Overlay',
            onPressed: () => setState(() => _showDebug = !_showDebug),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleAutoScroll,
        icon: Icon(_autoScrolling ? Icons.stop : Icons.play_arrow),
        label: Text(_autoScrolling ? 'Stop Demo' : 'Auto Scroll'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      // 2. Wrap your list in a ViewportFocusScope
      body: ViewportFocusScope<int>(
        controller: _focusController,
        // Define the "Focus Zone" (e.g. center 300px)
        region: ViewportFocusRegion.zone(
          anchor: const ViewportAnchor.fraction(0.5),
          extentPx: 300,
        ),
        // Define how to pick the "Primary" item (Closest to center)
        policy: const ViewportFocusPolicy.closestToAnchor(),
        // Optional: Debug overlay to visualize the zone
        debug: _showDebug,
        debugConfig: const ViewportFocusDebugConfig(
          showFocusRegion: true,
          showLabels: true,
          showPrimaryOutline: true,
          visibleFillOpacity: 0.0, // Clean look, just outlines
        ),
        child: ListView.builder(
          controller: _scrollController,
          itemCount: 20,
          // Make items large enough to be interesting
          itemExtent: 500,
          itemBuilder: (context, index) {
            // 3. Wrap each item in ViewportFocusItem
            return ViewportFocusItem<int>(
              id: index,
              builder: (context, focus, _) {
                return _InteractiveFeedItem(index: index, focus: focus);
              },
            );
          },
        ),
      ),
    );
  }
}

class _InteractiveFeedItem extends StatelessWidget {
  const _InteractiveFeedItem({required this.index, required this.focus});

  final int index;
  final ViewportItemFocus<int> focus;

  @override
  Widget build(BuildContext context) {
    // React to focus state
    final bool isPrimary = focus.isPrimary;
    final bool isFocused = focus.isFocused;

    // Animate scale based on "how close to center" (focusProgress)
    final double scale = 0.90 + (0.10 * focus.focusProgress);
    final double opacity = 0.4 + (0.6 * focus.focusProgress);

    return Center(
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: Container(
            height: 460,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(24),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: Colors.indigoAccent.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
              border: isPrimary
                  ? Border.all(color: Colors.indigoAccent, width: 2)
                  : Border.all(color: Colors.white10, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Placeholder Content (Gradient)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors
                            .primaries[index % Colors.primaries.length]
                            .shade800,
                        Colors
                            .primaries[(index + 1) % Colors.primaries.length]
                            .shade900,
                      ],
                    ),
                  ),
                ),

                // Content Info
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video Content #${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _StatusBadge(
                            isPrimary: isPrimary,
                            isFocused: isFocused,
                          ),
                          const Spacer(),
                          Text(
                            '${(focus.visibleFraction * 100).toInt()}% visible',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Play Icon (Centered)
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isPrimary ? Colors.white : Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPrimary ? Icons.pause : Icons.play_arrow,
                      color: isPrimary ? Colors.black : Colors.white,
                      size: 36,
                    ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isPrimary, required this.isFocused});

  final bool isPrimary;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    if (isPrimary) {
      color = Colors.greenAccent;
      label = 'PLAYING';
      icon = Icons.equalizer;
    } else if (isFocused) {
      color = Colors.amberAccent;
      label = 'READY';
      icon = Icons.hourglass_empty;
    } else {
      color = Colors.grey;
      label = 'PAUSED';
      icon = Icons.pause_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
