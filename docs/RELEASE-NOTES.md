# RockLog release notes

## 1.0 (6) — 2026-08-09

TestFlight build **6** (marketing version **1.0**). Previous TF upload was **build 5**.

### What’s new

- **Gym pass + body profile sync to iCloud** (NSUbiquitousKeyValueStore) so membership barcode and height/weight/sex survive reinstall
- **Body profile UX:** draft text fields (no sticky zeros), explicit **Save**, keyboard dismiss in Settings
- **Day-aware Add Exercise:** prefers muscles for the current day plan (Push/Pull/Arms/etc.)
- **Multi-muscle compounds** in catalog seed + `muscleGroupNames` / display helpers; migration for existing library
- Slimmer day plans / library labels using multi-muscle display
- Hydrate gym + body prefs on launch; compound muscle migration in seed path

### Files touched (high level)

- `Services/BodyProfilePreferences.swift`, `GymMembershipPreferences.swift` — Observable stores + KVS
- `Views/Settings/SettingsView.swift`, `GymPassView.swift` — draft/save UX, store bindings
- `Models/DayType.swift`, `Exercise.swift`, `SeedData.swift` — day relevance, multi-muscle, seed
- `Views/Workout/AddExercisePicker.swift` — day-prefer ordering
- Library/progress views — muscle display / minor polish
- `ContentView.swift` — hydrate + migrate on launch

### Build / ship checklist

1. Confirm `CURRENT_PROJECT_VERSION` is **greater** than last App Store Connect build (this release: **6**).
2. `xcodebuild … archive` then export App Store IPA.
3. Upload to TestFlight; wait for processing before re-uploading the same number.
