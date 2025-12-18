/// Viewport-aware focus detection for scrollables.
///
/// This package helps you derive **attention state** from scrolling UI without
/// manually wiring scroll listeners and geometry math.
///
/// Conceptually, it answers:
/// - Which items are currently *visible* in the viewport?
/// - Which items intersect an application-defined *focus region* (line/zone)?
/// - Which single item is the *primary* winner (useful for autoplay/feed UX)?
///
/// The public API is built around three roles:
/// - `ViewportFocusScope`: owns the focus engine for a scrollable subtree and
///   publishes computed frames into a controller.
/// - `ViewportFocusItem`: registers an item's `RenderBox` so it can participate
///   in geometry/focus computation.
/// - `ViewportFocusController`: exposes the latest results as `ValueListenable`s
///   (`primaryId`, `focusedIds`, `snapshot`) and per-item listenables.
///
/// The package also exports advanced utilities (debug overlay, engine helpers,
/// equality utilities, diagnostics). Most apps can ignore these unless they
/// need custom instrumentation or want to build on the low-level pipeline.
///
/// ### How focus is computed
/// On layout/scroll changes, the scope’s engine:
/// 1) Measures each registered item’s rect in **viewport coordinates**.
/// 2) Evaluates a `ViewportFocusRegion` to decide `isFocused` and compute
///    `focusProgress` / `focusOverlapFraction`.
/// 3) Chooses a single primary winner using `ViewportFocusPolicy`.
/// 4) Applies `ViewportFocusStability` to reduce primary flicker (optional).
///
/// ### Quick start
/// ```dart
/// final focus = ViewportFocusController<int>();
///
/// ViewportFocusScope<int>(
///   controller: focus,
///   region: ViewportFocusRegion.zone(
///     anchor: ViewportAnchor.fraction(0.5),
///     extentPx: 200,
///   ),
///   policy: ViewportFocusPolicy.closestToAnchor(),
///   child: ListView.builder(
///     itemBuilder: (context, index) => ViewportFocusItem<int>(
///       id: index,
///       builder: (context, itemFocus, child) {
///         return Opacity(
///           opacity: itemFocus.isPrimary ? 1.0 : 0.6,
///           child: child,
///         );
///       },
///       child: YourItemWidget(index: index),
///     ),
///   ),
/// );
/// ```
///
/// For side effects without rebuilding, use `ViewportPrimaryListener`.
/// For visual inspection, enable `ViewportFocusScope(debug: true)` and tweak the
/// overlay with `ViewportFocusDebugConfig`.
library;

export 'src/debug/debug_config.dart';
export 'src/debug/debug_overlay.dart';
export 'src/debug/debug_painter.dart';
export 'src/engine/focus_diff.dart';
export 'src/engine/focus_engine.dart';
export 'src/engine/focus_geometry.dart';
export 'src/engine/focus_registry.dart';
export 'src/engine/focus_selection.dart';
export 'src/public/viewport_focus_controller.dart';
export 'src/public/viewport_focus_models.dart';
export 'src/public/viewport_focus_policy.dart';
export 'src/public/viewport_focus_region.dart';
export 'src/public/viewport_focus_stability.dart';
export 'src/public/viewport_focus_update_policy.dart';
export 'src/utils/diagnostics.dart';
export 'src/widgets/viewport_focus_builders.dart';
export 'src/widgets/viewport_focus_item.dart';
export 'src/widgets/viewport_focus_listeners.dart';
export 'src/widgets/viewport_focus_scope.dart';
