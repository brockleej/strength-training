# RockLog — session handoff

**Parked:** 2026-08-30 (shipped PR 7 + Progress/score from this session)  
**Project:** `~/strength-training-pr7` (branch `cursor/swipe-delete-tap-c4d4`) · dirty `~/strength-training` still leave it  
**App:** RockLog · bundle `com.lee.lift2026` · Apple ID `6797695631`  
**Marketing version:** 1.0 · **Testers now:** **25** (VALID, Friends).  
**Pushing `main` starts Xcode Cloud.**

> Resume: *“Continue from ~/strength-training-pr7 — load docs/SESSION.md. Testers: TF 25 Friends. Listing 1.0 still Prepare for Submission.”*  
> HA parked: `~/Documents/Hobbies/Home Automation/docs/HA-SESSION.md`.

---

## Git

| Place | State |
|------|--------|
| `origin/main` | This ship (PR 7 + Progress snapshot + strength-score slots + Side-tag load). |
| `~/strength-training` | Stale local `main`. **Do not checkout, stash, or discard.** |
| `~/strength-training-pr8` | PR **#8** `cursor/planned-owns-today-9fdc` — planned queue owns Today. **Not in this ship.** |
| PR **#7** | Swipe trash + last-day keep + use planned as split + Progress/score. |

---

## This TestFlight (25)

What to Test is on the build. Friends is attached.

Shipped here:

- Swipe-left trash on Edit [day] and Edit training split actually removes the row (build 24 showed trash; tap did nothing).
- Last remaining split day cannot be deleted — **Keep at least one day**. If planned workouts are waiting, **Use planned workouts as my split** under the last preset.
- Progress tab snapshots once (first open can spin; should not freeze).
- Strength score = strongest estimated 1RM **per muscle**. Side-tagged sets count both limbs. Dumbbell vs barbell bench share chest.

Not in this ship (still PR #8):

- Planned queue owns Today (hide split cards while unused planned sessions wait).

---

## What to Test

See **Next TestFlight** in `docs/TESTFLIGHT-WHAT-TO-TEST.md`. Testers are non-technical.

After Cloud succeeds:

```
~/Documents/Hobbies/RockLog/scripts/asc-set-what-to-test.sh <build>
```

Add Friends to that build (Lee asked for this push).

---

## Publish process

1. Repo, README, TestFlight, What to Test.
2. Merge `main` only when Lee wants a build.
3. Watch Xcode Cloud. Success includes pasting What to Test.
4. Friends: Lee asked to add them on this push.
5. Testers are non-technical.
6. 6pm daily check: ask Friends if Groups(0); auto-fill blank What to Test only after a successful Cloud build.

## App Store Connect 1.0

*Prepare for Submission*. **Not ready to submit.**

| Item | Status |
|------|--------|
| iPhone 6.9" screenshots (6) | COMPLETE on listing |
| App previews | Empty — optional |
| Age 4+, name, subtitle | Done |
| Description, keywords, support URL, privacy URL | **Missing** |
| Category, copyright, App Review contact | **Missing** |
| Build attached to the listing | Still **11** — attach a current TF when you mean 1.0 |
| iPad 13" screenshots | None (app is iPhone+iPad) |

RockCoach stays GitHub/local only. Cloud must stay on the RockLog scheme. `ci_pre_xcodebuild.sh` fails if Cloud is pointed at RockCoach; pins RockLog to `max(17, CI_BUILD_NUMBER)`.

ASC API (local, not in git): `~/Documents/Hobbies/RockLog/secrets/` + `source …/scripts/asc-env.sh`.

---

## Decisions (keep)

| Topic | Decision |
|---|---|
| One RockLog vs share-only SKU | **One app.** |
| Share vs backup | **Stay separate.** Coach file ≠ restore. |
| Coach UI | Hidden behind **Use RockCoach** (default off). |
| RockCoach TestFlight | **No.** |
| Tonnage in coach | **No.** |
| Duration | Set span, not Start→Finish wall. |
| Note keyboard | Cancel/Save on the lift screen. |
| Doc-only `main` pushes | **Avoid.** |
| Programmed block + split | **Block owns Today** is PR #8, not this ship. This ship: keep last split day; optional **Use planned workouts as my split**. |
| Strength score | Best e1RM per primary muscle. Side tag doubles load. |
| Personal logs / backup JSON | **Never commit.** |

Backup used for shots: `~/Documents/RockLog-backup-2026-08-26.json`. Body check-in is **sim only**. Phone unchanged.

---

## Next

1. Confirm swipe trash and last-day copy on device (TF 25).
2. PR #8 (planned owns Today) when Lee wants that — do not merge to `main` until then.
3. Listing copy / privacy URL / attach a current TF to 1.0 when submitting.

---

## Project map

| Path | Role |
|------|------|
| `strength-training/` | RockLog |
| `strength-training-tests/` | Unit tests |
| `Shared/Algorithm/` | Pure progression algorithm |
| `Shared/CoachFormat/` | session/batch codec + compare grid |
| `RockCoach/` | Companion (local) |
| `RockCoachShare/` | Share extension |
| `progression-lab/` | macOS algo lab (local only) |
| `AGENTS.md` | Architecture + build |

**CloudKit:** `iCloud.com.lee.lift2026`
