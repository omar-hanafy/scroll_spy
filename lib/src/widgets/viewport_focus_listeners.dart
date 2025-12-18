import 'package:flutter/widgets.dart';

import 'package:viewport_focus/src/public/viewport_focus_controller.dart';
import 'package:viewport_focus/src/public/viewport_focus_models.dart';
import 'package:viewport_focus/src/widgets/viewport_focus_scope.dart';

/// Builder signature for reacting to primary ID changes.
///
/// Used by [ViewportPrimaryBuilder]. The builder is invoked whenever the
/// controller's `primaryId` listenable changes. The optional [child] is
/// forwarded from the widget’s `child` parameter so callers can avoid
/// rebuilding static subtrees.
typedef ViewportPrimaryWidgetBuilder<T> = Widget Function(
    BuildContext context, T? primaryId, Widget? child);

/// Builder signature for reacting to focused ID set changes.
///
/// Used by [ViewportFocusedIdsBuilder]. The builder is invoked whenever the
/// controller's `focusedIds` listenable changes. The optional [child] is
/// forwarded from the widget’s `child` parameter so callers can avoid
/// rebuilding static subtrees.
typedef ViewportFocusedIdsWidgetBuilder<T> = Widget Function(
    BuildContext context, Set<T> focusedIds, Widget? child);

/// Builder signature for reacting to full snapshot changes.
///
/// Used by [ViewportSnapshotBuilder]. This is the most data-rich (and most
/// frequently updating) builder, and it triggers on every new snapshot the
/// engine publishes.
typedef ViewportSnapshotWidgetBuilder<T> = Widget Function(
  BuildContext context,
  ViewportFocusSnapshot<T> snapshot,
  Widget? child,
);

/// Builder signature for reacting to a single item’s focus changes.
///
/// Used by [ViewportItemFocusBuilder]. The builder is invoked whenever the
/// controller's per-item listenable changes for that ID. The optional [child]
/// is forwarded from the widget’s `child` parameter so callers can avoid
/// rebuilding static subtrees.
typedef ViewportItemFocusWidgetBuilder<T> = Widget Function(
  BuildContext context,
  ViewportItemFocus<T> itemFocus,
  Widget? child,
);

ViewportFocusController<T> _resolveController<T>(
  BuildContext context, {
  ViewportFocusController<T>? controller,
}) {
  final resolved =
      controller ?? ViewportFocusScope.maybeOf<T>(context)?.controller;
  if (resolved == null) {
    throw FlutterError(
      'ViewportFocusController<$T> not found.\n'
      'Provide a controller explicitly or wrap your subtree with ViewportFocusScope<$T>.',
    );
  }
  return resolved;
}

/// A convenience widget that rebuilds only when the **primary item ID**
/// changes.
///
/// Use this when you want to update a UI element that depends on *which* item
/// is currently the winner (e.g., a "Now Playing" bar at the bottom of the
/// screen).
class ViewportPrimaryBuilder<T> extends StatelessWidget {
  /// Creates a builder that rebuilds on primary ID changes.
  const ViewportPrimaryBuilder({
    super.key,
    this.controller,
    this.child,
    required this.builder,
  });

  /// The controller to listen to. If null, it looks up the nearest [ViewportFocusScope].
  final ViewportFocusController<T>? controller;

  /// Optional subtree that does not depend on the listenable value.
  final Widget? child;

  /// Called when the primary ID value changes.
  final ViewportPrimaryWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    final ctrl = _resolveController<T>(context, controller: controller);
    return ValueListenableBuilder<T?>(
      valueListenable: ctrl.primaryId,
      builder: (context, primaryId, _) => builder(context, primaryId, child),
    );
  }
}

/// A non-rebuilding widget that triggers a callback when the **primary item
/// ID** changes.
///
/// Use this for side effects, such as logging analytics, haptic feedback, or
/// triggering navigation, without needing to rebuild a widget subtree. The
/// callback is invoked only when the ID actually changes (no initial call).
class ViewportPrimaryListener<T> extends StatefulWidget {
  /// Creates a listener that reacts to primary ID changes without rebuilding.
  const ViewportPrimaryListener({
    super.key,
    this.controller,
    required this.onChanged,
    required this.child,
  });

  /// The controller to observe. If null, resolves from the nearest
  /// [ViewportFocusScope].
  final ViewportFocusController<T>? controller;

  /// Called with the previous and current primary IDs whenever the primary item changes.
  final void Function(T? previous, T? current) onChanged;

  /// Subtree that is not rebuilt by this listener.
  final Widget child;

  @override
  State<ViewportPrimaryListener<T>> createState() =>
      _ViewportPrimaryListenerState<T>();
}

class _ViewportPrimaryListenerState<T>
    extends State<ViewportPrimaryListener<T>> {
  ViewportFocusController<T>? _controller;
  T? _last;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
  }

  @override
  void didUpdateWidget(ViewportPrimaryListener<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    _syncController();
  }

  void _syncController() {
    final resolved = _resolveController<T>(
      context,
      controller: widget.controller,
    );
    if (identical(resolved, _controller)) return;

    _controller?.primaryId.removeListener(_handle);
    _controller = resolved;
    _last = resolved.primaryId.value;
    resolved.primaryId.addListener(_handle);
  }

  void _handle() {
    final ctrl = _controller;
    if (ctrl == null) return;

    final current = ctrl.primaryId.value;
    final previous = _last;
    if (previous != current) {
      _last = current;
      widget.onChanged(previous, current);
    }
  }

  @override
  void dispose() {
    _controller?.primaryId.removeListener(_handle);
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Rebuilds when the focused ids set changes.
///
/// If [controller] is omitted, it is resolved from [ViewportFocusScope] above.
class ViewportFocusedIdsBuilder<T> extends StatelessWidget {
  /// Creates a builder that rebuilds when the focused ID set changes.
  const ViewportFocusedIdsBuilder({
    super.key,
    this.controller,
    this.child,
    required this.builder,
  });

  /// The controller to listen to. If null, it looks up the nearest
  /// [ViewportFocusScope].
  final ViewportFocusController<T>? controller;

  /// Optional subtree that does not depend on the listenable value.
  final Widget? child;

  /// Called when the focused ID set value changes.
  final ViewportFocusedIdsWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    final ctrl = _resolveController<T>(context, controller: controller);
    return ValueListenableBuilder<Set<T>>(
      valueListenable: ctrl.focusedIds,
      builder: (context, focused, _) => builder(context, focused, child),
    );
  }
}

/// Rebuilds when the snapshot changes.
///
/// If [controller] is omitted, it is resolved from [ViewportFocusScope] above.
class ViewportSnapshotBuilder<T> extends StatelessWidget {
  /// Creates a builder that rebuilds on every snapshot update.
  const ViewportSnapshotBuilder({
    super.key,
    this.controller,
    this.child,
    required this.builder,
  });

  /// The controller to listen to. If null, it looks up the nearest
  /// [ViewportFocusScope].
  final ViewportFocusController<T>? controller;

  /// Optional subtree that does not depend on the listenable value.
  final Widget? child;

  /// Called when the snapshot value changes.
  final ViewportSnapshotWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    final ctrl = _resolveController<T>(context, controller: controller);
    return ValueListenableBuilder<ViewportFocusSnapshot<T>>(
      valueListenable: ctrl.snapshot,
      builder: (context, snap, _) => builder(context, snap, child),
    );
  }
}

/// Rebuilds when a specific item's focus state changes.
///
/// If [controller] is omitted, it is resolved from [ViewportFocusScope] above.
class ViewportItemFocusBuilder<T> extends StatelessWidget {
  /// Creates a builder that rebuilds when a specific item's focus changes.
  const ViewportItemFocusBuilder({
    super.key,
    this.controller,
    required this.id,
    this.child,
    required this.builder,
  });

  /// The controller to listen to. If null, it looks up the nearest
  /// [ViewportFocusScope].
  final ViewportFocusController<T>? controller;

  /// The item ID to observe.
  final T id;

  /// Optional subtree that does not depend on the listenable value.
  final Widget? child;

  /// Called when the item focus value changes.
  final ViewportItemFocusWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    final ctrl = _resolveController<T>(context, controller: controller);
    return ValueListenableBuilder<ViewportItemFocus<T>>(
      valueListenable: ctrl.itemFocusOf(id),
      builder: (context, focus, _) => builder(context, focus, child),
    );
  }
}
