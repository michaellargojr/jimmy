# Jimmy for iOS

Native SwiftUI rebuild of the workout logger. Same data model, progression rules and
seed history as the web app in the repo root, so a web export (Settings › Export)
imports here unchanged.

## Open and run

1. Open `ios/Jimmy.xcodeproj` in Xcode 16 or newer.
2. Pick an iPhone simulator (or your phone) and press Run.
3. For a real phone, set your team under Signing & Capabilities once.

Requires iOS 17.

## Layout

- `Jimmy/Model`: the types (`Models.swift`), progression rules (`Overload.swift`), history derivations, workout builder.
- `Jimmy/Data`: `AppStore` (one JSON file in Documents, debounced writes), settings, the export snapshot.
- `Jimmy/Seed`: the Notion history, the exercise library, the set-line parser.
- `Jimmy/Theme`: palettes (dark and light, five accent schemes).
- `Jimmy/Views`: Home, Workout, Plan, History, Settings.
- `JimmyTests`: the overload rules, parser and seed, mirroring `src/overload.test.ts`.

The project uses Xcode's folder-synchronized groups, so adding a Swift file under `Jimmy/` adds it to the target.
