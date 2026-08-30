# Periodization — follow-up (not this PR)

This PR is the foundation only: a `rocklog.program` block, merge import, start-from-plan, and a queue of unused sessions (missed calendar days are not consumed).

Do **not** build these here:

- Coach-AI / auto-periodizer that writes next week from the log
- Progression rules that rewrite upcoming planned sessions after a trained day
- Deleting or swapping a whole block from Settings
- Silently rewriting the library day plan or A/B labels to match the block
- Treating the day-plan catalog as the workout list when a dated session already has a roster

When that work starts, keep session-level plans as the source of truth. Do not treat file dates as a calendar that burns unused days. A later pass can optionally generate the next week’s targets from completed work.
