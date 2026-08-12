# RockLog — session handoff

**Last updated:** 2026-08-11 (build **7** shipping)  
**Project:** `~/strength-training`  
**App:** RockLog · bundle `com.lee.lift2026`  
**Marketing version:** 1.0 · **Build:** 7 (TestFlight)  
**Branch:** `main`  

> Resume: *“Continue from ~/strength-training — load docs/SESSION.md, README.md, docs/RELEASE-NOTES.md, CLAUDE.md.”*

---

## Status

- Last ship: **TestFlight build 7** — see `docs/RELEASE-NOTES.md`.
- Next TF upload: bump `CURRENT_PROJECT_VERSION` **> 7**.
- Friends testers **Invited** need resend invite / correct Apple ID (not a binary issue).

---

## Project map

| Path | Role |
|------|------|
| `strength-training/` | iOS app (SwiftUI + SwiftData) |
| `strength-training-tests/` | Unit tests |
| `Shared/Algorithm/` | Pure progression algorithm |
| `progression-lab/` | macOS algo lab (local only) |
| `docs/RELEASE-NOTES.md` | TF / ship notes |
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

**RockLog 1.0 (6) on main — ready for next feature / TF build 7+.**
