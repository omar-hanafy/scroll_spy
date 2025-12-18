import 'package:flutter/widgets.dart';

import 'package:viewport_focus/src/debug/debug_config.dart';
import 'package:viewport_focus/src/debug/debug_overlay.dart';
import 'package:viewport_focus/src/engine/focus_engine.dart';
import 'package:viewport_focus/src/engine/focus_registry.dart';
import 'package:viewport_focus/src/public/viewport_focus_controller.dart';
import 'package:viewport_focus/src/public/viewport_focus_policy.dart';
import 'package:viewport_focus/src/public/viewport_focus_region.dart';
import 'package:viewport_focus/src/public/viewport_focus_stability.dart';
import 'package:viewport_focus/src/public/viewport_focus_update_policy.dart';

/// The root widget that establishes a focus context for a scrollable subtree.
///
/// This widget initializes and manages the [FocusEngine], which is responsible
/// for:
/// 1. Listening to scroll events from the [child] (via [NotificationListener]).
/// 2. Calculating the geometry of all registered `ViewportFocusItem`s.
/// 3. Applying the [ViewportFocusPolicy] and [ViewportFocusStability] rules.
/// 4. Publishing the results to the [ViewportFocusController].
///
/// When [debug] is enabled, the scope inserts a debug overlay that subscribes to
/// the engine's debug frame stream and paints the current focus state.
///
/// **Usage:**
/// Wrap your [ListView], [GridView], or [CustomScrollView] with this widget.
///
/// ```dart
/// ViewportFocusScope<String>(
///   controller: myController,
///   region: ViewportFocusRegion.zone(anchor: ViewportAnchor.fraction(0.5), extentPx: 200),
///   policy: ViewportFocusPolicy.closestToAnchor(),
///   child: ListView(...),
/// )
/// ```
class ViewportFocusScope<T> extends StatefulWidget {
  /// Creates a focus scope for a scrollable subtree.
  ///
  /// Provide a [controller], [region], and [policy] at minimum. The scope
  /// listens to scroll notifications from [child] and publishes focus results
  /// into the controller.
  const ViewportFocusScope({
    super.key,
    required this.controller,
    required this.region,
    required this.policy,
    this.stability = const ViewportFocusStability(),
    this.updatePolicy = const ViewportUpdatePolicy.perFrame(),
    this.scrollController,
    this.notificationDepth = 0,
    this.notificationPredicate,
    this.debug = false,
    this.debugConfig,
    required this.child,
  });

  /// The controller that will receive focus updates.
  ///
  /// You must provide this to listen to the results (e.g., `controller.primaryId`).
  /// The scope strictly *writes* to this controller; it does not read from it.
  final ViewportFocusController<T> controller;

  /// Defines the "attention area" within the viewport.
  ///
  /// Items intersecting this region are considered `ViewportItemFocus.isFocused`.
  final ViewportFocusRegion region;

  /// The rule for selecting a single "primary" winner among the focused items.
  final ViewportFocusPolicy<T> policy;

  /// Configuration to prevent rapid focus switching (flicker).
  final ViewportFocusStability stability;

  /// Controls how often the focus engine runs (per-frame vs. scroll-end).
  final ViewportUpdatePolicy updatePolicy;

  /// An optional external scroll controller for the child scrollable.
  ///
  /// **Behavior:**
  /// If provided, the engine will listen to this controller in addition to notification bubbling.
  /// This ensures that programmatic scroll jumps (e.g., `controller.jumpTo`) are detected
  /// even if they don't produce standard drag notifications.
  final ScrollController? scrollController;

  /// The depth of scroll notifications to listen to (default: 0).
  ///
  /// **Why is this needed?**
  /// If your scrollable is nested inside another (e.g., a horizontal list inside a vertical one),
  /// you generally only want the *inner* list to drive this scope's focus.
  /// - `0`: Listens to the immediate child scrollable.
  /// - `>0`: Listens to deeper descendants.
  final int notificationDepth;

  /// A custom filter for scroll notifications.
  ///
  /// Use this if [notificationDepth] is insufficient (e.g., if you have a complex
  /// nested structure and need to target a specific scrollable by type or property).
  /// Returns `true` to process the notification.
  final bool Function(ScrollNotification notification)? notificationPredicate;

  /// Whether to paint a debug overlay on top of the child.
  ///
  /// The overlay visualizes:
  /// - The focus region (red box/line).
  /// - The bounding boxes of registered items.
  /// - Which items are focused (yellow) or primary (green).
  final bool debug;

  /// Customizes the appearance of the debug overlay.
  final ViewportFocusDebugConfig? debugConfig;

  /// The subtree containing the scrollable widget and [ViewportFocusItem]s.
  ///
  /// Items must be explicitly registered (typically via `ViewportFocusItem`) for
  /// the engine to produce non-empty focus state.
  final Widget child;

  /// Retrieves the nearest [ViewportFocusScopeState] ancestor.
  ///
  /// This is primarily used internally by `ViewportFocusItem` to register
  /// itself.
  static ViewportFocusScopeState<T> of<T>(BuildContext context) {
    final _ViewportFocusScopeInherited<T>? inherited = context
        .dependOnInheritedWidgetOfExactType<_ViewportFocusScopeInherited<T>>();
    assert(
      inherited != null,
      'ViewportFocusScope.of() called with a context that does not contain a ViewportFocusScope<$T>.',
    );
    return inherited!.state;
  }

  /// Retrieves the nearest [ViewportFocusScopeState] ancestor, or null if none exists.
  static ViewportFocusScopeState<T>? maybeOf<T>(BuildContext context) {
    final _ViewportFocusScopeInherited<T>? inherited = context
        .dependOnInheritedWidgetOfExactType<_ViewportFocusScopeInherited<T>>();
    return inherited?.state;
  }

  @override
  State<ViewportFocusScope<T>> createState() => ViewportFocusScopeState<T>();
}

/// Runtime state backing a [ViewportFocusScope].
///
/// This state object owns the internal engine and registry. It is exposed so
/// that `ViewportFocusItem` can register/unregister itself, and for advanced
/// integrations that need access to the engine’s debug stream.
///
/// In normal app usage you should:
/// - configure focus behavior via the [ViewportFocusScope] widget parameters,
/// - listen to results via the associated [ViewportFocusController], and
/// - wrap items with `ViewportFocusItem` for registration.
class ViewportFocusScopeState<T> extends State<ViewportFocusScope<T>>
    with WidgetsBindingObserver {
  late final FocusRegistry<T> _registry;
  late FocusEngine<T> _engine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _registry = FocusRegistry<T>();

    _engine = FocusEngine<T>(
      controller: widget.controller,
      registry: _registry,
      region: widget.region,
      policy: widget.policy,
      stability: widget.stability,
      updatePolicy: widget.updatePolicy,
      includeItemRects: _shouldIncludeItemRects,
    );
  }

  bool get _shouldIncludeItemRects {
    if (!widget.debug) return false;
    final cfg = widget.debugConfig ?? const ViewportFocusDebugConfig();
    return cfg.includeItemRectsInFrame;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _engine.attach(scrollController: widget.scrollController);
  }

  @override
  void didUpdateWidget(covariant ViewportFocusScope<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool configChanged = oldWidget.region != widget.region ||
        oldWidget.policy != widget.policy ||
        oldWidget.stability != widget.stability ||
        oldWidget.updatePolicy != widget.updatePolicy ||
        oldWidget.controller != widget.controller ||
        oldWidget.debug != widget.debug ||
        oldWidget.debugConfig != widget.debugConfig;

    if (oldWidget.scrollController != widget.scrollController) {
      _engine.updateScrollController(widget.scrollController);
    }

    if (configChanged) {
      _engine.updateConfig(
        controller: widget.controller,
        region: widget.region,
        policy: widget.policy,
        stability: widget.stability,
        updatePolicy: widget.updatePolicy,
        includeItemRects: _shouldIncludeItemRects,
      );
    }
  }

  @override
  void didChangeMetrics() {
    // Called on window metrics changes (rotation, keyboard, etc).
    _engine.handleMetricsChanged();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _engine.dispose();
    super.dispose();
  }

  /// Called by [ViewportFocusItem] to register its render-proxy context.
  ///
  /// `ViewportFocusItem` schedules registration after the frame so the render
  /// object has a stable size and paint transform.
  void registerItem(
    T id, {
    required BuildContext context,
    required RenderBox box,
  }) {
    _engine.registerItem(id, context: context, box: box);
  }

  /// Called by `ViewportFocusItem` to unregister itself.
  void unregisterItem(T id) {
    _engine.unregisterItem(id);
  }

  /// The controller that this scope writes focus frames into.
  ViewportFocusController<T> get controller => widget.controller;

  /// The internal engine instance driving focus computation for this scope.
  ///
  /// This is primarily useful for debug tooling (for example wiring the
  /// engine’s debug frame stream into a custom overlay).
  FocusEngine<T> get engine => _engine;

  bool _onScrollNotification(ScrollNotification n) {
    if (n.depth != widget.notificationDepth) return false;
    if (widget.notificationPredicate != null &&
        !widget.notificationPredicate!(n)) {
      return false;
    }
    return _engine.handleScrollNotification(n);
  }

  bool _onScrollMetricsNotification(ScrollMetricsNotification n) {
    if (n.depth != widget.notificationDepth) return false;
    return _engine.handleScrollMetricsNotification(n);
  }

  bool _onSizeChangedNotification(SizeChangedLayoutNotification n) {
    // Parent layout / viewport size changes.
    _engine.handleMetricsChanged();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    Widget result = _ViewportFocusScopeInherited<T>(
      state: this,
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: _onSizeChangedNotification,
        child: SizeChangedLayoutNotifier(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: _onScrollMetricsNotification,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    if (widget.debug) {
      final ViewportFocusDebugConfig cfg =
          widget.debugConfig ?? const ViewportFocusDebugConfig();

      result = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          result,
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: ViewportFocusDebugOverlay<T>(
                debugFrameListenable: _engine.debugFrame,
                config: cfg,
              ),
            ),
          ),
        ],
      );
    }

    return result;
  }
}

class _ViewportFocusScopeInherited<T> extends InheritedWidget {
  const _ViewportFocusScopeInherited({
    required this.state,
    required super.child,
  });

  final ViewportFocusScopeState<T> state;

  @override
  bool updateShouldNotify(_ViewportFocusScopeInherited<T> oldWidget) => false;
}
