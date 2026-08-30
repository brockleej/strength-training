# Planned workouts

What's new: You can add a planned training block from a file. It does not erase your old workouts.

Please try: 1) Settings → Add planned workouts, pick the file. 2) Confirm Add workouts — old history should still be there. 3) Today should show the next planned day. 4) Start it — warmup and work sets should already be filled in. 5) Screenshot anything that looks off.

## Dates

Workouts stay on the dates in the file. The sample starts **Monday 2026-08-31** (Lower A / deadlift), then Mon / Tue / Thu / Fri. Import does **not** move day 1 to today. **Start this block today** is optional — leave it off.

## The file

- Sample (fake lifts only): [fixtures/sample-8-week-block.rocklog.program.json](fixtures/sample-8-week-block.rocklog.program.json)
- Formal schema: [rocklog.program.v1.schema.json](rocklog.program.v1.schema.json)
- This is not a backup. Restore still replaces everything. This is not a RockCoach file.

## What import does

Adds the planned days. Your old workouts, lifts, and split stay. Each day in the file is its own list of lifts — two Lowers in one week can be different (deadlift one day, Romanian the next). A 3-day split trained 4 days a week does not have to restart on Monday.

Lifts match ones you already have (same id, or same name). New names are added; nothing is duplicated on purpose.

## When you train

Start the day type that matches that date. You get that day’s warmups and work sets, not every lift on the day plan. Start a different day and the plan is left alone. If you miss a planned day, it is not saved as a finished workout.

## Later

Rules that rewrite next week from the log are not in this build. See [FOLLOW-UP.md](FOLLOW-UP.md).
