// Smoke test: every demo page must build, lay out, and scroll without throwing.
//
// Uses fixed-duration pumps (not pumpAndSettle) because some demos run
// continuous animations (e.g. the feed equalizer) that never settle.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scroll_spy_example/common.dart';
import 'package:scroll_spy_example/demos/demos.dart';
import 'package:scroll_spy_example/theme.dart';

void main() {
  for (final DemoInfo demo in kDemos) {
    testWidgets('${demo.title} builds and scrolls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildShowcaseTheme(),
          home: Builder(builder: (context) => demo.builder(context, demo)),
        ),
      );

      // Let post-frame registration + the first compute pass run.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final Finder scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable.first, const Offset(0, -450));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.drag(scrollable.first, const Offset(0, 200));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(tester.takeException(), isNull);
    });
  }
}
