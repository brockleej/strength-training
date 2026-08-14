# TestFlight — What to Test

Paste into App Store Connect → the build → **Test Details** → **What to Test**.  
There is no API key on this Mac, so this is not pushed automatically.

App Apple ID: `6797695631` · bundle `com.lee.lift2026`

---

## Build 9 (1.0)

```
Build 9 — welcome guide + the logging fixes from 8.

What’s new
• First-run welcome (4 pages). Replay anytime: Settings → Welcome guide.
• Swipe-delete an extra set (full swipe or trash). Sets renumber.
• After the last lift is Done: “Finish this workout?”
• Exercise notes on the lift screen (and Edit exercise).

What to test
• Welcome: Continue through all pages, then Skip on a replay from Settings.
• Log a set by mistake → swipe left → gone, numbers 1…n.
• Tap a set → change it → Update set. Cancel edit leaves it alone.
• Assist (machine help + body weight in Settings), Sides, Warm, ±5/1/0.5 under Weight.
• Mark every lift Done → Finish vs Keep training.
• Add a note, leave the lift, come back — still there.

If something feels off, say which lift and whether last-vs-this was showing.
```

## Build 8 (already processing — paste if 9 is not up yet)

```
Build 8 — swipe-delete extra sets, finish prompt, exercise notes.

What to test
• Log a set by mistake → swipe left → set is gone and remaining sets renumber 1…n.
• Mark every lift Done → “Finish this workout?” → Finish still goes to effort/summary; Keep training stays in the session.
• Add a note on a lift (difficulty / next time / modification), leave Focus, come back — note is still there. Same field on Edit exercise.
```
