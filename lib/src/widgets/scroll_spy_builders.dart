import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:scroll_spy/src/debug/debug_config.dart';
import 'package:scroll_spy/src/public/scroll_spy_controller.dart';
import 'package:scroll_spy/src/public/scroll_spy_policy.dart';
import 'package:scroll_spy/src/public/scroll_spy_region.dart';
import 'package:scroll_spy/src/public/scroll_spy_stability.dart';
import 'package:scroll_spy/src/public/scroll_spy_update_policy.dart';
import 'package:scroll_spy/src/widgets/scroll_spy_scope.dart';

typedef _ScrollViewBuilder = Widget Function(
    {ScrollController? controller, bool? primary});

/// A convenience widget that combines a [ScrollSpyScope] with a [ListView].
///
/// This wrapper reduces boilerplate and keeps the **focus engine** and the
/// underlying scrollable **wired to the same effective** [ScrollController],
/// including when the app relies on `PrimaryScrollController`.
///
/// Important: This widget does **not** automatically register list items. Your
/// `itemBuilder` still needs to wrap each trackable item with `ScrollSpyItem`
/// (or otherwise register items in the scope). Without registration the engine
/// will compute an empty focus state.
///
/// Use the named constructors [builder] and [separated] similarly to [ListView].
class ScrollSpyListView<T> extends StatefulWidget {
  /// Creates a focus-aware ListView wrapper.
  ///
  /// Use the [builder] or [separated] factories to mirror ListView APIs while
  /// wiring the focus scope and scroll controller automatically.
  const ScrollSpyListView._({
    super.key,
    required this.controller,
    required this.region,
    required this.policy,
    required this.stability,
    required this.updatePolicy,
    required this.viewportInsets,
    required this.insetsAffectVisibility,
    required this.scrollController,
    required this.notificationDepth,
    required this.notificationPredicate,
    required this.metricsNotificationPredicate,
    required this.debug,
    required this.debugConfig,
    required this.scrollDirection,
    required this.primary,
    required this.itemExtentBuilder,
    required this.hitTestBehavior,
    required _ScrollViewBuilder scrollableBuilder,
  }) : _scrollableBuilder = scrollableBuilder;

  final _ScrollViewBuilder _scrollableBuilder;

  /// Focus controller (NOT the ScrollController).
  final ScrollSpyController<T> controller;

  /// Focus region used by the scope.
  final ScrollSpyRegion region;

  /// Focus selection policy used by the scope.
  final ScrollSpyPolicy<T> policy;

  /// Stability configuration applied to primary selection.
  final ScrollSpyStability stability;

  /// Update cadence for engine compute passes.
  final ScrollSpyUpdatePolicy updatePolicy;

  /// Insets to deflate the viewport rect (e.g. for pinned headers).
  final EdgeInsets viewportInsets;

  /// If true (default), items completely covered by [viewportInsets] are considered not visible.
  final bool insetsAffectVisibility;

  /// Scroll controller for the underlying ListView.
  final ScrollController? scrollController;

  /// Filters scroll notifications by depth (default: 0).
  final int notificationDepth;

  /// Optional predicate to further filter scroll notifications.
  final bool Function(ScrollNotification notification)? notificationPredicate;

  /// Optional predicate to further filter scroll metrics notifications.
  final bool Function(ScrollMetricsNotification notification)?
      metricsNotificationPredicate;

  /// Whether to show the debug overlay.
  final bool debug;

  /// Optional debug overlay configuration.
  final ScrollSpyDebugConfig? debugConfig;

  /// Scroll direction for the underlying ListView.
  final Axis scrollDirection;

  /// Whether the ListView should use a PrimaryScrollController.
  final bool? primary;

  /// Optional item-extent builder passed to ListView.
  final ItemExtentBuilder? itemExtentBuilder;

  /// Hit test behavior for the underlying ListView.
  final HitTestBehavior hitTestBehavior;

  /// Equivalent to [ListView.builder] but wrapped in a [ScrollSpyScope].
  factory ScrollSpyListView.builder({
    Key? key,
    required ScrollSpyController<T> controller,
    required ScrollSpyRegion region,
    required ScrollSpyPolicy<T> policy,
    ScrollSpyStability stability = const ScrollSpyStability(),
    ScrollSpyUpdatePolicy updatePolicy = const ScrollSpyUpdatePolicy.perFrame(),
    EdgeInsets viewportInsets = EdgeInsets.zero,
    bool insetsAffectVisibility = true,
    ScrollController? scrollController,
    int notificationDepth = 0,
    bool Function(ScrollNotification notification)? notificationPredicate,
    bool Function(ScrollMetricsNotification notification)?
        metricsNotificationPredicate,
    bool debug = false,
    ScrollSpyDebugConfig? debugConfig,
    // ListView.builder params:
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    bool? primary,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
    double? itemExtent,
    ItemExtentBuilder? itemExtentBuilder,
    Widget? prototypeItem,
    required NullableIndexedWidgetBuilder itemBuilder,
    int? itemCount,
    double? cacheExtent,
    int? semanticChildCount,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    ScrollViewKeyboardDismissBehavior keyboardDismissBehavior =
        ScrollViewKeyboardDismissBehavior.manual,
    String? restorationId,
    Clip clipBehavior = Clip.hardEdge,
    HitTestBehavior hitTestBehavior = HitTestBehavior.opaque,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
    int? Function(Key)? findChildIndexCallback,
  }) {
    return ScrollSpyListView<T>._(
      key: key,
      controller: controller,
      region: region,
      policy: policy,
      stability: stability,
      updatePolicy: updatePolicy,
      viewportInsets: viewportInsets,
      insetsAffectVisibility: insetsAffectVisibility,
      scrollController: scrollController,
      notificationDepth: notificationDepth,
      notificationPredicate: notificationPredicate,
      metricsNotificationPredicate: metricsNotificationPredicate,
      debug: debug,
      debugConfig: debugConfig,
      scrollDirection: scrollDirection,
      primary: primary,
      itemExtentBuilder: itemExtentBuilder,
      hitTestBehavior: hitTestBehavior,
      scrollableBuilder: ({ScrollController? controller, bool? primary}) {
        return ListView.builder(
          controller: controller,
          scrollDirection: scrollDirection,
          reverse: reverse,
          primary: primary,
          physics: physics,
          shrinkWrap: shrinkWrap,
          padding: padding,
          itemExtent: itemExtent,
          itemExtentBuilder: itemExtentBuilder,
          prototypeItem: prototypeItem,
          itemBuilder: itemBuilder,
          itemCount: itemCount,
          cacheExtent: cacheExtent,
          semanticChildCount: semanticChildCount,
          dragStartBehavior: dragStartBehavior,
          keyboardDismissBehavior: keyboardDismissBehavior,
          restorationId: restorationId,
          clipBehavior: clipBehavior,
          hitTestBehavior: hitTestBehavior,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          addSemanticIndexes: addSemanticIndexes,
          findChildIndexCallback: findChildIndexCallback,
        );
      },
    );
  }

  /// Equivalent to [ListView.separated] but wrapped in a [ScrollSpyScope].
  factory ScrollSpyListView.separated({
    Key? key,
    required ScrollSpyController<T> controller,
    required ScrollSpyRegion region,
    required ScrollSpyPolicy<T> policy,
    ScrollSpyStability stability = const ScrollSpyStability(),
    ScrollSpyUpdatePolicy updatePolicy = const ScrollSpyUpdatePolicy.perFrame(),
    EdgeInsets viewportInsets = EdgeInsets.zero,
    bool insetsAffectVisibility = true,
    ScrollController? scrollController,
    int notificationDepth = 0,
    bool Function(ScrollNotification notification)? notificationPredicate,
    bool Function(ScrollMetricsNotification notification)?
        metricsNotificationPredicate,
    bool debug = false,
    ScrollSpyDebugConfig? debugConfig,
    // ListView.separated params:
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    bool? primary,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
    required NullableIndexedWidgetBuilder itemBuilder,
    required IndexedWidgetBuilder separatorBuilder,
    required int itemCount,
    double? cacheExtent,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    ScrollViewKeyboardDismissBehavior keyboardDismissBehavior =
        ScrollViewKeyboardDismissBehavior.manual,
    String? restorationId,
    Clip clipBehavior = Clip.hardEdge,
    HitTestBehavior hitTestBehavior = HitTestBehavior.opaque,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
    int? Function(Key)? findChildIndexCallback,
  }) {
    return ScrollSpyListView<T>._(
      key: key,
      controller: controller,
      region: region,
      policy: policy,
      stability: stability,
      updatePolicy: updatePolicy,
      viewportInsets: viewportInsets,
      insetsAffectVisibility: insetsAffectVisibility,
      scrollController: scrollController,
      notificationDepth: notificationDepth,
      notificationPredicate: notificationPredicate,
      metricsNotificationPredicate: metricsNotificationPredicate,
      debug: debug,
      debugConfig: debugConfig,
      scrollDirection: scrollDirection,
      primary: primary,
      itemExtentBuilder: null,
      hitTestBehavior: hitTestBehavior,
      scrollableBuilder: ({ScrollController? controller, bool? primary}) {
        return ListView.separated(
          controller: controller,
          scrollDirection: scrollDirection,
          reverse: reverse,
          primary: primary,
          physics: physics,
          shrinkWrap: shrinkWrap,
          padding: padding,
          itemBuilder: itemBuilder,
          separatorBuilder: separatorBuilder,
          itemCount: itemCount,
          cacheExtent: cacheExtent,
          dragStartBehavior: dragStartBehavior,
          keyboardDismissBehavior: keyboardDismissBehavior,
          restorationId: restorationId,
          clipBehavior: clipBehavior,
          hitTestBehavior: hitTestBehavior,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          addSemanticIndexes: addSemanticIndexes,
          findChildIndexCallback: findChildIndexCallback,
        );
      },
    );
  }

  @override
  State<ScrollSpyListView<T>> createState() => _ScrollSpyListViewState<T>();
}

class _ScrollSpyListViewState<T> extends State<ScrollSpyListView<T>> {
  ScrollController? _internalController;

  ScrollController _ensureInternalController() =>
      _internalController ??= ScrollController();

  @override
  void didUpdateWidget(covariant ScrollSpyListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the user provides a controller, we must not own an internal one.
    if (widget.scrollController != null) {
      _internalController?.dispose();
      _internalController = null;
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    _internalController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController? primaryController = PrimaryScrollController.maybeOf(
      context,
    );

    final bool scrollViewWantsPrimary =
        widget.primary ?? (widget.scrollDirection == Axis.vertical);

    final bool usesExternalPrimaryController =
        widget.scrollController == null &&
            scrollViewWantsPrimary &&
            primaryController != null;

    final ScrollController effectiveEngineController =
        usesExternalPrimaryController
            ? primaryController
            : (widget.scrollController ?? _ensureInternalController());

    final bool shouldWrapWithPrimary = widget.scrollController == null &&
        scrollViewWantsPrimary &&
        primaryController == null;

    final ScrollController? scrollableController = shouldWrapWithPrimary
        ? null
        : (usesExternalPrimaryController ? null : effectiveEngineController);

    final bool? scrollablePrimary =
        shouldWrapWithPrimary ? (widget.primary ?? true) : widget.primary;

    Widget scrollable = widget._scrollableBuilder(
      controller: scrollableController,
      primary: scrollablePrimary,
    );

    if (shouldWrapWithPrimary) {
      scrollable = PrimaryScrollController(
        controller: effectiveEngineController,
        child: scrollable,
      );
    }

    return ScrollSpyScope<T>(
      controller: widget.controller,
      region: widget.region,
      policy: widget.policy,
      stability: widget.stability,
      updatePolicy: widget.updatePolicy,
      viewportInsets: widget.viewportInsets,
      insetsAffectVisibility: widget.insetsAffectVisibility,
      scrollController: effectiveEngineController,
      notificationDepth: widget.notificationDepth,
      notificationPredicate: widget.notificationPredicate,
      metricsNotificationPredicate: widget.metricsNotificationPredicate,
      debug: widget.debug,
      debugConfig: widget.debugConfig,
      child: scrollable,
    );
  }
}

/// A convenience widget that combines a [ScrollSpyScope] with a [GridView].
///
/// This is the grid equivalent of [ScrollSpyListView] and exists primarily
/// to:
/// - forward focus configuration into a scope, and
/// - ensure the focus engine listens to the same effective scroll controller as
///   the underlying grid (including `PrimaryScrollController` adoption).
///
/// As with all scopes, you must still register items (typically via
/// `ScrollSpyItem`) inside your grid’s `itemBuilder`.
class ScrollSpyGridView<T> extends StatefulWidget {
  /// Creates a focus-aware GridView wrapper.
  ///
  /// Use the [builder] factory to mirror GridView APIs while wiring the focus
  /// scope and scroll controller automatically.
  const ScrollSpyGridView._({
    super.key,
    required this.controller,
    required this.region,
    required this.policy,
    required this.stability,
    required this.updatePolicy,
    required this.viewportInsets,
    required this.insetsAffectVisibility,
    required this.scrollController,
    required this.notificationDepth,
    required this.notificationPredicate,
    required this.metricsNotificationPredicate,
    required this.debug,
    required this.debugConfig,
    required this.scrollDirection,
    required this.primary,
    required this.hitTestBehavior,
    required _ScrollViewBuilder scrollableBuilder,
  }) : _scrollableBuilder = scrollableBuilder;

  final _ScrollViewBuilder _scrollableBuilder;

  /// Focus controller (NOT the ScrollController).
  final ScrollSpyController<T> controller;

  /// Focus region used by the scope.
  final ScrollSpyRegion region;

  /// Focus selection policy used by the scope.
  final ScrollSpyPolicy<T> policy;

  /// Stability configuration applied to primary selection.
  final ScrollSpyStability stability;

  /// Update cadence for engine compute passes.
  final ScrollSpyUpdatePolicy updatePolicy;

  /// Insets to deflate the viewport rect (e.g. for pinned headers).
  final EdgeInsets viewportInsets;

  /// If true (default), items completely covered by [viewportInsets] are considered not visible.
  final bool insetsAffectVisibility;

  /// Scroll controller for the underlying GridView.
  final ScrollController? scrollController;

  /// Filters scroll notifications by depth (default: 0).
  final int notificationDepth;

  /// Optional predicate to further filter scroll notifications.
  final bool Function(ScrollNotification notification)? notificationPredicate;

  /// Optional predicate to further filter scroll metrics notifications.
  final bool Function(ScrollMetricsNotification notification)?
      metricsNotificationPredicate;

  /// Whether to show the debug overlay.
  final bool debug;

  /// Optional debug overlay configuration.
  final ScrollSpyDebugConfig? debugConfig;

  /// Scroll direction for the underlying GridView.
  final Axis scrollDirection;

  /// Whether the GridView should use a PrimaryScrollController.
  final bool? primary;

  /// Hit test behavior for the underlying GridView.
  final HitTestBehavior hitTestBehavior;

  /// Equivalent to [GridView.builder] but wrapped in a [ScrollSpyScope].
  factory ScrollSpyGridView.builder({
    Key? key,
    required ScrollSpyController<T> controller,
    required ScrollSpyRegion region,
    required ScrollSpyPolicy<T> policy,
    ScrollSpyStability stability = const ScrollSpyStability(),
    ScrollSpyUpdatePolicy updatePolicy = const ScrollSpyUpdatePolicy.perFrame(),
    EdgeInsets viewportInsets = EdgeInsets.zero,
    bool insetsAffectVisibility = true,
    ScrollController? scrollController,
    int notificationDepth = 0,
    bool Function(ScrollNotification notification)? notificationPredicate,
    bool Function(ScrollMetricsNotification notification)?
        metricsNotificationPredicate,
    bool debug = false,
    ScrollSpyDebugConfig? debugConfig,
    // GridView.builder params:
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    bool? primary,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
    required SliverGridDelegate gridDelegate,
    required NullableIndexedWidgetBuilder itemBuilder,
    int? itemCount,
    double? cacheExtent,
    int? semanticChildCount,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    ScrollViewKeyboardDismissBehavior keyboardDismissBehavior =
        ScrollViewKeyboardDismissBehavior.manual,
    String? restorationId,
    Clip clipBehavior = Clip.hardEdge,
    HitTestBehavior hitTestBehavior = HitTestBehavior.opaque,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
    int? Function(Key)? findChildIndexCallback,
  }) {
    return ScrollSpyGridView<T>._(
      key: key,
      controller: controller,
      region: region,
      policy: policy,
      stability: stability,
      updatePolicy: updatePolicy,
      viewportInsets: viewportInsets,
      insetsAffectVisibility: insetsAffectVisibility,
      scrollController: scrollController,
      notificationDepth: notificationDepth,
      notificationPredicate: notificationPredicate,
      metricsNotificationPredicate: metricsNotificationPredicate,
      debug: debug,
      debugConfig: debugConfig,
      scrollDirection: scrollDirection,
      primary: primary,
      hitTestBehavior: hitTestBehavior,
      scrollableBuilder: ({ScrollController? controller, bool? primary}) {
        return GridView.builder(
          controller: controller,
          scrollDirection: scrollDirection,
          reverse: reverse,
          primary: primary,
          physics: physics,
          shrinkWrap: shrinkWrap,
          padding: padding,
          gridDelegate: gridDelegate,
          itemBuilder: itemBuilder,
          itemCount: itemCount,
          cacheExtent: cacheExtent,
          semanticChildCount: semanticChildCount,
          dragStartBehavior: dragStartBehavior,
          keyboardDismissBehavior: keyboardDismissBehavior,
          restorationId: restorationId,
          clipBehavior: clipBehavior,
          hitTestBehavior: hitTestBehavior,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          addSemanticIndexes: addSemanticIndexes,
          findChildIndexCallback: findChildIndexCallback,
        );
      },
    );
  }

  @override
  State<ScrollSpyGridView<T>> createState() => _ScrollSpyGridViewState<T>();
}

class _ScrollSpyGridViewState<T> extends State<ScrollSpyGridView<T>> {
  ScrollController? _internalController;

  ScrollController _ensureInternalController() =>
      _internalController ??= ScrollController();

  @override
  void didUpdateWidget(covariant ScrollSpyGridView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the user provides a controller, we must not own an internal one.
    if (widget.scrollController != null) {
      _internalController?.dispose();
      _internalController = null;
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    _internalController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController? primaryController = PrimaryScrollController.maybeOf(
      context,
    );

    final bool scrollViewWantsPrimary =
        widget.primary ?? (widget.scrollDirection == Axis.vertical);

    final bool usesExternalPrimaryController =
        widget.scrollController == null &&
            scrollViewWantsPrimary &&
            primaryController != null;

    final ScrollController effectiveEngineController =
        usesExternalPrimaryController
            ? primaryController
            : (widget.scrollController ?? _ensureInternalController());

    final bool shouldWrapWithPrimary = widget.scrollController == null &&
        scrollViewWantsPrimary &&
        primaryController == null;

    final ScrollController? scrollableController = shouldWrapWithPrimary
        ? null
        : (usesExternalPrimaryController ? null : effectiveEngineController);

    final bool? scrollablePrimary =
        shouldWrapWithPrimary ? (widget.primary ?? true) : widget.primary;

    Widget scrollable = widget._scrollableBuilder(
      controller: scrollableController,
      primary: scrollablePrimary,
    );

    if (shouldWrapWithPrimary) {
      scrollable = PrimaryScrollController(
        controller: effectiveEngineController,
        child: scrollable,
      );
    }

    return ScrollSpyScope<T>(
      controller: widget.controller,
      region: widget.region,
      policy: widget.policy,
      stability: widget.stability,
      updatePolicy: widget.updatePolicy,
      viewportInsets: widget.viewportInsets,
      insetsAffectVisibility: widget.insetsAffectVisibility,
      scrollController: effectiveEngineController,
      notificationDepth: widget.notificationDepth,
      notificationPredicate: widget.notificationPredicate,
      metricsNotificationPredicate: widget.metricsNotificationPredicate,
      debug: widget.debug,
      debugConfig: widget.debugConfig,
      child: scrollable,
    );
  }
}

/// Wraps a [CustomScrollView] with a [ScrollSpyScope].
///
/// Use this for sliver-based layouts when you want the same focus behavior as a
/// list/grid, but you need fine control over slivers.
///
/// Item registration is still explicit: sliver children that should participate
/// in focus computation must be wrapped with `ScrollSpyItem`.
class ScrollSpyCustomScrollView<T> extends StatefulWidget {
  /// Creates a focus-aware CustomScrollView wrapper.
  ///
  /// This forwards focus configuration to a scope while preserving full sliver
  /// control via [slivers].
  const ScrollSpyCustomScrollView({
    super.key,
    required this.controller,
    required this.region,
    required this.policy,
    this.stability = const ScrollSpyStability(),
    this.updatePolicy = const ScrollSpyUpdatePolicy.perFrame(),
    this.viewportInsets = EdgeInsets.zero,
    this.insetsAffectVisibility = true,
    this.scrollController,
    this.notificationDepth = 0,
    this.notificationPredicate,
    this.metricsNotificationPredicate,
    this.debug = false,
    this.debugConfig,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.primary,
    this.physics,
    this.scrollBehavior,
    this.shrinkWrap = false,
    this.center,
    this.anchor = 0.0,
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.paintOrder = SliverPaintOrder.firstIsTop,
    required this.slivers,
  });

  /// Focus controller (NOT the ScrollController).
  final ScrollSpyController<T> controller;

  /// Focus region used by the scope.
  final ScrollSpyRegion region;

  /// Focus selection policy used by the scope.
  final ScrollSpyPolicy<T> policy;

  /// Stability configuration applied to primary selection.
  final ScrollSpyStability stability;

  /// Update cadence for engine compute passes.
  final ScrollSpyUpdatePolicy updatePolicy;

  /// Insets to deflate the viewport rect (e.g. for pinned headers).
  final EdgeInsets viewportInsets;

  /// If true (default), items completely covered by [viewportInsets] are considered not visible.
  final bool insetsAffectVisibility;

  /// Optional scroll controller for the CustomScrollView.
  final ScrollController? scrollController;

  /// Filters scroll notifications by depth (default: 0).
  final int notificationDepth;

  /// Optional predicate to further filter scroll notifications.
  final bool Function(ScrollNotification notification)? notificationPredicate;

  /// Optional predicate to further filter scroll metrics notifications.
  final bool Function(ScrollMetricsNotification notification)?
      metricsNotificationPredicate;

  /// Whether to show the debug overlay.
  final bool debug;

  /// Optional debug overlay configuration.
  final ScrollSpyDebugConfig? debugConfig;

  // CustomScrollView params:
  /// Scroll direction for the underlying CustomScrollView.
  final Axis scrollDirection;

  /// Whether to reverse the scroll view.
  final bool reverse;

  /// Whether the CustomScrollView should use a PrimaryScrollController.
  final bool? primary;

  /// Scroll physics for the CustomScrollView.
  final ScrollPhysics? physics;

  /// Scroll behavior for the CustomScrollView.
  final ScrollBehavior? scrollBehavior;

  /// Whether the CustomScrollView should shrink-wrap its contents.
  final bool shrinkWrap;

  /// Center sliver key for the CustomScrollView.
  final Key? center;

  /// The anchor point for the CustomScrollView.
  final double anchor;

  /// Cache extent for the CustomScrollView.
  final double? cacheExtent;

  /// Semantic child count for the CustomScrollView.
  final int? semanticChildCount;

  /// Drag start behavior for the CustomScrollView.
  final DragStartBehavior dragStartBehavior;

  /// Keyboard dismiss behavior for the CustomScrollView.
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// Restoration ID for the CustomScrollView.
  final String? restorationId;

  /// Clip behavior for the CustomScrollView.
  final Clip clipBehavior;

  /// Hit test behavior for the CustomScrollView.
  final HitTestBehavior hitTestBehavior;

  /// Paint order for slivers in the CustomScrollView.
  final SliverPaintOrder paintOrder;

  /// Slivers that make up the scrollable content.
  final List<Widget> slivers;

  @override
  State<ScrollSpyCustomScrollView<T>> createState() =>
      _ScrollSpyCustomScrollViewState<T>();
}

class _ScrollSpyCustomScrollViewState<T>
    extends State<ScrollSpyCustomScrollView<T>> {
  ScrollController? _internalController;

  ScrollController _ensureInternalController() =>
      _internalController ??= ScrollController();

  @override
  void didUpdateWidget(covariant ScrollSpyCustomScrollView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.scrollController != null) {
      _internalController?.dispose();
      _internalController = null;
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    _internalController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController? primaryController = PrimaryScrollController.maybeOf(
      context,
    );

    final bool scrollViewWantsPrimary =
        widget.primary ?? (widget.scrollDirection == Axis.vertical);

    final bool usesExternalPrimaryController =
        widget.scrollController == null &&
            scrollViewWantsPrimary &&
            primaryController != null;

    final ScrollController effectiveEngineController =
        usesExternalPrimaryController
            ? primaryController
            : (widget.scrollController ?? _ensureInternalController());

    final bool shouldWrapWithPrimary = widget.scrollController == null &&
        scrollViewWantsPrimary &&
        primaryController == null;

    final ScrollController? scrollableController = shouldWrapWithPrimary
        ? null
        : (usesExternalPrimaryController ? null : effectiveEngineController);

    final bool? scrollablePrimary =
        shouldWrapWithPrimary ? (widget.primary ?? true) : widget.primary;

    Widget scrollable = CustomScrollView(
      controller: scrollableController,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      primary: scrollablePrimary,
      physics: widget.physics,
      scrollBehavior: widget.scrollBehavior,
      shrinkWrap: widget.shrinkWrap,
      center: widget.center,
      anchor: widget.anchor,
      cacheExtent: widget.cacheExtent,
      semanticChildCount: widget.semanticChildCount,
      dragStartBehavior: widget.dragStartBehavior,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      restorationId: widget.restorationId,
      clipBehavior: widget.clipBehavior,
      hitTestBehavior: widget.hitTestBehavior,
      paintOrder: widget.paintOrder,
      slivers: widget.slivers,
    );

    if (shouldWrapWithPrimary) {
      scrollable = PrimaryScrollController(
        controller: effectiveEngineController,
        child: scrollable,
      );
    }

    return ScrollSpyScope<T>(
      controller: widget.controller,
      region: widget.region,
      policy: widget.policy,
      stability: widget.stability,
      updatePolicy: widget.updatePolicy,
      viewportInsets: widget.viewportInsets,
      insetsAffectVisibility: widget.insetsAffectVisibility,
      scrollController: effectiveEngineController,
      notificationDepth: widget.notificationDepth,
      notificationPredicate: widget.notificationPredicate,
      metricsNotificationPredicate: widget.metricsNotificationPredicate,
      debug: widget.debug,
      debugConfig: widget.debugConfig,
      child: scrollable,
    );
  }
}

/// Wraps a [PageView.builder] with a [ScrollSpyScope].
///
/// This is useful for paged carousels where you want to know which page is
/// "primary" (or within a focus zone) as the user swipes.
///
/// The engine listens to the effective [PageController] (a [ScrollController])
/// so programmatic page changes are also detected.
///
/// Pages that should participate in focus computation must still be wrapped with
/// `ScrollSpyItem`.
class ScrollSpyPageView<T> extends StatefulWidget {
  /// Creates a focus-aware PageView wrapper.
  ///
  /// Use the [builder] factory to mirror PageView APIs while wiring the focus
  /// scope and page controller automatically.
  const ScrollSpyPageView._({
    super.key,
    required this.controller,
    required this.region,
    required this.policy,
    required this.stability,
    required this.updatePolicy,
    required this.viewportInsets,
    required this.insetsAffectVisibility,
    required this.pageController,
    required this.notificationDepth,
    required this.notificationPredicate,
    required this.metricsNotificationPredicate,
    required this.debug,
    required this.debugConfig,
    required this.scrollDirection,
    required this.reverse,
    required this.physics,
    required this.pageSnapping,
    required this.onPageChanged,
    required this.dragStartBehavior,
    required this.allowImplicitScrolling,
    required this.restorationId,
    required this.clipBehavior,
    required this.hitTestBehavior,
    required this.scrollBehavior,
    required this.padEnds,
    required this.itemBuilder,
    required this.itemCount,
    required this.findChildIndexCallback,
    required this.viewportFraction,
    required this.keepPage,
    required this.initialPage,
  });

  /// Focus controller (NOT the ScrollController).
  final ScrollSpyController<T> controller;

  /// Focus region used by the scope.
  final ScrollSpyRegion region;

  /// Focus selection policy used by the scope.
  final ScrollSpyPolicy<T> policy;

  /// Stability configuration applied to primary selection.
  final ScrollSpyStability stability;

  /// Update cadence for engine compute passes.
  final ScrollSpyUpdatePolicy updatePolicy;

  /// Insets to deflate the viewport rect (e.g. for pinned headers).
  final EdgeInsets viewportInsets;

  /// If true (default), items completely covered by [viewportInsets] are considered not visible.
  final bool insetsAffectVisibility;

  /// Optional external [PageController].
  ///
  /// If null, this widget will create and own an internal controller.
  final PageController? pageController;

  /// Filters scroll notifications by depth (default: 0).
  final int notificationDepth;

  /// Optional predicate to further filter scroll notifications.
  final bool Function(ScrollNotification notification)? notificationPredicate;

  /// Optional predicate to further filter scroll metrics notifications.
  final bool Function(ScrollMetricsNotification notification)?
      metricsNotificationPredicate;

  /// Whether to show the debug overlay.
  final bool debug;

  /// Optional debug overlay configuration.
  final ScrollSpyDebugConfig? debugConfig;

  // PageView.builder params:
  /// Scroll direction for the underlying PageView.
  final Axis scrollDirection;

  /// Whether to reverse the PageView.
  final bool reverse;

  /// Scroll physics for the PageView.
  final ScrollPhysics? physics;

  /// Whether the PageView snaps to page boundaries.
  final bool pageSnapping;

  /// Callback invoked when the PageView changes pages.
  final void Function(int)? onPageChanged;

  /// Drag start behavior for the PageView.
  final DragStartBehavior dragStartBehavior;

  /// Whether to allow implicit scrolling.
  final bool allowImplicitScrolling;

  /// Restoration ID for the PageView.
  final String? restorationId;

  /// Clip behavior for the PageView.
  final Clip clipBehavior;

  /// Hit test behavior for the PageView.
  final HitTestBehavior hitTestBehavior;

  /// Scroll behavior for the PageView.
  final ScrollBehavior? scrollBehavior;

  /// Whether to add padding at the ends of the PageView.
  final bool padEnds;

  /// Item builder for pages.
  final IndexedWidgetBuilder itemBuilder;

  /// Number of pages.
  final int? itemCount;

  /// Callback to map keys to indices for keep-alive behavior.
  final int? Function(Key)? findChildIndexCallback;

  /// Used only when [pageController] is null.
  final double viewportFraction;

  /// Used only when [pageController] is null.
  final bool keepPage;

  /// Used only when [pageController] is null.
  final int initialPage;

  /// Equivalent to [PageView.builder] but wrapped in a [ScrollSpyScope].
  factory ScrollSpyPageView.builder({
    Key? key,
    required ScrollSpyController<T> controller,
    required ScrollSpyRegion region,
    required ScrollSpyPolicy<T> policy,
    ScrollSpyStability stability = const ScrollSpyStability(),
    ScrollSpyUpdatePolicy updatePolicy = const ScrollSpyUpdatePolicy.perFrame(),
    EdgeInsets viewportInsets = EdgeInsets.zero,
    bool insetsAffectVisibility = true,
    PageController? pageController,
    int notificationDepth = 0,
    bool Function(ScrollNotification notification)? notificationPredicate,
    bool Function(ScrollMetricsNotification notification)?
        metricsNotificationPredicate,
    bool debug = false,
    ScrollSpyDebugConfig? debugConfig,
    // PageView.builder params:
    Axis scrollDirection = Axis.horizontal,
    bool reverse = false,
    ScrollPhysics? physics,
    bool pageSnapping = true,
    void Function(int)? onPageChanged,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    bool allowImplicitScrolling = false,
    String? restorationId,
    Clip clipBehavior = Clip.hardEdge,
    HitTestBehavior hitTestBehavior = HitTestBehavior.opaque,
    ScrollBehavior? scrollBehavior,
    bool padEnds = true,
    required IndexedWidgetBuilder itemBuilder,
    int? Function(Key)? findChildIndexCallback,
    int? itemCount,
    double viewportFraction = 1.0,
    bool keepPage = true,
    int initialPage = 0,
  }) {
    return ScrollSpyPageView<T>._(
      key: key,
      controller: controller,
      region: region,
      policy: policy,
      stability: stability,
      updatePolicy: updatePolicy,
      viewportInsets: viewportInsets,
      insetsAffectVisibility: insetsAffectVisibility,
      pageController: pageController,
      notificationDepth: notificationDepth,
      notificationPredicate: notificationPredicate,
      metricsNotificationPredicate: metricsNotificationPredicate,
      debug: debug,
      debugConfig: debugConfig,
      scrollDirection: scrollDirection,
      reverse: reverse,
      physics: physics,
      pageSnapping: pageSnapping,
      onPageChanged: onPageChanged,
      dragStartBehavior: dragStartBehavior,
      allowImplicitScrolling: allowImplicitScrolling,
      restorationId: restorationId,
      clipBehavior: clipBehavior,
      hitTestBehavior: hitTestBehavior,
      scrollBehavior: scrollBehavior,
      padEnds: padEnds,
      itemBuilder: itemBuilder,
      itemCount: itemCount,
      findChildIndexCallback: findChildIndexCallback,
      viewportFraction: viewportFraction,
      keepPage: keepPage,
      initialPage: initialPage,
    );
  }

  @override
  State<ScrollSpyPageView<T>> createState() => _ScrollSpyPageViewState<T>();
}

class _ScrollSpyPageViewState<T> extends State<ScrollSpyPageView<T>> {
  PageController? _internalController;

  @override
  void initState() {
    super.initState();
    if (widget.pageController == null) {
      _internalController = _createInternalController();
    }
  }

  @override
  void didUpdateWidget(covariant ScrollSpyPageView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the user provided a controller, we must not own an internal one.
    if (widget.pageController != null) {
      _internalController?.dispose();
      _internalController = null;
      return;
    }

    // We own the controller: create/recreate when required.
    final bool ownershipChanged =
        oldWidget.pageController != widget.pageController;
    final bool internalParamsChanged =
        oldWidget.initialPage != widget.initialPage ||
            oldWidget.keepPage != widget.keepPage ||
            oldWidget.viewportFraction != widget.viewportFraction;

    if (_internalController == null ||
        ownershipChanged ||
        internalParamsChanged) {
      _internalController?.dispose();
      _internalController = _createInternalController();
    }
  }

  PageController _createInternalController() {
    return PageController(
      initialPage: widget.initialPage,
      keepPage: widget.keepPage,
      viewportFraction: widget.viewportFraction,
    );
  }

  @override
  void dispose() {
    _internalController?.dispose();
    _internalController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PageController effectiveController = widget.pageController ??
        (_internalController ??= _createInternalController());

    final pv = PageView.builder(
      controller: effectiveController,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      physics: widget.physics,
      pageSnapping: widget.pageSnapping,
      onPageChanged: widget.onPageChanged,
      dragStartBehavior: widget.dragStartBehavior,
      allowImplicitScrolling: widget.allowImplicitScrolling,
      restorationId: widget.restorationId,
      clipBehavior: widget.clipBehavior,
      hitTestBehavior: widget.hitTestBehavior,
      scrollBehavior: widget.scrollBehavior,
      padEnds: widget.padEnds,
      findChildIndexCallback: widget.findChildIndexCallback,
      itemBuilder: widget.itemBuilder,
      itemCount: widget.itemCount,
    );

    return ScrollSpyScope<T>(
      controller: widget.controller,
      region: widget.region,
      policy: widget.policy,
      stability: widget.stability,
      updatePolicy: widget.updatePolicy,
      // PageController is a ScrollController; pass through for optional engine listening.
      scrollController: effectiveController,
      notificationDepth: widget.notificationDepth,
      notificationPredicate: widget.notificationPredicate,
      debug: widget.debug,
      debugConfig: widget.debugConfig,
      viewportInsets: widget.viewportInsets,
      insetsAffectVisibility: widget.insetsAffectVisibility,
      metricsNotificationPredicate: widget.metricsNotificationPredicate,
      child: pv,
    );
  }
}
