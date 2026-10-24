# Units, body weight, machine stacks, workout order, rest, and the lift screen

Spec only. No code in this change. Nothing in this file has shipped.

Audience: Lee, before anyone builds it. Tester-facing copy waits until a build exists.

| | What Lee gets |
| --- | --- |
| **a** | A kilograms / pounds setting. One stored unit. Plate math in both. |
| **b** | Body weight over time, used for bodyweight lifts and for strength relative to body weight. |
| **c** | A saved stack for each machine, so a target rounds to a weight the stack can actually load, and reps move to keep the effort. |
| **d** | Drag exercises into a new order during the workout. The session keeps that order. Saving it back to the day or the program is a separate choice. |
| **e** | Groups of two to four exercises. Logging a set moves to the next one in the group and comes back around. Rest follows the exercise just finished, and each lift has its own default rest. |
| **Focus** | A starting-weight choice (last time, or the suggestion). A planned weight always wins. Previous moves the way Next already does. Done stays where it is. |
| **Rest alert** | One pocket-strength buzz at zero, an optional tap at 10 seconds, a chime that dips an audiobook without stopping it, and the countdown on the Lock Screen and Dynamic Island. |
| **Carry** | Editing one set’s weight updates only the later unlogged working sets that were planned at that same weight. Ramps stay on their plan, then snap to the lift’s stack step. |

Lee’s notes for **d** and **e**, in his words: he is on the individual exercises most of the time and wants to rearrange them from inside the workout. He sometimes cycles two to four exercises before moving on. Rest depends on the exercise he just did: some leave him breathing hard, some need a short break.

## What the app does today

Weights are pounds everywhere they are stored: set `weightLbs`, body-metric weight, the Settings body-weight number, coach files, and planned-workout files. The Focus stepper jumps **5 lb → 1 lb → 0.5 lb**. Progression rounds targets to the nearest 5 lb (`snap5`), including a lift that has only one prior session (on `main` as of `eb497bd`, not on TestFlight yet). There is no kilogram setting. Pull request #9 left kilograms for later.

Body measurements already exist. `BodyMetricEntry` is a dated log of weight, waist, neck, chest, arm, and hips (pounds and inches). `BodyCompositionMath` turns the latest waist, neck, hips, height, and sex into a Navy body-fat estimate and an FFMI. It can already pick the latest entry on or before a date. That is the log to extend. A second `WeightEntry` model would duplicate it. The April 2026 feature note that proposed `WeightEntry` is out of date on this point.

A different number, Settings → Body profile → weight, is what assisted lifts use. Effective load is body weight minus the assistance on the stack. Logging a body-metric weight overwrites that Settings number, including when the log is backdated. Every old assisted set then recalculates with the new number, because the set does not store the body weight it used.

Assist is the only bodyweight mode. There is no “body weight plus added load” mode (weighted pull-up, dip with a chain).

There is no per-machine stack. The stepper does not know that a machine only moves in 10, 15, or 20 lb jumps. Fixing set 1 from 145 to 140 leaves set 2 on 145 when set 2 was planned at 145, because nothing copies a correction onto the later sets that shared that plan weight. History can still reopen a finished workout (Edit, then Save Changes). That path stays as it is.

During a workout, **Reorder / edit day plan** opens the day-plan editor and writes the library order (`Exercise` day sort). The next session on that day follows it. The session itself does not keep a private order, except a planned workout: those sessions set `followsSessionRoster` and list lifts by `ExerciseRecord.sortOrder`. The lift screen (Focus) has next / previous. It has no drag handle. Lee spends his time on that screen. How that screen fills the stepper, and how Previous differs from Next, is under [Focus screen](#focus-screen).

Rest is one duration for the whole app (default 3 minutes, Settings chips from 1 to 5 minutes). Each lift can turn auto-rest on or off. That on/off flag lives in UserDefaults, so a backup does not include it. Logging a set starts the timer when the lift’s auto-rest is on. While it runs, the chips are **−30**, **+30**, and **Skip**. There is no circuit, and Next walks the whole list rather than a pair of lifts. The countdown he sees off the lift screen is not a Live Activity. Sound is a tick on each of the last 5 seconds plus a two-tone chirp at zero, mixed on top of other audio (`.mixWithOthers`) without ducking it. A success haptic and two heavy taps fire at zero, and those generators run while the app is on screen. Local-notification banners for the timer were removed on purpose. The app still clears any leftover ones on launch. How that should change is under [Rest alert](#rest-alert).

The iCloud store on `main` is `RockLogSchemaV1` with an empty migration plan (`eb497bd`, not on TestFlight yet). V1 is frozen. The next stored fields are `RockLogSchemaV2` plus one lightweight stage. CloudKit will not run a heavy migration. New fields need defaults so existing phones open.

Coach files are `rocklog.coach.session` v1. The schema rejects unknown fields. Coach progression compares the stored `weightLbs` and does not apply the assisted-load formula. Exercise order in the file is the array order. Sets sit under their lift. Rest is not in the file.

---

## a) Kilograms and pounds

### Stored unit

Pounds stay the one stored unit. Every set, measurement, backup, coach file, and program file is already pounds. A kilogram preference changes what the screen shows and what the plate math uses. It does not rewrite old numbers.

The Settings choice is **Pounds** or **Kilograms**, default pounds. It syncs the same way height and body weight do (this phone, plus iCloud key-value). Existing logs stay pounds. The first launch after the setting exists still shows pounds.

### Display and entry

The number on the stepper is in the chosen unit. Saving converts that entry into pounds and stores the pounds.

Round-trip while you stay in one unit: the number you typed is the number you see next time. Do that by storing the pound equivalent of the entered display value, at a precision that converts back onto the same display step.

Switching units converts the stored pounds and rounds onto the other unit’s display step. Switching back can land one step away. That drift is limited to the moment you change units. Staying in pounds, or staying in kilograms, does not drift.

Display steps:

| Unit | Readout | Stepper cycle |
| --- | --- | --- |
| Pounds | nearest 0.5 lb | 5 → 1 → 0.5, as today |
| Kilograms | nearest 0.25 kg | 2.5 → 1 → 0.5 |

Half-pound and quarter-kilogram ties round half away from zero, matching today’s `snap5` (`rounded()`).

Girths stay inches. The Navy formula stays in inches and pounds underneath the screen. Only the weight readout follows the unit setting. Centimetres are an open question.

Backup still rejects a non-finite weight, a negative weight, and a weight over 10,000 lb. That ceiling is in canonical pounds. A kilogram entry converts before the check.

### Plate math

Plate math is separate from the stepper step. It answers “which plates go on the bar?” in the unit you are looking at.

| | Bar | Plates, each side, pairs |
| --- | --- | --- |
| Pounds | 45 lb | 45, 35, 25, 10, 5, 2.5, 1.25 |
| Kilograms | 20 kg | 25, 20, 15, 10, 5, 2.5, 1.25 |

The calculator uses that unit’s bar and plates. A 20 kg bar is not shown as a 45 lb bar with converted plates. The calculator is a readout on the lift screen. It does not change the stored weight.

### Progression rounding

When the lift has no machine stack (part **c**), the suggestion snaps in the active unit, then converts back to stored pounds:

- Pounds: nearest 5 lb (today’s rule, including a single prior session).
- Kilograms: nearest 2.5 kg.

The suggestion the lifter sees sits on their plate grid. The stored target is the pound equivalent of that snapped display value.

### Imports and exports

Backup JSON, coach files, and `rocklog.program` / `rocklog.split` files keep `weightLbs` as pounds. An old file with no unit field is pounds. A new file may include `"weightUnit": "lb"` as a label. The numbers do not get rescaled to the reader’s display unit.

The display preference can ride along as metadata. Restoring a file does not switch the phone’s unit unless we later add an explicit choice. Default: leave the phone’s setting alone.

### App vs coach

**RockLog** owns the Settings control, stepper labels, the plate readout, the key-value preference, and converting at the edge so SwiftData stays in pounds. Screens that print `lb` today (History volume, Progress, Focus, monthly deltas) take the preference.

**Shared progression** owns the snap. `snap5` becomes “snap to the active increment” with the unit passed in. ProgressionLab’s weight increment stays a pound value in the lab, and the lab labels it as pounds.

**RockCoach** keeps file numbers in pounds. A display toggle on the coach’s phone can convert for reading. Comparison and e1RM stay in pounds internally. Monthly delta text (`+5 lb`) is formatted by the screen, in the unit that screen is showing.

No new SwiftData model. No `RockLogSchemaV2` for the preference; it is key-value, like the body profile. Set values do not migrate.

---

## b) Body weight over time, bodyweight lifts, relative strength

### Use the log that already exists

`BodyMetricEntry` with kind `weight` is the history. `BodyCompositionMath.latest(kind:asOf:)` is the lookup. Height and sex stay on the body profile. FFMI and Navy body fat keep using that path.

The Settings body-weight number stays the fallback when the log is empty, and the number assist uses until a log exists. Logging a weight updates the Settings number to the latest weight **by date**, not to a backdated entry that is older than the log’s newest row.

### Load for one set

Three ways a stored weight is interpreted. The first two exist. The third is new.

| Mode | What you type | Load used for volume, e1RM, and progression |
| --- | --- | --- |
| Bar | The weight on the bar or machine | That weight |
| Assist | The help the machine gives (the “−100” on the stack) | Body weight minus assistance, never below zero |
| Added | The extra load (belt, chain, dumbbell between the feet) | Body weight plus that load |

Body weight for a set is the latest body-metric weight on or before the set’s time, then the session date, then the Settings number. If none is set, assist and added contribute no load, and the lift screen says to save a body weight. That matches assist today.

Old assisted sets, once this ships, use the body weight from the date of the set when a log exists. Until the log has a row that old, they keep using the Settings number. We do not invent past weigh-ins.

Relative strength on a lift is that set’s e1RM divided by the same body weight. The lift detail can show it once a weigh-in exists (for example “1.21 × body weight”). The strength score on Progress stays the absolute sum unless Lee turns on a relative view. That toggle is an open question, not part of the first build.

### App vs coach

**RockLog** owns check-in (already on Progress), the three load modes on the lift, the date lookup, and the relative-strength line on the lift detail. `effectiveLoadLbs` grows the added case and takes the body weight for that date instead of always reading the live Settings number.

**Progression** already receives effective load for assist. Added mode feeds it the same way: the algorithm sees body weight plus added load, so a heavier body at the same added load counts as more load. Suggestions stay in the mode the lifter types (assistance, or added plates), converted back from the effective target so the stepper shows the number they will dial.

**RockCoach** does not have the body-metric log. A set that uses body weight includes the body weight used that day on the coach file, plus the mode. Coach progression then compares effective load. Comparing raw assistance across months treats “less help” as “lighter,” which is the wrong direction. This is a coach-schema addition: optional fields, still readable when they are absent. v1 files stay valid. A build of RockCoach that shares this repo reads the new fields. The locked “do not add fields without a version bump” rule means the file’s `schemaVersion` moves to 2 when those fields ship, and this repo’s coach updates with it.

### Data and migration

No new measurement model. One new stored field on the exercise (or on the set): the load mode. Existing rows are bar, or assist when `isAssisted` is already true. Added is opt-in per lift.

That field is `RockLogSchemaV2`. Optional, with a default, lightweight stage from V1. V1 stays untouched. Backup writes the field. An older backup that omits it restores as bar or assist, using the same nil-vs-empty care PR #9 used for measurements.

The April feature note’s ÷ body-weight strength score and Hall of Fame are not this work.

---

## c) Machine stack increments

### Profile

Each exercise can save a stack profile. Empty means “use the normal stepper and the 5 lb / 2.5 kg snap.”

A profile is either:

- a fixed step, or
- an explicit list of pin weights.

The step control offers **10 lb**, **15 lb**, **20 lb**, and **Custom**. Custom is any step he types. A step learned from his corrections uses this same control and is described under [Same-weight carry and the stack step](#same-weight-carry-and-the-stack-step).

Plus add-on plates (the magnets): a small list such as 2.5 and 5. An available weight is a pin, or a pin plus one add-on. Stacking several magnets is an open question; the first version allows one add-on at a time.

The profile remembers whether those pins were entered in pounds or kilograms. A 10 kg stack and a 10 lb stack are different machines. Comparison against stored sets converts the available weights into pounds.

### Rounding a prescribed load

The program, the progression suggestion, or the stepper can ask for a weight the stack cannot load. The profile’s policy picks the replacement:

- **Nearest** available weight (ties round down, so the lifter is not handed more than they asked).
- **Down** to the next available weight at or below the target.
- **Up** to the next available weight at or above the target.

The policy is saved on the profile. Default is nearest.

### Reps follow the effort

After the weight moves, reps change so the Epley estimate stays as close as possible to the original target. The formula already in the app is `weight × (1 + reps / 30)`.

Ideal reps at the new weight `w2`, given the original e1RM `e`:

`reps = 30 × (e / w2 − 1)`

Round that to the nearest whole rep, minimum 1. If the rounded reps would push the new e1RM further from the target than the other neighbour, keep the neighbour that lands closer. Cap reps at the mode’s existing ceiling when one exists (strength rep cap in progression). Show the stack weight and the adjusted reps together. The lifter can still log a different pair.

Example. Target 205 lb × 5. e1RM = 205 × (1 + 5/30) = 239.2. The 10 lb pins on either side are 200 and 210. 205 sits halfway, and a halfway tie rounds down, so the weight becomes 200. At 200 lb, ideal reps = 30 × (239.2 / 200 − 1) = 5.9, which rounds to 6. The suggestion becomes 200 × 6.

Warm-up targets round onto the stack the same way. They do not change the working-set suggestion.

### App vs coach

**RockLog** owns the profile editor (on the exercise, and a short cut from the lift screen), the policy control, and snapping the stepper so − / + land on available weights. The 5 / 1 / 0.5 cycle remains for lifts with no profile.

**Shared progression** owns “given a target weight and reps, and a list of available pounds, return the weight and reps to suggest.” RockLog and RockCoach both call it. Planned-workout targets in the file stay the coach’s ideal numbers. The phone rounds when it displays and when it pre-fills. Import does not rewrite the file.

**RockCoach** can show the same rounded pair when the athlete’s export includes the stack profile, or when the coach types a target. The first version can ship rounding on the phone only, and add the profile to the coach file in the same schema bump as part **b**. Until the file carries the profile, the coach shows the ideal target and the phone shows the stack-legal one. That gap should be short. Prefer one schema bump that carries body weight, load mode, and stack together.

### Data and migration

The profile is stored on the exercise: step or pin list, add-ons, unit of the pins, policy, and whether the step was learned or typed. All optional. No profile means today’s behaviour. `RockLogSchemaV2`, same lightweight stage as part **b**. Backup includes the profile. Old backups restore with no profile. Learning also stores the weight a set was offered, on that set, when he logged something else. That field is optional and empty on older sets.

Part **a**’s 5 lb / 2.5 kg snap is the fallback only when the lift has no profile.

---

## d) Drag to reorder during the workout

### What he can do

On the lift list and on the lift screen, long-press the lift number and drag. That is the same gesture the day plan already uses. The new order is this session’s order immediately.

The session stores it on the records that already exist: `ExerciseRecord.sortOrder`, and `followsSessionRoster = true` for this workout. The list, Focus next / previous, and History then read that order. The library day plan is unchanged.

Two optional actions, each a button he taps on purpose:

- **Save order to this day** writes the library day plan (`Exercise` day sort) so the next unplanned session on that day starts in this order.
- **Save order to remaining planned days** updates later unused planned sessions with this day name. Finished history is left alone. This queued session updates either way, because it is the session he is in.

Closing the workout without those buttons keeps the order on this session only.

Planned sessions already follow their own roster. Reordering one of them updates that session’s record order. It still does not change the day plan or the other queued days until he taps the matching button.

### History, coach, progression

History already lists a session’s lifts by record `sortOrder`. After a reorder, that is the order he trained. Sessions he never reorders keep the order their records were created in. We do not rebuild old sessions.

The coach file lists exercises in session order. Reorder changes that array order. It does not move sets between lifts. Coach progression matches on the lift name, then weight and reps. Order is not an input. e1RM, PRs, the strength score, and the month table do not change because two lifts swapped places.

The same-date session sort from `eb497bd` (newest date, then session id) is about which session is “last.” It is not exercise order.

### Data and migration

No new model and no schema version. `sortOrder` and `followsSessionRoster` are already on V1. Using them for a normal session is a behaviour change. Backup already writes both. A phone on the TestFlight build from before this work still restores the fields; it only shows a private order for sessions that already had `followsSessionRoster` set (planned workouts).

### App vs coach

**RockLog** owns the drag gesture on the list and on Focus, the two save-back buttons, and writing record order.

**RockCoach** displays the exported order. It does not write back into RockLog. Progression services do not gain an order input.

---

## e) Groups of two to four, and rest after each lift

### The group

A group is two, three, or four lifts in this session. He builds it from the lift list (select the lifts, or drag one onto another). One lift sits in at most one group. Lifts outside a group stay straight sets: log, rest, stay on that lift.

Logging a **working** set moves Focus to the next lift in the group. After the last lift in the group, it returns to the first lift in the group that is not finished. Warm-up sets stay on the current lift so he can warm the first movement up before the group starts. That warm-up choice is an open question; it is the recommendation.

Set counts may differ. Each lift finishes on its own. A lift drops out of the loop when he taps **Done**, or when a planned workout already gave it a set count and he has logged that many working sets. The others keep going. When every lift in the group is done, the existing “finish this workout?” prompt runs if the rest of the session is done too.

### Rest follows the exercise he just did

Rest starts when he logs the set, for the exercise he just logged, before the screen moves on. The countdown keeps running on the next lift. He is resting from the hard set while he sets up the next one. Logging the next set replaces that countdown with the rest for the exercise he just finished.

There is no single rest at the end of the round. A squat can ask for three minutes and a curl for one minute inside the same group.

Each exercise has its own default rest, editable on the lift and on Edit exercise. Until he sets one, the app seeds it:

| Kind of lift | Starting default |
| --- | --- |
| Squat, deadlift, lunge, leg press | 3 min |
| Other compounds (bench, row, overhead, pull-up, dip) | 2 min |
| Isolation (curl, raise, extension, fly) | 90 sec |
| Anything we cannot tell | The Settings rest duration (3 min today) |

The seed uses the muscles and the name already on the exercise. His edit replaces the seed and is what we remember. Auto-rest on/off per lift stays. Off means logging does not start a timer. **Start** still can.

On a running timer the chips are **−15**, **+15**, and **Skip**. Skip is one tap and clears the countdown. The Settings screen still picks the fallback duration (the 1–5 minute chips). The ±15 buttons only nudge the timer that is running.

### Learning his real rests

Optional, and off until he turns it on. The app records, for a lift, how long the timer actually ran: from the start until Skip, until he logs the next set, or until it hits zero, whichever comes first. A gap between `completedAt` stamps is not enough, because in a group that gap includes the other exercises.

Ignore a sample under 10 seconds (a stray Skip) or over 10 minutes (the phone sat down). After 8 kept samples, if the median is at least 15 seconds away from the saved default, offer a new default once. He confirms. The app does not change the default by itself, and it does not ask again that session.

Weight and rep suggestions ignore rest. A short rest does not add weight.

### History, coach, progression

History keeps each lift’s sets together, in the session’s lift order from part **d**. A group draws one label on those lifts (“with the next two” or the group’s names) so the pairing is visible. Sets are not interleaved into one list in the first version. A minute-by-minute timeline can wait.

The coach file gains an optional group id and position on each exercise, in the same schema bump as parts **b** and **c**. Absent means “not in a group.” Coach progression still scores each lift on its own. The group is context for the coach, not a change to the best-set rule.

Per-lift rest can be included on the export as the default he had that day. The coach does not suggest weights from it.

### Data and migration

New optional fields, all on `RockLogSchemaV2` with defaults:

- On the exercise: default rest in seconds. `0` means “not chosen,” so the seed or the Settings duration applies. This replaces the UserDefaults on/off flag as the thing backup must keep. The on/off flag moves onto the exercise as well so a reinstall keeps “rest off on face pulls.”
- On the session’s exercise record: optional group id, position in the group (1…4). Empty means not in a group.
- On the set, only if learning ships: planned rest seconds and actual rest seconds. Both optional. The first circuit build can ship without them.

V1 is not edited. One lightweight stage. Existing sessions have no groups and rest behaviour stays the global timer until an exercise has its own default.

Backup writes the new fields. An older file that omits them leaves groups empty and rest on the Settings default. A file that includes groups restores them.

Program JSON (`rocklog.program`) can carry a group on a planned lift later. Old program files have no group and import as straight sets. The first build does not need to read groups from the file. Saving a group back to a planned day uses the same explicit button as part **d**.

UserDefaults rest on/off values are copied once onto the exercise, then the exercise is the source of truth.

### App vs coach

**RockLog** owns creating the group, auto-advance, the per-lift rest editor, the timer chips, and the optional learning prompt.

**Shared code** owns “given the group and which lifts are done, which lift is next” so the rule is testable without the screen. The timer service stays in the app.

**RockCoach** shows the group label and the rest default when the file has them. It does not advance sets and it does not edit RockLog’s defaults.

---

## Focus screen

Lee’s answers from the optimization session, in his words: “Make that a user option. If it is a custom plan default to the plan weight.” Done stays where it is. Recovery stays as it works now: back at the top, restart at the bottom. The only navigation change is that Previous mirrors Next.

Both pieces are small. Neither needs a new SwiftData field. Neither changes coach files or progression math.

### What the lift screen does today

**Next set default** (Settings) is a different control, and it stays. **Last session** refills the next set from the same set number last time. **Last set** repeats the set just logged. The default is Last session.

The first number on the steppers uses that same control. With Last session, a planned target for this set number is used in place of last time, so a planned lift already opens on the plan when that setting is on. With Last set, and nothing logged yet this session, the stepper opens on the progression suggestion instead, and the plan is skipped.

**Next** sits at the top of the lift (the accent capsule). It skips lifts marked Done and wraps around the list. If every other lift is already Done, it steps one lift forward in list order so a finished lift can still be reviewed, and it does not wrap in that fallback. On the last lift, with nothing else unfinished, Next is hidden.

**Previous** sits at the top, to the left of Next (the chevron). It moves one lift toward the start of the list. It does not skip Done lifts, and it does not wrap. On the first lift it is hidden.

**Done** sits on the bottom row, to the right of Warm and Log set. Tapping it marks this lift finished and moves on the same path as Next. After that, the same button reads **Resume** and un-marks the lift without leaving it. That is the restart at the bottom. The back chevron stays at the top. Leave both where they are.

### Starting weight

A new Settings choice, next to Next set default: **Starting weight**.

| Choice | What the steppers show when this set has no prescribed plan weight |
| --- | --- |
| **Last time** (default) | The same set number from the last completed session. If last time had fewer sets, the best working set from that session. |
| **Suggested** | The progression suggestion for the mode selected on this lift (strength or endurance), including the 5 lb snap already on `main`. |

A custom plan wins over both. When this workout is a planned session and this set number has a prescribed weight, the steppers open on that prescribed weight and those prescribed reps, then on the stack snap when this lift has a step. The Starting weight setting does not apply. Next set default does not apply to that set either: after set 1 is logged at the plan weight, set 2 still opens on the plan when the plan has a set 2. An edit to that weight follows same-weight carry.

When the plan has no target for this set number, the rules above take over. Sets after the first, with no plan target, still follow Next set default.

Under the steppers, one line shows last time and the suggestion together, for example `Last time 225×5 · Suggested 230×5`. The line is text. It does not write the steppers, and logging saves the stepper numbers. Editing the steppers leaves the line as it was. A missing side is left off the line (no last time yet, or no suggestion yet). The PLAN column on a planned lift stays the place that shows the prescribed sets. The line does not repeat the plan.

When this lift has a stack step (part **c**, typed or learned), every weight the steppers would offer snaps onto that step before he sees it. A planned 165×5 on a 10 lb stack opens at 160×6. The PLAN column still shows 165×5. The line under the steppers shows the stack-legal suggestion. − / + then move by the stack step. Same-weight carry, in the next section, can replace that snapped weight on the later sets that shared the edited set’s plan weight. His own edit is kept as he set it.

The choice is stored on this phone the same way Next set default is (UserDefaults). It is not a SwiftData field and it is not in the backup. Default is Last time, so a phone that has never chosen stays on today’s first-set behavior for an unplanned lift.

**RockLog** owns the Settings control, the prefill choice, and the line under the steppers. **Progression** is only read, to fill the Suggested side. **RockCoach** does not get this control. The coach still sees the sets that were logged.

### Previous mirrors Next

Previous uses the same rule as Next, walking backward.

1. Look backward through the list, wrapping past the start, and stop on the first lift that is not Done.
2. If every other lift is Done, or this is the only lift, step one lift backward in list order so a finished lift can still be reviewed. That fallback does not wrap. On the first lift, Previous is hidden.

Done and Resume stay on the bottom row. Resume still un-marks the lift and stays on it. Next stays the top capsule. Previous stays the top chevron. Groups (part **e**) change which lift is “next” inside a circuit. This Previous rule is the one used when he is moving through the session list, including from one group to another. Inside a group, the auto-advance in part **e** is a separate path. Previous from inside a group still follows this skip-and-wrap rule across the session order, so back does not get stuck on a lift he already marked Done.

### Tests

**Starting weight**

- Setting Last time, no plan. Last session set 1 was 225×5. Suggestion is 230×5. Steppers open on 225×5. The line reads last time 225×5 and suggested 230×5. Logging without an edit saves 225×5.
- Setting Suggested, same history. Steppers open on 230×5. The line is unchanged. Logging without an edit saves 230×5.
- A planned set prescribes 185×8. Both settings open the steppers on 185×8. The line still shows 225×5 and 230×5. Logging without an edit saves 185×8.
- The plan’s set 2 is 205×5. Next set default is Last set. After set 1 is logged at 205, the steppers show 205×5. Logging the plan weight does not carry.
- The plan has no set 3. After set 2, Next set default fills set 3.
- Changing the stepper does not change the line.
- No last session: the Last time choice uses the suggestion when there is one, and otherwise the same empty default as today. The line omits last time.
- No suggestion: the line omits the suggested side. Last time still fills the steppers when that choice is on and there is no plan weight.
- A 10 lb stack and a planned 165×5. The steppers open on 160×6. The PLAN column still shows 165×5. The line shows the stack-legal suggestion.

**Previous**

- Lifts A B C. B is Done. From A, Next opens C. From C, Previous opens A.
- A B C, none Done. From A, Previous opens C. From C, Next opens A.
- A B C, A and C Done, standing on B. Next opens C (the review fallback, one step forward). Previous opens A (one step back).
- Standing on A with B and C Done. Previous is hidden. Next opens B.
- Standing on C with A and B Done. Next is hidden. Previous opens B.
- One lift. Next and Previous are both hidden.
- Done stays on the bottom row, right of Log set. After Done, that button reads Resume. Resume clears Done and stays on this lift.
- The Previous control remains the top chevron. Next remains the top capsule.

## Same-weight carry and the stack step

Lee’s words: he does not usually fix a workout after he has finished. He finds the error the next time he does the workout, usually a 5 lb gap, as when the app says 145 and the machine only does 140. He fixes the first set and forgets the second. Mostly, if he changes the weight on one set and the next set was supposed to be the same, he does not want to change it again. If the plan ramps, some machines move in 10 lb, 15 lb, or 20 lb jumps.

### Same-weight carry

This runs while the workout is in progress, on the lift he is logging.

When he edits a working set’s weight, look at the plan weight that set had before the edit. Each later working set that is still unlogged, and whose plan weight is that same number, takes the new weight. A later set with a different plan weight keeps its plan. Warm-ups stay on their own numbers, including a warm-up that happened to say 145. Editing a warm-up does not move working sets. Sets he has already logged stay logged. Reps on a carried set stay the reps that set already had. Only the weight moves.

“Plan weight” means the prescribed weight when this set has one. When it does not, it means the weight that set was going to open on (last time, the suggestion, or a carry already applied). Same means the same stored pounds.

The program file and the day plan keep the original numbers. Next week starts from those again. This session’s unlogged rows are what change.

Example. Plan 145×5, 145×5, 165×5. He edits set 1 to 140. Set 2 was also planned at 145, so it becomes 140×5. Set 3 was planned at 165, so it stays 165×5 until a stack step snaps it, below. Undo puts set 2 back to 145×5. Set 1 stays 140.

A ramp he is following does not flatten. Plan 135, 155, 175, and he edits set 1 to 130. Sets 2 and 3 stay 155 and 175, because neither was planned at 135.

Logging the weight the set already offered is not an edit. Changing reps only is not an edit. No carry in either case.

### Show it, and one undo

The set list shows the weight each unlogged set will open on. Every row this edit changed is marked until he logs that set or undoes. One line names them, for example “Set 2 set to 140,” with **Undo**. One tap. No dialog. Undo restores those unlogged sets to the weights they had before this edit, including a snap this edit caused. It does not change the set he edited. A second edit replaces that Undo, so only the latest edit can be undone. Leaving the lift keeps the new weights. The Undo line does not have to still be there when he comes back.

### Every offer snaps to the stack step

Once this lift has a step, every suggested weight and every plan weight he did not just overwrite snaps onto that step. The rule is part **c**: nearest pin, a halfway tie rounds down, then reps move so the Epley estimate stays as close as it can. The weight he typed, and the copies same-weight carry just made, stay as he set them.

The same example with a step:

| Step | After he edits set 1 from 145 to 140 |
| --- | --- |
| None yet | 140×5, 140×5, 165×5 |
| 10 lb | 140×5, 140×5, 160×6 |
| 15 lb | 140×5, 140×5, 165×5 |
| 20 lb | 140×5, 140×5, 160×6 |

165 on a 10 lb step sits halfway between 160 and 170, and the tie rounds down. 165 × (1 + 5/30) = 192.5. At 160 lb the nearest rep count is 6 (160×6 estimates 192). 165 is already on a 15 lb step. On a 20 lb step, 160 is closer than 180.

The PLAN column still shows 145 / 145 / 165. The rows he will log show the snapped or carried numbers. Those rows are marked the same way as a carry.

With no step, the only snap is today’s nearest 5 lb.

### Learning the step from corrections

He should not have to set up a stack for the 145-versus-140 case. The phone learns the step from working sets he actually changed.

A session qualifies when he logs at least one working set at a weight other than the weight that set offered. Warm-ups do not qualify a session. Several sets in one session are one session, not several votes. The weights that count are the corrected working weights, so an unedited ramp at 165 does not spoil a correction to 140.

For that session, try 20, 15, and 10 lb. A step fits when every corrected weight is a whole number of steps (within half a pound). The session’s step is the largest of those three that fits. 140 fits 20 and 10, so the session’s step is 20. 140 and 150 together fit 10 only. 150 and 165 fit 15. 145, 185, and 225 fit none of them.

When none of the three fit, the custom candidate is the greatest common divisor of the corrected weights, and only if that divisor is greater than 5 lb. 25, 50, and 75 give 25. A divisor of 5 lb is the snap the app already uses, so a barbell does not grow a stack.

The learned step is written when the last three qualifying sessions all have the same step. One session, or two, write nothing. A later session with a different step does not change a step already learned. Replacing 20 lb with 10 lb takes three new sessions whose step is 10. Sessions where he logs the offer are skipped. They do not count, and they do not wipe the three.

Old workouts cannot teach this. The offer was not stored. From this build on, a working set he logs at a different weight stores the weight it was offered. That field is how the three sessions are read back.

The learned step is the part **c** profile: a fixed step, pounds, nearest, tie down, marked learned. Future suggestions and plan weights snap with the table above. History is not rewritten. Progression still computes the ideal target first. The step rounds it.

On the exercise, next to the 10 / 15 / 20 / Custom control, a learned step says it was learned and names the three sessions in one line. **Clear** removes it and remembers the time, so those same three sessions do not write it back. Sets logged after Clear can teach a new step. Typing 10, 15, 20, or a custom step marks the profile as his. Learning does not replace a step he typed. **Learn stack from corrections** sits on that exercise, default on. Off means new corrections are only for this session’s carry. The switch is optional on the exercise. Empty means on.

### Finished workouts stay as they are

Finding the bad 145 the next time he does the lift is the path this section is for. Editing a workout after Finish is low priority. History keeps Edit, the confirm (“Edit this workout?”), and Save Changes. Reopening a finished session does not run same-weight carry, does not snap the old sets onto a step, and does not add a learning sample. That screen is not in the build order.

### App, data, coach

**RockLog** owns the carry, the marked rows, Undo, the step chips, and learning. Carry is this session only. It adds no SwiftData field. The program file is untouched.

**Progression** still returns the ideal target. It does not know about the step. RockLog snaps after that, with the shared helper from part **c**.

**RockCoach** does not learn a step. Once the coach file includes the profile, the coach can show the same snapped pair. Until then, the phone is the place the step lives.

The offered weight on a corrected set, the learned-or-typed flag, and the Clear time are optional fields in the same `RockLogSchemaV2` as part **c**. Empty on old data. Backup round-trips them. An old file restores with no step and no offers.

### Tests

**Carry**

- Plan 145×5, 145×5, 165×5. Edit set 1 to 140, no stack step. Unlogged set 2 becomes 140×5. Set 3 stays 165×5. Set 1 stays 140×5. The program file still says 145 / 145 / 165.
- Undo restores set 2 to 145×5 and leaves set 1 at 140.
- The same plan with a 10 lb step. Set 2 becomes 140×5. Set 3 becomes 160×6. The PLAN column still shows 165×5. Undo restores set 2 to 145×5 and set 3 to 165×5.
- A 15 lb step leaves set 3 at 165×5. A 20 lb step makes set 3 160×6.
- Plan 135, 155, 175. Edit set 1 to 130. Sets 2 and 3 stay 155 and 175.
- A warm-up planned at 145 stays 145 when working set 1 moves from 145 to 140. Editing that warm-up’s weight does not move the working sets.
- Set 2 is already logged at 145. Editing set 1 to 140 does not change set 2. A later unlogged set that was also planned at 145 does change.
- Editing set 2 of 145 / 145 / 165 to 140 does not change set 3.
- Both later sets planned at 145 become 140. Their reps stay what each set had.
- The changed rows are marked, and the line offers one Undo. A second edit replaces that Undo.
- Another lift in the session is unchanged.
- No plan. Set 1 and set 2 were both going to open at 145. Edit set 1 to 140. Set 2 opens at 140. If set 2 was going to open at 165, it stays 165.
- Logging the offered weight does not carry. Changing reps only does not carry.

**Learning**

- One session, or two, of 145 corrected to 140 writes no step.
- Three sessions whose corrected weights are 140, then 160, then 180 learn a 20 lb step.
- Three sessions of 140, 150, and 160 learn 10 lb.
- Three sessions of 150, 165, and 180 learn 15 lb.
- After a 20 lb step is learned, one session that corrects to 150 leaves the step at 20. Three such sessions move it to 10.
- Logged working weights 145, 185, and 225 learn nothing.
- Three sessions of 25, 50, and 75 learn a custom step of 25.
- A warm-up edited off its offer does not qualify the session.
- A session that corrects 145 to 140 and leaves a ramp at 165 counts {140} only. Three of those learn 20 lb.
- With a learned 10 lb step, a suggestion of 145 opens at 140, and a suggestion of 165×5 opens at 160×6.
- Clear removes the step. The next suggestion uses the 5 lb snap. The same three old sessions do not write the step again.
- A step he typed as 15 stays 15 when the logs would learn 10. Clear is the learned-step action. His typed step stays until he changes it.
- Learn stack from corrections off: a third qualifying session does not write a step.
- A set logged with no stored offer, including every set from before this field existed, does not qualify.
- Three corrected sets inside one session are still one session.

**Finished workouts**

- History → Edit still asks “Edit this workout?” and Save Changes still saves. Reopening does not carry, does not snap, and does not store an offered weight.

## Rest alert

Lee’s words: the phone is in his pocket, in his hand, or on the ground next to him. Sound is on, and sometimes an audiobook is playing, or he is on a call.

This is how the rest timer tells him the break is over. It does not change which lift the rest belongs to (part **e**) or the length of that rest. The on-screen rest card stays: Start, the running countdown, Skip, and the ±15 nudge from part **e**. That card is not a banner.

### At zero, and at 10 seconds

At zero, one strong haptic. The pattern is the three sharp taps already used when a workout is completed (`HapticService.workoutCompleted`): full intensity, about a quarter of a second, so he can feel it in a pocket when the phone can play it. It fires once. The last-5-seconds tick tones go away, so an audiobook is not bumped five times.

A Settings switch, **Tap at 10 seconds**, default off. When it is on, one light tap fires as the countdown crosses 10 seconds. No chime with that tap. A rest shorter than 10 seconds does not tap. Adding time back above 10 seconds arms the tap once more. Skip before zero cancels whatever has not fired.

### Chime, and an audiobook

At zero, one short chirp, the current two-tone “go,” only when sound is on and he is not in a call. The session for that chirp is `.playback` with `.mixWithOthers` and `.duckOthers`. Other audio dips for the length of the chirp and then comes back. The chirp does not pause or stop the audiobook. Do not use a category option that interrupts spoken audio.

The near-silent loop that keeps the timer alive while the screen is locked stays `.mixWithOthers` only. It must not hold `.duckOthers` for the whole rest, or the book would stay quiet for minutes. Ducking turns on just before the chirp and turns off when the chirp finishes.

The existing sound switch stays. Off means haptics only, including no chirp and no duck.

### A call

If a call is connected (CallKit: a call that has not ended, including a call on hold), the timer still runs and the Live Activity still counts. Sound does not play. Ducking does not run. The zero haptic and the optional 10-second tap still fire. A call that starts during the rest cuts off a chirp that is already playing. A call that ends before zero allows the chirp when zero arrives.

An audiobook is not a call. Other audio playing is not a reason to mute the chirp.

### Countdown off the phone screen

Do not post a notification that updates every second. That banner is what an older build stacked on each tick, and it stays gone.

When rest starts, start one Live Activity. Its countdown is a system timer from now until the rest end date, so the number moves without the app pushing an update every second. Update the activity only when the end date changes (±15 or a new rest) or when rest ends (Skip, or zero). The activity shows the exercise name and the time left.

On a phone with a Dynamic Island, the system puts it there. On a phone without one, the same activity is the Lock Screen timer and the system’s Live Activity banner. There is no second layout to build. RockLog’s minimum system is iOS 26.2, so every phone the app runs on has Live Activities. The island itself is the hardware. iPad, if the app is run there, gets the Lock Screen activity and no island.

The in-app rest card still shows the same countdown while he is on the lift.

Ending rest (zero, Skip, or logging a set that replaces the timer) ends the activity. Leaving it up after the set is logged is wrong.

### Pocket, lock, background, Silent, Focus, permission

The phone in his hand with RockLog open plays the Core Haptics pattern and the chirp directly.

The phone locked, or RockLog in the background, keeps the process awake the way it does today (`UIBackgroundModes` audio and the mix-only keep-alive) so the chirp can still play and the activity can still be ended at zero. App haptics often do not run with the screen off. For that case, one Live Activity alert at zero carries the system buzz he feels in a pocket. If the app’s own pattern already played, the alert does not also buzz. He gets one buzz, not two.

If the system suspends RockLog anyway, one local notification armed for the end time is the backup buzz and chirp. It is a single notification, not a tick. When the app itself plays the end, it cancels that notification. Skip cancels it too.

The silent switch does not mute the chirp. The session stays `.playback`, which is what lets a gym timer sound while the ringer is off. That matches the timer today.

A Focus mode that silences notifications can swallow the Live Activity alert and the backup notification. The Lock Screen activity can still show the countdown, and the in-app chirp can still play, because that chirp is the app’s audio session and not a notification. This build does not mark the alert Time Sensitive. Breaking through Focus is a later choice.

Live Activities off, or the system refusing to start one: rest still runs, the on-screen card still counts, the chirp and the in-app haptic still follow the rules above. No per-second banner is substituted. Notification permission denied: the backup notification is skipped, once, without asking on every set. Ask the first time he leaves the app during a rest, from that moment, not from a cold Settings lecture. Denied stays denied until he turns it on himself.

### Apple Watch, later

Not this build. A later watch glance can take a “rest done” event and play a watch haptic. Nothing in the first rest-alert work adds a watch target, and the iPhone Live Activity is not described as a watch buzz.

### App, data, coach

**RockLog** owns the activity, the audio session, the call check, and the two haptics. The Live Activity UI lives in a widget extension. `NSSupportsLiveActivities` is set. No new SwiftData model. **Tap at 10 seconds** is UserDefaults, default off, same place as the sound switch. It is not in the backup.

**Progression** and **RockCoach** do not read this. A missed buzz does not change the logged set.

### Tests

- Zero fires the strong pattern once. A second poll at zero does not fire it again.
- **Tap at 10 seconds** off: crossing 10 does nothing. On: one light tap as it crosses 10, and no chirp at that moment. A 8 second rest never taps. Adding time from 5 back to 20 arms one more tap.
- The chirp’s audio options are `.mixWithOthers` and `.duckOthers`. The keep-alive options are `.mixWithOthers` only. After the chirp, ducking is off.
- Other audio playing, no connected call: the chirp plays. The session does not use the option that interrupts spoken audio, and it does not stop the other player.
- A connected call: no chirp, no duck, zero haptic still requested. A call that begins during the chirp stops it.
- Skip: no zero haptic, no chirp, the Live Activity ends, the backup notification is cancelled.
- ±15 updates the activity’s end date once per tap. The activity is not updated every second. The countdown view is a timer interval.
- Live Activities unavailable: starting rest does not crash, the on-screen card still counts, and no per-second notification is scheduled.
- Notification permission denied: the backup notification is not scheduled, and rest in the foreground still chirps.
- Background or locked: the code arms one end-time notification and does not arm tick notifications. A device check, not a unit test: locked in a pocket, one buzz at zero, audiobook dips and continues, a call stays silent of the chirp.
- The silent switch does not change the category away from `.playback`.
- The end alert is not Time Sensitive.
- Phones without a Dynamic Island use the same activity. The countdown does not depend on an island-only view.

## Schema in one step

`RockLogSchemaV1` shipped in source at `eb497bd` and is frozen. Parts **b**, **c**, and **e** add optional fields with defaults in **one** `RockLogSchemaV2` and one lightweight stage. Shipping the screens in a later order is fine. Adding a further stored field after V2 is V3, so the fields we already know about belong in V2 even if the screen comes later.

Part **a** is key-value. Part **d** uses V1 fields. Focus starting weight is key-value, same as Next set default. Previous is a behavior change on the lift screen. Same-weight carry is this session only and adds no field. Learning’s offered weight, learned-or-typed flag, and Clear time belong in V2 with the stack profile.

CloudKit will accept this only as a lightweight additive change. There is no custom migration stage.

`PreviewSampleData` gains whatever new fields the models grow, or previews crash. Backup’s nil-vs-empty rule from PR #9 applies to every new array.

## Suggested build order

1. **Starting weight (Focus).** Settings choice, plan weight always wins, comparison line under the steppers. No migration.
2. **Previous mirrors Next (Focus).** Done and Resume stay on the bottom row. Back stays at the top. No migration.
3. **Same-weight carry.** No migration. Editing 145 on the first of two matching sets fills the second. Ramps stay. It can ship before a stack step exists.
4. **Reorder (d).** No migration. It is the gap he feels on the lift screen. The day-plan editor stays for editing the library.
5. **Per-lift rest and ±15 (the rest half of e).** Small, and it matches “the last exercise decides the break.” Circuits can follow in the next slice.
6. **Rest alert.** Pocket buzz, 10-second tap, ducked chime, Live Activity. Uses the timer from today, so it can sit beside per-lift rest and does not wait on circuits. The per-lift length, once it exists, is the duration this alert counts.
7. **Groups and auto-advance (the rest of e).**
8. **Body-weight lookup and added-load mode (b).** No new measurement model. Date-based assist math is the part that stops old assisted e1RMs from moving when he updates the scale.
9. **Pounds / kilograms and plate math (a).**
10. **Stack steps and learning (c).** 10, 15, 20 lb, and custom. Suggestions snap, and three matching corrections write the step. Needs the unit work so a kilogram stack and a pound stack stay distinct, and needs the shared Epley helper. Sits with the stack profile, after carry.
11. **Rest learning.** After real timer samples exist. Suggest only.

The month-boundary fix is already on `main` (`a877aad`, pull request #10) and is **not on TestFlight yet**. It does not block this list.

One V2 migration can land with the per-lift rest step, containing the optional fields for rest, groups, bodyweight load, and stacks, so later steps do not each mint a schema version. The two Focus items, same-weight carry, and the rest alert do not add SwiftData fields. The rest alert does add a widget extension for the Live Activity. Learning’s extra fields ride in the one V2 with the stack profile. Editing a finished workout is unchanged and is not a build step.

## Tests

**a. Units**

- 100 kg entered, stored as pounds, shown again as 100 kg.
- Staying in pounds, 225 stays 225. A 47.5 lb log still displays 47.5.
- Switching to kilograms and back moves at most one display step, and a second toggle in the same direction does not walk further.
- Plate readout for 135 lb is a 45 lb bar plus the pound plates. 60 kg uses a 20 kg bar plus the kilogram plates.
- A one-session suggestion of 137.3 lb still becomes 135 lb. The same load with kilograms selected snaps to 2.5 kg, not to 5 lb converted for display after the fact.
- A backup with no `weightUnit` restores as pounds. Numbers in an old file are unchanged.
- A weight that converts to more than 10,000 lb is refused on restore, with nothing changed.

**b. Body weight**

- Latest weigh-in on or before the session date is the one assist and added-load use. A later weigh-in does not change that session’s e1RM.
- A backdated weigh-in does not replace the Settings number when a newer log exists.
- Assist with no weigh-in and no Settings weight contributes 0 and says so.
- Added mode: body weight 180 and a 25 lb belt is load 205. Progression’s next target is expressed as added weight, not as 205 on the belt stepper.
- Relative line is e1RM / that day’s body weight. Missing weigh-in hides the line.
- Navy / FFMI tests still pass on the same entries.
- An old backup without a load mode restores assist flags as they are. A new backup round-trips added mode.
- Coach file: assisted set includes the body weight used. Coach “up / down” follows effective load (less assistance is up).

**c. Stacks**

- Fixed 10 lb step from 10 to 200 exposes 10, 20, …, 200. A 2.5 add-on also exposes 12.5, 22.5, …
- Nearest, down, and up policies, including a tie (nearest tie goes down).
- 205 × 5 on a 10 lb stack becomes 200 × 6 under nearest-with-tie-down, and the new e1RM is closer to the original than 200 × 5 or 200 × 7.
- A lift with no profile still snaps to 5 lb or 2.5 kg.
- A kilogram pin list stays on kilogram pins after a pound display conversion.
- Planned target in the file is unchanged after the phone shows a rounded pair.
- Backup round-trips a profile. An old backup restores with no profile and the old stepper.

**d. Reorder**

- Drag on the list and drag from the lift screen write the same `sortOrder`.
- After a drag, `followsSessionRoster` is true and the library day order is unchanged.
- Save to this day updates the day plan. Skipping that button leaves the day plan.
- Save to remaining planned days updates unused sessions with that day name and leaves finished sessions.
- History order matches the session order.
- Coach export array order matches the session. Best-set comparison for a lift is unchanged when its neighbours move.
- A planned session’s roster reorder does not change a different queued day.

**e. Groups and rest**

- A group of 2, 3, and 4 advances on a working set and wraps to the first unfinished member.
- A 5th lift is refused.
- Unequal counts: the lift that has hit its planned count is skipped; the partner keeps getting sets.
- A warm-up log does not advance.
- Rest after a squat uses the squat default; the next log, on a curl, starts the curl default even if the squat timer was still running.
- Skip clears the timer in one tap. −15 / +15 move a running timer by 15 seconds and do not change the saved default.
- Seed: a squat starts at 3 minutes, a curl at 90 seconds, an unknown lift at the Settings duration. An edited default wins over the seed.
- Learning: 8 samples, median 45 seconds from a 90 second default, offers 45 once. A 12 minute sample is ignored. Declining leaves the default.
- e1RM for the lift is unchanged by the rest value.
- V1 store opens on V2. Old sessions have no group. Backup round-trips a group and a per-lift rest. A file that omits them does not clear rests already on the phone.
- Coach file with a group id shows the pairing. A v1 file without it still imports, each lift on its own.

**Same-weight carry and the stack step.** Cases are under [Same-weight carry and the stack step](#same-weight-carry-and-the-stack-step).

**Rest alert.** Cases are under [Rest alert](#rest-alert). No SwiftData change.

## Open questions for Lee

1. Pounds as the stored unit, kilograms as a view. Confirm, or say if you want the store converted to kilograms instead.
2. Kilogram suggestions snap to 2.5 kg. Prefer 1.25 or 5?
3. Girths stay inches for now?
4. On RockCoach, always show the pounds the athlete logged, or follow a unit setting on the coach’s phone?
5. Added load (body weight plus a belt) is a third mode next to bar and assist. Is that the split you want?
6. Relative strength on the lift screen only, for the first build. A “divide the strength score by body weight” switch can wait. Agree?
7. Stack policy default is nearest, and an exact halfway tie rounds down. Prefer always down (never more than the target)?
8. One magnet at a time, or several?
9. One stack profile per exercise. A “same machine as this other lift” copy can wait. Agree?
10. Reorder saves the session always. Extra buttons save the day plan, and the remaining planned days. You do not want a reorder to change next week unless you tap that. Confirm.
11. From the lift screen, is long-press on the lift number the right drag handle?
12. Replace −30 / +30 with −15 / +15. Confirm.
13. Warm-up sets stay on the current lift; working sets advance the group. Prefer warm-ups to advance too?
14. The seed table (3 min legs, 2 min other compounds, 90 sec isolation) is a starting point. Change any of those?
15. Rest learning only suggests, and only after you turn it on. It never edits the default alone. Confirm.
16. A group is not written into the program file until you tap save. The phone can do groups before the program format knows about them. Agree?
17. The last-5-seconds tick tones go away, so an audiobook dips once at zero instead of five times. The 10-second cue is a haptic only, and its switch starts off. Confirm.
18. A learned stack step is the largest of 10, 15, and 20 lb that fits the corrected weights, and it is written after three sessions agree. A custom step is the greatest common divisor when it is above 5 lb. Change either rule?

## Crash when a set is logged with no live session

`WorkoutViewModel.findOrCreateRecord` used to call `fatalError` when Focus asked it to log a set and the session was already gone. That happens after a restore replaces the store, after the session is suspended, or when the session row has been deleted while the lift screen is still up.

The finder now returns nil. `addSet`, marking a lift done, and adding a lift to the session return without writing. The screen does not trap. `RockLogTests` covers a log with no live session.

## Warm-up tag

Warm-up is a tag on the set being logged. It is left out of estimated one-rep max, progression, suggestions, and same-weight carry.

Logging a warm-up does not copy the tag onto the next set. The next set opens warm only when that set's own plan says warm. `setLogged` clears the tag. The old bug was `FocusView.apply(prefill:)` copying `isWarmup` from the set just logged, and a no-op clear when the tag was already on.

An optional ramp, off until the lift asks for it, offers 50% × 8, 70% × 5, and 85% × 3 of the first working weight, snapped down to the stack step or to 5 lb. Nothing in that ramp is logged until he taps it. Those sets are warm-ups, so they stay out of the numbers above.

## Where the code moved

The new behavior lives beside the screens, not inside them.

| Path | What it holds |
| --- | --- |
| `RockLog/Services/Optimization/` | Units, load, stacks, carry, focus order, circuits, rest policy. Pure functions the tests call without a phone. |
| `RockLog/Models/Gym.swift`, `MachineStackProfile.swift` | Gyms and the (gym, lift) stack. |
| `Shared/Algorithm/BackupMigration.swift` | Backup payload v1 → v2, and the unknown-key count. |
| `Shared/CoachFormat/InterchangeCodec.swift` | The one JSON envelope. |
| `Shared/RestActivity/RestActivityAttributes.swift` | Live Activity fields compiled into the app. |
| `RockLogWidget/` | The extension. Its own bundle id, profile, and App Group are in [rest-widget.md](rest-widget.md). |
| `docs/format/` | JSON Schema, field table, and synthetic samples. |
| `docs/specs/schema-v2-rollback.md` | How to leave V2, and the rule against promoting the production CloudKit schema. |

`RockLogSchemaV2` is the only new schema stage. It is not V3.

## Interchange file

Import, export, backup, `.rocklogprogram`, split, and coach files share one envelope: `format` `rocklog.interchange`, `formatVersion`, `weightUnit`, `kind`, and `payload`. The field table, the version rules, and the synthetic samples are in [docs/format/README.md](../format/README.md).

The backup payload inside that envelope is version 2. Version 1 still opens. `BackupMigration.promoteToCurrent` is the pure step, and it only changes the version number. Version 0 and any version above 2 are refused. Unknown keys and unknown enum values are counted on the restore prompt. Weights stay full-precision pounds. Stack pins keep `pinUnitRaw`. Ids are not minted again, and a duplicate id in one list is refused.

Coach files moved to `schemaVersion` 2 in the same change as the RockCoach reader. The reader accepts 1 and 2 and refuses 0 and 3. A version 1 coach file still imports.
