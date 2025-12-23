# Repository Workflow Preferences

This document is my default policy for how I manage all published package repos.

## Branch model
- main: stable releases only; pubspec version must be X.Y.Z (no pre-release suffix).
- dev: pre-releases only; pubspec version must include a suffix (e.g., -dev.1, -beta.1, -rc.1).
- feature branches: all work happens here; no direct work on main or dev.

## PR-only merges
- No direct pushes to main or dev.
- PRs require code owner approval (1 approval).
- Admins cannot bypass protections.

## Required checks (blocking)
- Flutter CI: format, analyze, test on stable and beta (beta is non-blocking but must report).
- Pub dry-run: `flutter pub publish --dry-run`.
- Pana: full score only.
- Version channel: main requires stable versions; dev requires pre-release versions (release PRs only).
- Release PRs (version bump) are auto-labeled `release`.

## Release and publishing
- On merge to main or dev, create tag `scroll_spy-v<version>` and a GitHub Release if pubspec.yaml version changed.
- main releases: standard release (not prerelease).
- dev releases: prerelease.
- Tag must match pubspec.yaml version exactly.
- Fail if the tag already exists.
- Publishing uses OIDC Trusted Publisher on pub.dev.

## Tagging and versioning
- main uses stable semver (X.Y.Z).
- dev uses pre-release semver (X.Y.Z-dev.N, X.Y.Z-beta.N, X.Y.Z-rc.N).
- Version bumps are required only for release PRs.

## Branch protection settings
- Require status checks to pass and use strict mode.
- Required checks: "Test on stable", "Test on beta", "pub-dry-run".
- Require code owner reviews and dismiss stale approvals on new pushes.
- Block force pushes and branch deletions.

## Notes
- If publish fails after a tag, bump the version and re-release; avoid deleting tags.
- Keep this file in each repo and update the package/tag prefix where needed.
