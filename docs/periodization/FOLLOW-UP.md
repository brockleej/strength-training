# Periodization — follow-up (not this PR)

This PR is the foundation only: a `rocklog.program` block, merge import, start-from-plan, and no fake-complete of missed days.

Do **not** build these here:

- Coach-AI / auto-periodizer that writes next week from the log
- Progression rules that rewrite upcoming planned sessions after a trained day
- Deleting or swapping a whole block from Settings
- Silently rewriting the library day plan or A/B labels to match the block
- Treating the day-plan catalog as the workout list when a dated session already has a roster

When that work starts, keep session-level plans as the source of truth. A later pass can mark a missed day skipped and optionally generate the next week’s targets from completed work.
