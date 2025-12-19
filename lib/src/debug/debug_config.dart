// lib/src/debug/debug_config.dart
import 'dart:ui' show Color, Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show EdgeInsets, TextStyle;
import 'package:scroll_spy/src/public/scroll_spy_models.dart';

/// Configuration options for the visual debug overlay.
///
/// When `ScrollSpyScope(debug: true)` is enabled, the scope inserts a
/// transparent overlay above your scrollable and feeds it debug frames produced
/// by the focus engine. This config controls **what gets painted** and how it is
/// styled, and it also tells the engine whether to include per-item rects in
/// each debug frame.
///
/// It helps you visualize:
/// - Where the focus region (line or zone) is located.
/// - Which items are currently detected by the engine.
/// - Which item is "primary" and which are "focused".
/// - Internal metrics like "distance to anchor" and "visible fraction".
///
/// **Usage:**
/// Pass this to `ScrollSpyScope.debugConfig`. The scope will forward
/// [includeItemRectsInFrame] to the engine so debug frames contain enough
/// geometry for the overlay to draw item bounds.
@immutable
class ScrollSpyDebugConfig {
  /// Whether the debug overlay should paint anything at all.
  final bool enabled;

  /// If true, the engine will allocate and include `Rect` objects for every
  /// item in the debug frame so the overlay can paint per-item bounds and
  /// visible rectangles.
  ///
  /// **Performance Warning:** This increases memory allocation per frame and is
  /// intended only for debugging.
  final bool includeItemRectsInFrame;

  /// Whether to draw a border around the scrollable viewport itself.
  ///
  /// Useful for seeing the exact bounds the engine is using when measuring
  /// items and evaluating regions.
  final bool showViewportBounds;

  /// Whether to draw the "attention area" (line or zone).
  final bool showFocusRegion;

  /// Whether to draw outlines around every registered item.
  final bool showItemBounds;

  /// Whether to draw a semi-transparent fill over the *visible* portion of
  /// items.
  ///
  /// Useful for verifying visibility calculations and debugging partial
  /// overlaps.
  final bool showVisibleBounds;

  /// Whether to highlight the primary item with a distinct border.
  final bool showPrimaryOutline;

  /// Whether to highlight all focused items with a distinct border.
  final bool showFocusedOutlines;

  /// Whether to paint text labels containing item IDs and metrics
  /// (e.g., "dist: 12px").
  final bool showLabels;

  /// Stroke width for generic item bounds.
  final double itemStrokeWidth;

  /// Stroke width for focused item bounds.
  final double focusedStrokeWidth;

  /// Stroke width for primary item bounds.
  final double primaryStrokeWidth;

  /// Stroke width for focus region bounds.
  final double regionStrokeWidth;

  /// Fill opacity for visible rect overlays. (0..1)
  final double visibleFillOpacity;

  /// Outline/Fill colors (defaults chosen for clarity on light/dark UIs).
  final Color viewportBoundsColor;

  /// Color used to outline/fill the focus region.
  final Color regionColor;

  /// Color used for generic item bounds (non-focused).
  final Color itemBoundsColor;

  /// Color used to outline focused items.
  final Color focusedBoundsColor;

  /// Color used to outline the primary item.
  final Color primaryBoundsColor;

  /// Color used for visible-portion fill overlays.
  final Color visibleFillColor;

  /// Label styling.
  final TextStyle labelTextStyle;

  /// Padding around label text when painting debug labels.
  final EdgeInsets labelPadding;

  /// Corner radius for label background rectangles.
  final double labelCornerRadius;

  /// Creates a debug config with optional overrides.
  ///
  /// Supply this to `ScrollSpyScope.debugConfig` to control overlay styling
  /// and whether the engine includes per-item rects in debug frames.
  const ScrollSpyDebugConfig({
    this.enabled = true,
    this.includeItemRectsInFrame = true,
    this.showViewportBounds = false,
    this.showFocusRegion = true,
    this.showItemBounds = false,
    this.showVisibleBounds = true,
    this.showPrimaryOutline = true,
    this.showFocusedOutlines = true,
    this.showLabels = true,
    this.itemStrokeWidth = 1.0,
    this.focusedStrokeWidth = 2.0,
    this.primaryStrokeWidth = 3.0,
    this.regionStrokeWidth = 2.0,
    this.visibleFillOpacity = 0.10,
    this.viewportBoundsColor = const Color(0xFF8E8E93), // iOS system gray
    this.regionColor = const Color(0xFFFF3B30), // system red
    this.itemBoundsColor = const Color(0xFF007AFF), // system blue
    this.focusedBoundsColor = const Color(0xFFFFCC00), // system yellow
    this.primaryBoundsColor = const Color(0xFF34C759), // system green
    this.visibleFillColor = const Color(0xFF007AFF),
    this.labelTextStyle = const TextStyle(
      fontSize: 11,
      height: 1.1,
      color: Color(0xFFFFFFFF),
    ),
    this.labelPadding = const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    this.labelCornerRadius = 6,
  });

  /// A preset that turns the overlay fully off and avoids per-item `Rect`
  /// allocation in debug frames.
  ///
  /// Use this when you want `ScrollSpyScope(debug: true)` available but
  /// need a single switch to disable painting/allocations (for example, in a
  /// release build where a debug toggle could still be flipped accidentally).
  static const ScrollSpyDebugConfig disabled = ScrollSpyDebugConfig(
    enabled: false,
    includeItemRectsInFrame: false,
    showViewportBounds: false,
    showFocusRegion: false,
    showItemBounds: false,
    showVisibleBounds: false,
    showPrimaryOutline: false,
    showFocusedOutlines: false,
    showLabels: false,
  );

  /// Creates a new config by overriding a subset of fields.
  ///
  /// This is the intended way to toggle individual overlay features while
  /// keeping the rest of the styling consistent. When this config is supplied
  /// to a scope, changing [includeItemRectsInFrame] also changes whether the
  /// engine computes per-item rects for debug frames.
  ///
  /// Note: The debug painter repaints when the config’s **values** change
  /// (equality is value-based), so rebuilding with an equal config does not
  /// force a repaint.
  ScrollSpyDebugConfig copyWith({
    bool? enabled,
    bool? includeItemRectsInFrame,
    bool? showViewportBounds,
    bool? showFocusRegion,
    bool? showItemBounds,
    bool? showVisibleBounds,
    bool? showPrimaryOutline,
    bool? showFocusedOutlines,
    bool? showLabels,
    double? itemStrokeWidth,
    double? focusedStrokeWidth,
    double? primaryStrokeWidth,
    double? regionStrokeWidth,
    double? visibleFillOpacity,
    Color? viewportBoundsColor,
    Color? regionColor,
    Color? itemBoundsColor,
    Color? focusedBoundsColor,
    Color? primaryBoundsColor,
    Color? visibleFillColor,
    TextStyle? labelTextStyle,
    EdgeInsets? labelPadding,
    double? labelCornerRadius,
  }) {
    return ScrollSpyDebugConfig(
      enabled: enabled ?? this.enabled,
      includeItemRectsInFrame:
          includeItemRectsInFrame ?? this.includeItemRectsInFrame,
      showViewportBounds: showViewportBounds ?? this.showViewportBounds,
      showFocusRegion: showFocusRegion ?? this.showFocusRegion,
      showItemBounds: showItemBounds ?? this.showItemBounds,
      showVisibleBounds: showVisibleBounds ?? this.showVisibleBounds,
      showPrimaryOutline: showPrimaryOutline ?? this.showPrimaryOutline,
      showFocusedOutlines: showFocusedOutlines ?? this.showFocusedOutlines,
      showLabels: showLabels ?? this.showLabels,
      itemStrokeWidth: itemStrokeWidth ?? this.itemStrokeWidth,
      focusedStrokeWidth: focusedStrokeWidth ?? this.focusedStrokeWidth,
      primaryStrokeWidth: primaryStrokeWidth ?? this.primaryStrokeWidth,
      regionStrokeWidth: regionStrokeWidth ?? this.regionStrokeWidth,
      visibleFillOpacity: visibleFillOpacity ?? this.visibleFillOpacity,
      viewportBoundsColor: viewportBoundsColor ?? this.viewportBoundsColor,
      regionColor: regionColor ?? this.regionColor,
      itemBoundsColor: itemBoundsColor ?? this.itemBoundsColor,
      focusedBoundsColor: focusedBoundsColor ?? this.focusedBoundsColor,
      primaryBoundsColor: primaryBoundsColor ?? this.primaryBoundsColor,
      visibleFillColor: visibleFillColor ?? this.visibleFillColor,
      labelTextStyle: labelTextStyle ?? this.labelTextStyle,
      labelPadding: labelPadding ?? this.labelPadding,
      labelCornerRadius: labelCornerRadius ?? this.labelCornerRadius,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScrollSpyDebugConfig &&
        other.enabled == enabled &&
        other.includeItemRectsInFrame == includeItemRectsInFrame &&
        other.showViewportBounds == showViewportBounds &&
        other.showFocusRegion == showFocusRegion &&
        other.showItemBounds == showItemBounds &&
        other.showVisibleBounds == showVisibleBounds &&
        other.showPrimaryOutline == showPrimaryOutline &&
        other.showFocusedOutlines == showFocusedOutlines &&
        other.showLabels == showLabels &&
        other.itemStrokeWidth == itemStrokeWidth &&
        other.focusedStrokeWidth == focusedStrokeWidth &&
        other.primaryStrokeWidth == primaryStrokeWidth &&
        other.regionStrokeWidth == regionStrokeWidth &&
        other.visibleFillOpacity == visibleFillOpacity &&
        other.viewportBoundsColor == viewportBoundsColor &&
        other.regionColor == regionColor &&
        other.itemBoundsColor == itemBoundsColor &&
        other.focusedBoundsColor == focusedBoundsColor &&
        other.primaryBoundsColor == primaryBoundsColor &&
        other.visibleFillColor == visibleFillColor &&
        other.labelTextStyle == labelTextStyle &&
        other.labelPadding == labelPadding &&
        other.labelCornerRadius == labelCornerRadius;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        enabled,
        includeItemRectsInFrame,
        showViewportBounds,
        showFocusRegion,
        showItemBounds,
        showVisibleBounds,
        showPrimaryOutline,
        showFocusedOutlines,
        showLabels,
        itemStrokeWidth,
        focusedStrokeWidth,
        primaryStrokeWidth,
        regionStrokeWidth,
        visibleFillOpacity,
        viewportBoundsColor,
        regionColor,
        itemBoundsColor,
        focusedBoundsColor,
        primaryBoundsColor,
        visibleFillColor,
        labelTextStyle,
        labelPadding,
        labelCornerRadius,
      ]);
}

/// A single computed debug frame (one per engine compute).
///
/// Frames are produced by the engine and consumed by the debug overlay/painter.
/// Coordinate space:
/// - All rects here MUST be in the same coordinate space as the debug overlay's
///   canvas (typically the `ScrollSpyScope` render box coordinate space).
@immutable
class ScrollSpyDebugFrame<T> {
  /// Monotonically increasing sequence number assigned by the engine.
  ///
  /// The painter uses this as a repaint key so every compute pass can be
  /// visualized, even when higher-level signals do not change.
  final int sequence;

  /// The viewport rect bounds (within the overlay coordinate space).
  final Rect viewportRect;

  /// The focus region drawn as a rect. For a "line region", this should be a
  /// thin rect whose thickness equals the line thickness.
  ///
  /// If null, the overlay won't draw the region.
  final Rect? focusRegionRect;

  /// Optional label for the region (e.g., "center zone +/- 80px").
  final String? focusRegionLabel;

  /// Current primary id.
  final T? primaryId;

  /// Current focused ids.
  final Set<T> focusedIds;

  /// Per-item debug information. Typically contains only registered items and
  /// only includes rects when [ScrollSpyDebugConfig.includeItemRectsInFrame]
  /// is enabled.
  final Map<T, ScrollSpyDebugItem<T>> items;

  /// Optional snapshot for richer labels; safe for overlay to ignore.
  final ScrollSpySnapshot<T>? snapshot;

  /// Creates a debug frame for a single engine compute pass.
  ///
  /// All rects must already be in the overlay's coordinate space.
  const ScrollSpyDebugFrame({
    required this.sequence,
    required this.viewportRect,
    required this.focusRegionRect,
    required this.primaryId,
    required this.focusedIds,
    required this.items,
    this.focusRegionLabel,
    this.snapshot,
  });

  /// Returns an empty frame.
  ///
  /// This is used as an initial value before the engine has produced a real
  /// compute pass.
  static ScrollSpyDebugFrame<T> empty<T>() {
    return ScrollSpyDebugFrame<T>(
      sequence: 0,
      viewportRect: Rect.zero,
      focusRegionRect: null,
      primaryId: null,
      focusedIds: const {},
      items: const {},
      focusRegionLabel: null,
      snapshot: null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScrollSpyDebugFrame<T> && other.sequence == sequence;

  @override
  int get hashCode => sequence.hashCode;
}

/// Debug information for a single registered item within a [ScrollSpyDebugFrame].
///
/// The overlay uses this data to draw rectangles and per-item labels. The
/// engine only populates these rects when debug mode requests them (see
/// [ScrollSpyDebugConfig.includeItemRectsInFrame]) to avoid per-frame
/// allocations in production.
@immutable
class ScrollSpyDebugItem<T> {
  /// The item’s identifier (the same ID used by `ScrollSpyItem`).
  final T id;

  /// Item bounds in overlay coordinate space.
  final Rect itemRect;

  /// Visible bounds (intersection with viewport) in overlay coordinate space.
  final Rect? visibleRect;

  /// Optional per-item metrics (the same object a controller snapshot would
  /// expose for this item).
  final ScrollSpyItemFocus<T>? focus;

  /// Creates per-item debug data for overlay rendering.
  const ScrollSpyDebugItem({
    required this.id,
    required this.itemRect,
    required this.visibleRect,
    required this.focus,
  });
}
