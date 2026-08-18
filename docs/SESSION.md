# RockLog — session handoff

**Last updated:** 2026-08-17 (build **12** committed — not pushed)  
**Project:** `~/strength-training`  
**App:** RockLog · bundle `com.lee.lift2026`  
**Marketing version:** 1.0 · **Build:** 12 (local; TF still 11 until push)  
**Branch:** `main`  

> Resume: *“Continue from ~/strength-training — load docs/SESSION.md, README.md, docs/RELEASE-NOTES.md, CLAUDE.md.”*  
> HA is parked. ASC: RockLog 1.0 has build 11 attached; Aequis 1.0 has build 2 attached (icons, not submitted).

---

## Status

- Last ship: **TestFlight build 11** (2026-08-14). **12** is committed locally — push `main` when you want Xcode Cloud → TF.
- **2026-08-16:** ASC app-header icon was the placeholder because App Store version **1.0** had **no build selected**. Attached build **11** to 1.0 (Prepare for Submission — not submitted). After 12 is on TF, attach **12** if you want the store listing to follow.
- Next TF upload: **push main** (version already **12**).
- **RockCoach** stays **local** — scheme `RockCoach`, bundle `com.lee.rockcoach`. Do not archive/upload it. Notes: `docs/coaching-companion/PATH-1.md`.

### Do with the next bug-fix build (iCloud UI)

Sync is functioning. On the **next** bug-fix drop (not a standalone ship):

- **Remove** Settings **Retry sync** and pull-to-refresh-as-resync. User should not manage CloudKit.
- **Keep** a quiet **status indicator** (signed in / last synced / real failure only).
- Make sync **transparent**: no “hiccup / skipped items / pull to refresh” copy in the happy path. Don’t flip the row red on a later retryable export if import already succeeded.
- Leave the nudge code in the service if useful internally; just don’t expose it.
- **ASC API key (local):** `~/Documents/Hobbies/RockLog/secrets/` — create in App Store Connect, then `source …/scripts/asc-env.sh` + `asc-check.sh`. Not in git.
- Friends testers **Invited** need resend invite / correct Apple ID (not a binary issue).
- **User guide:** `docs/USER-GUIDE.md`. In-app: first launch + Settings → Welcome guide.
- **Next polish (not blocking):** recapture **README + App Store screenshots** — `docs/SCREENSHOTS.md`. Current `docs/screenshots/*.png` are stale.
- **RockCoach (Path 1):** session v1 unchanged. Catch-up uses sibling **`rocklog.coach.batch` v1** (same `.rocklogcoach` file). Share this workout or everything not yet sent. Not on TestFlight yet. Notes: `docs/coaching-companion/PATH-1.md`.

---

## Project map

| Path | Role |
|------|------|
| `strength-training/` | iOS app (SwiftUI + SwiftData) |
| `strength-training-tests/` | Unit tests |
| `Shared/Algorithm/` | Pure progression algorithm |
| `Shared/CoachFormat/` | `rocklog.coach.session` codec + set comparison |
| `RockCoach/` | Companion app (import / roster / session / progression) |
| `progression-lab/` | macOS algo lab (local only) |
| `docs/RELEASE-NOTES.md` | TF / ship notes |
| `docs/SCREENSHOTS.md` | README + App Store capture list (todo) |
| `CLAUDE.md` | Architecture + build commands |

**CloudKit:** `iCloud.com.lee.lift2026`  
**Note:** `main` → Xcode Cloud → TestFlight (treat main as release).

### Build

```bash
cd ~/strength-training
open strength-training.xcodeproj
# or
xcodebuild -scheme strength-training -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild test -scheme strength-training -destination 'platform=iOS Simulator,name=iPhone 17'
```

---

## One-line

**RockLog 1.0 (12) committed locally — split persist, Progress spreadsheet, welcome, coach send off. Not pushed. RockCoach local only.**
