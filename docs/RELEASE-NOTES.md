# RockLog release notes

## 1.0 (7) — 2026-08-11

TestFlight build **7** (marketing version **1.0**). Previous TF upload was **build 6**.

### What’s new

- **Rest timer audio-only:** no more stacked local notification banners on each countdown tick; tones via background audio only; clears legacy rest-timer notifications on launch
- **Readable past sets:** larger weight × reps on history strip, last-vs-this column, workout list “Last” line, last-session card
- **Mid-workout lift edits:** swipe left to remove a lift from this workout; Focus ⋯ **Replace exercise**; clearer list hint
- **Next-set defaults (Settings → Logging):** **Last session** (by set #, good for 135→225→315 ramps) or **Last set** (straight sets); default Last session
- **Settings reorganized:** Logging / Rest / Progression / Training days / Gym pass / Body / Health / iCloud / Backup; shorter footers
- **Progress overhaul:** strength score + workout/set counts instead of total volume tonnage; workouts-over-time bars; sets by muscle; mode split by set count
- **Exercise drill-down:** primary **e1RM line** (toggle top weight) with PR markers; clearer captions

### Files touched (high level)

- Rest timer: `RestTimerNotificationScheduler.swift`, `strength_trainingApp.swift`
- Prefill: `SetPrefillPreferences.swift`, `FocusTargetLogic.swift`, `FocusView.swift`, tests
- Workout list/Focus: `ExerciseListView`, `FocusView`, `SwipeToDelete`, fonts on strip/cards
- Progress: dashboard + drill-down view models/charts
- Settings: `SettingsView.swift`

### Build / ship checklist

1. Confirm `CURRENT_PROJECT_VERSION` is **greater** than last App Store Connect build (this release: **7**).
2. `xcodebuild … archive` then export App Store IPA (upload).
3. Wait for processing before re-uploading the same number.

---

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
