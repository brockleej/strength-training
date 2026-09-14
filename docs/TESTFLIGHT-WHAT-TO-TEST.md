# TestFlight — What to Test

Paste into App Store Connect → the build → **Test Details** → **What to Test**,  
**or** drop an API key in `~/Documents/Hobbies/RockLog/secrets/` (see that folder’s README) and we set it from here.

App Apple ID: `6797695631` · bundle `com.lee.lift2026`

---

## Next TestFlight — after 25 (planned list, split import, AI instructions)

Build 25 is live. This drop is for gym testers — no files or coding needed unless you want to try import.

```
What's new: Planned workouts are a next-up list on Today. Tap a later day to see the lifts before you start. When you log a planned lift you'll see last time, the plan, and what you actually did. You can import a new training split without erasing History, share one Instructions for AI file, pick which workouts to send a coach, and delete leftover planned days. Settings should stay smooth.

Please try (plain gym use):
1) Open Today. If planned workouts are waiting, you should see a next-up list — not the usual day cards. History still has your old sessions.
2) Tap a later workout in that list. You should see the lifts. Start on that screen begins that day. The Home Start button still starts the next unused one.
3) Start a planned workout. On a lift you should see three columns: last time, the plan, and this session (blank until you log a set).
4) Open Settings. It should not freeze. Edit training split is always there — you can still change a day's color or icon while a plan is waiting.
5) Optional — leftover plan: swipe a planned day on Today to delete it, or Settings → Remove unused planned workouts. Finished workouts stay in History.
6) Optional — Settings → Add planned workouts. Add keeps leftover planned days. Replace unused plan swaps them for the new file. History stays.
7) Optional — Settings → Import training split. Days and lifts update. It should not add a new planned list. If a plan is still waiting, choose Keep remaining planned workouts or Remove leftover plan.
8) Optional — Settings → Instructions for AI. You'll get one file you can send to ChatGPT / Grok / etc. You do not need to read it unless you want someone to write a plan or split for you.
9) Optional — Settings → RockCoach → Choose workouts to send (only if you use a coach).
10) Screenshot anything that looks off.
```

Today with a plan: next-up list, tap to preview, Home Start is next unused. Focus: last / plan / actual. Settings: Edit training split always; Import training split; Instructions for AI.

---

## Build 17–19 (1.0)

17, 18, and 19 are the same app (three Cloud jobs 2026-08-26). Testers used **19**. Jump **14 → 19**.


```
Build 17 — gym duration + note keyboard you can actually dismiss.

What’s new
• Workout time is first logged set → last logged set (plus up to 15 minutes after the last set). Idle Start / late Finish no longer make a 200+ minute workout.
• Accidental note keyboard on the lift screen: Cancel/Save stay on screen; drag the list to dismiss. No landscape workaround.
• History rows that stored a huge time show the set span instead.

What to test
• Start, wait a while, then log as usual and Finish. Duration should match the lifting block, not the wait.
• On a lift, tap Add a note so the keyboard opens. Cancel or Save should return you to Log set without rotating the phone.
• Open the two old >200 min History rows — minutes should look like the real gym time.
```

## Build 15–16

Internal / not for testers. 15 was the duration queue; 16 stayed internal. Testers jump 14 → 17.

## Build 14 (1.0)

```
Build 14 — finish always asks effort; duration stays in RockLog; restore no longer crashes an open workout.

What’s new
• Finish a workout (including Done on the last lift) always asks Rate Your Effort. Apple Health no longer has to succeed first.
• Duration is saved on the workout. Older sessions without a Health time use first set → last set, so History should not show “—”.
• Restore while a workout is open should not crash. Export backup is named RockLog-backup-YYYY-MM-DD.json (old strength-training-backup files still restore).

What to test
• Log a real session, lock the phone during rest, then mark the last lift Done → Finish. You should get effort, then a summary with minutes — not a blank duration.
• History for that session (and older ones) should show a duration. Open the session — Duration is a number, not “—”.
• Optional: Settings → Restore a backup with a workout still open. After restore, start or resume a workout. Should not crash.
• Optional: Export backup — filename starts with RockLog-backup-.

If effort is skipped or duration is still blank, note whether Apple Health was on and if the phone locked during the session.
```

## Build 13 (1.0)

```
Build 13 — day plan is yours; first-use picker; restore asks first.

What’s new
• Custom split + which lifts sit on each day persist across backup, restore, and iCloud reinstall.
• First launch (no iCloud split): pick a split or restore a JSON. Then starters or empty days.
• Full Body is a real day with 4 starters, not “every lift in the library.”
• Restore asks Don’t restore vs Replace split and exercises. Cancel does not change the plan.
• Edit a day: swipe left → Remove from that day. Long-press the number to reorder.

What to test
• Fresh install signed into iCloud: your days and lifts come back. No extra unused templates.
• Fresh install not signed in: first screen is Pick a split or restore. Empty days stay empty. Starters are only the short list.
• Settings → Restore: Don’t restore leaves Today unchanged. Replace matches the file (counts and names).
• Edit Push (or Upper): swipe a lift left and remove. Leave, come back — still gone.
• Long-press a lift name → Remove from this day still works.

If defaults reappear on a day you already customized, say whether you restored a file and which one.
```

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
