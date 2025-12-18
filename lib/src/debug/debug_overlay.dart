// lib/src/debug/debug_overlay.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:viewport_focus/src/debug/debug_config.dart';
import 'package:viewport_focus/src/debug/debug_painter.dart';

/// A transparent overlay widget that visualizes the internal state of the focus
/// engine.
///
/// This widget is automatically inserted by `ViewportFocusScope` when `debug`
/// is true. It listens to engine debug frames and paints them on top of the
/// scrollable without intercepting pointer events.
///
/// What gets drawn (region, bounds, labels) and the colors/styles used are
/// controlled by [ViewportFocusDebugConfig].
class ViewportFocusDebugOverlay<T> extends StatelessWidget {
  /// The listenable stream of debug frames to paint.
  ///
  /// In normal usage this is `scope.engine.debugFrame`. The engine publishes a
  /// new frame after each compute pass, even when the controller’s diff-only
  /// signals (like `primaryId`) do not change.
  final ValueListenable<FocusDebugFrame<T>?> debugFrameListenable;

  /// Paint/styling configuration for the overlay.
  final ViewportFocusDebugConfig config;

  /// Creates a debug overlay bound to a debug frame listenable.
  const ViewportFocusDebugOverlay({
    super.key,
    required this.debugFrameListenable,
    this.config = const ViewportFocusDebugConfig(),
  });

  @override
  Widget build(BuildContext context) {
    if (!config.enabled) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: true,
      child: RepaintBoundary(
        child: ValueListenableBuilder<FocusDebugFrame<T>?>(
          valueListenable: debugFrameListenable,
          builder: (context, frame, _) {
            if (frame == null) {
              return const SizedBox.expand();
            }

            return CustomPaint(
              painter: ViewportFocusDebugPainter<T>(
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
