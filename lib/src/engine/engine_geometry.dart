import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'package:scroll_spy/src/engine/item_slot.dart';

/// Viewport-relative geometry for [ItemSlot]s.
///
/// Built on one fact: scrolling translates painted content rigidly along the
/// main axis. For an item whose chain to the viewport is a pure translation,
/// its main-axis position is linear in the scroll offset:
///
/// ```
/// mainStart(pixels) = mainStart0 - dir * (pixels - pixels0)
/// ```
///
/// so after one full measurement (the anchor), steady-state passes derive the
/// position with a subtraction plus an O(1) validation, allocating nothing and
/// walking no trees. Items that cannot use the anchor re-measure every pass
/// with an allocation-free walk (translation accumulation, falling back to
/// matrix composition only for chains containing real transforms).
final class EngineGeometry {
  RenderAbstractViewport? _viewport;
  RenderBox? _viewportBox;

  double _pixels = 0;
  Axis _axis = Axis.vertical;
  double _dir = 1;
  double _viewportW = 0;
  double _viewportH = 0;
  bool _canFastTier = false;

  /// Epoch of the current viewport identity/size/axis. Fast anchors captured
  /// under an older epoch are re-measured instead of trusted.
  int _epoch = 0;

  int _passCount = 0;
  int _fastHitIndex = 0;
  int _crossCheckTarget = 0;

  /// Number of full measurements performed (anchor captures and walk/matrix
  /// tier passes). Steady-state scrolling must not grow this.
  @visibleForTesting
  int fullMeasures = 0;

  /// Number of O(1) fast-tier derivations performed.
  @visibleForTesting
  int fastHits = 0;

  // Reused walk scratch. Never escapes this object.
  final Matrix4 _levelScratch = Matrix4.zero();
  final Matrix4 _chainScratch = Matrix4.zero();
  final List<RenderObject> _chain = <RenderObject>[];

  // Results of the last _walk call.
  bool _walkOk = false;
  bool _walkPure = false;
  double _walkL = 0;
  double _walkT = 0;
  double _walkW = 0;
  double _walkH = 0;
  RenderSliver? _walkSliver;
  RenderObject? _walkSliverChild;
  double _walkLayoutOffset = 0;
  bool _walkHasLayoutOffset = false;

  /// Scroll offset read at [beginPass].
  double get pixels => _pixels;

  /// Main axis of the tracked viewport.
  Axis get axis => _axis;

  /// +1 when increasing pixels moves content toward the axis start
  /// (AxisDirection.down/right), -1 otherwise.
  double get dir => _dir;

  /// Viewport extent along the main axis.
  double get viewportMainExtent =>
      _axis == Axis.vertical ? _viewportH : _viewportW;

  /// Viewport extent along the cross axis.
  double get viewportCrossExtent =>
      _axis == Axis.vertical ? _viewportW : _viewportH;

  /// Finds the nearest enclosing viewport of [box], if any.
  static RenderAbstractViewport? viewportOf(RenderBox box) =>
      RenderAbstractViewport.maybeOf(box);

  /// Prepares per-pass viewport state. Returns false when the viewport cannot
  /// be measured yet (detached, unsized, or without pixels).
  bool beginPass({
    required RenderAbstractViewport viewport,
    required Axis axisHint,
  }) {
    if (viewport is! RenderBox) return false;
    final RenderBox box = viewport as RenderBox;
    if (!box.attached || !box.hasSize) return false;

    Axis axis = axisHint;
    double dir = 1;
    double pixels = 0;
    bool canFast = false;

    if (viewport is RenderViewportBase) {
      final RenderViewportBase base = viewport;
      final AxisDirection axisDirection = base.axisDirection;
      axis = axisDirectionToAxis(axisDirection);
      dir = (axisDirection == AxisDirection.down ||
              axisDirection == AxisDirection.right)
          ? 1.0
          : -1.0;
      final ViewportOffset offset = base.offset;
      if (!offset.hasPixels) return false;
      pixels = offset.pixels;
      canFast = true;
    }

    final bool changed = !identical(_viewport, viewport) ||
        box.size.width != _viewportW ||
        box.size.height != _viewportH ||
        axis != _axis;
    if (changed) _epoch++;

    _viewport = viewport;
    _viewportBox = box;
    _axis = axis;
    _dir = dir;
    _pixels = pixels;
    _canFastTier = canFast;
    _viewportW = box.size.width;
    _viewportH = box.size.height;

    _passCount++;
    _fastHitIndex = 0;
    _crossCheckTarget = _passCount % 17;
    return true;
  }

  /// Brings `slot.mainStart/mainEnd/crossStartNow/crossEndNow` up to date for
  /// this pass and sets `slot.measurable`.
  void ensureMeasured(ItemSlot<Object?> slot) {
    final RenderBox? box = slot.box;
    if (box == null || !box.attached || !box.hasSize) {
      slot.resetMetrics();
      return;
    }

    if (slot.tier == GeometryTier.fast &&
        slot.anchorEpoch == _epoch &&
        _fastAnchorValid(slot)) {
      fastHits++;
      final double mainStart =
          slot.mainStart0 - _dir * (_pixels - slot.pixels0);
      slot
        ..mainStart = mainStart
        ..mainEnd = mainStart + slot.mainExtent
        ..crossStartNow = slot.crossStart
        ..crossEndNow = slot.crossStart + slot.crossExtent
        ..measurable = true;
      assert(_debugCrossCheck(slot));
      return;
    }

    _fullMeasure(slot);
  }

  bool _fastAnchorValid(ItemSlot<Object?> slot) {
    final RenderSliver? sliver = slot.sliver;
    final RenderObject? child = slot.sliverChild;
    if (sliver == null || child == null) return false;
    if (!sliver.attached || !child.attached) return false;

    final ParentData? parentData = child.parentData;
    if (parentData is! SliverMultiBoxAdaptorParentData) return false;
    final double? layoutOffset = parentData.layoutOffset;
    if (layoutOffset == null || layoutOffset != slot.layoutOffset0) {
      return false;
    }
    if (sliver.constraints.precedingScrollExtent != slot.precedingExtent0) {
      return false;
    }

    final Size size = slot.box!.size;
    if (size.width != slot.boxW0 || size.height != slot.boxH0) return false;

    return true;
  }

  void _fullMeasure(ItemSlot<Object?> slot) {
    fullMeasures++;
    final RenderBox box = slot.box!;
    _walk(box);

    if (!_walkOk) {
      slot.resetMetrics();
      slot.invalidateGeometry();
      return;
    }

    final bool vertical = _axis == Axis.vertical;
    final double mainStart = vertical ? _walkT : _walkL;
    final double mainExtent = vertical ? _walkH : _walkW;
    final double crossStart = vertical ? _walkL : _walkT;
    final double crossExtent = vertical ? _walkW : _walkH;

    slot
      ..mainStart = mainStart
      ..mainEnd = mainStart + mainExtent
      ..crossStartNow = crossStart
      ..crossEndNow = crossStart + crossExtent
      ..measurable = true;

    final RenderSliver? sliver = _walkSliver;
    if (_walkPure &&
        _canFastTier &&
        _walkHasLayoutOffset &&
        sliver is RenderSliverMultiBoxAdaptor) {
      slot
        ..tier = GeometryTier.fast
        ..anchorEpoch = _epoch
        ..mainStart0 = mainStart
        ..pixels0 = _pixels
        ..mainExtent = mainExtent
        ..crossStart = crossStart
        ..crossExtent = crossExtent
        ..sliver = sliver
        ..sliverChild = _walkSliverChild
        ..layoutOffset0 = _walkLayoutOffset
        ..precedingExtent0 = sliver.constraints.precedingScrollExtent
        ..boxW0 = box.size.width
        ..boxH0 = box.size.height;
    } else {
      slot
        ..tier = _walkPure ? GeometryTier.walk : GeometryTier.matrix
        ..sliver = null
        ..sliverChild = null;
    }
  }

  /// Measures `box` in viewport coordinates.
  ///
  /// One validating walk from the box to the viewport: aborts on broken or
  /// foreign-viewport chains and on kept-alive children; accumulates pure
  /// translations; records the enclosing sliver boundary. When a
  /// non-translation segment exists, composes the whole chain like
  /// `getTransformTo` into reused storage.
  void _walk(RenderBox box) {
    _walkOk = false;
    _walkPure = true;
    _walkSliver = null;
    _walkSliverChild = null;
    _walkHasLayoutOffset = false;

    final RenderObject viewport = _viewportBox!;
    double dx = 0;
    double dy = 0;
    RenderObject node = box;

    while (!identical(node, viewport)) {
      final RenderObject? parent = node.parent;
      if (parent == null) return;
      if (parent is RenderAbstractViewport && !identical(parent, viewport)) {
        // The item lives inside a nested viewport; not ours to track.
        return;
      }

      if (_walkSliver == null && parent is RenderSliver && node is RenderBox) {
        _walkSliver = parent;
        _walkSliverChild = node;
        final ParentData? parentData = node.parentData;
        if (parentData is SliverMultiBoxAdaptorParentData) {
          final double? layoutOffset = parentData.layoutOffset;
          if (layoutOffset == null) {
            // Kept alive without layout: not measurable this pass.
            return;
          }
          _walkLayoutOffset = layoutOffset;
          _walkHasLayoutOffset = true;
        }
      }

      if (_walkPure) {
        _levelScratch.setIdentity();
        parent.applyPaintTransform(node, _levelScratch);
        if (_isPureTranslation(_levelScratch)) {
          dx += _levelScratch.storage[12];
          dy += _levelScratch.storage[13];
        } else {
          _walkPure = false;
        }
      }

      node = parent;
    }

    if (_walkPure) {
      _walkL = dx;
      _walkT = dy;
      _walkW = box.size.width;
      _walkH = box.size.height;
      _walkOk = true;
      return;
    }

    _chain.clear();
    RenderObject n = box;
    while (!identical(n, viewport)) {
      _chain.add(n);
      n = n.parent!;
    }
    _chain.add(viewport);

    _chainScratch.setIdentity();
    for (int i = _chain.length - 1; i > 0; i--) {
      _chain[i].applyPaintTransform(_chain[i - 1], _chainScratch);
    }
    _chain.clear();

    final Rect rect = MatrixUtils.transformRect(
      _chainScratch,
      Offset.zero & box.size,
    );
    _walkL = rect.left;
    _walkT = rect.top;
    _walkW = rect.width;
    _walkH = rect.height;
    _walkOk = true;
  }

  static bool _isPureTranslation(Matrix4 m) {
    final Float64List s = m.storage;
    return s[0] == 1.0 &&
        s[1] == 0.0 &&
        s[2] == 0.0 &&
        s[3] == 0.0 &&
        s[4] == 0.0 &&
        s[5] == 1.0 &&
        s[6] == 0.0 &&
        s[7] == 0.0 &&
        s[8] == 0.0 &&
        s[9] == 0.0 &&
        s[10] == 1.0 &&
        s[11] == 0.0 &&
        s[14] == 0.0 &&
        s[15] == 1.0;
  }

  /// Debug-only rotating verification that the fast tier agrees with a fresh
  /// walk. Catches custom slivers that reposition children without touching
  /// layoutOffset (which the fingerprint cannot see).
  bool _debugCrossCheck(ItemSlot<Object?> slot) {
    if (_fastHitIndex++ != _crossCheckTarget) return true;
    final double derived = slot.mainStart;
    _walk(slot.box!);
    if (!_walkOk) return true;
    final double actual = _axis == Axis.vertical ? _walkT : _walkL;
    assert(
      (actual - derived).abs() < 0.01,
      'scroll_spy: fast-tier geometry drift for item ${slot.id} '
      '(derived $derived, actual $actual). This usually means a custom '
      'sliver repositions children without changing their layoutOffset. ',
    );
    return true;
  }
}
