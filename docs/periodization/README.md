# Periodization (v1 foundation)

RockLog can import a **planned training block** and you lift against it. History stays.

## File

- Format name: `rocklog.program`
- Schema version: `1`
- Formal schema: [rocklog.program.v1.schema.json](rocklog.program.v1.schema.json)
- Extension: `.rocklogprogram` (JSON also works)
- Sample (fake lifts only): [fixtures/sample-8-week-block.rocklog.program.json](fixtures/sample-8-week-block.rocklog.program.json)

This is **not** a backup. Restore still replaces the store. This is **not** a RockCoach file (those are finished sessions going out).

## How import works

1. Settings → **Add planned workouts**, or open the file from Files / a share sheet.
2. Confirm: “Add 8 weeks of planned workouts? This does not replace your history.”
3. RockLog inserts upcoming planned days with target sets (`isWarmup` honored).
4. Existing completed sessions, the exercise catalog, and the split are left alone.
5. Lifts match by UUID, then by name. A name already in the library is reused.

Import shifts the block so the first day lands on **today**.

Each dated session is its own roster. The same day type can appear twice in a week with different lifts (Lower + Conventional Deadlift, then Lower + Romanian Deadlift). A running 3-day split trained 4 days a week (Lower → Push → Pull → Lower, then continue — no Monday reset) is valid. Import does **not** merge sessions by day type or week.

## Lifting against the plan

Starting the matching day type on a planned date loads **that date’s** target sets (ramps show as warm-ups), not the whole day-plan catalog. Starting a different day type leaves the plan alone.

Missing a planned day does **not** mark it completed. It stays planned until it expires as skipped. History only shows trained work.

## Follow-up

Progression that rewrites next week from the log is stubbed in [FOLLOW-UP.md](FOLLOW-UP.md).
