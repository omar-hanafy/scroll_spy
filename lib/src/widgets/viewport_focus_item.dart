import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:viewport_focus/src/public/viewport_focus_models.dart';
import 'package:viewport_focus/src/widgets/viewport_focus_scope.dart';

/// Signature for building a focus-aware item subtree.
///
/// The [focus] argument is the latest computed [ViewportItemFocus] for the item
/// [ViewportFocusItem.id]. The optional [child] is the static subtree passed to
/// [ViewportFocusItem.child] and is provided so callers can avoid rebuilding
/// expensive widgets on every focus update.
typedef ViewportFocusItemBuilder<T> = Widget Function(
  BuildContext context,
  ViewportItemFocus<T> focus,
  Widget? child,
);

/// Marks a widget as a trackable item within a [ViewportFocusScope].
///
/// This widget performs two critical functions:
/// 1. **Registration:** It registers the item's `RenderBox` with the nearest
///    scope so the engine can track its position relative to the viewport. The
///    registration happens after the frame so layout and transforms are stable.
/// 2. **Reactivity:** It listens to the [ViewportFocusController] for this
///    specific [id] and rebuilds its child whenever the focus state (e.g.,
///    visibility, primary status) changes.
///
/// **Implementation Note:**
/// This widget inserts a lightweight `RenderProxyBox` into the render tree to
/// get accurate geometry without affecting layout or painting performance.
class ViewportFocusItem<T> extends StatefulWidget {
  /// Creates a focus-aware item that registers itself with the nearest scope.
  ///
  /// Provide a stable [id] and a [builder] that reacts to focus changes.
  const ViewportFocusItem({
    super.key,
    required this.id,
    required this.builder,
    this.child,
  });

  /// The unique identifier for this item in the scope.
  final T id;

  /// A builder that provides the current [ViewportItemFocus] state.
  ///
  /// Use this to drive UI updates, such as:
  /// - Playing a video when `focus.isPrimary` is true.
  /// - Scaling the item based on `focus.focusProgress`.
  final ViewportFocusItemBuilder<T> builder;

  /// An optional static child widget.
  ///
  /// Pass the static part of your item subtree here (e.g., the image or background)
  /// so it doesn't rebuild every time the focus state changes.
  final Widget? child;

  @override
  State<ViewportFocusItem<T>> createState() => _ViewportFocusItemState<T>();
}

class _ViewportFocusItemState<T> extends State<ViewportFocusItem<T>> {
  ViewportFocusScopeState<T>? _scope;
  T? _registeredId;
  RenderBox? _probeBox;
  bool _registerScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleRegister();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleRegister();
  }

  @override
  void didUpdateWidget(covariant ViewportFocusItem<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _unregister(oldWidget.id);
      _scheduleRegister();
    }
  }

  @override
  void dispose() {
    _unregister(_registeredId);
    super.dispose();
  }

  void _scheduleRegister() {
    if (_registerScheduled) return;
    _registerScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerScheduled = false;
      if (!mounted) return;
      _registerIfPossible();
    });
  }

  void _registerIfPossible() {
    final ViewportFocusScopeState<T>? newScope = ViewportFocusScope.maybeOf<T>(
      context,
    );
    if (newScope == null) return;

    final RenderBox? box = _probeBox;
    if (box == null || !box.attached || !box.hasSize) return;

    if (!identical(_scope, newScope)) {
      _unregister(_registeredId);
      _scope = newScope;
    }

    final T id = widget.id;
    if (_registeredId == id) {
      // Already registered under the correct id, but the render box may have changed.
      _scope!.registerItem(id, context: context, box: box);
      return;
    }

    _registeredId = id;
    _scope!.registerItem(id, context: context, box: box);
  }

  void _unregister(T? id) {
    if (id == null) return;
    _scope?.unregisterItem(id);
    if (_registeredId == id) _registeredId = null;
  }

  @override
  Widget build(BuildContext context) {
    final ViewportFocusScopeState<T>? scope = ViewportFocusScope.maybeOf<T>(
      context,
    );
    assert(
      scope != null,
      'ViewportFocusItem<$T> must be placed under a ViewportFocusScope<$T>.',
    );

    final controller = scope!.controller;
    final id = widget.id;

    return _ViewportFocusProbe(
      onProbeBox: _handleProbeBox,
      child: ValueListenableBuilder<ViewportItemFocus<T>>(
        valueListenable: controller.itemFocusOf(id),
        builder: (context, focus, _) =>
            widget.builder(context, focus, widget.child),
      ),
    );
  }

  void _handleProbeBox(RenderBox box) {
    if (identical(_probeBox, box)) return;
    _probeBox = box;
    _scheduleRegister();
  }
}

/// A minimal render-proxy used to provide a stable [RenderBox] for geometry.
/// This adds no compositing layer and does not alter layout.
class _ViewportFocusProbe extends SingleChildRenderObjectWidget {
  const _ViewportFocusProbe({required this.onProbeBox, super.child});

  final ValueChanged<RenderBox> onProbeBox;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final ro = _RenderViewportFocusProbe();
    onProbeBox(ro);
    return ro;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderViewportFocusProbe renderObject,
  ) {
    onProbeBox(renderObject);
  }
}

class _RenderViewportFocusProbe extends RenderProxyBox {}
