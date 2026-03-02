# BoulderLog iOS App

BoulderLog is an iOS app for logging bouldering sessions and projects with a manual-first hold marking workflow.

## What is implemented

- Tabs: `Log`, `Library`, `Insights`, `Settings`
- Session list and session detail with project entries
- 5-step New Project wizard: photo, crop, holds, metadata, save
- Project detail with photo overlay, 2D problem card, hold-note editing
- Library filters + search
- Insights charts + rules-based suggestions
- SwiftData persistence + local compressed image storage
- Frosted Dojo visual design system

## Design system

Reusable Dojo components are in:
- `BoulderLog/Utilities/DojoTheme.swift`

Includes:
- `DojoScreen`
- `DojoSurface`
- `DojoButtonPrimary`
- `DojoButtonSecondary`
- `DojoTagChip`
- `DojoSectionHeader`
- `DojoEmptyState`
- `DojoHoldMarker`

## Open and run

1. Open `BoulderLog.xcodeproj` in Xcode.
2. Choose scheme `BoulderLog`.
3. Set your signing team in target settings.
4. Build and run (iOS 17+).

## App logo / AppIcon

The project includes `Assets.xcassets` and an `AppIcon.appiconset` template.

To generate all required icon sizes from your logo source image:

```bash
cd "/Users/ruilingtu/Codex Projects /Sherpa"
./scripts/generate_appicon.sh /absolute/path/to/your-logo-image.png
```

Then in Xcode target build settings, set `App Icons Source` to `AppIcon` if not already set.
