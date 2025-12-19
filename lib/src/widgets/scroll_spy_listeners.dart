import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:scroll_spy/src/public/scroll_spy_controller.dart';
import 'package:scroll_spy/src/public/scroll_spy_models.dart';
import 'package:scroll_spy/src/widgets/scroll_spy_scope.dart';

/// Builder signature for reacting to primary ID changes.
///
/// Used by [ScrollSpyPrimaryBuilder]. The builder is invoked whenever the
/// controller's `primaryId` listenable changes. The optional [child] is
/// forwarded from the widget’s `child` parameter so callers can avoid
/// rebuilding static subtrees.
typedef ScrollSpyPrimaryWidgetBuilder<T> = Widget Function(
    BuildContext context, T? primaryId, Widget? child);

/// Builder signature for reacting to focused ID set changes.
///
/// Used by [ScrollSpyFocusedIdsBuilder]. The builder is invoked whenever the
/// controller's `focusedIds` listenable changes. The optional [child] is
/// forwarded from the widget’s `child` parameter so callers can avoid
/// rebuilding static subtrees.
typedef ScrollSpyFocusedIdsWidgetBuilder<T> = Widget Function(
    BuildContext context, Set<T> focusedIds, Widget? child);

/// Builder signature for reacting to full snapshot changes.
///
/// Used by [ScrollSpySnapshotBuilder]. This is the most data-rich (and most
/// frequently updating) builder, and it triggers on every new snapshot the
/// engine publishes.
typedef ScrollSpySnapshotWidgetBuilder<T> = Widget Function(
  BuildContext context,
  ScrollSpySnapshot<T> snapshot,
  Widget? child,
);

/// Builder signature for reacting to a single item’s focus changes.
///
/// Used by [ScrollSpyItemFocusBuilder]. The builder is invoked whenever the
/// controller's per-item listenable changes for that ID. The optional [child]
/// is forwarded from the widget’s `child` parameter so callers can avoid
/// rebuilding static subtrees.
typedef ScrollSpyItemFocusWidgetBuilder<T> = Widget Function(
  BuildContext context,
  ScrollSpyItemFocus<T> itemFocus,
  Widget? child,
);

/// Builder signature for reacting to a boolean status change.
///
/// Used by [ScrollSpyItemPrimaryBuilder], [ScrollSpyItemFocusedBuilder],
/// and [ScrollSpyItemVisibleBuilder].
typedef ScrollSpyItemBoolWidgetBuilder<T> = Widget Function(
  BuildContext context,
  bool value,
  Widget? child,
);

ScrollSpyController<T> _resolveController<T>(
  BuildContext context, {
  ScrollSpyController<T>? controller,
}) {
  final resolved = controller ?? ScrollSpyScope.maybeOf<T>(context)?.controller;
  if (resolved == null) {
    throw FlutterError(
      'ScrollSpyController<$T> not found.\n'
      'Provide a controller explicitly or wrap your subtree with ScrollSpyScope<$T>.',
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
class ScrollSpyPrimaryBuilder<T> extends StatelessWidget {
  /// Creates a builder that rebuilds on primary ID changes.
  const ScrollSpyPrimaryBuilder({
    super.key,
    this.controller,
    this.child,
    required this.builder,
  });

  /// The controller to listen to. If null, it looks up the nearest [ScrollSpyScope].
  final ScrollSpyController<T>? controller;

  /// Optional subtree that does not depend on the listenable value.
  final Widget? child;

  /// Called when the primary ID value changes.
  final ScrollSpyPrimaryWidgetBuilder<T> builder;

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
class ScrollSpyPrimaryListener<T> extends StatefulWidget {
  /// Creates a listener that reacts to primary ID changes without rebuilding.
  const ScrollSpyPrimaryListener({
    super.key,
    this.controller,
    required this.onChanged,
    required this.child,
  });

  /// The controller to observe. If null, resolves from the nearest
  /// [ScrollSpyScope].
  final ScrollSpyController<T>? controller;

  /// Called with the previous and current primary IDs whenever the primary item changes.
  final void Function(T? previous, T? current) onChanged;

  /// Subtree that is not rebuilt by this listener.
  final Widget child;

  @override
  State<ScrollSpyPrimaryListener<T>> createState() =>
      _ScrollSpyPrimaryListenerState<T>();
}

class _ScrollSpyPrimaryListenerState<T>
    extends State<ScrollSpyPrimaryListener<T>> {
  ScrollSpyController<T>? _controller;
  T? _last;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
  }

  @override
  void didUpdateWidget(ScrollSpyPrimaryListener<T> oldWidget) {
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
/// If [controller] is omitted, it is resolved from [ScrollSpyScope] above.
class ScrollSpyFocusedIdsBuilder<T> extends StatelessWidget {
  /// Creates a builder that rebuilds when the focused ID set changes.
  const ScrollSpyFocusedIdsBuilder({
    super.key,
    this.controller,
    this.child,
    required this.builder,
  });

  /// The controller to listen to. If null, it looks up the nearest
  /// [ScrollSpyScope].
  final ScrollSpyController<T>? controller;

  /// Optional subtree that does not depend on the listenable value.
  final Widget? child;

  /// Called when the focused ID set value changes.
  final ScrollSpyFocusedIdsWidgetBuilder<T> builder;

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
/// If [controller] is omitted, it is resolved from [ScrollSpyScope] above.
class ScrollSpySnapshotBuilder<T> extends StatelessWidget {
  /// Creates a builder that rebuilds on every snapshot update.
  const ScrollSpySnapshotBuilder({
    super.key,
    this.controller,
    this.child,
    required this.builder,
  });

  /// The controller to listen to. If null, it looks up the nearest
  /// [ScrollSpyScope].
  final ScrollSpyController<T>? controller;

  /// Optional subtree that does not depend on the listenable value.
  final Widget? child;

  /// Called when the snapshot value changes.
  final ScrollSpySnapshotWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    final ctrl = _resolveController<T>(context, controller: controller);
    return ValueListenableBuilder<ScrollSpySnapshot<T>>(
      valueListenable: ctrl.snapshot,
      builder: (context, snap, _) => builder(context, snap, child),
    );
  }
}

/// Rebuilds when a specific item's focus state changes.
///
/// If [controller] is omitted, it is resolved from [ScrollSpyScope] above.
class ScrollSpyItemFocusBuilder<T> extends StatelessWidget {
  /// Creates a builder that rebuilds when a specific item's focus changes.
  const ScrollSpyItemFocusBuilder({
    super.key,
    this.controller,
    required this.id,
    this.child,
    required this.builder,
  });

  /// The controller to listen to. If null, it looks up the nearest
  /// [ScrollSpyScope].
  final ScrollSpyController<T>? controller;

  /// The item ID to observe.
  final T id;

  /// Optional subtree that does not depend on the listenable value.
  final Widget? child;

  /// Called when the item focus value changes.
  final ScrollSpyItemFocusWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    final ctrl = _resolveController<T>(context, controller: controller);
    return ValueListenableBuilder<ScrollSpyItemFocus<T>>(
      valueListenable: ctrl.itemFocusOf(id),
      builder: (context, focus, _) => builder(context, focus, child),
    );
  }
}

/// Rebuilds only when the **primary** status of [id] changes.
class ScrollSpyItemPrimaryBuilder<T> extends StatelessWidget {
  /// Creates a builder that rebuilds when [id] toggles primary status.
  const ScrollSpyItemPrimaryBuilder({
    super.key,
    this.controller,
    required this.id,
    this.child,
    required this.builder,
  });

  /// The controller to listen to. If null, resolves from the nearest [ScrollSpyScope].
  final ScrollSpyController<T>? controller;

  /// The item ID to observe.
  final T id;

  /// Optional subtree that does not depend on the boolean value.
  final Widget? child;

  /// Builder invoked when the primary status changes.
  final ScrollSpyItemBoolWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    final ctrl = _resolveController<T>(context, controller: controller);
    return ValueListenableBuilder<bool>(
      valueListenable: ctrl.itemIsPrimaryOf(id),
      builder: (context, v, _) => builder(context, v, child),
    );
  }
}

/// Rebuilds only when the **focused** status of [id] changes.
class ScrollSpyItemFocusedBuilder<T> extends StatelessWidget {
  /// Creates a builder that rebuilds when [id] toggles focused status.
  const ScrollSpyItemFocusedBuilder({
    super.key,
    this.controller,
    required this.id,
    this.child,
    required this.builder,
  });

  /// The controller to listen to. If null, resolves from the nearest [ScrollSpyScope].
  final ScrollSpyController<T>? controller;

  /// The item ID to observe.
  final T id;

  /// Optional subtree that does not depend on the boolean value.
  final Widget? child;

  /// Builder invoked when the focused status changes.
  final ScrollSpyItemBoolWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    final ctrl = _resolveController<T>(context, controller: controller);
    return ValueListenableBuilder<bool>(
      valueListenable: ctrl.itemIsFocusedOf(id),
      builder: (context, v, _) => builder(context, v, child),
    );
  }
}

/// Rebuilds only when the **visible** status of [id] changes.
class ScrollSpyItemVisibleBuilder<T> extends StatelessWidget {
  /// Creates a builder that rebuilds when [id] toggles visibility.
  const ScrollSpyItemVisibleBuilder({
    super.key,
    this.controller,
    required this.id,
    this.child,
    required this.builder,
  });

  /// The controller to listen to. If null, resolves from the nearest [ScrollSpyScope].
  final ScrollSpyController<T>? controller;

  /// The item ID to observe.
  final T id;

  /// Optional subtree that does not depend on the boolean value.
  final Widget? child;

  /// Builder invoked when the visible status changes.
  final ScrollSpyItemBoolWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    final ctrl = _resolveController<T>(context, controller: controller);
    return ValueListenableBuilder<bool>(
      valueListenable: ctrl.itemIsVisibleOf(id),
      builder: (context, v, _) => builder(context, v, child),
    );
  }
}

/// Triggers a callback when the **primary** status of [id] changes (no rebuild).
class ScrollSpyItemPrimaryListener<T> extends StatefulWidget {
  /// Creates a listener that reacts to primary status changes for [id].
  const ScrollSpyItemPrimaryListener({
    super.key,
    this.controller,
    required this.id,
    required this.onChanged,
    required this.child,
  });

  /// The controller to observe. If null, resolves from the nearest [ScrollSpyScope].
  final ScrollSpyController<T>? controller;

  /// The item ID to observe.
  final T id;

  /// Called with the previous and current values when the status toggles.
  final void Function(bool previous, bool current) onChanged;

  /// Subtree that is not rebuilt by this listener.
  final Widget child;

  @override
  State<ScrollSpyItemPrimaryListener<T>> createState() =>
      _ScrollSpyItemPrimaryListenerState<T>();
}

class _ScrollSpyItemPrimaryListenerState<T>
    extends State<ScrollSpyItemPrimaryListener<T>> {
  ValueListenable<bool>? _listenable;
  bool _last = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ScrollSpyItemPrimaryListener<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller || oldWidget.id != widget.id) {
      _sync();
    }
  }

  void _sync() {
    final ctrl = _resolveController<T>(context, controller: widget.controller);
    final l = ctrl.itemIsPrimaryOf(widget.id);

    if (identical(l, _listenable)) return;

    _listenable?.removeListener(_handle);
    _listenable = l;
    _last = l.value;
    l.addListener(_handle);
  }

  void _handle() {
    final l = _listenable;
    if (l == null) return;

    final curr = l.value;
    final prev = _last;
    if (prev != curr) {
      _last = curr;
      widget.onChanged(prev, curr);
    }
  }

  @override
  void dispose() {
    _listenable?.removeListener(_handle);
    _listenable = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Triggers a callback when the **focused** status of [id] changes (no rebuild).
class ScrollSpyItemFocusedListener<T> extends StatefulWidget {
  /// Creates a listener that reacts to focused status changes for [id].
  const ScrollSpyItemFocusedListener({
    super.key,
    this.controller,
    required this.id,
    required this.onChanged,
    required this.child,
  });

  /// The controller to observe. If null, resolves from the nearest [ScrollSpyScope].
  final ScrollSpyController<T>? controller;

  /// The item ID to observe.
  final T id;

  /// Called with the previous and current values when the status toggles.
  final void Function(bool previous, bool current) onChanged;

  /// Subtree that is not rebuilt by this listener.
  final Widget child;

  @override
  State<ScrollSpyItemFocusedListener<T>> createState() =>
      _ScrollSpyItemFocusedListenerState<T>();
}

class _ScrollSpyItemFocusedListenerState<T>
    extends State<ScrollSpyItemFocusedListener<T>> {
  ValueListenable<bool>? _listenable;
  bool _last = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ScrollSpyItemFocusedListener<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller || oldWidget.id != widget.id) {
      _sync();
    }
  }

  void _sync() {
    final ctrl = _resolveController<T>(context, controller: widget.controller);
    final l = ctrl.itemIsFocusedOf(widget.id);

    if (identical(l, _listenable)) return;

    _listenable?.removeListener(_handle);
    _listenable = l;
    _last = l.value;
    l.addListener(_handle);
  }

  void _handle() {
    final l = _listenable;
    if (l == null) return;

    final curr = l.value;
    final prev = _last;
    if (prev != curr) {
      _last = curr;
      widget.onChanged(prev, curr);
    }
  }

  @override
  void dispose() {
    _listenable?.removeListener(_handle);
    _listenable = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Triggers a callback when the **visible** status of [id] changes (no rebuild).
class ScrollSpyItemVisibleListener<T> extends StatefulWidget {
  /// Creates a listener that reacts to visibility changes for [id].
  const ScrollSpyItemVisibleListener({
    super.key,
    this.controller,
    required this.id,
    required this.onChanged,
    required this.child,
  });

  /// The controller to observe. If null, resolves from the nearest [ScrollSpyScope].
  final ScrollSpyController<T>? controller;

  /// The item ID to observe.
  final T id;

  /// Called with the previous and current values when the status toggles.
  final void Function(bool previous, bool current) onChanged;

  /// Subtree that is not rebuilt by this listener.
  final Widget child;

  @override
  State<ScrollSpyItemVisibleListener<T>> createState() =>
      _ScrollSpyItemVisibleListenerState<T>();
}

class _ScrollSpyItemVisibleListenerState<T>
    extends State<ScrollSpyItemVisibleListener<T>> {
  ValueListenable<bool>? _listenable;
  bool _last = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ScrollSpyItemVisibleListener<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller || oldWidget.id != widget.id) {
      _sync();
    }
  }

  void _sync() {
    final ctrl = _resolveController<T>(context, controller: widget.controller);
    final l = ctrl.itemIsVisibleOf(widget.id);

    if (identical(l, _listenable)) return;

    _listenable?.removeListener(_handle);
    _listenable = l;
    _last = l.value;
    l.addListener(_handle);
  }

  void _handle() {
    final l = _listenable;
    if (l == null) return;

    final curr = l.value;
    final prev = _last;
    if (prev != curr) {
      _last = curr;
      widget.onChanged(prev, curr);
    }
  }

  @override
  void dispose() {
    _listenable?.removeListener(_handle);
    _listenable = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
