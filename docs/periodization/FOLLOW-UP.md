# Periodization — follow-up

The foundation is on `main`: a `rocklog.program` block, import, start-from-plan, and a queue of unused sessions (missed calendar days are not consumed).

## Already in the app

- **Remove unused planned workouts** (Settings, swipe on Today, or delete on the preview). Finished workouts stay in History.
- Re-import can **Add** (keep leftovers) or **Replace unused plan**.
- **Import training split** replaces days and lifts and asks before removing a leftover plan.
- Adding a program file asks **Use this as your training split?** That prompt is at import time. Edit training split does not offer it again. An older draft of this note and the user guide described a preset-list button for that. The button is not in the app.
- A planned session’s own roster is the workout list (`followsSessionRoster`). The day-plan catalog is not substituted.

## Still not built

- Coach-AI / auto-periodizer that writes next week from the log
- Progression rules that rewrite upcoming planned sessions after a trained day
- A later control that applies an already-imported block as the split without re-importing the file
- Silently rewriting the library day plan or A/B labels to match the block

When that work starts, keep session-level plans as the source of truth. File dates are not a calendar that burns unused days. A later pass can optionally generate the next week’s targets from completed work. Units, bodyweight loads, machine stacks, in-workout reorder, and rest groups are specified separately in [../specs/units-bodyweight-machine-stacks.md](../specs/units-bodyweight-machine-stacks.md).
