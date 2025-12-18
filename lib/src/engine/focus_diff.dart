import 'package:viewport_focus/src/public/viewport_focus_controller.dart';
import 'package:viewport_focus/src/public/viewport_focus_models.dart';

/// Diff/commit boundary between the engine and the controller.
///
/// The focus engine computes a complete [ViewportFocusSnapshot] on each compute
/// pass, but the [ViewportFocusController] is responsible for:
/// - Normalizing/freezing collections (unmodifiable sets/maps).
/// - Emitting diff-only updates for `primaryId` / `focusedIds`.
/// - Updating and evicting per-item listenables created via
///   `ViewportFocusController.itemFocusOf`.
///
/// This class exists as a tiny seam so the engine pipeline can stay focused on
/// geometry/selection logic and remain easier to test in isolation, while the
/// controller remains the single authority for listener semantics.
final class FocusDiff {
  const FocusDiff._();

  /// Publishes [next] into [controller].
  ///
  /// This is an internal call-site used by the engine after it finishes a
  /// compute pass.
  static void commitToController<T>({
    required ViewportFocusController<T> controller,
    required ViewportFocusSnapshot<T> next,
  }) {
    controller.commitFrame(next);
  }
}
