import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewport_focus/viewport_focus.dart';

/// Deterministic widget-test harness for viewport_focus behavior.
///
/// Conventions:
/// - item ids are 0..itemCount-1
/// - ListView uses fixed [itemExtent]
/// - Viewport size is enforced via a SizedBox
final class ViewportFocusTestHarness {
  ViewportFocusTestHarness({
    ViewportFocusController<int>? controller,
    this.itemCount = 20,
    this.itemExtent = 100.0,
    this.viewportSize = const Size(400, 300),
    ViewportFocusRegion? region,
    ViewportFocusPolicy<int>? policy,
    this.stability = const ViewportFocusStability(),
    this.updatePolicy = const ViewportUpdatePolicy.perFrame(),
    this.scrollController,
    this.debug = false,
    this.debugConfig,
    Key? scopeKey,
    Key? listKey,
  })  : assert(itemCount >= 0),
        assert(itemExtent > 0),
        assert(viewportSize.width > 0 && viewportSize.height > 0),
        controller = controller ?? ViewportFocusController<int>(),
        region = region ??
            ViewportFocusRegion.zone(
              anchor: const ViewportAnchor.fraction(0.5),
              extentPx: itemExtent,
            ),
        policy = policy ?? const ViewportFocusPolicy.closestToAnchor(),
        scopeKey = scopeKey ?? const Key('vf_scope'),
        listKey = listKey ?? const Key('vf_list');

  /// Public so tests can inspect/commit frames.
  final ViewportFocusController<int> controller;

  /// Optional: if provided, passed to both ListView and ViewportFocusScope.
  final ScrollController? scrollController;

  final int itemCount;
  final double itemExtent;
  final Size viewportSize;

  final ViewportFocusRegion region;
  final ViewportFocusPolicy<int> policy;
  final ViewportFocusStability stability;
  final ViewportUpdatePolicy updatePolicy;

  final bool debug;
  final ViewportFocusDebugConfig? debugConfig;

  /// Keys to find the scope/list reliably in tests.
  final Key scopeKey;
  final Key listKey;

  /// Builds the widget tree (Directionality + MediaQuery + SizedBox + Scope + List).
  Widget build() {
    final list = ListView.builder(
      key: listKey,
      controller: scrollController,
      itemExtent: itemExtent,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return ViewportFocusItem<int>(
          id: index,
          child: const _StaticItemChild(),
          builder: (context, focus, child) {
            // The ListView's fixed extent constrains this subtree; keep it stable.
            return child!;
          },
        );
      },
    );

    final scoped = ViewportFocusScope<int>(
      key: scopeKey,
      controller: controller,
      region: region,
      policy: policy,
      stability: stability,
      updatePolicy: updatePolicy,
      scrollController: scrollController,
      debug: debug,
      debugConfig: debugConfig,
      child: list,
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(size: viewportSize),
        child: Center(
          child: SizedBox(
            width: viewportSize.width,
            height: viewportSize.height,
            child: scoped,
          ),
        ),
      ),
    );
  }

  /// Pumps the harness and advances enough frames for:
  /// - post-frame item registration
  /// - engine compute
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(build());

    // Frame 1: lets ViewportFocusItem post-frame registration run
    // and schedule an engine compute.
    await tester.pump();

    // Frame 2: lets the engine post-frame compute run and commit.
    await tester.pump();
  }

  /// Convenience: fetch the mounted [ViewportFocusScopeState<int>] by [scopeKey].
  ViewportFocusScopeState<int> scopeState(WidgetTester tester) {
    return tester.state<ViewportFocusScopeState<int>>(find.byKey(scopeKey));
  }
}

class _StaticItemChild extends StatelessWidget {
  const _StaticItemChild();

  @override
  Widget build(BuildContext context) {
    // Deterministic, const subtree. Size is driven by ListView constraints.
    return const SizedBox.expand();
  }
}
