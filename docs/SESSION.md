# RockLog — session handoff

**Shipped:** 2026-08-20  
**Project:** `~/strength-training`  
**App:** RockLog · bundle `com.lee.lift2026`  
**Marketing version:** 1.0 · **Build:** 14 on TestFlight (uploaded; **VALID**).  
**Git:** `main` — 13/14 work committed locally (see log). Do **not** bump past 14 until the next drop.  
**Branch:** `main`

> Resume: *“Continue from ~/strength-training — load docs/SESSION.md. 14 is live on TestFlight.”*  
> HA parked 2026-08-20 (`~/Documents/Hobbies/Home Automation/docs/HA-SESSION.md`). ASC: attach TF **14** to the 1.0 listing if you want the store icon to follow.

---

## Where we left it

**14 is live for Friends** (ASC `2448ec97-e7ff-46ee-a0b3-1a885dd2066b`, VALID). Archive `build/RockLog-14.xcarchive`. What to Test is set.

Shipped in 14:
- Finish always asks effort (no longer gated on HealthKit UUID).
- Local `durationSeconds`; older sessions infer first→last set so History is not “—”.
- If the live Health session died, write a full start→finish Health workout at Finish. (`workout-processing` rejected by ASC; iPhone cannot use that background mode.)
- Restore-while-open teardown (TF 13 SIGTRAP).
- Export filename `RockLog-backup-YYYY-MM-DD.json`.

RockCoach stays local — do **not** archive or upload it.

---

## What shipped in 12 (since TF 11)

- First launch no longer blocks 20–30s on CloudKit `ModelContainer` in `App.init`. Extra tabs stay unloaded until tapped.
- Split **membership and order** persist to iCloud KVS + backup JSON. Reinstall should not merge leftover bro-split **Arms / Full Body**. Old backups infer days from **sessions**, not the catalog.
- Progress **lift progression** is the coach spreadsheet. Lift names stay; set columns scroll sideways.
- Welcome guide rewritten: five **tabs**, start in Settings, Today vs Home/Resume, verbose logging, Progress matches current metrics.
- Settings order: Edit training split → Rolling/Weekly → Next set default → Progression → Timer → Body profile → Gym pass → RockCoach → Backup → Welcome guide → Apple Health → iCloud.
- Apple Health row opens **Settings → RockLog** after the first ask (no public deep link into Health → Apps).
- **Use RockCoach** is **off**. Send UI hidden until that switch is on. `.rocklogcoach` is for a coach, not a backup.

Notes: `docs/RELEASE-NOTES.md`, tester copy: `docs/TESTFLIGHT-WHAT-TO-TEST.md` (build **14**). User guide: `docs/USER-GUIDE.md`.

---

## Decisions (this thread)

| Topic | Decision |
|---|---|
| One RockLog vs a share-only SKU | **One app.** Share is optional. |
| Share vs backup | **Stay separate.** Coach file ≠ restore. Backup is Settings → Export backup. |
| Coach UI | Hidden behind **Use RockCoach** (default off). One Settings row when off. |
| RockCoach TestFlight | **No.** Local Xcode only. Share extension `RockCoachShare` is part of that app. |
| Isolation warnings | Sit until a real drop (now 14+). |
| Tonnage in coach | **Still no.** Session v1 locked. Batch is sibling `rocklog.coach.batch` v1. |
| Restore-crash fix (T1/T2) | **Shipped in 14.** |
| Backup filename | **Shipped in 14.** `RockLog-backup-YYYY-MM-DD.json`. Old `strength-training-backup-*.json` still restores. |
| Finish effort + duration | **Shipped in 14.** Effort even if HK UUID missing. Local duration; infer old sessions from sets. |

Path 1: `docs/coaching-companion/PATH-1.md`.

---

## How 12 actually got to TestFlight

`main` → GitHub **does** start Xcode Cloud (workflow on `main`). Cloud **run #11** is *not* TestFlight 11 — it is the 11th Cloud job. It archived commit `c0bc533` (app version **12**) and **failed** at App Store upload:

> The bundle version must be higher than the previously uploaded version.

Same failure on Cloud runs 4–10. Cloud’s own next-build number is behind hand-uploaded 11/12.

**12 testers have** is a **local** `xcodebuild archive` + `ExportOptions.plist` upload (`build/`). What to Test via `~/Documents/Hobbies/RockLog/scripts/asc-set-what-to-test.sh 12`.

**13 testers should get** a local `xcodebuild archive` to `build/RockLog-13.xcarchive` (see below). `ci_scripts/ci_pre_xcodebuild.sh` pins Cloud’s RockLog version to **max(13, CI_BUILD_NUMBER)** so a push to `main` should not fail with “bundle version must be higher.” RockCoach stays at **1**.

---

## Next (not now)

- Phone: install **14**, finish a session (lock the phone during rest), confirm effort + duration. History should show minutes on old sessions too.
- Optional: attach TF **14** to ASC 1.0 listing icon.
- **iCloud UI:** still later — quiet status only.
- Screenshots still stale (`docs/SCREENSHOTS.md`).
- Push `main` when you want GitHub to match TestFlight (Xcode Cloud upload is still behind; TF is local archive).

**ASC API (local, not in git):** `~/Documents/Hobbies/RockLog/secrets/` + `source …/scripts/asc-env.sh`.

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
| `docs/RELEASE-NOTES.md` | TF / ship notes |
| `docs/coaching-companion/` | Path 1 + locked schemas |
| `CLAUDE.md` | Architecture + build commands |

**CloudKit:** `iCloud.com.lee.lift2026`  
**Pushing `main` starts Xcode Cloud.** Treat `main` as release. Cloud upload is currently broken on version; TF still needs a local archive or a Cloud number bump.

### Build

```bash
cd ~/strength-training
open strength-training.xcodeproj
xcodebuild -scheme strength-training -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme RockCoach -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Ship RockLog (when you mean it):

```bash
xcodebuild archive -scheme strength-training -configuration Release \
  -destination generic/platform=iOS -archivePath build/RockLog-14.xcarchive \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=53AH938CUW
xcodebuild -exportArchive -archivePath build/RockLog-14.xcarchive \
  -exportPath build/export-14 -exportOptionsPlist build/ExportOptions.plist \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=53AH938CUW
~/Documents/Hobbies/RockLog/scripts/asc-set-what-to-test.sh 14
```

---

## One-line

**Shipped 2026-08-20. RockLog 1.0 build 14 VALID on TestFlight. RockCoach local.**
