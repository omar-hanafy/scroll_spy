import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:scroll_spy/src/public/scroll_spy_models.dart';
import 'package:scroll_spy/src/widgets/scroll_spy_scope.dart';

/// Signature for building a focus-aware item subtree.
///
/// The [focus] argument is the latest computed [ScrollSpyItemFocus] for the item
/// [ScrollSpyItem.id]. The optional [child] is the static subtree passed to
/// [ScrollSpyItem.child] and is provided so callers can avoid rebuilding
/// expensive widgets on every focus update.
typedef ScrollSpyItemBuilder<T> = Widget Function(
  BuildContext context,
  ScrollSpyItemFocus<T> focus,
  Widget? child,
);

/// Signature for building a lite focus-aware item subtree.
///
/// Only receives boolean state toggles.
typedef ScrollSpyItemLiteBuilder<T> = Widget Function(
  BuildContext context,
  bool isPrimary,
  bool isFocused,
  Widget? child,
);

/// Marks a widget as a trackable item within a [ScrollSpyScope].
///
/// This widget performs two critical functions:
/// 1. **Registration:** It registers the item's `RenderBox` with the nearest
///    scope so the engine can track its position relative to the viewport. The
///    registration happens after the frame so layout and transforms are stable.
/// 2. **Reactivity:** It listens to the [ScrollSpyController] for this
///    specific [id] and rebuilds its child whenever the focus state (e.g.,
///    visibility, primary status) changes.
///
/// **Implementation Note:**
/// This widget inserts a lightweight `RenderProxyBox` into the render tree to
/// get accurate geometry without affecting layout or painting performance.
class ScrollSpyItem<T> extends StatefulWidget {
  /// Creates a focus-aware item that registers itself with the nearest scope.
  ///
  /// Provide a stable [id] and a [builder] that reacts to focus changes.
  const ScrollSpyItem({
    super.key,
    required this.id,
    required this.builder,
    this.child,
  });

  /// The unique identifier for this item in the scope.
  final T id;

  /// A builder that provides the current [ScrollSpyItemFocus] state.
  ///
  /// Use this to drive UI updates, such as:
  /// - Playing a video when `focus.isPrimary` is true.
  /// - Scaling the item based on `focus.focusProgress`.
  final ScrollSpyItemBuilder<T> builder;

  /// An optional static child widget.
  ///
  /// Pass the static part of your item subtree here (e.g., the image or background)
  /// so it doesn't rebuild every time the focus state changes.
  final Widget? child;

  @override
  State<ScrollSpyItem<T>> createState() => _ScrollSpyItemState<T>();
}

class _ScrollSpyItemState<T> extends State<ScrollSpyItem<T>> {
  ScrollSpyScopeState<T>? _scope;
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
  void didUpdateWidget(covariant ScrollSpyItem<T> oldWidget) {
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
    final ScrollSpyScopeState<T>? newScope = ScrollSpyScope.maybeOf<T>(
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
    final ScrollSpyScopeState<T>? scope = ScrollSpyScope.maybeOf<T>(
      context,
    );
    assert(
      scope != null,
      'ScrollSpyItem<$T> must be placed under a ScrollSpyScope<$T>.',
    );

    final controller = scope!.controller;
    final id = widget.id;

    return _ScrollSpyProbe(
      onProbeBox: _handleProbeBox,
      child: ValueListenableBuilder<ScrollSpyItemFocus<T>>(
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

/// A "Lite" version of [ScrollSpyItem] that rebuilds ONLY when
/// [isPrimary] or [isFocused] changes.
///
/// It ignores high-frequency updates (like distance changes or visible fraction).
/// Use this for performance-critical lists where you only need boolean states.
class ScrollSpyItemLite<T> extends StatefulWidget {
  /// Creates a lite focus-aware item for [id].
  const ScrollSpyItemLite({
    super.key,
    required this.id,
    required this.builder,
    this.child,
  });

  /// Unique ID used by the controller to track this item.
  final T id;

  /// Called when the item's primary/focused status toggles.
  final ScrollSpyItemLiteBuilder<T> builder;

  /// Optional subtree that does not depend on focus state.
  final Widget? child;

  @override
  State<ScrollSpyItemLite<T>> createState() => _ScrollSpyItemLiteState<T>();
}

class _ScrollSpyItemLiteState<T> extends State<ScrollSpyItemLite<T>> {
  ScrollSpyScopeState<T>? _scope;
  T? _registeredId;
  RenderBox? _probeBox;
  bool _registerScheduled = false;

  ValueListenable<bool>? _isPrimary;
  ValueListenable<bool>? _isFocused;
  Listenable? _merged;

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
  void didUpdateWidget(covariant ScrollSpyItemLite<T> oldWidget) {
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
    final ScrollSpyScopeState<T>? newScope = ScrollSpyScope.maybeOf<T>(
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
    final scope = ScrollSpyScope.maybeOf<T>(context);
    assert(
      scope != null,
      'ScrollSpyItemLite<$T> must be placed under a ScrollSpyScope<$T>.',
    );

    final controller = scope!.controller;
    final id = widget.id;

    // Cache merged listenable to avoid rebuild-time allocations.
    final p = controller.itemIsPrimaryOf(id);
    final f = controller.itemIsFocusedOf(id);

    if (!identical(p, _isPrimary) ||
        !identical(f, _isFocused) ||
        _merged == null) {
      _isPrimary = p;
      _isFocused = f;
      _merged = Listenable.merge(<Listenable>[p, f]);
    }

    return _ScrollSpyProbe(
      onProbeBox: _handleProbeBox,
      child: AnimatedBuilder(
        animation: _merged!,
        child: widget.child,
        builder: (context, child) {
          return widget.builder(
            context,
            _isPrimary!.value,
            _isFocused!.value,
            child,
          );
        },
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
class _ScrollSpyProbe extends SingleChildRenderObjectWidget {
  const _ScrollSpyProbe({required this.onProbeBox, super.child});

  final ValueChanged<RenderBox> onProbeBox;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final ro = _RenderScrollSpyProbe();
    onProbeBox(ro);
    return ro;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderScrollSpyProbe renderObject,
  ) {
    onProbeBox(renderObject);
  }
}

class _RenderScrollSpyProbe extends RenderProxyBox {}
