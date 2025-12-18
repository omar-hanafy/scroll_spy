// lib/src/debug/debug_painter.dart
import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import 'package:viewport_focus/src/public/viewport_focus_models.dart';
import 'package:viewport_focus/src/debug/debug_config.dart';

/// Paints a [FocusDebugFrame] produced by the focus engine.
///
/// This painter is used by `ViewportFocusDebugOverlay` and intentionally keeps
/// all *geometry decisions* in the engine:
/// - All rects in [frame] are assumed to already be in the same coordinate
///   space as the canvas.
/// - When per-item rects are not provided by the engine (because
///   [ViewportFocusDebugConfig.includeItemRectsInFrame] is false), the painter
///   only draws what is available (region + global label).
///
/// Repaint contract:
/// - Repaints when [frame.sequence] changes (new engine compute), or
/// - when [config] values change (value-based equality).
class ViewportFocusDebugPainter<T> extends CustomPainter {
  /// The frame to visualize.
  final FocusDebugFrame<T> frame;

  /// Visual and feature toggles for debug painting.
  final ViewportFocusDebugConfig config;

  /// Creates a painter for a single debug frame.
  ViewportFocusDebugPainter({required this.frame, required this.config})
      : super(repaint: null);

  @override
  void paint(Canvas canvas, Size size) {
    if (!config.enabled) return;

    final Rect viewport = _normalizeViewportRect(frame.viewportRect, size);

    // Optional viewport bounds.
    if (config.showViewportBounds && viewport.isFinite && !viewport.isEmpty) {
      final Paint p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = config.viewportBoundsColor;
      canvas.drawRect(viewport, p);
    }

    // Focus region.
    if (config.showFocusRegion && frame.focusRegionRect != null) {
      final Rect region = frame.focusRegionRect!;
      final Paint outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = config.regionStrokeWidth
        ..color = config.regionColor;

      // Slight fill to make it easy to see.
      final Paint fill = Paint()
        ..style = PaintingStyle.fill
        ..color = _withOpacity(config.regionColor, 0.08);

      canvas.drawRect(region, fill);
      canvas.drawRect(region, outline);
    }

    // Visible rect overlays (filled) first, so outlines stay crisp.
    if (config.showVisibleBounds) {
      final Paint fill = Paint()
        ..style = PaintingStyle.fill
        ..color = _withOpacity(
          config.visibleFillColor,
          config.visibleFillOpacity,
        );

      for (final FocusDebugItem<T> item in frame.items.values) {
        final Rect? vr = item.visibleRect;
        if (vr == null || vr.isEmpty) continue;
        canvas.drawRect(vr, fill);
      }
    }

    // Item outlines.
    final Paint itemOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = config.itemStrokeWidth
      ..color = config.itemBoundsColor;

    final Paint focusedOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = config.focusedStrokeWidth
      ..color = config.focusedBoundsColor;

    final Paint primaryOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = config.primaryStrokeWidth
      ..color = config.primaryBoundsColor;

    for (final FocusDebugItem<T> item in frame.items.values) {
      final bool isPrimary =
          frame.primaryId != null && item.id == frame.primaryId;
      final bool isFocused = frame.focusedIds.contains(item.id) ||
          (item.focus?.isFocused ?? false);

      if (config.showItemBounds) {
        canvas.drawRect(item.itemRect, itemOutline);
      }

      if (config.showFocusedOutlines && isFocused && !isPrimary) {
        canvas.drawRect(item.itemRect, focusedOutline);
      }

      if (config.showPrimaryOutline && isPrimary) {
        canvas.drawRect(item.itemRect, primaryOutline);
      }
    }

    // Labels (global + per item).
    if (config.showLabels) {
      _paintGlobalLabel(canvas, viewport, size);
      _paintItemLabels(canvas, viewport, size);
    }
  }

  void _paintGlobalLabel(Canvas canvas, Rect viewport, Size size) {
    final String primary = frame.primaryId?.toString() ?? 'null';
    final int focusedCount = frame.focusedIds.length;
    final int itemCount = frame.items.length;

    final StringBuffer sb = StringBuffer()
      ..writeln('ViewportFocus Debug')
      ..writeln('seq: ${frame.sequence}')
      ..writeln('primary: $primary')
      ..writeln('focused: $focusedCount, items: $itemCount');

    if (frame.focusRegionLabel != null &&
        frame.focusRegionLabel!.trim().isNotEmpty) {
      sb.writeln('region: ${frame.focusRegionLabel}');
    }

    final Offset origin = (viewport.isFinite && !viewport.isEmpty)
        ? viewport.topLeft + const Offset(8, 8)
        : const Offset(8, 8);

    _drawLabel(
      canvas: canvas,
      at: origin,
      text: sb.toString().trimRight(),
      maxWidth: math.max(
        120,
        (viewport.isFinite ? viewport.width : size.width) - 16,
      ),
      backgroundColor: const Color(0xCC000000),
    );
  }

  void _paintItemLabels(Canvas canvas, Rect viewport, Size size) {
    for (final FocusDebugItem<T> item in frame.items.values) {
      final ViewportItemFocus<T>? f = item.focus;
      if (f == null) continue;

      // Keep label inside viewport-ish area for readability.
      final Offset labelPos = _clampOffsetToRect(
        item.itemRect.topLeft + const Offset(6, 6),
        viewport.isFinite && !viewport.isEmpty
            ? viewport
            : (Offset.zero & size),
      );

      final bool isPrimary =
          frame.primaryId != null && item.id == frame.primaryId;
      final bool isFocused = frame.focusedIds.contains(item.id) || f.isFocused;

      final StringBuffer sb = StringBuffer()
        ..writeln('${item.id}')
        ..writeln(
          '${isPrimary ? "PRIMARY" : (isFocused ? "focused" : "idle")} '
          '${f.isVisible ? "visible" : "off"}',
        )
        ..writeln('vis: ${(f.visibleFraction * 100).toStringAsFixed(0)}%')
        ..writeln('prog: ${f.focusProgress.toStringAsFixed(2)}')
        ..writeln('dist: ${f.distanceToAnchorPx.toStringAsFixed(1)}px');

      _drawLabel(
        canvas: canvas,
        at: labelPos,
        text: sb.toString().trimRight(),
        maxWidth: math.max(120, item.itemRect.width - 12),
        backgroundColor: isPrimary
            ? _withOpacity(config.primaryBoundsColor, 0.70)
            : (isFocused
                ? _withOpacity(config.focusedBoundsColor, 0.70)
                : const Color(0xAA000000)),
      );
    }
  }

  void _drawLabel({
    required Canvas canvas,
    required Offset at,
    required String text,
    required double maxWidth,
    required Color backgroundColor,
  }) {
    final TextSpan span = TextSpan(text: text, style: config.labelTextStyle);

    final TextPainter tp = TextPainter(
      text: span,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    final Rect textRect = Rect.fromLTWH(
      at.dx,
      at.dy,
      tp.width + config.labelPadding.horizontal,
      tp.height + config.labelPadding.vertical,
    );

    final RRect bg = RRect.fromRectAndRadius(
      textRect,
      Radius.circular(config.labelCornerRadius),
    );

    final Paint bgPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = backgroundColor;

    canvas.drawRRect(bg, bgPaint);

    final Offset textOffset = Offset(
      at.dx + config.labelPadding.left,
      at.dy + config.labelPadding.top,
    );

    tp.paint(canvas, textOffset);
  }

  Rect _normalizeViewportRect(Rect viewportRect, Size size) {
    if (viewportRect.isFinite && !viewportRect.isEmpty) return viewportRect;
    return Offset.zero & size;
  }

  Offset _clampOffsetToRect(Offset p, Rect rect) {
    final double dx = p.dx.clamp(rect.left, rect.right - 1);
    final double dy = p.dy.clamp(rect.top, rect.bottom - 1);
    return Offset(dx, dy);
  }

  Color _withOpacity(Color c, double opacity) {
    final int a = (opacity.clamp(0.0, 1.0) * 255).round();
    return c.withAlpha(a);
  }

  @override
  bool shouldRepaint(covariant ViewportFocusDebugPainter<T> oldDelegate) {
    // Repaint when the engine produces a new frame (sequence) or config toggles change.
    return oldDelegate.frame.sequence != frame.sequence ||
        oldDelegate.config != config;
  }
}
