# RockLog — session handoff

**Last updated:** 2026-08-14 (build **11** — iCloud retry + export warning)  
**Project:** `~/strength-training`  
**App:** RockLog · bundle `com.lee.lift2026`  
**Marketing version:** 1.0 · **Build:** 11 (TestFlight)  
**Branch:** `main`  

> Resume: *“Continue from ~/strength-training — load docs/SESSION.md, README.md, docs/RELEASE-NOTES.md, CLAUDE.md.”*

---

## Status

- Last ship: **TestFlight build 11** — Retry nudges CloudKit; export PartialFailure is a warning if import already succeeded.
- **CloudKit:** still deploy schema Dev → Production if a device never synced — `~/Documents/Hobbies/RockLog/docs/CLOUDKIT.md`.
- Next TF upload: bump `CURRENT_PROJECT_VERSION` **> 11**.
- **ASC API key (local):** `~/Documents/Hobbies/RockLog/secrets/` — create in App Store Connect, then `source …/scripts/asc-env.sh` + `asc-check.sh`. Not in git.
- Friends testers **Invited** need resend invite / correct Apple ID (not a binary issue).
- **User guide:** `docs/USER-GUIDE.md`. In-app: first launch + Settings → Welcome guide.
- **Next polish (not blocking):** recapture **README + App Store screenshots** — `docs/SCREENSHOTS.md`. Current `docs/screenshots/*.png` are stale.

---

## Project map

| Path | Role |
|------|------|
| `strength-training/` | iOS app (SwiftUI + SwiftData) |
| `strength-training-tests/` | Unit tests |
| `Shared/Algorithm/` | Pure progression algorithm |
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

**RockLog 1.0 (11) — Retry nudges CloudKit; export PartialFailure is a warning after a good import.**
