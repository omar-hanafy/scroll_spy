# AI coding-assistant support for scroll_spy

scroll_spy ships the **ScrollSpy Assistant** plugin: package-specific skills
for AI coding agents working in apps that use scroll_spy. One plugin tree in
this repository (`plugins/scroll-spy/`) serves both Claude Code and OpenAI
Codex; the skill content is identical on both.

This is tooling for your coding assistant. It is not a runtime dependency and
adds nothing to your app; `dart pub add scroll_spy` installs the Flutter
package only, never this plugin.

## What is included

Six skills, all instructions-and-reference only (no hooks, no MCP servers, no
executable scripts, no network access, no telemetry):

| Skill | Audience | Use it when |
|---|---|---|
| `integrate-scroll-spy` | app developers | Wiring scroll_spy into feeds, autoplay, carousels, reading position/TOC, impression analytics, or grids; choosing regions, policies, stability, update policies; writing widget tests for focus behavior |
| `tune-scroll-spy-stability` | app developers | The primary item flickers or alternates, switches too eagerly or too slowly, goes null between items, sticks too long, or autoplay stutters at boundaries |
| `diagnose-scroll-spy` | app developers | primaryId stays null, focusedIds stays empty, listeners never fire, jumps via ScrollController are not detected, highlights are offset under pinned headers, or nested scrollables interfere |
| `optimize-scroll-spy-performance` | app developers | Jank, dropped frames, or rebuild storms in large feeds; choosing between ScrollSpyItem, ScrollSpyItemLite, builders, and listeners |
| `migrate-scroll-spy-v0-to-v1` | upgraders | Moving a project from scroll_spy 0.1.x/0.2.x to 1.x, including code that used removed engine internals (ScrollSpyRegistry, ScrollSpyGeometry, ScrollSpySelection, ScrollSpyDiff, commitFrame) |
| `convert-visibility-detector-to-scroll-spy` | adopters | Replacing the visibility_detector package with scroll_spy, or adding a stable primary to a VisibilityDetector-based feed |

There are deliberately no custom agents, hooks, or MCP servers: scroll_spy
work is sequential code reasoning inside your project, which stock agents plus
these skills handle; automatic lifecycle hooks and external tool servers would
add trust surface without adding capability.

## Install

### Claude Code

Requires Claude Code v2 or later (CLI, desktop, or web with plugin support).

```
/plugin marketplace add omar-hanafy/scroll_spy
/plugin install scroll-spy@scroll-spy
```

Non-interactive equivalent:

```bash
claude plugin marketplace add omar-hanafy/scroll_spy
claude plugin install scroll-spy@scroll-spy
```

### OpenAI Codex

Requires Codex CLI v0.144 or later. Plugins load in the Codex CLI and the
ChatGPT desktop app; the Codex IDE extension and mobile do not load plugins.

```bash
codex plugin marketplace add omar-hanafy/scroll_spy
codex plugin add scroll-spy@scroll-spy
```

You can also browse and enable it with `/plugins` inside the Codex TUI.

If you only want a single skill (for example on a machine that uses the Codex
IDE extension), Codex's bundled installer skill copies one skill folder into
`~/.codex/skills`:

```
$skill-installer install https://github.com/omar-hanafy/scroll_spy/tree/main/plugins/scroll-spy/skills/integrate-scroll-spy
```

### After installing

Start a new session so skills are discovered. Verify with `/help` (Claude
Code, skills appear as `/scroll-spy:<skill>`) or `/skills` (Codex, skills
appear as `$<skill>`).

## Using the skills

Both assistants select skills automatically from your request; explicit
invocation also works:

| Task you type | Skill that should engage |
|---|---|
| "Add autoplay to my feed with scroll_spy: one video plays at a time" | `integrate-scroll-spy` |
| "My scroll_spy primary flickers between cards 3 and 4 while scrolling slowly" | `tune-scroll-spy-stability` |
| "primaryId is always null even though items are visible" | `diagnose-scroll-spy` |
| "The feed janks since I added focus effects to 1000 items" | `optimize-scroll-spy-performance` |
| "Upgrade us from scroll_spy 0.2.6, the build broke on commitFrame" | `migrate-scroll-spy-v0-to-v1` |
| "Swap visibility_detector for scroll_spy in our impression tracking" | `convert-visibility-detector-to-scroll-spy` |

Skills inspect your project before acting (installed scroll_spy version,
Flutter constraints, existing scope/controller usage) and instruct the agent
to make minimal changes, run `dart format`, `flutter analyze`, and relevant
tests, and report assumptions.

## Permissions and trust

The plugin contains markdown only. It requests no tool permissions of its
own, defines no hooks, starts no processes, and makes no network calls.
Everything the agent does with it goes through your normal assistant
permission flow.

## Compatibility

| | Supported |
|---|---|
| scroll_spy | 1.x (migration skill also reads 0.1.x/0.2.x projects) |
| Claude Code | v2+ CLI, desktop, and web clients with plugin marketplaces |
| Codex | CLI v0.144+, ChatGPT desktop app (not the IDE extension, not mobile) |
| Plugin version | Matches the package version (both are released together) |

## Update and uninstall

Claude Code:

```
/plugin marketplace update scroll-spy
/plugin update scroll-spy@scroll-spy
/plugin uninstall scroll-spy@scroll-spy
```

Codex:

```bash
codex plugin marketplace upgrade
codex plugin remove scroll-spy@scroll-spy
```

## Troubleshooting

- **Skills do not appear after install:** start a new session; then `/help`
  (Claude) or `/skills` (Codex). In Claude Code, `/plugin` shows installed
  plugins and errors.
- **Marketplace add fails:** the source is the public GitHub repository
  `omar-hanafy/scroll_spy` (git access required); corporate proxies that block
  GitHub will block installation.
- **A skill gives advice that does not match your scroll_spy version:** the
  skills target 1.x. If you are on 0.x, run `migrate-scroll-spy-v0-to-v1`
  first or upgrade manually.
- **Codex IDE extension:** plugins do not load there; use the
  `$skill-installer` flow above to install individual skills for the IDE.

## For maintainers

- Canonical plugin lives in `plugins/scroll-spy/`; Claude Code reads
  `.claude-plugin/plugin.json`, Codex reads `.codex-plugin/plugin.json`, and
  both read the shared `skills/` directory. Repo-level catalogs:
  `.claude-plugin/marketplace.json` (Claude, also read by Codex and Cursor as
  a compatibility fallback) and `.agents/plugins/marketplace.json` (Codex
  native).
- Versions of pubspec.yaml, both plugin manifests, and the Claude marketplace
  entry must match; `dart run tool/validate_ai_plugin.dart` enforces this and
  runs in CI.
- Validate locally: `claude plugin validate . --strict` (marketplace) and
  `claude plugin validate plugins/scroll-spy --strict` (plugin), plus a smoke
  test via `claude --plugin-dir plugins/scroll-spy`.
- Skills must stay self-contained (no `../` references) so single-skill
  installs keep working.
- Every future breaking release adds a dedicated `migrate-scroll-spy-vX-to-vY`
  skill; see AGENTS.md.
