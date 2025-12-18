import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FocusEngine handles empty registry (itemCount=0)', (
    tester,
  ) async {
    final harness = ViewportFocusTestHarness(
      itemCount: 0,
      itemExtent: 100,
      viewportSize: const Size(400, 300),
      debug: false,
    );
    addTearDown(harness.controller.dispose);

    await harness.pump(tester);

    expect(harness.controller.primaryId.value, isNull);
    expect(harness.controller.focusedIds.value, isEmpty);
    expect(harness.controller.snapshot.value.items, isEmpty);
  });
}
