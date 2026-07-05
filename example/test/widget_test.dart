// Smoke test for the showcase app.

import 'package:flutter_test/flutter_test.dart';

import 'package:scroll_spy_example/main.dart';

void main() {
  testWidgets('showcase app builds and shows the gallery', (tester) async {
    await tester.pumpWidget(const ShowcaseApp());
    await tester.pump();

    expect(find.byType(HomeGalleryPage), findsOneWidget);
    expect(find.text('scroll_spy'), findsOneWidget);
    // The gallery lists demos.
    expect(find.text('Autoplay feed'), findsOneWidget);
  });
}
