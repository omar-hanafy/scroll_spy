# ScrollSpy Assistant

Package-specific AI coding-assistant plugin for
[scroll_spy](https://pub.dev/packages/scroll_spy), the viewport focus
detection package for Flutter. One plugin tree serves both Claude Code and
OpenAI Codex; the skills are identical on both.

This plugin contains instructions and reference material only: no hooks, no
MCP servers, no executable scripts, and no network access.

## Install

From Claude Code (v2 or later):

```
/plugin marketplace add omar-hanafy/scroll_spy
/plugin install scroll-spy@scroll-spy
```

From Codex CLI (v0.144 or later; also usable from the ChatGPT desktop app):

```
codex plugin marketplace add omar-hanafy/scroll_spy
codex plugin add scroll-spy@scroll-spy
```

Start a new session after installing so the skills are discovered.

## Skills

| Skill | Use it when |
|---|---|
| `integrate-scroll-spy` | Adding scroll_spy to a screen: feeds, autoplay, carousels, reading position, impression analytics, grids |
| `tune-scroll-spy-stability` | The primary flickers, switches too eagerly/slowly, goes null between items, or autoplay stutters |
| `diagnose-scroll-spy` | No output or wrong output: null primary, empty focusedIds, jumps not detected, offsets under pinned headers, nested-scrollable interference |
| `optimize-scroll-spy-performance` | Jank or rebuild storms in large feeds; choosing Item vs ItemLite vs listeners |
| `migrate-scroll-spy-v0-to-v1` | Upgrading 0.1.x/0.2.x to 1.x; build breaks mentioning ScrollSpyRegistry, ScrollSpyGeometry, ScrollSpySelection, ScrollSpyDiff, or commitFrame |
| `convert-visibility-detector-to-scroll-spy` | Replacing the visibility_detector package with scroll_spy |

In Claude Code, invoke explicitly as `/scroll-spy:<skill-name>`; in Codex as
`$<skill-name>`. Both assistants also pick the right skill automatically from
your request ("my autoplay feed flickers between two cards" triggers
`tune-scroll-spy-stability`).

## Compatibility

- Skills target scroll_spy 1.x (the migration skill also reads 0.x projects).
- Claude Code: CLI, desktop, and web clients that support plugin marketplaces.
- Codex: CLI and ChatGPT desktop app (the Codex IDE extension does not load
  plugins; for IDE-only use, install individual skills into `~/.codex/skills`
  with the bundled `$skill-installer` skill).

## Update / remove

Claude Code:

```
/plugin update scroll-spy@scroll-spy
/plugin uninstall scroll-spy@scroll-spy
```

Codex:

```
codex plugin marketplace upgrade scroll-spy
codex plugin remove scroll-spy@scroll-spy
```

## For maintainers

Skill sources live in `skills/<skill-name>/SKILL.md` with per-skill
`references/` files. Keep every skill self-contained (no `../` references),
keep manifest versions in sync with `pubspec.yaml`, and run
`dart run tool/validate_ai_plugin.dart` from the repository root before
committing. See `AGENTS.md` at the repository root for the full release
process.
