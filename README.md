# BoulderLog iOS MVP (Milestones 1-5)

Implemented UX and screen requirements:
- Tabs: `Log`, `Library`, `Insights`, `Settings`
- Log flow: session list, create session, session detail, add project
- New Project Wizard (5 steps): Photo, Crop, Holds, Metadata+Notes, Save
- Project detail: photo overlay toggle, 2D problem card, metadata/tags, per-hold editor
- Library: list + filters + notes search
- Insights: max sent grade per month, attempt volume, distributions, dynamic suggestions

## Persistence

- Uses SwiftData models:
  - `SessionEntity`
  - `ProjectEntryEntity`
  - `HoldEntity`
- Repository layer with CRUD:
  - sessions
  - entries
  - holds
- Image persistence helper:
  - compressed JPEG save/load/delete in app Documents

## Correctness-critical rendering

- Shared transform utility (`ImageSpaceTransform`) is used for:
  - tap-to-normalized hold coordinates
  - overlay rendering on photo
  - consistent position mapping across devices
- 2D problem card uses normalized coordinates and role-specific colors for start/finish/normal.

## Seed Data

- First launch inserts sample session + project + holds for testability.

## Run

1. Create or open your iOS app target in Xcode (iOS 17+).
2. Add all files under `/Users/ruilingtu/Codex Projects /Sherpa/BoulderLog` into the target.
3. Ensure these privacy keys are present in Info.plist:
   - Camera usage description
   - Photo library usage description
4. Build and run.
