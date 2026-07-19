#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="$repo_root/build/pages"
mkdir -p "$repo_root/build"
staging_root="$(mktemp -d "$repo_root/build/pages-stage.XXXXXX")"
staging_site="$staging_root/scroll-spy"

cleanup() {
  rm -rf -- "$staging_root"
}
trap cleanup EXIT

bash "$repo_root/tool/generate_brand_assets.sh"

cd "$repo_root/example"
flutter build web --release --wasm --base-href /scroll-spy/demo/

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
grep -Fq '<base href="/scroll-spy/demo/">' "$staging_site/demo/index.html"

mkdir -p "$build_root/scroll-spy"
rsync -a --delete "$staging_site/" "$build_root/scroll-spy/"

echo "Pages bundle: $build_root/scroll-spy"
