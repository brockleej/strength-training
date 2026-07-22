<div align="center">
  <img src="docs/screenshots/app_icon.png" alt="IronLog Icon" width="120" />
  <h1>IronLog</h1>
  <em>Your gym, your data, your progress.<br>A native iOS strength tracker built with SwiftUI.</em>
  <br><br>

  <img src="https://img.shields.io/badge/Platform-iOS_26.2+-000000?style=flat-square&logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/Swift-6-FA7343?style=flat-square&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/SwiftUI-blue?style=flat-square&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" />
</div>

---

> [!NOTE]
> **IronLog** is a **hobby project** I ([Lee Brock](https://github.com/brockleej)) build for my own workout tracking and metrics. The product shape—freeform splits, assisted lifts, rest timer habits, body measurements / FFMI, gym pass, and the dark “refined native” UI—reflects **how I actually train**, not a generic fitness checklist. Data lives on-device by default (SwiftData). Export a JSON backup anytime. If you find it useful, feel free to use it, fork it, or contribute.

## Acknowledgments & authors

This project stands on a strong foundation. **Significant gratitude** goes to **[Daniel Kuhlwein](https://github.com/danielkuhlwein)** for the **initial app**: the overall organization, MVVM + SwiftData architecture, progression engine, design-system direction, HealthKit/CloudKit wiring, and the framework that made IronLog possible to extend. Much of the structure you see in this repo still traces back to that work.

### Authors

| Author | Role |
| --- | --- |
| **[Daniel Kuhlwein](https://github.com/danielkuhlwein)** | Original app, organization, and framework |
| **[Lee Brock](https://github.com/brockleej)** | Maintainer; IronLog branding, training-style features, body metrics, and ongoing product direction |
| **[Grok](https://x.ai)** (xAI) | Co-author / pair-programming collaborator on features, refactors, docs, and day-to-day development |

## Screenshots

<p align="center">
  <img src="docs/screenshots/workout.png" alt="Workout" width="200" />
  <img src="docs/screenshots/exercises.png" alt="Exercises" width="200" />
  <img src="docs/screenshots/history.png" alt="History" width="200" />
  <img src="docs/screenshots/progress.png" alt="Progress" width="200" />
</p>

## Features

### Training
- **Freeform training splits** — define day types (Push/Pull/Legs, Upper/Lower, custom names) and assign exercises per day
- **Rolling or strict weekly schedule** — advance through the split after each workout, or stick to a Mon–Sun plan
- **Focus workout UI** — log sets with steppers, training mode (strength / endurance), and last-session reference
- **Supersets & multi-exercise flow** — move between exercises in a session without losing place
- **Assisted lifts** — mark sets as assisted (e.g. pull-ups/dips); tonnage uses body weight − assist (never negative)
- **Rest timer** — global defaults plus per-exercise on/off (handy for supersets); optional countdown sounds
- **Progressive overload** — built-in suggestions for next weight/reps from recent history
- **PR detection** — celebrate e1RM, top-set weight, and rep PRs

### Progress & body
- **Dashboard** — volume, strength score (e1RM), PRs this month, muscle-group volume, mode split, lift progression
- **Body metrics** — log weight, waist, neck, chest, arm, hips (sex-aware labels and Navy formula requirements)
- **Muscularity index** — US Navy body-fat estimate → **FFMI** with bands (Light → Elite); trends and charts
- **Height & sex** in Settings for composition math; weight syncs for assisted lifts

### Everyday gym
- **Gym pass** — store membership barcode/ID and show a bright scan-friendly pass from Today
- **HealthKit** — start/stop Apple Fitness workouts and rate effort (device required)
- **JSON backup** — export / restore full workout data
- **Design system** — dark “Refined Native” UI (ice accent, tabular stats, shared components)
- **Offline-first** — SwiftData local store; no account required

### Data & sync
- **Local by default** in this build (`cloudKitDatabase: .none`) — Personal Team cannot provision CloudKit
- **CloudKit path remains in code** — can be re-enabled with a paid Apple Developer Program team
- **Export backup** recommended for safekeeping when iCloud sync is off

## How It Works

```mermaid
graph LR
    A["SwiftUI Views"] --> B["ViewModels"]
    B --> C["SwiftData Models"]
    B --> F["ProgressionService"]
    B --> G["BodyCompositionMath"]
    B --> E["HealthKit"]
    C --> D["Local store / optional CloudKit"]

    style A fill:#1a1a2e,stroke:#7dd3fc,color:#fff
    style B fill:#1a1a2e,stroke:#7dd3fc,color:#fff
    style C fill:#1a1a2e,stroke:#0f3460,color:#fff
    style D fill:#1a1a2e,stroke:#0f3460,color:#fff
    style E fill:#1a1a2e,stroke:#0f3460,color:#fff
    style F fill:#1a1a2e,stroke:#0f3460,color:#fff
    style G fill:#1a1a2e,stroke:#0f3460,color:#fff
```

1. **Views** render UI and send actions to **ViewModels** (`@Observable`)
2. **ViewModels** own feature state and talk to **SwiftData** via injected `ModelContext`
3. **Services** handle progression, E1RM, PRs, rest timer, body composition, HealthKit, and backup
4. **Design system** under `Views/DesignSystem/` provides tokens, typography, and shared components

## Getting Started

### Prerequisites

- Xcode 16+
- iOS 26.2+ simulator or device
- Apple Developer account for device signing / TestFlight

### Build & Run

```bash
# Clone
git clone https://github.com/brockleej/strength-training.git
cd strength-training

# Open in Xcode
open strength-training.xcodeproj

# Or build for simulator
xcodebuild -scheme strength-training -destination 'platform=iOS Simulator,name=iPhone 17'
```

Select your **signing team** under the app target → Signing & Capabilities, then run.

### Tests

```bash
xcodebuild test -scheme strength-training -destination 'platform=iOS Simulator,name=iPhone 17'
```

### ProgressionLab (macOS)

Local-only macOS tool for visualizing/tuning the progression algorithm (separate scheme; not shipped to TestFlight).

```bash
xcodebuild -scheme ProgressionLab -destination 'platform=macOS' build
xcodebuild test -scheme ProgressionLab -destination 'platform=macOS'
```

See [docs/superpowers/specs/2026-05-03-progression-lab-design.md](docs/superpowers/specs/2026-05-03-progression-lab-design.md).

### Local-dev caveats

- **HealthKit** needs a physical device
- **CloudKit** needs a paid team + entitlements; this repo currently uses a **local-only** store
- Use **Settings → Export Backup** before reinstalls or when switching devices without iCloud

## TestFlight

**Xcode Cloud** deploys every push to `main` to TestFlight for internal testers. Treat `main` as a release branch.

To request beta access, [open an issue](https://github.com/brockleej/strength-training/issues).

<details>
<summary><strong>Project structure</strong></summary>

```
strength-training/
├── Models/                 # SwiftData @Model types
│   ├── Exercise, WorkoutSession, ExerciseRecord, SetRecord
│   ├── SplitDay, BodyMetricEntry
│   └── SeedData, day/rotation types
├── ViewModels/             # @Observable feature VMs
│   ├── WorkoutViewModel, HistoryViewModel
│   ├── ProgressDashboardViewModel, BodyMetricsViewModel
│   └── ExerciseDrillDownViewModel
├── Views/
│   ├── Today/              # Home, day picker, week strip
│   ├── Workout/            # Focus flow, sets, supersets, assist
│   ├── History/            # Sessions list + detail
│   ├── Progress/           # Charts, body metrics, muscularity
│   ├── Library/            # Exercises & day plan editor
│   ├── Settings/           # Split, rest timer, body profile, gym pass, backup
│   └── DesignSystem/       # Tokens, typography, shared components
├── Services/
│   ├── Progression, E1RM, PRDetection, SessionMath
│   ├── Rest timer + sounds, body composition (Navy BF% → FFMI)
│   ├── HealthKit, CloudKit status, backup, gym barcode
├── Utilities/              # Preview sample data
├── strength_training.icon/ # App icon (Icon Composer)
└── LaunchScreen.storyboard
Shared/
└── Algorithm/              # Shared progression types (app + ProgressionLab)
```

</details>

## Contributing

Contributions welcome:

- Conventional commits (`feat:`, `fix:`, `refactor:`, …)
- Focused PRs (one feature/fix each)
- MVVM + `@Observable` — see [CLAUDE.md](CLAUDE.md) for architecture notes
- Direct pushes to `main` ship to TestFlight automatically — prefer a PR when you want review first

Please keep the tone of the project in mind: this is a personal training log first. Features that match real gym workflows are preferred over generic “fitness app” checklists.

## License

MIT — do whatever you want with it.

Upstream roots and inspiration live in the original strength-training work by Daniel Kuhlwein; this fork continues that lineage as **IronLog**.
