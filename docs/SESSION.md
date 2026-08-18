# RockLog — session handoff

**Parked:** 2026-08-17  
**Project:** `~/strength-training`  
**App:** RockLog · bundle `com.lee.lift2026`  
**Marketing version:** 1.0 · **Build:** 12 on TestFlight (VALID)  
**Git:** `main` at `c0bc533` on GitHub; local isolation-warning commit may sit on top — **do not push** until the next real 13.  
**Branch:** `main`

> Resume: *“Continue from ~/strength-training — load docs/SESSION.md, README.md, docs/RELEASE-NOTES.md, CLAUDE.md.”*  
> HA is parked. ASC: RockLog 1.0 still has **build 11** selected on the store listing (Prepare for Submission). Attach **12** if you want the listing icon to follow. Aequis 1.0 has build 2 attached (not submitted).

---

## Where we left it

RockLog **12** is live for internal **Friends** testers. What to Test is set. RockCoach is **in the repo only** — scheme `RockCoach`, bundle `com.lee.rockcoach`. Do **not** archive or upload it.

Isolation/`nonisolated` cleanups on coach helpers landed after 12 (warnings only). Sit on them until the next real change. Testers do not need a 13 for that.

---

## What shipped in 12 (since TF 11)

- First launch no longer blocks 20–30s on CloudKit `ModelContainer` in `App.init`. Extra tabs stay unloaded until tapped.
- Split **membership and order** persist to iCloud KVS + backup JSON. Reinstall should not merge leftover bro-split **Arms / Full Body**. Old backups infer days from **sessions**, not the catalog.
- Progress **lift progression** is the coach spreadsheet. Lift names stay; set columns scroll sideways.
- Welcome guide rewritten: five **tabs**, start in Settings, Today vs Home/Resume, verbose logging, Progress matches current metrics.
- Settings order: Edit training split → Rolling/Weekly → Next set default → Progression → Timer → Body profile → Gym pass → RockCoach → Backup → Welcome guide → Apple Health → iCloud.
- Apple Health row opens **Settings → RockLog** after the first ask (no public deep link into Health → Apps).
- **Use RockCoach** is **off**. Send UI hidden until that switch is on. `.rocklogcoach` is for a coach, not a backup.

Notes: `docs/RELEASE-NOTES.md`, tester copy: `docs/TESTFLIGHT-WHAT-TO-TEST.md` (build 12).

---

## Decisions (this thread)

| Topic | Decision |
|---|---|
| One RockLog vs a share-only SKU | **One app.** Share is optional. |
| Share vs backup | **Stay separate.** Coach file ≠ restore. Backup is Settings → Export backup. |
| Coach UI | Hidden behind **Use RockCoach** (default off). One Settings row when off. |
| RockCoach TestFlight | **No.** Local Xcode only. Share extension `RockCoachShare` is part of that app. |
| Isolation warnings | **Do not burn a TF 13** on them. |
| Tonnage in coach | **Still no.** Session v1 locked. Batch is sibling `rocklog.coach.batch` v1. |

Path 1: `docs/coaching-companion/PATH-1.md`.

---

## How 12 actually got to TestFlight

`main` → GitHub **does** start Xcode Cloud (workflow on `main`). Cloud **run #11** is *not* TestFlight 11 — it is the 11th Cloud job. It archived commit `c0bc533` (app version **12**) and **failed** at App Store upload:

> The bundle version must be higher than the previously uploaded version.

Same failure on Cloud runs 4–10. Cloud’s own next-build number is behind hand-uploaded 11/12.

**12 testers have** is a **local** `xcodebuild archive` + `ExportOptions.plist` upload (`build/`). What to Test via `~/Documents/Hobbies/RockLog/scripts/asc-set-what-to-test.sh 12`.

Next Cloud ship: set Cloud **next build number ≥ 13**, or keep uploading from this Mac after bumping `CURRENT_PROJECT_VERSION` to **13**. Do not push a docs-only commit expecting Cloud to ship 12 again.

---

## Next (not now)

On the **next real** RockLog drop (build **13+**):

- Bump `CURRENT_PROJECT_VERSION` in the **strength-training** target only (not RockCoach).
- Include the parked `nonisolated` coach-format cleanup if not already committed.
- **iCloud UI:** remove Settings **Retry sync** and pull-to-refresh-as-resync. Quiet status only (signed in / last synced / real failure). Don’t flip red on a later retryable export after a good import.
- Optional: attach TF **12** (or 13) to ASC version 1.0 so the store header icon follows.
- Optional: set Xcode Cloud next build number to 13+ if you want Cloud to succeed.
- Screenshots still stale (`docs/SCREENSHOTS.md`).
- Friends testers **Invited** may still need a resend / correct Apple ID.

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
  -destination generic/platform=iOS -archivePath build/RockLog.xcarchive \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=53AH938CUW
xcodebuild -exportArchive -archivePath build/RockLog.xcarchive \
  -exportPath build/export -exportOptionsPlist build/ExportOptions.plist \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=53AH938CUW
~/Documents/Hobbies/RockLog/scripts/asc-set-what-to-test.sh 13
```

---

## One-line

**Parked. RockLog 1.0 (12) on TestFlight. RockCoach local. Isolation warning fix not shipped. Next drop is 13.**
