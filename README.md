# Strength Training

A native iOS app for tracking gym workouts, built with SwiftUI and SwiftData. Log sets, monitor progress, and review your training history — all stored locally on device.

---

## Features

- **Workout sessions** — Start an Arms or Legs day session and log exercises as you go
- **Set logging** — Record weight and reps with quick increment/decrement controls
- **Training modes** — Toggle between Strength (heavy/low reps) and Endurance (light/high reps) per session
- **Last session reference** — Automatically surfaces your best set from the previous session so you know what to beat
- **Exercise library** — 19 built-in exercises across Arms and Legs days, plus support for custom exercises
- **Workout history** — Browse past sessions grouped by month, filterable by day type
- **Progress charts** — Visualize weight, reps, and total volume progression per exercise over time
- **Offline-first** — All data is stored locally using SwiftData; no account or internet connection required

---

## Screenshots

<p align="center">
  <img src="docs/screenshots/workout.png" alt="Workout" width="200" />
  <img src="docs/screenshots/exercises.png" alt="Exercises" width="200" />
  <img src="docs/screenshots/history.png" alt="History" width="200" />
  <img src="docs/screenshots/progress.png" alt="Progress" width="200" />
</p>

---

## Requirements

- Xcode 16+
- iOS 26.2+

## Build & Run

```bash
# Build for simulator
xcodebuild -scheme strength-training -destination 'platform=iOS Simulator,name=iPhone 17'

# Open in Xcode
open strength-training.xcodeproj
```

## App Icon

The icon source file is `strength_training.icon/` (Apple Icon Composer).

Icon Composer exports PNGs with an alpha channel, which App Store Connect rejects (ITMS-90717). After exporting, strip the alpha with the included script:

```bash
# 1. Copy the three iOS variants into the asset catalog
cp "strength_training Exports/strength_training-iOS-Default-1024x1024@1x.png" \
   strength-training/Assets.xcassets/AppIcon.appiconset/Icon-iOS-Default.png
cp "strength_training Exports/strength_training-iOS-Dark-1024x1024@1x.png" \
   strength-training/Assets.xcassets/AppIcon.appiconset/Icon-iOS-Dark.png
cp "strength_training Exports/strength_training-iOS-TintedDark-1024x1024@1x.png" \
   strength-training/Assets.xcassets/AppIcon.appiconset/Icon-iOS-Tinted.png

# 2. Strip alpha channel
swift scripts/strip-icon-alpha.swift \
  strength-training/Assets.xcassets/AppIcon.appiconset/*.png

# 3. Clean up the exports folder
rm -rf "strength_training Exports/"
```
