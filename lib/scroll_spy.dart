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
/// - `ScrollSpyScope`: owns the focus engine for a scrollable subtree and
///   publishes computed frames into a controller.
/// - `ScrollSpyItem`: registers an item's `RenderBox` so it can participate
///   in geometry/focus computation.
/// - `ScrollSpyController`: exposes the latest results as `ValueListenable`s
///   (`primaryId`, `focusedIds`, `snapshot`) and per-item listenables.
///
/// The package also exports advanced utilities (debug overlay, engine helpers,
/// equality utilities, diagnostics). Most apps can ignore these unless they
/// need custom instrumentation or want to build on the low-level pipeline.
///
/// ### How focus is computed
/// On layout/scroll changes, the scope’s engine:
/// 1) Measures each registered item’s rect in **viewport coordinates**.
/// 2) Evaluates a `ScrollSpyRegion` to decide `isFocused` and compute
///    `focusProgress` / `focusOverlapFraction`.
/// 3) Chooses a single primary winner using `ScrollSpyPolicy`.
/// 4) Applies `ScrollSpyStability` to reduce primary flicker (optional).
///
/// ### Quick start
/// ```dart
/// final focus = ScrollSpyController<int>();
///
/// ScrollSpyScope<int>(
///   controller: focus,
///   region: ScrollSpyRegion.zone(
///     anchor: ScrollSpyAnchor.fraction(0.5),
///     extentPx: 200,
///   ),
///   policy: ScrollSpyPolicy.closestToAnchor(),
///   child: ListView.builder(
///     itemBuilder: (context, index) => ScrollSpyItem<int>(
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
/// For side effects without rebuilding, use `ScrollSpyPrimaryListener`.
/// For visual inspection, enable `ScrollSpyScope(debug: true)` and tweak the
/// overlay with `ScrollSpyDebugConfig`.
library;

export 'src/debug/debug_config.dart';
export 'src/debug/debug_overlay.dart';
export 'src/debug/debug_painter.dart';
export 'src/engine/focus_diff.dart';
export 'src/engine/focus_engine.dart';
export 'src/engine/focus_geometry.dart';
export 'src/engine/focus_registry.dart';
export 'src/engine/focus_selection.dart';
export 'src/public/scroll_spy_controller.dart';
export 'src/public/scroll_spy_models.dart';
export 'src/public/scroll_spy_policy.dart';
export 'src/public/scroll_spy_region.dart';
export 'src/public/scroll_spy_stability.dart';
export 'src/public/scroll_spy_update_policy.dart';
export 'src/utils/diagnostics.dart';
export 'src/widgets/scroll_spy_builders.dart';
export 'src/widgets/scroll_spy_item.dart';
export 'src/widgets/scroll_spy_listeners.dart';
export 'src/widgets/scroll_spy_scope.dart';
