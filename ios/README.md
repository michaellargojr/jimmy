# Jimmy for iOS

Native SwiftUI rebuild of the workout logger. Same data model, progression rules and
seed history as the web app in the repo root, so a web export (Settings › Export)
imports here unchanged.

## Open and run

1. Open `ios/Jimmy.xcodeproj` in Xcode 16 or newer.
2. Pick an iPhone simulator (or your phone) and press Run.
3. For a real phone, set your team under Signing & Capabilities once.
4. The lock screen card is a second target, JimmyWidgets: set the same team on it once. Free signing covers it.

Requires iOS 17.

## Layout

- `Jimmy/Model`: the types (`Models.swift`), progression rules (`Overload.swift`), history derivations, workout builder.
- `Jimmy/Data`: `AppStore` (one JSON file in Documents, debounced writes), settings, the export snapshot.
- `Jimmy/Seed`: the Notion history, the exercise library, the set-line parser.
- `Jimmy/Theme`: palettes (dark and light, five accent schemes).
- `Jimmy/Views`: Home, Workout, Plan, History, Settings.
- `JimmyTests`: the overload rules, parser and seed, mirroring `src/overload.test.ts`.

The project uses Xcode's folder-synchronized groups, so adding a Swift file under `Jimmy/` adds it to the target.

## Versions and release notes

- **Version** (`MARKETING_VERSION`) is major.minor.patch, as the App Store shows it. Every install on Michael's phone gets a new one: a new minor (2.2) when it adds or changes something you'd notice, a patch (2.2.1) when it only fixes the last install, a new major (3.0) for a big turn such as going public. A reinstall of the same code (the 7-day free-signing refresh) keeps both numbers.
- **Build** (`CURRENT_PROJECT_VERSION`) goes up by one with every install and never resets. App Store uploads must have a higher build number than the last one. 2.0 and 2.1 both went out as build 1; the latest numbers are at the top of `CHANGELOG.md`.
- Both numbers live on two targets, the app (Jimmy) and the lock screen card (JimmyWidgets), and must match on both, since an extension's version has to equal its app's.
- Settings shows both at the bottom, read from the app ("Jimmy 2.2 - Build 2"), so nothing is typed in by hand.
- **`CHANGELOG.md`** is the record: newest first, a few plain lines per version written for anyone using the app, ready to paste into the App Store's "What's New in This Version" (4000 characters max; the App Store takes none for an app's first version). Internal details go in the HTML comment under each heading. Text style: "-" between items, never an em dash or "·".
- **Each PR** fills in the "Release note" section of the PR template: one plain line, or "None".
- **The install step** (whoever builds for the phone): collect the release notes of the PRs merged since the last entry, add the new version at the top of `CHANGELOG.md`, and bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` for Debug and Release of both the Jimmy and JimmyWidgets targets, in one commit on the iOS branch before building. Then build and install from that commit.
