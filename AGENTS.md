# Repository guide for coding agents

scroll_spy is a published pure-Dart Flutter package (pub.dev: `scroll_spy`) that
computes visible/focused/primary items for scrollables. This file is maintainer
guidance for working on the package itself. Package consumers should install
the ScrollSpy Assistant plugin instead (see "AI coding-assistant support" in
README.md).

## Validation commands

Run from the repository root, in this order, before any PR:

```bash
dart format .
flutter analyze
flutter test
dart run tool/validate_ai_plugin.dart
flutter pub publish --dry-run
```

CI additionally requires a perfect pana score on PRs to main/dev. Never "fix"
a gate by disabling tests, weakening lints, or adding broad ignores.

## Architecture boundaries

- Public API is exactly what `lib/scroll_spy.dart` exports; `@internal` members
  are not public even when their library is exported.
- The engine hot path (`lib/src/engine/`) must stay allocation-free during
  steady scrolling; `test/perf/` and `test/engine/engine_invariants_test.dart`
  assert this. Do not add per-pass allocations, render-tree walks, or
  wall-clock time reads there (stability timing is monotonic).
- Public behavior changes require: tests, README updates (API map + relevant
  section), a CHANGELOG.md entry, and doc comments (public_member_api_docs is
  an error-level lint).

## Release process (automated)

1. Branch `release/X.Y.Z`, bump `version:` in pubspec.yaml, update
   CHANGELOG.md, and sync the AI plugin version (see below).
2. PR to `main` (stable versions only; `dev` takes `-dev.*` prereleases only).
3. Merging a pubspec version bump to main auto-tags `scroll_spy-vX.Y.Z` and
   publishes to pub.dev via OIDC (no manual `pub publish`).
4. Never re-tag or force-push a released version.

## AI plugin tree (`plugins/scroll-spy/`)

- One canonical plugin serves Claude Code and Codex; skills live in
  `plugins/scroll-spy/skills/`, one directory per skill.
- Versions must stay in sync across pubspec.yaml, both plugin manifests, and
  `.claude-plugin/marketplace.json`; `dart run tool/validate_ai_plugin.dart`
  enforces this and CI runs it.
- Skills must stay self-contained (no `../` references) so single-skill
  installs keep working.
- The whole tree is excluded from the pub.dev archive via `.pubignore`; never
  remove those entries.
- When a future release introduces a breaking API change, add a dedicated
  `migrate-scroll-spy-vX-to-vY` skill next to the existing migration skill and
  update the plugin README's capability table.
