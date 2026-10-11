---
name: migrate-scroll-spy-v1-to-v2
description: "Upgrade an existing scroll_spy 1.x integration to 2.x, including SDK constraints and optional ScrollCacheExtent migration. Use for 1.x-to-2.x upgrades or SDK resolution failures after that upgrade."
license: MIT
---

# Migrate scroll_spy 1.x to 2.x

The breaking requirement is the SDK floor: Flutter 3.47.7 or later with
Dart 3.13.5 or later. Existing public Dart APIs remain source-compatible.

1. Inspect the actual package version, SDK selection, pubspec constraints,
   and CI versions. Keep 1.x if the application must support older SDKs;
   do not change that product constraint without authorization.
2. When the SDK upgrade is in scope, align the selected toolchain and CI,
   set `environment.sdk: ^3.13.5` and `environment.flutter: '>=3.47.7'`,
   then update the dependency to `scroll_spy: ^2.0.0` and run `flutter pub get`.
3. Preserve existing controllers, regions, policies, listeners, and item IDs.
   List, grid, and custom-scroll wrappers now follow Flutter's actual
   primary-controller inheritance policy, including desktop. Pass an explicit
   scroll controller or `primary: true` only when that is the intended behavior.
4. Existing `cacheExtent` values still mean logical pixels. Optionally use
   `scrollCacheExtent: ScrollCacheExtent.pixels(500)` or
   `ScrollCacheExtent.viewport(2)` on list, grid, or custom-scroll wrappers.
   Import `ScrollCacheExtent` from `package:flutter/rendering.dart`.
   If both arguments are supplied, `scrollCacheExtent` takes precedence.
5. Format, analyze, and run the application's tests. Exercise its actual
   scrolling flow, programmatic jumps, controller replacement, and any autoplay
   ownership/lifecycle behavior before claiming the integration migrated.

Snapshots now own immutable copies of constructor collections. Do not rely on
mutating an input map or set to change an existing snapshot; construct a new
snapshot instead. Equal snapshots also have insertion-order-independent hashes.
