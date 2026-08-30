# Planned workouts

What's new: You can add a planned training block from a file. It does not erase your old workouts.

Please try: 1) Settings → Add planned workouts, pick the file. 2) Confirm Add workouts — old history should still be there. 3) Today should say **Next up: Lower** (or the first unused day), even if you skipped a calendar day. 4) Start it — warmup and work sets should already be filled in. 5) Screenshot anything that looks off.

## Queue, not calendar

The file is an ordered queue. Missed days stay waiting — they are not skipped or written to History. The sample starts with **Lower A / deadlift**. If you import Sunday and fly past Monday, Start still loads that Lower. The session date becomes the day you actually train. **Start this block today** is optional (slides every date); leave it off. Rolling-on-train is the default either way.

## The file

- Sample (fake lifts only): [fixtures/sample-8-week-block.rocklog.program.json](fixtures/sample-8-week-block.rocklog.program.json)
- Formal schema: [rocklog.program.v1.schema.json](rocklog.program.v1.schema.json)
- This is not a backup. Restore still replaces everything. This is not a RockCoach file.

## What import does

Adds the planned days. Your old workouts stay. After import, RockLog asks if you want to use the block as your training split (days + lifts). Keep my current split leaves Today’s days as they are. Each day in the file is its own list of lifts — two Lowers in one week can be different (deadlift one day, Romanian the next). A 3-day split trained 4 days a week does not have to restart on Monday.

Lifts match ones you already have (same id, or same name). New names are added; nothing is duplicated on purpose.

## When you train

Start the next unused day. You get that session’s warmups and work sets, not every lift on the day plan. Start a different day and the queue is left alone. Missed calendar days stay in the queue and are not saved as finished workouts.

## Later

Rules that rewrite next week from the log are not in this build. See [FOLLOW-UP.md](FOLLOW-UP.md).
