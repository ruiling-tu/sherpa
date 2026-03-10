# BoulderLog iOS App

BoulderLog is an iOS app for logging bouldering sessions and projects, with locally extracted route blueprints generated from wall photos.

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
- Local route extraction and blueprint export in Step 3 and Step 4
- Side-by-side route visuals in review and project detail:
1. Original image (+ optional markers overlay)
2. Extracted route blueprint
- Grade-reactive 2D card frame styling across the full grade range

## Route extraction pipeline

- Input used locally:
1. Cropped wall photo
2. Selected route color
3. Selected grade and wall angle metadata
- Extraction priorities:
1. Color-guided hold isolation for the selected route color
2. Preservation of hold outline geometry and relative spacing
3. Editable wall outline and draggable hold correction before export
- Output:
1. Persisted vector-like route geometry for each hold
2. PNG export of the current route blueprint

## Settings

`Settings` now documents the local extraction, editing, and export workflow.

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
