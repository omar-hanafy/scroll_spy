import 'package:flutter/widgets.dart';

import 'package:scroll_spy/src/debug/debug_config.dart';
import 'package:scroll_spy/src/debug/debug_overlay.dart';
import 'package:scroll_spy/src/engine/focus_engine.dart';
import 'package:scroll_spy/src/engine/focus_registry.dart';
import 'package:scroll_spy/src/public/scroll_spy_controller.dart';
import 'package:scroll_spy/src/public/scroll_spy_policy.dart';
import 'package:scroll_spy/src/public/scroll_spy_region.dart';
import 'package:scroll_spy/src/public/scroll_spy_stability.dart';
import 'package:scroll_spy/src/public/scroll_spy_update_policy.dart';

/// The root widget that establishes a focus context for a scrollable subtree.
///
/// This widget initializes and manages the [ScrollSpyEngine], which is responsible
/// for:
/// 1. Listening to scroll events from the [child] (via [NotificationListener]).
/// 2. Calculating the geometry of all registered `ScrollSpyItem`s.
/// 3. Applying the [ScrollSpyPolicy] and [ScrollSpyStability] rules.
/// 4. Publishing the results to the [ScrollSpyController].
///
/// When [debug] is enabled, the scope inserts a debug overlay that subscribes to
/// the engine's debug frame stream and paints the current focus state.
///
/// **Usage:**
/// Wrap your [ListView], [GridView], or [CustomScrollView] with this widget.
///
/// ```dart
/// ScrollSpyScope<String>(
///   controller: myController,
///   region: ScrollSpyRegion.zone(anchor: ScrollSpyAnchor.fraction(0.5), extentPx: 200),
///   policy: ScrollSpyPolicy.closestToAnchor(),
///   child: ListView(...),
/// )
/// ```
class ScrollSpyScope<T> extends StatefulWidget {
  /// Creates a focus scope for a scrollable subtree.
  ///
  /// Provide a [controller], [region], and [policy] at minimum. The scope
  /// listens to scroll notifications from [child] and publishes focus results
  /// into the controller.
  const ScrollSpyScope({
    super.key,
    required this.controller,
    required this.region,
    required this.policy,
    this.stability = const ScrollSpyStability(),
    this.updatePolicy = const ScrollSpyUpdatePolicy.perFrame(),
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
  final ScrollSpyController<T> controller;

  /// Defines the "attention area" within the viewport.
  ///
  /// Items intersecting this region are considered `ScrollSpyItemFocus.isFocused`.
  final ScrollSpyRegion region;

  /// The rule for selecting a single "primary" winner among the focused items.
  final ScrollSpyPolicy<T> policy;

  /// Configuration to prevent rapid focus switching (flicker).
  final ScrollSpyStability stability;

  /// Controls how often the focus engine runs (per-frame vs. scroll-end).
  final ScrollSpyUpdatePolicy updatePolicy;

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
  final ScrollSpyDebugConfig? debugConfig;

  /// The subtree containing the scrollable widget and [ScrollSpyItem]s.
  ///
  /// Items must be explicitly registered (typically via `ScrollSpyItem`) for
  /// the engine to produce non-empty focus state.
  final Widget child;

  /// Retrieves the nearest [ScrollSpyScopeState] ancestor.
  ///
  /// This is primarily used internally by `ScrollSpyItem` to register
  /// itself.
  static ScrollSpyScopeState<T> of<T>(BuildContext context) {
    final _ScrollSpyScopeInherited<T>? inherited = context
        .dependOnInheritedWidgetOfExactType<_ScrollSpyScopeInherited<T>>();
    assert(
      inherited != null,
      'ScrollSpyScope.of() called with a context that does not contain a ScrollSpyScope<$T>.',
    );
    return inherited!.state;
  }

  /// Retrieves the nearest [ScrollSpyScopeState] ancestor, or null if none exists.
  static ScrollSpyScopeState<T>? maybeOf<T>(BuildContext context) {
    final _ScrollSpyScopeInherited<T>? inherited = context
        .dependOnInheritedWidgetOfExactType<_ScrollSpyScopeInherited<T>>();
    return inherited?.state;
  }

  @override
  State<ScrollSpyScope<T>> createState() => ScrollSpyScopeState<T>();
}

/// Runtime state backing a [ScrollSpyScope].
///
/// This state object owns the internal engine and registry. It is exposed so
/// that `ScrollSpyItem` can register/unregister itself, and for advanced
/// integrations that need access to the engine’s debug stream.
///
/// In normal app usage you should:
/// - configure focus behavior via the [ScrollSpyScope] widget parameters,
/// - listen to results via the associated [ScrollSpyController], and
/// - wrap items with `ScrollSpyItem` for registration.
class ScrollSpyScopeState<T> extends State<ScrollSpyScope<T>>
    with WidgetsBindingObserver {
  late final ScrollSpyRegistry<T> _registry;
  late ScrollSpyEngine<T> _engine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _registry = ScrollSpyRegistry<T>();

    _engine = ScrollSpyEngine<T>(
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
    final cfg = widget.debugConfig ?? const ScrollSpyDebugConfig();
    return cfg.includeItemRectsInFrame;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _engine.attach(scrollController: widget.scrollController);
  }

  @override
  void didUpdateWidget(covariant ScrollSpyScope<T> oldWidget) {
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

  /// Called by [ScrollSpyItem] to register its render-proxy context.
  ///
  /// `ScrollSpyItem` schedules registration after the frame so the render
  /// object has a stable size and paint transform.
  void registerItem(
    T id, {
    required BuildContext context,
    required RenderBox box,
  }) {
    _engine.registerItem(id, context: context, box: box);
  }

  /// Called by `ScrollSpyItem` to unregister itself.
  void unregisterItem(T id) {
    _engine.unregisterItem(id);
  }

  /// The controller that this scope writes focus frames into.
  ScrollSpyController<T> get controller => widget.controller;

  /// The internal engine instance driving focus computation for this scope.
  ///
  /// This is primarily useful for debug tooling (for example wiring the
  /// engine’s debug frame stream into a custom overlay).
  ScrollSpyEngine<T> get engine => _engine;

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
    Widget result = _ScrollSpyScopeInherited<T>(
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
      final ScrollSpyDebugConfig cfg =
          widget.debugConfig ?? const ScrollSpyDebugConfig();

      result = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          result,
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: ScrollSpyDebugOverlay<T>(
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

class _ScrollSpyScopeInherited<T> extends InheritedWidget {
  const _ScrollSpyScopeInherited({
    required this.state,
    required super.child,
  });

  final ScrollSpyScopeState<T> state;

  @override
  bool updateShouldNotify(_ScrollSpyScopeInherited<T> oldWidget) => false;
}
