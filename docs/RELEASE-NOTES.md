# RockLog release notes

## 1.0 (10) — 2026-08-14

TestFlight build **10** (marketing version **1.0**). Previous TF upload was **build 9**.

### What’s new

- **iCloud sync:** CloudKit-safe defaults on session HealthKit UUID + effort rating (optional fields without defaults can cause **CKError 2 / PartialFailure** on every pass).
- **Settings:** Sync hiccup copy instead of raw `CKErrorDomain error 2`; shows last full sync; pull to refresh.

Also deploy the container schema **Development → Production** in [CloudKit Console](https://icloud.developer.apple.com/dashboard) for `iCloud.com.lee.lift2026` if you have not already. TestFlight uses Production.

### What to Test

See `docs/TESTFLIGHT-WHAT-TO-TEST.md` (build 10). After install: Settings → iCloud — should go green, or a readable hiccup (not “error 2”).

### Files

- `WorkoutSession.swift`, `CloudKitErrorFormatting.swift`, `CloudKitSyncService.swift`, `SettingsView.swift`

---

## 1.0 (9) — 2026-08-14

TestFlight build **9** (marketing version **1.0**). Previous TF upload was **build 8**.

### What’s new

- **Welcome guide** on first launch (Today, logging controls, History / Progress / Exercises). Replay: **Settings → Welcome guide**.
- Still includes build 8: swipe-delete extra sets, finish-workout prompt, exercise notes.

### What to Test (paste in App Store Connect)

See `docs/TESTFLIGHT-WHAT-TO-TEST.md` (build 9 block). No ASC API key on this Mac — must paste in Test Details.

### Files touched (high level)

- `FirstRunView.swift`, `FirstRunPreferences.swift`
- `ContentView.swift`, `SettingsView.swift` (Help)

### Build / ship checklist

1. Confirm `CURRENT_PROJECT_VERSION` is **greater** than last App Store Connect build (this release: **9**).
2. Local archive + upload (`build/ExportOptions.plist`). Xcode Cloud has been failing.
3. Paste What to Test from `docs/TESTFLIGHT-WHAT-TO-TEST.md`.
4. Wait for processing before re-uploading the same number.

---

## 1.0 (8) — 2026-08-13

TestFlight build **8** (marketing version **1.0**). Previous TF upload was **build 7**.

### What’s new

- **Delete an extra set:** swipe left on a logged set in Focus actually removes it (trash was untappable; full swipe now deletes). Remaining sets renumber.
- **Finish this workout?** After you mark the last lift **Done**, a prompt offers Finish or Keep training.
- **Exercise notes:** on the lift screen (and Edit exercise), jot difficulty / next time / a modification. Sticks on the exercise for the next session.

### What to test

- Log a set by mistake → swipe left → set gone, numbers 1…n.
- Mark every lift Done → confirm dialog → Finish Workout still goes to effort/summary.
- Add a note on a lift, leave Focus, come back — note still there.

### Files touched (high level)

- Swipe: `SwipeToDelete.swift`, `FocusSetsCard.swift`
- Sets: `SetMutation.swift`, `WorkoutViewModel.deleteSet`
- Finish prompt: `WorkoutCompletionLogic.swift`, `FocusFlowView`, `WorkoutTabView`
- Notes: `ExerciseNoteCard.swift`, `FocusView`, `EditExerciseView`
- Tests: `WorkoutSessionLogicTests.swift`

### Build / ship checklist

1. Confirm `CURRENT_PROJECT_VERSION` is **greater** than last App Store Connect build (this release: **8**).
2. Push `main` → Xcode Cloud → TestFlight (or local archive + upload).
3. Wait for processing before re-uploading the same number.

### Later (not this build)

- Fresh **README + App Store screenshots** (`docs/screenshots/` is stale). See `docs/SCREENSHOTS.md`.

---

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
