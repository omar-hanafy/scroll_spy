# scroll_spy brand

The scroll_spy mark is called **Primary Rail**. Three offset feed bars form a
subtle vertical `S` rhythm while a fixed horizontal rail crosses the selected
green item. The geometry represents the package's core behavior: items move,
the viewport stays fixed, and one stable primary item wins.

## Masters

- `scroll-spy-mark.svg`: mark for light backgrounds.
- `scroll-spy-mark-dark.svg`: mark for dark backgrounds.
- `scroll-spy-app-icon.svg`: opaque launcher and README icon master.
- `scroll-spy-round-icon.svg`: legacy Android round-icon master.
- `scroll-spy-maskable-icon.svg`: safe-zone PWA icon master.
- `scroll-spy-adaptive-foreground.svg`: transparent Android adaptive foreground.
- `scroll-spy-macos-icon.svg`: rounded macOS icon master.

Run `bash tool/generate_brand_assets.sh` from the repository root to regenerate
all checked-in raster assets.

## Palette

- Field: `#070908`
- Signal: `#4DF477`
- Foreground: `#F2F5EF`
- Inactive line: `#252B26`

## Usage

- Keep clear space around the mark equal to at least one bar height.
- Use the dark-background mark in the website, demo app, and social artwork.
- Use the light-background mark only on white or bone surfaces.
- Keep the lowercase `scroll_spy` wordmark in a monospaced typeface.
- Do not add an eye, radar sweep, play triangle, gradient, glow, or rounded
  container to the standalone mark.
- At 16 pixels, preserve the three bars and center rail. Do not add detail.
