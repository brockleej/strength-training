# RockLog — session handoff

**Parked:** 2026-08-27 (re-closed 2026-08-29 — switched to HA)  
**Project:** `~/strength-training` (dirty checkout — leave it) · PR 7 worktree: `~/strength-training-pr7`  
**App:** RockLog · bundle `com.lee.lift2026`  
**Marketing version:** 1.0 · **Testers now:** **19** (VALID; 17/18 same app). **Next drop:** after 24 — swipe trash tap (this PR) on top of planned workouts + split edit.  
**Git:** `origin/main` = `e29d871`. This branch `cursor/swipe-delete-tap-c4d4`. Local `~/strength-training` is `main` at `1c68df8` (docs-only, not pushed) — **do not checkout or mutate that tree**.  
**Branch:** `cursor/swipe-delete-tap-c4d4` (PR 7). **Do not merge or push `main`.**

> Resume: *“Continue from ~/strength-training-pr7 — load docs/SESSION.md. Parked 2026-08-27, re-closed 2026-08-29 (HA). Testers: TF 19. Next: swipe trash + planned split. Listing 1.0 still Prepare for Submission.”*  
> HA parked: `~/Documents/Hobbies/Home Automation/docs/HA-SESSION.md`.

---

## Where we left it

**TestFlight live:** 17, 18, 19 all VALID (2026-08-26). Three Cloud jobs from three `main` pushes the same day. Testers still on **19**. 16 was internal only. Jump **14 → 19**.

**Product on `origin/main` + this PR (not the live tester build yet):**
- Planned blocks import as an unused-session queue — dates and lift lists stay; history is not wiped. Sample: `docs/periodization/fixtures/sample-8-week-block.rocklog.program.json`.
- After Add planned workouts: **Use this as your training split?** can replace days/lifts; History stays (`#6`).
- Monthly overload recap on Progress and RockCoach.
- Split editing is back: swipe a lift off a day; swipe a day off the split (confirm Delete day); long-press the number to reorder (press-without-drag must not freeze).
- **This PR:** swipe-left trash on Edit training split / Edit [day] actually removes the row. Build 24 showed trash; the tap did nothing.

**What to Test:** keep the PR 7 / `origin/main` “Next TestFlight” in `docs/TESTFLIGHT-WHAT-TO-TEST.md` (trash tap after 24). Do **not** replace it with the TF 19 rewrite from local `1c68df8`.

**Shipped in 17+ (what testers have):**
- Duration is first logged set → last logged set (≤15 min wrap-up). Old 200+ min History rows show the set span.
- Lift-note keyboard: footer hides while editing; Cancel/Save stay on screen; scroll dismisses. No landscape workaround.
- Listing screenshots from a real 2026-08-26 backup.

**GitHub:** README screenshots are current. Agent briefing is **`AGENTS.md`** (stub `CLAUDE.md` points there). RockCoach icon PNG is `docs/screenshots/rockcoach-app-icon.png` (GitHub/local; not a TestFlight asset).

**App Store Connect 1.0** — *Prepare for Submission* (`cd4e6907-…`). **Not ready to submit.**

| Item | Status |
|------|--------|
| iPhone 6.9" screenshots (6) | COMPLETE on listing |
| App previews | Empty — optional |
| Age 4+, name, subtitle | Done |
| Description, keywords, support URL, privacy URL | **Missing** |
| Category, copyright, App Review contact | **Missing** |
| Build attached to the listing | Still **11** — attach a current TF when you mean 1.0 |
| iPad 13" screenshots | None (app is iPhone+iPad) |

Release type: **after approval** (you tap Release when Apple says yes).

RockCoach stays GitHub/local only. Cloud must stay on the RockLog scheme. `ci_pre_xcodebuild.sh` fails if Cloud is pointed at RockCoach and pins RockLog to `max(17, CI_BUILD_NUMBER)`.

---

## Decisions (keep)

| Topic | Decision |
|---|---|
| One RockLog vs share-only SKU | **One app.** Share is optional. |
| Share vs backup | **Stay separate.** Coach file ≠ restore. Backup is Settings → Export backup. |
| Coach UI | Hidden behind **Use RockCoach** (default off). |
| RockCoach TestFlight | **No.** Source is on GitHub; run it from Xcode. Share extension `RockCoachShare` is part of that app. |
| Tonnage in coach | **No.** Session v1 locked. Batch is sibling `rocklog.coach.batch` v1. |
| Duration | Set span, not Start→Finish wall. **In 17+/19.** |
| Note keyboard | Cancel/Save on the lift screen. **In 17+/19.** |
| Restore-crash + backup filename | **Shipped in 14.** `RockLog-backup-YYYY-MM-DD.json`. |
| Finish effort | **Shipped in 14.** Even if HK UUID missing. |
| Isolation warnings | Sit until a real drop. |
| Doc-only `main` pushes | Avoid — each one archives a new TF build. |

Backup used for shots: `~/Documents/RockLog-backup-2026-08-26.json`. Body check-in is **sim only** (6′3.75″, 231.5, waist 37.5, neck 17, chest 49, arm 17.5). Phone unchanged.

Path 1: `docs/coaching-companion/PATH-1.md`.

---

## Next (not now)

- Land PR 7 (swipe trash tap) when tests are green; **do not merge/push `main` from the dirty checkout.**
- Next Cloud job on `main` is the next tester build (What to Test = trash tap after 24, plus planned-block split from `#6`).
- Fill listing: description, keywords, support URL, privacy URL, category, copyright, review contact.
- Attach a current TF build to the 1.0 listing when you mean to submit (not 11).
- iPad 13" screenshots if 1.0 ships iPhone+iPad.
- Optional: one 15–30s app preview (886×1920). Not required.
- When Submit is enabled → Waiting for Review → after approval, **Release this version**.

**ASC API (local, not in git):** `~/Documents/Hobbies/RockLog/secrets/` + `source …/scripts/asc-env.sh`.  
What to Test: `~/Documents/Hobbies/RockLog/scripts/asc-set-what-to-test.sh <build>`.

---

## Project map

| Path | Role |
|------|------|
| `strength-training/` | RockLog (SwiftUI + SwiftData + CloudKit) |
| `strength-training-tests/` | Unit tests |
| `Shared/Algorithm/` | Pure progression algorithm |
| `Shared/CoachFormat/` | session/batch codec + compare grid |
| `RockCoach/` | Companion (local): roster, import, spreadsheet |
| `RockCoachShare/` | Share extension → App Group `group.com.lee.rockcoach` → `rockcoach://inbox` |
| `progression-lab/` | macOS algo lab (local only) |
| `docs/screenshots/` | README + `asc-6.9/` + `rockcoach-app-icon.png` |
| `docs/RELEASE-NOTES.md` | TF / ship notes |
| `docs/coaching-companion/` | Path 1 + locked schemas |
| `AGENTS.md` | Architecture + build (Claude stub: `CLAUDE.md`) |

**CloudKit:** `iCloud.com.lee.lift2026`  
**Pushing `main` starts Xcode Cloud.** Treat `main` as release. Pin: `ci_pre_xcodebuild.sh` `max(17, CI_BUILD_NUMBER)`.

### Build

```bash
cd ~/strength-training-pr7   # or the dirty checkout only if you intend to touch it
open strength-training.xcodeproj
xcodebuild -scheme strength-training -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme RockCoach -destination 'platform=iOS Simulator,name=iPhone 17' build
```

---

## One-line

**Parked 2026-08-27 (re-closed 2026-08-29 — HA). Testers: TF 19. Next: swipe trash + planned split (PR 7 / origin/main). Listing 1.0 not submittable (copy + privacy URL + attach a current build).**
