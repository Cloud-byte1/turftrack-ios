# fairLie logo & app icon prompts

The shipped icon lives at `TurfTrack/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
(1024×1024, opaque, no alpha channel, no rounded corners).

## Brand palette

| Token | Hex | Use |
| --- | --- | --- |
| Green deep | `#11623C` | Icon gradient start, headers |
| Green | `#1B9B5E` | Primary actions, gradient end |
| Gold | `#F4D232` | Swing-path accent |
| Cream | `#F7F5EF` | App background |
| Ink | `#14201A` | Body text |

## Primary app icon prompt

> A premium iOS App Store app icon for a golf strike-training app. Perfectly square,
> completely full-bleed edge to edge, no rounded corners, no white corners, no
> transparency, no border, no outer padding — the background must reach all four
> corners and edges. Background: rich golf-green diagonal gradient from #11623C in
> the top-left to #1B9B5E in the bottom-right filling the entire square. Centered
> symbol: a clean white golf ball with subtle dimples resting on a short white tee,
> with a single bold golden-yellow #F4D232 swoosh arc sweeping upward from lower-left
> to upper-right behind the ball to suggest a swing path. Flat vector, minimal,
> geometric, crisp edges, high contrast. No text, no letters, no words, no numbers.
> Generous inner spacing so the symbol reads clearly at small sizes.

### Why each constraint matters

- **Full-bleed square, no rounded corners** — iOS applies the squircle mask itself.
  An icon that already has rounded corners renders with visible dark corner wedges.
- **No transparency / no alpha** — App Store Connect rejects icons with an alpha
  channel. Export as 24-bit RGB PNG.
- **No text** — the app name already appears under the icon on the Home Screen, and
  small text turns to mush at 40×40.
- **Generous inner spacing** — the icon is displayed as small as 29 pt in Settings.

## Variant prompts

**Monochrome / tinted icon (iOS 18+ dark and tinted Home Screen modes):**

> The same golf ball on a tee with a swoosh arc behind it, rendered as a single
> solid white silhouette on a pure black square background. Full-bleed square, no
> rounded corners, no transparency, no text. Flat vector, high contrast, chunky
> shapes that stay legible when scaled down.

**Wordmark lockup (marketing site, support page, press kit):**

> A horizontal logo lockup on a transparent background. On the left, a compact
> circular badge with a #11623C to #1B9B5E green gradient containing a white golf
> ball on a tee with a golden-yellow #F4D232 swing arc. To the right, the lowercase
> wordmark "fairLie" in a modern geometric sans-serif, with "fair" in #14201A and
> "Lie" in #1B9B5E, capital L. Clean, minimal, generous letter spacing, vector.

**App Store screenshot background plate:**

> A subtle vertical gradient background from #F7F5EF cream at the top to #EDEAE0 at
> the bottom, with a very faint large golden-yellow swing arc at 6% opacity sweeping
> across the lower third. No text, no objects, no vignette. Portrait 9:16.

## Export checklist

1. Generate at 1024×1024 or larger, then downsample to exactly 1024×1024.
2. Flatten onto an opaque background and export 24-bit PNG (no alpha channel).
3. Replace `AppIcon-1024.png` in the asset catalog; Xcode generates the smaller sizes.
4. Preview at 40×40 to confirm the ball and arc are still distinguishable.
