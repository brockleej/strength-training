# RockLog — session handoff

**Status (2026-10-24):** The 2026-09-13 planned-workout work below is on `main` (merge `a4179c1` and the commits it names). It is no longer an unpushed local branch.

**On `main`, not on TestFlight yet:** `eb497bd` (pull request #9) — backup includes body measurements and planned programs, restore rolls back on failure, schema `RockLogSchemaV1`, 5 lb rounding after one session, stable same-date order. Tester text is in `docs/TESTFLIGHT-WHAT-TO-TEST.md` under “do not paste.”

**Not merged:** pull request #10 — this-month / last-month table counts midnight on the 1st in both months.

**Spec, not built:** [docs/specs/units-bodyweight-machine-stacks.md](specs/units-bodyweight-machine-stacks.md).

**App:** RockLog · bundle `com.lee.lift2026`  
GitHub remote is still `brockleej/strength-training`.

The machine path `~/Projects/RockLog` below was Lee’s checkout in September 2026. This file does not claim that path is the only copy.

---

## One folder (September 2026 note)

Lee’s machine that night:

`~/Projects/RockLog`  
(`~/RockLog` and `~/strength-training` both symlinked there.)

Open: `RockLog.xcodeproj` · scheme **RockLog**

GitHub remote is still `brockleej/strength-training`.

---

## Shipped on main (2026-09-13 session)

These commits are on `main`. The “not pushed” note from that night is out of date.

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

## Phone check that went with that drop

- Import a `rocklog.split` file; days/lifts update; no new planned queue.
- If a plan is waiting, confirm Keep vs Remove leftover plan.
- Settings → Instructions for AI shares one file covering both formats.

If Push/Pull are still missing from an old queue, re-add the same plan file (Add, or Replace unused plan).

The “do not push until Lee asks” line from that night applied to the September branch. It does not describe `main` now.
