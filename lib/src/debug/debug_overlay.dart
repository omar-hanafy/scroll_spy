// lib/src/debug/debug_overlay.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:scroll_spy/src/debug/debug_config.dart';
import 'package:scroll_spy/src/debug/debug_painter.dart';

/// A transparent overlay widget that visualizes the internal state of the focus
/// engine.
///
/// This widget is automatically inserted by `ScrollSpyScope` when `debug`
/// is true. It listens to engine debug frames and paints them on top of the
/// scrollable without intercepting pointer events.
///
/// What gets drawn (region, bounds, labels) and the colors/styles used are
/// controlled by [ScrollSpyDebugConfig].
class ScrollSpyDebugOverlay<T> extends StatelessWidget {
  /// The listenable stream of debug frames to paint.
  ///
  /// In normal usage this is `scope.engine.debugFrame`. The engine publishes a
  /// new frame after each compute pass, even when the controller’s diff-only
  /// signals (like `primaryId`) do not change.
  final ValueListenable<ScrollSpyDebugFrame<T>?> debugFrameListenable;

  /// Paint/styling configuration for the overlay.
  final ScrollSpyDebugConfig config;

  /// Creates a debug overlay bound to a debug frame listenable.
  const ScrollSpyDebugOverlay({
    super.key,
    required this.debugFrameListenable,
    this.config = const ScrollSpyDebugConfig(),
  });

  @override
  Widget build(BuildContext context) {
    if (!config.enabled) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: true,
      child: RepaintBoundary(
        child: ValueListenableBuilder<ScrollSpyDebugFrame<T>?>(
          valueListenable: debugFrameListenable,
          builder: (context, frame, _) {
            if (frame == null) {
              return const SizedBox.expand();
            }

            return CustomPaint(
              painter: ScrollSpyDebugPainter<T>(
                frame: frame,
                config: config,
              ),
              isComplex: true,
              willChange: true,
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}
