import 'package:flutter/foundation.dart';

/// Configuration for controlling the stability and "stickiness" of the primary
/// focus.
///
/// These settings prevent rapid focus switching ("flicker") when two items are
/// competing for the primary spot (e.g., when scrolling slowly near the
/// boundary between two items).
///
/// This logic is applied *after* the policy (`ViewportFocusPolicy`) ranks
/// candidates. It never changes which items are focused; it only decides when
/// the primary is allowed to switch.
///
/// In this package’s engine, stability affects two phases:
/// - **While there are focused candidates:** controls when/if the primary is
///   allowed to switch away from the current primary.
/// - **When there are no focused candidates:** controls whether a "best
///   available" primary should be kept/selected anyway
///   ([allowPrimaryWhenNoItemFocused]).
@immutable
class ViewportFocusStability {
  /// The distance (in pixels) by which a new candidate must beat the current primary
  /// in order to take over.
  ///
  /// **Why use this?**
  /// Prevents "chatter" when two items are nearly equidistant from the anchor.
  /// Without hysteresis, micro-fluctuations in scroll position could cause the primary ID
  /// to toggle back and forth rapidly.
  ///
  /// In this package’s engine, the comparison is based on absolute
  /// `distanceToAnchorPx`: a challenger must be closer to the anchor by at least
  /// [hysteresisPx] (after [minPrimaryDuration] is satisfied and when
  /// [preferCurrentPrimary] is true).
  ///
  /// **Recommended:** `10.0` to `50.0` pixels depending on item size.
  final double hysteresisPx;

  /// The minimum amount of time the current primary item must hold its status before
  /// it can be replaced by a better candidate.
  ///
  /// **Why use this?**
  /// Prevents a fast-scrolling list from triggering a barrage of primary updates.
  /// It ensures an item is "seen" for at least this duration before it counts as primary.
  ///
  /// This timer only matters while the current primary remains focused. If the
  /// current primary stops being focused, the engine immediately considers other
  /// focused candidates (or falls back according to
  /// [allowPrimaryWhenNoItemFocused]).
  ///
  /// **Note:** If the current primary item leaves the focus region entirely, it loses
  /// status as a *focused* primary immediately. If you allow a fallback primary
  /// when nothing is focused, that behavior is controlled by
  /// [allowPrimaryWhenNoItemFocused].
  final Duration minPrimaryDuration;

  /// Whether to bias selection towards the *current* primary item.
  ///
  /// - `true` (default): The current primary keeps its status until a challenger beats it
  ///   by [hysteresisPx] AND [minPrimaryDuration] has passed.
  /// - `false`: The engine always picks the absolute best candidate every frame (subject only to min duration).
  final bool preferCurrentPrimary;

  /// Whether to maintain a "best available" primary item even when no item strictly
  /// intersects the focus region.
  ///
  /// - `true` (default): If the focus region (e.g., a thin line) falls between two items,
  ///   the engine will keep the last known primary (or pick the closest visible one).
  ///   This is crucial for "gapless" playback in feeds.
  /// - `false`: Primary ID becomes `null` as soon as no item is in the focus region.
  final bool allowPrimaryWhenNoItemFocused;

  /// Creates a stability configuration for primary selection.
  ///
  /// These values are applied after policy ranking to reduce primary flicker.
  const ViewportFocusStability({
    this.hysteresisPx = 0.0,
    this.minPrimaryDuration = Duration.zero,
    this.preferCurrentPrimary = true,
    this.allowPrimaryWhenNoItemFocused = true,
  }) : assert(hysteresisPx >= 0.0);

  /// Disables all stability rules.
  ///
  /// This disables hysteresis and minimum-duration stickiness, meaning the
  /// engine will report the currently best focused candidate every compute pass.
  ///
  /// Note: This still keeps [allowPrimaryWhenNoItemFocused] enabled, so the
  /// engine can maintain a "best available" primary even when the region falls
  /// between items.
  const ViewportFocusStability.disabled()
      : hysteresisPx = 0.0,
        minPrimaryDuration = Duration.zero,
        preferCurrentPrimary = false,
        allowPrimaryWhenNoItemFocused = true;

  /// Whether hysteresis or minimum-duration stickiness is enabled.
  ///
  /// This does not include [allowPrimaryWhenNoItemFocused], which is a separate
  /// (often desirable) fallback behavior.
  bool get isEnabled =>
      hysteresisPx > 0.0 || minPrimaryDuration > Duration.zero;

  @override
  String toString() {
    return 'ViewportFocusStability('
        'hysteresisPx: $hysteresisPx, '
        'minPrimaryDuration: $minPrimaryDuration, '
        'preferCurrentPrimary: $preferCurrentPrimary, '
        'allowPrimaryWhenNoItemFocused: $allowPrimaryWhenNoItemFocused'
        ')';
  }

  @override
  bool operator ==(Object other) {
    return other is ViewportFocusStability &&
        other.hysteresisPx == hysteresisPx &&
        other.minPrimaryDuration == minPrimaryDuration &&
        other.preferCurrentPrimary == preferCurrentPrimary &&
        other.allowPrimaryWhenNoItemFocused == allowPrimaryWhenNoItemFocused;
  }

  @override
  int get hashCode => Object.hash(
        hysteresisPx,
        minPrimaryDuration,
        preferCurrentPrimary,
        allowPrimaryWhenNoItemFocused,
      );
}
