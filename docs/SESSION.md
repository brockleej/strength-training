# RockLog — session handoff

**Parked:** 2026-09-13 (Lee using the phone build). Settings freeze while opening Export is in progress — do not push.  
**Project (only checkout):** `~/Projects/strength-training`  
**App:** RockLog · bundle `com.lee.lift2026`  
**Branch:** `cursor/planned-owns-today-9fdc` (PR #8) · local tip `2d99e99`  
**Do not push** until Lee says the phone Xcode build is good to ship. Pushes to `main` start Xcode Cloud / TestFlight.

> Resume: *“Continue from ~/Projects/strength-training — load docs/SESSION.md. Parked 2026-09-13. Branch planned-owns-today. LAST/PLAN/ACTUAL on Focus when a planned workout is loaded. Last-week coach export. Do not push until asked.”*  
> HA parked: `~/Documents/Hobbies/Home Automation/docs/HA-SESSION.md`.

---

## One folder

All app code lives here:

`~/Projects/strength-training`  
(`~/strength-training` is a symlink to that.)

Removed extra worktrees:

| Old folder | What it was |
|------------|-------------|
| `strength-training-pr7` | PR #7 swipe-delete (branch kept in git: `cursor/swipe-delete-tap-c4d4`) |
| `strength-training-pr8` | This same PR #8 tree, now checked out in the main folder |

Coach files / backups stay in `~/Documents/Hobbies/RockLog` (not source).

Open in Xcode: `~/Projects/strength-training/strength-training.xcodeproj`

---

## Where we left it (2026-09-13)

Lee said the app looks good and will use it, then come back.

On this branch (not on TestFlight yet):

- Planned queue still owns Today while unused sessions wait.
- **Focus sets:** no planned workout → LAST / THIS. Planned workout → LAST / PLAN / ACTUAL (Actual empty until a set is logged).
- Planned targets are not volume, not coach export, not “this week.”
- **Send to RockCoach** (finish + History): This workout / **Last week** (previous Monday–Sunday) / Unsent.

`origin/main` has moved on (TestFlight past 24). Do not merge this branch onto `main` until Lee wants a Cloud build.

---

## Git

| Place | State |
|-------|--------|
| This folder | `cursor/planned-owns-today-9fdc` @ `2d99e99` |
| `origin/main` | Live TestFlight line — do not push this branch there yet |
| PR #8 | https://github.com/brockleej/strength-training/pull/8 — still not pushed with LAST/PLAN/ACTUAL |

---

**Parked 2026-09-13. One checkout: ~/Projects/strength-training. Do not push until Lee asks after phone use.**
