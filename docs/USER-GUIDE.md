# RockLog user guide

Log the session. Own the data. See the trend.

Five tabs sit at the bottom: **Workout**, **History**, **Progress**, **Exercises**, **Settings**.  
**Today** (Home) is the Workout tab when you are not in a session. After **Start**, that tab becomes the workout overview, then a lift screen for each exercise.

---

## Getting started

### First open

1. On a **new phone** (no iCloud split yet) you pick a training split or restore a JSON backup. Starter lifts are optional; empty days stay empty. Full Body is four lifts, not the whole catalog.
2. Allow **Apple Health** if you want finished sessions on your rings. You can skip this and turn it on later in Settings.
3. Open **Settings** once before the first gym visit. You can change any of this later.

### Setup (do this first)

| In Settings | Why |
|-------------|-----|
| **Next set default** | How RockLog fills the next set after you log. See [Auto-fill](#auto-fill-settings--logging). |
| **Rest timer** | Default countdown after a set. You can still turn rest off on a single lift (supersets). |
| **Progression** | How quickly suggested weight/reps move up after consistent sessions. |
| **Edit training split** | Your days (Push, Legs, …) and order. Drag to match the week you actually train. |
| **Body profile → weight** | Required for **Assist** math (body weight minus machine help). Height + sex unlock body-fat / FFMI on Progress. Tap **Save**. |
| **Gym pass** | Membership number for the barcode on Today. Syncs with iCloud. |

**Exercises** already has a starter catalog, grouped by day. Add, rename, or assign lifts whenever you want. Custom notes and A/B week labels live there too.

Then go back to **Workout** — that is Today.

The first time you open RockLog you get a short **welcome** (same topics as this guide). Replay it anytime: **Settings → Welcome guide**.

---

## Today (Home)

This is the Workout tab with no session running.

**Header**
- Today’s date and **Today**.
- **Gym pass** (barcode) — fullscreen membership card at check-in. Set the number in Settings.

**Planned workouts** (when a training block is waiting)
- Today shows the next unused workouts as a simple list. The rolling split and **Edit [day] list** are hidden until that list is empty.
- **Start** begins the first unused workout. History is unchanged.

**What are you training?** (when there is no planned list)
- One card per day in your split. Tap to select.
- A checkmark means that day is already done this week (strict weekly schedule).
- If you left a session mid-way, the matching day can show how many lifts were in progress.

**Week rotation** (only if any lift is labeled A or B)
- **A week** / **B week**. Shared lifts stay on **Every** and always appear.
- Label lifts A/B in **Exercises**.

**Start**
- **Start [Day] · [A/B]** begins a session and opens the workout overview.
- **Resume …** if that day already has a parked session.
- Starting a *different* day while another has logged sets asks before discarding the old one.

**Edit [Day] list** — change that day’s lifts without starting a workout.

**Cancel workout** — appears if something is parked. Discards an unfinished live session (not History).

**Last session** — the most recent finished workout (volume, sets, PRs). Tap to open the same detail as History.

**This week** — session count, volume, set count, and a Mon–Sun strip.

If last week’s split was incomplete, Today may ask whether to finish remaining days, restart the week, or switch to rolling splits.

---

## Workout overview

After **Start**, the Workout tab is the session list — your map of the hour.

**Top**
- **Home** — leave without finishing. The session stays parked; Today offers **Resume**.
- Day name and **X of Y exercises complete**. Complete means you tapped **Done** on the lift, not “you logged N sets.”
- **⋯** — reorder / edit the day plan, or cancel the workout.

**Strength / Endurance**
- **Strength** = heavier, fewer reps. **Endurance** = lighter, more reps.
- Suggestions and last-session comparison follow the mode you pick.

**Week rotation** (if you use A/B)
- **A / B / All** mid-session if you need the other week’s lifts.

**Each lift row**
- Name, last session (or tap that line to flip to the progression **target**).
- Tap the row to open logging (Focus).
- Swipe left → **Remove from this workout** (today only) or **Remove from [day]** (drops it from that day’s plan; stays in the library).
- Long-press for edit / replace.

**Add exercise** — pull in a library lift or create a new one for today only (or assign it to this day).

**Finish Workout** (bottom)
- Saves the session to History, then **Rate Your Effort**, then the summary (duration, volume, sets, PRs).
- When every lift is marked **Done**, RockLog also asks **Finish this workout?** so you do not have to hunt for the button.
- Duration is **first set → last set** (plus a short wrap-up). Starting early or tapping Finish hours later does not make a 200-minute workout. If Health was interrupted (phone locked), you still get effort and a time.

---

## Logging a workout

Tap a lift. This is **Focus** — weight, reps, rest, and this session vs last time.

### Sets

The table is **last vs this** when you have history.

- **Last** — tap a previous set to load it into the steppers.
- **This** — what you logged today.
- Swipe a this-session set **left** to delete it (full swipe or trash). Remaining sets renumber.
- **History** (below) expands older sessions.

**Add a note** under the lift name — difficulty, “next time,” a modification. It stays on that exercise for the next session. Same field is on **Edit exercise**.

### Weight, assist, and step size

**Weight** stepper is the left tile.

- **− / +** change the load. Hold to repeat.
- Tap the small **± 5** (or ± 1 / ± 0.5) under the number to change the plate step: **5 → 1 → 0.5 → 5**. Use 0.5 for fractional plates.
- If the tile is iced with an arrow (for example **+5 lb**), that is the progression suggestion vs last time. The first −/+ you tap clears the highlight and you are in control.

**Assist** (chip under the weight)
- Turn on for assisted bodyweight work (pull-up / dip machine, etc.).
- Type the **machine assistance** (the “−100 lb” on the stack), not the bar.
- Tonnage and e1RM use **body weight − assist**. Set body weight in Settings or the math is 0.
- RockLog remembers Assist on that lift.

### Reps and sides

**Reps** stepper is the right tile.

**Sides** (chip under reps)
- On = you did that many reps **each side** (lunges, DB rows).
- Volume counts both sides. The set shows **×2** / **EA**.

### Warm, Log, Done

Bottom row:

| Control | What it does |
|---------|----------------|
| **Warm** | Tags the next log as a warm-up. Warm-ups are excluded from PRs and progression. Shows **W** on the set. |
| **Log set** | Saves the current weight × reps. Steppers then refill for the next set ([Auto-fill](#auto-fill-settings--logging)). Rest starts if that lift has the timer on. |
| **Done** | Marks **this lift** finished (any set count, including zero to skip). Jumps to the next unfinished lift. **Next** in the header skips Done lifts too. **Resume** un-dones a lift so you can add sets. |

When the last lift is **Done**, you get **Finish this workout?** / **Keep training**.

**Next** / chevron in the header moves between lifts without marking Done.

### Editing a set

1. Tap a logged **this** set (pencil on the row).
2. Steppers load that set. The big button becomes **Update set**.
3. Change weight, reps, Warm, Assist, or Sides → **Update set**.
4. **Cancel edit** leaves the set as it was.

Logging a new set or updating one also un-dones the lift if you had already tapped Done.

### Rest

The rest card is **per lift**.

- Tap the timer label to turn **auto-rest on/off for this exercise** (off is handy in a superset until the last movement).
- **Start** runs a manual countdown even if auto-rest is off.
- While running: **−30**, **+30**, **Skip**.
- Default length and sounds are in [Settings → Rest timer](#getting-started). Ticks are audio-only (no notification spam).

---

## Auto-fill (Settings → Logging)

After each **Log set**, steppers seed the next set from:

| Next set defaults to | Best for |
|----------------------|----------|
| **Last session** (default) | Ramps. Set 1 matches last time’s set 1 (often 135), set 2 matches set 2 (225), and so on. |
| **Last set** | Straight sets. After 225 × 5, the next log stays 225 × 5. |

First set of a lift also uses last session, recent average, and the progression suggestion. Ice on the stepper means “this is the suggested bump.”

Change this anytime; it applies to the next log, not past sets.

---

## History

Finished workouts only. Incomplete / cancelled sessions do not appear.

- Month groups, filter chips, and a small all-time strip.
- Each row: day, date, volume, sets, PR badges.

**Open a session**
- Lifts and sets, comparison to similar days, Apple Health stats if you saved them.
- **Send to RockCoach** (paper plane) sends this workout to your coach. Not a backup — see [RockCoach](#rockcoach).
- **Edit** reopens that session on the Workout tab. Sets stay in History the whole time. When you are done, **Save Changes** (same as Finish).

Swipe a History row to delete a workout (you will be asked). That is permanent.

---

## Progress

Trends across finished sessions — not a live workout screen.

- **Range** at the top (for example 1 month / 3 months).
- **Strength score** — sum of best estimated 1RMs (Epley) across lifts. The badge is change vs a month ago. This is *strength*, not “total pounds moved.”
- **Workouts** and **working sets** in the selected range.
- **Workouts** chart — frequency over time.
- **Body** — log weight, waist, neck, etc. Navy body-fat and FFMI if height + sex are saved.
- **PRs this month**.
- **Sets by muscle**.
- **Strength vs endurance** — how you split set counts.
- **Lift progression** — spreadsheet of the last few sessions of a split day (same layout as RockCoach). Tap a lift name for the e1RM line (toggle top weight) and PR marks.

Progress only moves when you **Finish** sessions.

---

## Exercises

Your library — not today’s session.

- Grouped by home day; **Unassigned** is library-only.
- Search by name or muscle.
- **+** creates a lift.
- Tap a row to **edit**: name, home days, A/B week (**Every** / **A** / **B**), muscles, **note**.
- Swipe: **remove from this day** (soft) or **delete from the library** (asks first; history may show a missing name).

Assigning a lift to Push (and maybe Legs) is what makes it show on Today and on that day’s workout list. A/B labels hide it on the other week unless you pick **All** mid-session.

Day order and which days exist are **Settings → Edit training split**. The list of lifts *on* a day is Exercises, **Edit [Day] list** on Today, or **Reorder / edit day plan** on the workout overview.

---

## RockCoach

Off by default. If nobody coaches you in **RockCoach**, leave **Settings → RockCoach → Use RockCoach** off. Send buttons stay hidden on the summary and in History; only that one switch remains in Settings.

If someone *does* coach you, turn **Use RockCoach** on, then send finished workouts as a `.rocklogcoach` file (Messages, Mail, AirDrop, or Files). They import the file in RockCoach.

**These files are for your coach, not a backup of RockLog.** They carry lifts and working sets so RockCoach can show progression. They do not restore your library, split, or history.

### Send a workout

- After **Finish**, the summary **paper plane**: **This workout** or **Unsent workouts**.
- History → open a session → paper plane (that workout only).
- **Settings → RockCoach**
  - **Use RockCoach** — show or hide the rest of this feature.
  - **Your name on coach files** — printed on the file, not your Apple ID.
  - **Offer to send after finish** — opens the send sheet when you finish a live workout (not when you save a History edit).
  - **Send last workout to coach**
  - **Send unsent workouts** — everything finished that you have not sent yet.

One workout is a session file. Two or more unsent workouts go as one batch file. Send the attachment — do not paste the file as text.

**Save to Files** in the system sheet keeps a copy of what you sent. That is still a coach file, not a restore.

### Backup (save / export)

**Settings → Backup** is how you save or move *this* phone’s log.

- **Export backup** — JSON of the library, split, day plans, and sessions. The file is named `RockLog-backup-YYYY-MM-DD.json`. Older `strength-training-backup-*.json` files still restore.
- **Restore from backup** — asks before replacing your current split and exercises. **Don’t restore** leaves this phone as-is.

Use this for safekeeping or another device. Do not restore a `.rocklogcoach` file.

### Planned workouts

A planned-workout file (`.rocklogprogram` or a JSON whose format is `rocklog.program`) adds upcoming days with the target sets already filled in. It does **not** replace your history. After you add the file, RockLog asks if you want to **use this as your training split** (days + lifts on each day). **Keep my current split** leaves Today’s days as they are.

- **Settings → Add planned workouts**, or open the file from Files / a share sheet.
- Confirm **Add workouts**. Then choose **Use this split** or **Keep my current split**. The file is a queue — missed gym days stay next up. **Start this block today** is optional (slides every date); you do not need it for rolling-on-train.
- Today shows **Next up: Lower** (or whatever is first unused). Start that day to load those ramps and work sets — not every lift on the day plan. Two Lowers in one week can be different (deadlift first, Romanian later).
- Starting a different day leaves the queue alone.
- A missed calendar day is not saved as a finished workout. History uses the day you actually trained.

---

## Quick reference

| I want to… | Do this |
|------------|---------|
| Start training | Workout tab → pick day → **Start** |
| Leave and come back | **Home** → later **Resume** |
| Log a set | Open lift → **Log set** |
| Fix a wrong set | Tap the set → change it → **Update set**, or swipe to delete |
| Skip a lift | **Done** with zero sets |
| Finish the hour | **Finish Workout**, or **Done** on the last lift — then rate effort |
| Assisted pull-ups | **Assist** on + body weight saved |
| Each-side lunges | **Sides** on |
| Warm-ups | **Warm** on, then **Log set** |
| Change plate jumps | Tap **± 5 / 1 / 0.5** under weight |
| Change how the next set fills | Settings → **Next set default** |
| Membership barcode | Today → **Gym pass** |
| Fix yesterday’s weights | History → session → **Edit** |
| Show or hide coach send | Settings → **RockCoach** → **Use RockCoach** |
| Send a workout to your coach | Turn Use RockCoach on, then summary or History paper plane |
| Save / move this phone’s log | Settings → **Export backup** |
| Add planned workouts | Settings → **Add planned workouts**, or open the file |
