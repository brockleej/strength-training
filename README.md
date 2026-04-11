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

| Requirement | Version |
|-------------|---------|
| iOS | 26.2+ |
| Xcode | 16+ |
| Swift | 5.0+ |

---

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/danielkuhlwein/strength-training.git
cd strength-training
```

### 2. Open in Xcode

```bash
open strength-training.xcodeproj
```

### 3. Run the app

Select a simulator or connected device from the Xcode toolbar, then press **⌘R** to build and run.

> **Physical device:** You'll need to set a Development Team under _Signing & Capabilities_ in the project target settings. A free Apple ID is sufficient for personal use.

---

## Usage

1. **Start a workout** — Tap the Workout tab and choose Arms or Legs day
2. **Log sets** — Tap an exercise to expand it, adjust weight and reps, then tap _Add Set_
3. **Reference history** — The "Last" banner shows your best set from the previous session; tap _Last_ to prefill those values
4. **Switch training modes** — Use the Strength / Endurance toggle at the top of the workout screen
5. **Finish** — Tap _Finish Workout_ when done; the session is saved to history
6. **Review progress** — Visit the Progress tab to see charts broken down by exercise, mode, and metric

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Data persistence | SwiftData |
| Charts | Swift Charts |
| Architecture | MVVM + `@Observable` |

---

## Project Structure

```
strength-training/
├── Models/              # SwiftData model definitions (Exercise, WorkoutSession, ExerciseRecord, SetRecord)
├── ViewModels/          # Observable state managers (Workout, History, Charts)
├── Views/               # UI components organised by feature
│   ├── Workout/
│   ├── History/
│   ├── Charts/
│   └── Exercises/
└── Utilities/           # Seed data and SwiftUI preview helpers
```

---

## License

MIT
