#!/usr/bin/env bash
set -euo pipefail

# Assembles the published product site into a single directory that can be
# uploaded verbatim as a GitHub Pages artifact.
#
# The site is a hybrid: `website/` is hand-authored source committed to this
# repository, and `demo/` is the Flutter web build of `example/`, produced here
# and never committed. Both halves land in one tree so the authored pages can
# link to `demo/` with a plain relative href.
#
# The site is served from https://omar-hanafy.github.io/scroll_spy/, so the
# demo has to be compiled for that subpath. Leading and trailing slashes are
# both required by `flutter build web --base-href`.
SITE_BASE="${SITE_BASE:-/scroll_spy/}"
DEMO_BASE="${SITE_BASE}demo/"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="$repo_root/build/pages"
mkdir -p "$repo_root/build"
staging_site="$(mktemp -d "$repo_root/build/pages-stage.XXXXXX")"

cleanup() {
  rm -rf -- "$staging_site"
}
trap cleanup EXIT

# Brand assets are regenerated from brand/ by tool/generate_brand_assets.sh and
# committed, so this build consumes them rather than re-rendering them. That
# keeps the published bytes identical to the reviewed bytes and keeps an image
# toolchain out of the deploy path.

cd "$repo_root/example"
flutter build web --release --wasm --base-href "$DEMO_BASE"

mkdir -p "$staging_site/demo"
rsync -a --exclude .DS_Store "$repo_root/website/" "$staging_site/"
rsync -a --exclude .DS_Store "$repo_root/example/build/web/" "$staging_site/demo/"
touch "$staging_site/.nojekyll"

test -f "$staging_site/index.html"
test -f "$staging_site/comparison.html"
test -f "$staging_site/guides/flutter-video-autoplay-feed.html"
test -f "$staging_site/site.webmanifest"
test -f "$staging_site/assets/favicon-16.png"
test -f "$staging_site/assets/apple-touch-icon.png"
test -f "$staging_site/assets/scroll-spy-mark-dark.svg"
test -f "$staging_site/demo/main.dart.wasm"
test -f "$staging_site/demo/assets/assets/scroll_spy_feed.mp4"
test -f "$staging_site/demo/assets/assets/scroll_spy_mark.png"
test -f "$staging_site/demo/icons/Icon-maskable-512.png"

mkdir -p "$build_root/site"
rsync -a --delete "$staging_site/" "$build_root/site/"

echo "Pages bundle: $build_root/site"
