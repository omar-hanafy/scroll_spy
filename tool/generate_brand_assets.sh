#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
brand_root="$repo_root/brand"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1" >&2
    exit 1
  fi
}

require_tool rsvg-convert

if command -v magick >/dev/null 2>&1; then
  image_tool="magick"
elif command -v convert >/dev/null 2>&1; then
  image_tool="convert"
else
  echo "Missing required tool: magick or convert" >&2
  exit 1
fi

render_square() {
  local source="$1"
  local size="$2"
  local output="$3"
  mkdir -p "$(dirname "$output")"
  rsvg-convert --width "$size" --height "$size" "$source" --output "$output"
  "$image_tool" "$output" -strip "$output"
}

app_master="$brand_root/scroll-spy-app-icon.svg"
round_master="$brand_root/scroll-spy-round-icon.svg"
maskable_master="$brand_root/scroll-spy-maskable-icon.svg"
adaptive_master="$brand_root/scroll-spy-adaptive-foreground.svg"
macos_master="$brand_root/scroll-spy-macos-icon.svg"
mark_dark_master="$brand_root/scroll-spy-mark-dark.svg"

# README and pub.dev-rendered package content.
render_square "$app_master" 1024 "$repo_root/screenshots/scroll_spy.png"

# Crawlable product site.
cp "$mark_dark_master" "$repo_root/website/assets/scroll-spy-mark-dark.svg"
render_square "$app_master" 512 "$repo_root/website/assets/scroll-spy-icon.png"
render_square "$app_master" 16 "$repo_root/website/assets/favicon-16.png"
render_square "$app_master" 32 "$repo_root/website/assets/favicon-32.png"
render_square "$app_master" 180 "$repo_root/website/assets/apple-touch-icon.png"
render_square "$app_master" 192 "$repo_root/website/assets/icon-192.png"
render_square "$app_master" 512 "$repo_root/website/assets/icon-512.png"
render_square "$maskable_master" 512 "$repo_root/website/assets/icon-maskable-512.png"
rsvg-convert --width 1200 --height 630 \
  "$repo_root/website/assets/social-preview.svg" \
  --output "$repo_root/website/assets/social-preview.png"
"$image_tool" "$repo_root/website/assets/social-preview.png" -strip \
  "$repo_root/website/assets/social-preview.png"

# Flutter example runtime and web install surfaces.
render_square "$mark_dark_master" 512 "$repo_root/example/assets/scroll_spy_mark.png"
render_square "$app_master" 32 "$repo_root/example/web/favicon.png"
render_square "$app_master" 192 "$repo_root/example/web/icons/Icon-192.png"
render_square "$app_master" 512 "$repo_root/example/web/icons/Icon-512.png"
render_square "$maskable_master" 192 "$repo_root/example/web/icons/Icon-maskable-192.png"
render_square "$maskable_master" 512 "$repo_root/example/web/icons/Icon-maskable-512.png"

# Android legacy launcher icons.
for density_and_size in \
  "mdpi:48" \
  "hdpi:72" \
  "xhdpi:96" \
  "xxhdpi:144" \
  "xxxhdpi:192"; do
  density="${density_and_size%%:*}"
  size="${density_and_size##*:}"
  render_square "$app_master" "$size" \
    "$repo_root/example/android/app/src/main/res/mipmap-$density/ic_launcher.png"
  render_square "$round_master" "$size" \
    "$repo_root/example/android/app/src/main/res/mipmap-$density/ic_launcher_round.png"
done
render_square "$adaptive_master" 432 \
  "$repo_root/example/android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png"

# iOS launcher icons. The marketing icon remains opaque, as required by Apple.
for file_and_size in \
  "Icon-App-20x20@1x.png:20" \
  "Icon-App-20x20@2x.png:40" \
  "Icon-App-20x20@3x.png:60" \
  "Icon-App-29x29@1x.png:29" \
  "Icon-App-29x29@2x.png:58" \
  "Icon-App-29x29@3x.png:87" \
  "Icon-App-40x40@1x.png:40" \
  "Icon-App-40x40@2x.png:80" \
  "Icon-App-40x40@3x.png:120" \
  "Icon-App-60x60@2x.png:120" \
  "Icon-App-60x60@3x.png:180" \
  "Icon-App-76x76@1x.png:76" \
  "Icon-App-76x76@2x.png:152" \
  "Icon-App-83.5x83.5@2x.png:167" \
  "Icon-App-1024x1024@1x.png:1024"; do
  filename="${file_and_size%%:*}"
  size="${file_and_size##*:}"
  render_square "$app_master" "$size" \
    "$repo_root/example/ios/Runner/Assets.xcassets/AppIcon.appiconset/$filename"
done

# iOS launch artwork.
render_square "$mark_dark_master" 168 \
  "$repo_root/example/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png"
render_square "$mark_dark_master" 336 \
  "$repo_root/example/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png"
render_square "$mark_dark_master" 504 \
  "$repo_root/example/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png"

# macOS launcher icons use a transparent canvas around a rounded field.
for size in 16 32 64 128 256 512 1024; do
  render_square "$macos_master" "$size" \
    "$repo_root/example/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png"
done

echo "Generated scroll_spy brand assets from $brand_root"
