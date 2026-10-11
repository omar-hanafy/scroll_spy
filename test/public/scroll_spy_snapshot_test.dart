import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_spy/scroll_spy.dart';

import '../helpers/focus_fixtures.dart';

void main() {
  test('equal snapshots have equal hashes regardless of insertion order', () {
    final first = makeFocusItem(id: 1);
    final second = makeFocusItem(id: 2);
    final a = makeSnapshot(
      focusedIds: {1, 2},
      visibleIds: {1, 2},
      items: {1: first, 2: second},
    );
    final b = makeSnapshot(
      focusedIds: {2, 1},
      visibleIds: {2, 1},
      items: {2: second, 1: first},
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect({a}.contains(b), isTrue);
  });

  test('snapshot owns immutable copies of supplied collections', () {
    final focused = {1};
    final visible = {1};
    final items = {1: makeFocusItem(id: 1)};
    final snapshot = ScrollSpySnapshot<int>(
      computedAt: DateTime.fromMillisecondsSinceEpoch(0),
      primaryId: 1,
      focusedIds: focused,
      visibleIds: visible,
      items: items,
    );
    final hash = snapshot.hashCode;

    focused.clear();
    visible.add(2);
    items.clear();

    expect(snapshot.focusedIds, {1});
    expect(snapshot.visibleIds, {1});
    expect(snapshot.items.keys, {1});
    expect(snapshot.hashCode, hash);
    expect(() => snapshot.focusedIds.add(2), throwsUnsupportedError);
    expect(() => snapshot.visibleIds.clear(), throwsUnsupportedError);
    expect(() => snapshot.items.clear(), throwsUnsupportedError);
  });
}
