# RockLog — session handoff

**Parked:** 2026-09-13. Split import + combined AI instructions. **Do not push** until Lee asks after a phone Xcode build.

**Project (only checkout):** `~/Projects/RockLog`  
**App:** RockLog · bundle `com.lee.lift2026` (unchanged — same TestFlight app)  
**Branch:** `cursor/planned-owns-today-9fdc` (PR #8)  
**HEAD:** `ed8bd08` Share one AI instructions file for program and split.

> Resume: *“Continue from ~/Projects/RockLog — load docs/SESSION.md. Open RockLog.xcodeproj, scheme RockLog. Test split import and Instructions for AI on the phone. Do not push until asked.”*  
> HA parked: `~/Documents/Hobbies/Home Automation/docs/HA-SESSION.md`.

---

## One folder

`~/Projects/RockLog`  
(`~/RockLog` and `~/strength-training` both symlink here.)

Open: `~/Projects/RockLog/RockLog.xcodeproj` · scheme **RockLog**

GitHub remote is still `brockleej/strength-training` until that repo is renamed.

---

## This session (2026-09-13)

Local commits (not pushed):

- `b578c52` Import a training split from the same program JSON.
- `e37280a` Ask whether to keep leftover planned days after a split import.
- `ed8bd08` Share one AI instructions file for program and split.

**Split import**

- Same JSON as a program file. One change: `"format": "rocklog.split"`.
- Settings → Import training split (same file picker as planned workouts; format picks the path). Sharing the file into the app also works.
- Replaces days and lifts only. Does not create a planned queue. History stays.
- If leftover planned workouts are waiting, a second alert asks **Keep remaining planned workouts?** Keep them / Remove leftover plan.
- First-run restore of a split file: finish setup, then Settings → Import training split.

**Instructions for AI**

- One button, one file: `RockLog-planned-workout-instructions.md`.
- Covers `rocklog.program` (queue) and `rocklog.split` (days + lifts; `sets` may be `[]`).
- Two pasteable prompts at the bottom.

**Still true from earlier today**

- Planned queue owns Today while unused sessions wait. File order, not calendar.
- Focus: LAST / THIS unless a planned workout is loaded, then LAST / PLAN / ACTUAL.
- Today: tap a future queued workout to preview lifts; Start on that screen. Home Start is next unused.
- Send to RockCoach: last week + picker of specific workouts.
- Settings always shows Edit training split. Pull default color is purple (`0xB569FF`).
- Delete leftover planned days: swipe on Today, Delete on preview, or Settings → Remove unused planned workouts.
- Re-import a plan: Add keeps leftovers; Replace unused plan swaps them. History stays.
- Do not auto-delete planned Push/Pull from old History.

---

## Phone test (before push)

Rebuild from Xcode on the device (`RockLog.xcodeproj`, scheme **RockLog**).

- Import a `rocklog.split` file; days/lifts update; no new planned queue.
- If a plan is waiting, confirm Keep vs Remove leftover plan.
- Settings → Instructions for AI shares one file covering both formats.

If Push/Pull are still missing from an old queue, re-add the same plan file (Add, or Replace unused plan).

---

**Do not push until Lee asks after phone use.**
