# RockLog — session handoff

**Last updated:** 2026-08-14 (build **9** — welcome guide)  
**Project:** `~/strength-training`  
**App:** RockLog · bundle `com.lee.lift2026`  
**Marketing version:** 1.0 · **Build:** 9 (TestFlight)  
**Branch:** `main`  

> Resume: *“Continue from ~/strength-training — load docs/SESSION.md, README.md, docs/RELEASE-NOTES.md, CLAUDE.md.”*

---

## Status

- Last ship: **TestFlight build 9** — welcome guide + build 8 logging. See `docs/RELEASE-NOTES.md`.
- Next TF upload: bump `CURRENT_PROJECT_VERSION` **> 9**.
- **What to Test paste:** `docs/TESTFLIGHT-WHAT-TO-TEST.md` (no ASC API key — cannot set Test Details from this Mac).
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

**RockLog 1.0 (9) — first-run welcome + Settings replay. TF What to Test must be pasted (no API key).**
