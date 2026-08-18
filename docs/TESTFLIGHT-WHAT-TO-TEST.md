# TestFlight — What to Test

Paste into App Store Connect → the build → **Test Details** → **What to Test**,  
**or** drop an API key in `~/Documents/Hobbies/RockLog/secrets/` (see that folder’s README) and we set it from here.

App Apple ID: `6797695631` · bundle `com.lee.lift2026`

---

## Build 12 (1.0)

```
Build 12 — split and order survive reinstall; Progress spreadsheet; welcome rewrite.

What’s new
• Training days and their order now save to iCloud and in Export backup.
• Progress → Lift progression is a side-by-side spreadsheet (names stay, swipe sets).
• First launch should not sit frozen for 20–30 seconds.
• Welcome guide is clearer. Settings order starts with split / Rolling-Weekly.
• Coach send is off unless you turn on Settings → RockCoach.

What to test
• Today: only the days you actually use, in the order you set. No surprise Arms / Full Body.
• Settings → Edit training split: drag a day, leave, come back — order stuck.
• Progress: pick a split day, swipe the numbers sideways. Lift names should not move. Tap a name → lift detail.
• Finish a workout. History still has it. Settings → iCloud still Active.
• Settings → RockCoach should be one switch (off). Turn it on only if you want to try sending a file. That file is not a backup.
• Settings → Welcome guide: skim all four pages. After the welcome, Settings should be the first stop on a new phone.
• (Optional) Export backup after this build. Restore only if you are okay replacing this phone’s log.

If Today grows extra days or the order resets, say which days you had and whether you restored a backup.
```

## Build 11 (1.0)

```
Build 11 — iCloud Retry actually syncs; export skips stay green.

What’s new
• Settings → Retry sync / pull-to-refresh wakes CloudKit (not just “are you signed in?”).
• After a good import, a later “skipped some items” pass no longer replaces Active with a red hiccup.

What to test
• Settings → iCloud: should show Active after launch.
• Wait 2–3 minutes. Prefer still Active (maybe a small gray note), not “Couldn’t sync.”
• Tap Retry sync — spinner, then Active again.
• Finish a workout and confirm History still has it.
```

## Build 10 (1.0)

```
Build 10 — iCloud sync fix for CKError 2.

What’s new
• Session fields that CloudKit needs defaults for (HealthKit id, effort rating).
• Settings shows a readable sync message instead of “CKErrorDomain error 2”.

What to test
• Settings → iCloud Sync: pull to refresh. Prefer “iCloud Sync Active” (or a short English hiccup, not error 2).
• Finish a workout, wait a minute, confirm History still has it.
• If you have a second device on 10, confirm the new session appears.

If it still fails, note the exact Settings sentence and whether iPhone Settings → iCloud storage is full.
```

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
