import 'package:scroll_spy/src/public/scroll_spy_controller.dart';
import 'package:scroll_spy/src/public/scroll_spy_models.dart';

/// Diff/commit boundary between the engine and the controller.
///
/// The focus engine computes a complete [ScrollSpySnapshot] on each compute
/// pass, but the [ScrollSpyController] is responsible for:
/// - Normalizing/freezing collections (unmodifiable sets/maps).
/// - Emitting diff-only updates for `primaryId` / `focusedIds`.
/// - Updating and evicting per-item listenables created via
///   `ScrollSpyController.itemFocusOf`.
///
/// This class exists as a tiny seam so the engine pipeline can stay focused on
/// geometry/selection logic and remain easier to test in isolation, while the
/// controller remains the single authority for listener semantics.
final class ScrollSpyDiff {
  const ScrollSpyDiff._();

  /// Publishes [next] into [controller].
  ///
  /// This is an internal call-site used by the engine after it finishes a
  /// compute pass.
  static void commitToController<T>({
    required ScrollSpyController<T> controller,
    required ScrollSpySnapshot<T> next,
  }) {
    controller.commitFrame(next);
  }
}
