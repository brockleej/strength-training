# RockLog — session handoff

**Last updated:** 2026-08-13 (build **8** shipping)  
**Project:** `~/strength-training`  
**App:** RockLog · bundle `com.lee.lift2026`  
**Marketing version:** 1.0 · **Build:** 8 (TestFlight)  
**Branch:** `main`  

> Resume: *“Continue from ~/strength-training — load docs/SESSION.md, README.md, docs/RELEASE-NOTES.md, CLAUDE.md.”*

---

## Status

- Last ship: **TestFlight build 8** — see `docs/RELEASE-NOTES.md`.
- Next TF upload: bump `CURRENT_PROJECT_VERSION` **> 8**.
- Friends testers **Invited** need resend invite / correct Apple ID (not a binary issue).
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

**RockLog 1.0 (8) on `main` — swipe-delete sets, finish prompt, exercise notes. Screenshot recapture still owed.**
