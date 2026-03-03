# BoulderLog iOS App

BoulderLog is an iOS app for logging bouldering sessions and projects, with optional AI-generated 2D problem cards from wall photos.

## Current app structure

- Tabs: `Sessions`, `Library`, `Insights`, `Settings`
- Navigation hierarchy: `Sessions -> Projects -> Project`
- New Project wizard: 6 steps
1. `Photo`
2. `Crop`
3. `Holds`
4. `Preview`
5. `Metadata`
6. `Save`

## Core features

- Session and project tracking with SwiftData persistence
- Manual hold annotation on the cropped wall photo (for logging and visualization)
- Route information controls in Step 3:
1. Grade selection (`V0` to `V10`)
2. Route color selection (`yellow`, `green`, `red`, `blue`, `black`, `white`, `purple`, `orange`, `pink`, `brown`, `gray`, `teal`)
- AI 2D problem card generation in Step 4
- Side-by-side route visuals in review and project detail:
1. Original image (+ optional markers overlay)
2. Generated 2D problem card
- Grade-reactive 2D card frame styling across the full grade range

## AI 2D card pipeline

- Input sent to model:
1. Clean source image (no local annotation overlay data)
2. Selected route color
3. Selected grade context
- Prompt constraints prioritize:
1. Spatial fidelity (highest priority)
2. Hold shape and size fidelity
3. Strict color filtering to selected route color only
- Upload preparation is tuned for quality under a 35s timeout:
1. Fidelity profile: up to 1408px long side, JPEG quality target 0.9, byte cap 2.8MB
2. Fallback profile for resilience if needed
- Generated cards are cached locally and keyed by prompt signature + model.

## Settings

`Settings -> AI Problem Cards` lets you:

- Enable or disable AI generation
- Configure OpenAI API key (or use bundled/default env configuration)
- Choose model preset (`Fast` or `Balanced`)
- Clear generated card cache

## Design system

Reusable UI primitives are in `BoulderLog/Utilities/DojoTheme.swift`:

- `DojoScreen`
- `DojoSurface`
- `DojoButtonPrimary`
- `DojoButtonSecondary`
- `DojoTagChip`
- `DojoSectionHeader`
- `DojoEmptyState`
- `DojoHoldMarker`

## Run locally

1. Open `BoulderLog.xcodeproj` in Xcode.
2. Select scheme `BoulderLog`.
3. Set signing team in target settings.
4. Build and run on iOS (17+ recommended).

## App icon helper

Generate all app icon sizes from one source image:

```bash
cd "/Users/ruilingtu/Codex Projects /Sherpa"
./scripts/generate_appicon.sh /absolute/path/to/your-logo-image.png
```

Then ensure target `App Icons Source` is set to `AppIcon`.
