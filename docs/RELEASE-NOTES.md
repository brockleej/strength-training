# RockLog release notes

There is no separate `CHANGELOG`. This file is the release log. The Xcode project’s `CURRENT_PROJECT_VERSION` for the RockLog app target is still **17**, while the notes below talk about build 25 and “next after 25.” The live TestFlight build number is not recorded in this repo.

## Next TestFlight — branch `cursor/optimization-build` (PR #13, draft), Branch Test green at `f075801`

Not merged to main and not on TestFlight. Adds on top of `a877aad`. Tester wording is in `docs/testflight-notes-next.txt`. `CURRENT_PROJECT_VERSION` is still 17 in the project; Xcode Cloud assigns the uploaded build number.

### What’s new

- **Body weight is dated.** Each set stores the body weight it used (`bodyWeightUsedLbs`). Assisted and added-load lifts use the latest weigh-in on or before the set, then the session date, then the Settings number. A later or backdated weigh-in no longer rewrites old assisted e1RMs or PRs. Logging a weight updates the Settings number only to the newest weigh-in by date.
- **Load modes:** Bar, Assist (body weight minus assistance), and Added (body weight plus a belt or chain). Relative strength (e1RM ÷ body weight) on the lift’s progress page.
- **Kilograms:** Settings → Units. The set keeps the unit and value you typed, so a kg → lb → kg round trip shows the same kilograms and does not fire a false PR. Plate math for kg bars and pairs.
- **Gyms and machine stacks:** Settings → Gyms / Gym Access (barcode pass on Today, optional when-in-use location to pick the nearest gym, camera barcode scan). Per-gym, per-lift stack steps, pins and offsets; offers snap to the stack. Same-weight carry onto later sets with one undo.
- **Workout order and groups:** drag to reorder during a workout; supersets / circuits of 2–4; rest follows the lift you just did and learns your real rests after 8 sets.
- **Rest alert:** one chirp at zero, re-arms at 10 s, skips the chirp during a call, mixes with an audiobook. The Live Activity countdown is built (`RockLogWidget`) but **off in this build**: the extension is not embedded, `FeatureFlags.liveActivity` is false and the app `Info.plist` has `NSSupportsLiveActivities` false (see `docs/specs/rest-widget.md`).
- **Warm-ups:** the Warm tag no longer copies onto the next set; warm-ups stay out of e1RM, PRs, suggestions and carry. Optional Suggest warm-ups.
- **No crash** when Log set is tapped with no live workout (was `fatalError`).
- **Starting weight / Previous:** the plan wins; Previous mirrors Next.
- **Versioned interchange file** (`docs/format/`): backup v2 with gyms, stack profiles and set units. v1 files are promoted; v0 and future versions are refused; unknown keys are counted.
- **Store:** SwiftData `RockLogSchemaV1 → V3` in **one** lightweight stage (Lee, Oct 30, checklist #47). V3 adds Gym, MachineStackProfile, the session’s gym, stack and rest fields, body weight used and the entered unit and value on sets, all defaulted. A V2 store from a pre-release development build opens through Core Data’s inferred lightweight migration (`RockLogMigrationPlan.openContainer`). The new record types must exist in the **production** CloudKit schema before TestFlight users sync them.
- **Stage 1–3 UI:** system swipe-to-delete with Undo, workouts open past midnight, files checked before anything is removed; RockCoach month table uses the coach file’s time zone; Retry when the store fails to open; Last/Target buttons; Settings split into pages; Programs on the Workout tab; a workout bar on every tab; Appearance Dark / Light / System.
- **Fixes in this branch’s last commits:** split and day-plan rows open reliably on the iPhone 18 Pro Max (`0c3bd34`); UI tests scroll to lazy Settings rows and the Import-split scroll is timed from the top with a 15 s bound (`d1fd4ad`, `f075801`); Xcode Cloud’s post-build script fails a test action on a non-zero xcodebuild exit and uses a committed unit-test floor (`d1fd4ad`, `b616bb0`).

### Known, deferred

- `GymAccessSettingsView.swift:309` warning becomes an error under Swift 6.
- AVAudioSession is set up on the main thread (runtime warning).

## On main, not on TestFlight yet — `eb497bd` (PR #9)

Merged 2026-10-24. **Do not paste this into App Store Connect until a TestFlight build includes it.** Tester wording is in `docs/TESTFLIGHT-WHAT-TO-TEST.md` under the same heading.

### What’s new

- **Backup file** now includes body measurements and planned programs, plus the library, split, day plans, and sessions.
- An older backup that does not have those sections leaves measurements and programs already on the phone. A file that includes an empty list clears them.
- Restore is one save. If the save fails, the phone is unchanged.
- A file with bad numbers, a duplicate id, or a measurement kind the app does not know is refused. Nothing is changed.
- A lift with a training mode this version does not understand is skipped. The app says how many.
- A lift you have only logged once suggests a weight on the 5 lb grid (137.3 lb becomes 135).
- Two workouts saved with the same date stay in a stable order (session id), so the next suggestion does not flip.
- The on-device store is versioned (`RockLogSchemaV1`). No data is rewritten. The next schema change needs a second version.

### What to test

See `docs/TESTFLIGHT-WHAT-TO-TEST.md` (on main, not TestFlight yet).

## On main, not on TestFlight yet — `a877aad` (PR #10)

Merged 2026-10-24. **Do not paste this into App Store Connect until a TestFlight build includes it.** Tester wording is in `docs/TESTFLIGHT-WHAT-TO-TEST.md` under the same heading.

### What’s new

- The this-month / last-month card counts a workout in one month only.
- A workout logged at the exact start of a month belongs to the month that is starting. It no longer also appears in the month before.
- The same rule is on the RockCoach table. February (including a leap day) and daylight-saving months still follow the phone’s calendar.

### What to test

See `docs/TESTFLIGHT-WHAT-TO-TEST.md` (on main, not TestFlight yet).

## 1.0 (next after 25) — 2026-09-13

TestFlight after **25**. RockCoach stays local (not on TestFlight).

### What’s new

- **Planned list owns Today** while unused sessions wait (file order, not calendar). Tap a later queued workout to preview lifts; Home Start is still the next unused day.
- **Focus:** LAST / THIS normally; LAST / PLAN / ACTUAL when a planned workout is loaded.
- **Split import:** Settings → Import training split. Same JSON family with `"format": "rocklog.split"`. Days and lifts only; asks whether to keep leftover planned workouts. History stays.
- **Instructions for AI:** one Settings share file covering program and split.
- **Leftover plan:** swipe on Today, delete on preview, or Settings → Remove unused planned workouts. Re-import can Add or Replace unused plan.
- **RockCoach:** send last week, or pick specific workouts.
- **Settings** stays usable during a planned block; Edit training split remains. Pull default color is purple.
- Last-day keep and per-muscle strength score from build 25 are still in this drop.

### What to Test

See `docs/TESTFLIGHT-WHAT-TO-TEST.md` (next after 25). Paste into App Store Connect after the Cloud build is VALID.

---

## 1.0 (17) — 2026-08-26

TestFlight / App Store listing screenshots. Testers jump **14 → 17** (15 queued internally; 16 internal only).

### What’s new

- **Duration:** first logged set → last logged set (plus ≤15 min after the last set). Idle Start / late Finish no longer inflate gym time. Old >200 min History rows show the set span.
- **Note keyboard:** on the lift screen, Cancel/Save stay reachable; drag the list to dismiss. No landscape workaround.
- **Listing screenshots:** Today, workout list, Focus, Progress, History, Exercises from a real log (`docs/screenshots/`).

### What to Test

See `docs/TESTFLIGHT-WHAT-TO-TEST.md` (build 17).

---

## 1.0 (14) — 2026-08-20

TestFlight build **14**. Previous: **13**. RockCoach stays local (not on TestFlight).

### What’s new

- **Finish:** marking the last lift Done still asks to finish, then **always** asks for effort. Apple Health no longer has to succeed first.
- **Duration:** saved on the workout (not only Apple Health). Older sessions without a stored time use first→last set. History / summary / Today last-session time should no longer show "—".
- **Apple Health:** if the live session dies (locked phone), RockLog still writes the full start→finish window so Health duration matches the gym session.
- **Restore:** tearing down the workout tab before a backup restore so an open session does not crash (TF 13 SIGTRAP).
- **Export:** `RockLog-backup-YYYY-MM-DD.json`. Old `strength-training-backup-*.json` still restores.

### What to Test

See `docs/TESTFLIGHT-WHAT-TO-TEST.md` (build 14).

---

## 1.0 (13) — 2026-08-18

TestFlight build **13**. Previous: **12**. RockCoach stays local (not on TestFlight).

### What’s new

- **Day plan:** your split and which lifts sit on each day survive backup, restore, and iCloud reinstall. Starter templates are not pinned back onto a split you already set.
- **First use:** pick a split or restore a JSON backup. If you pick a split, choose starter exercises or empty days. Full Body is a real roster (squat / press / row / overhead), not a catch-all.
- **Restore:** asks before overwrite. **Don’t restore** leaves this phone as-is. **Replace split and exercises** swaps the plan, library, and history.
- **Edit day:** swipe left uses the system swipe (same as Exercises) to remove a lift from that day. Long-press the number to reorder; long-press the name for the menu.

### What to Test

See `docs/TESTFLIGHT-WHAT-TO-TEST.md` (build 13).

---

## 1.0 (12) — 2026-08-17

TestFlight build **12**. Previous: **11**. RockCoach stays local (not on TestFlight).

### What’s new

- **Launch:** first open after install no longer freezes 20–30s on CloudKit store setup. Tabs besides Workout stay unloaded until you tap them.
- **Split:** Today days and their **order** are saved to iCloud and included in **Export backup**. Reinstall should not add leftover Arms / Full Body from the default seed. Restore no longer invents extra days from the exercise catalog.
- **Progress:** lift progression is a spreadsheet of recent sessions for each split day (same layout as RockCoach). Lift names stay on the left; swipe sets sideways. Tap a name for the existing lift detail.
- **Welcome:** five tabs named as tabs; start in Settings; Today vs Home/Resume spelled out; logging in full sentences; Progress matches current metrics (strength score, frequency, body, PRs this month, sets by muscle, split spreadsheet).
- **Settings:** new order — training split, Rolling/Weekly, next set, progression, timer, body, gym pass, RockCoach, backup, welcome, Apple Health, iCloud. Health row opens Settings → RockLog when access is already decided.
- **RockCoach send (off by default):** Settings → RockCoach → **Use RockCoach**. Hidden unless you turn it on. Files are for a coach, not a backup.

### What to Test

See `docs/TESTFLIGHT-WHAT-TO-TEST.md` (build 12). Confirm Today still has *your* days in *your* order, Progress names stay put when you swipe, and Settings → RockCoach is a single off switch.

---

## 1.0 (11) — 2026-08-14

TestFlight build **11**. Previous: **10**.

### What’s new

- **iCloud:** pull-to-refresh and **Retry sync** actually poke CloudKit (10 only re-checked sign-in).
- A later export “partial failure” after a good import stays **green** with a quiet “skipped some items” line — that is iCloud retrying, not lost workouts.

### What to Test

Settings → iCloud: after launch should go **Active**. If a warning appears a minute later, it should stay Active (not flip to a red hiccup). Tap **Retry sync**.

---

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

- Fresh **README + App Store screenshots**. Those frames were recaptured for the 2026-08-26 listing (`docs/SCREENSHOTS.md`). They still predate the planned-workout list.

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
