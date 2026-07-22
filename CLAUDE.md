# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Note:** This is a Swift/iOS project. Global instructions referencing Angular/TypeScript best practices do **not** apply here.

# IronLog (Strength Training iOS App)

## Project Overview

IronLog is a native iOS strength-training app built with SwiftUI and SwiftData. Users log gym workouts, track sets/reps/weight, rest timers, assisted lifts, and body metrics (Navy BF% → FFMI). Data is local-first (CloudKit optional when a paid team is available); HealthKit can start/stop Apple Fitness workouts on device.

- **Language:** Swift 6
- **Platform:** iOS 26.2+ (minimum deployment target)
- **Build:** Xcode 16+ (`.xcodeproj` — no SPM, CocoaPods, or package manager)
- **Frameworks:** SwiftUI, SwiftData, Swift Charts, HealthKit, CloudKit (all built-in)

## Build & Run

```bash
# Build for simulator
xcodebuild -scheme strength-training -destination 'platform=iOS Simulator,name=iPhone 17'

# Open in Xcode
open strength-training.xcodeproj
```

### Tests

```bash
# Run all iOS tests
xcodebuild test -scheme strength-training -destination 'platform=iOS Simulator,name=iPhone 17'

# Run a specific test class
xcodebuild test -scheme strength-training -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:strength-training-tests/<TestClassName>
```

No lint commands are configured.

### ProgressionLab (macOS dev tool)

Local-only macOS app for visualizing and tuning the progression algorithm. Never ships to TestFlight (separate scheme, not part of the Xcode Cloud workflow). See [docs/superpowers/specs/2026-05-03-progression-lab-design.md](docs/superpowers/specs/2026-05-03-progression-lab-design.md).

```bash
# Build the macOS dev tool
xcodebuild -scheme ProgressionLab -destination 'platform=macOS' build

# Run its tests
xcodebuild test -scheme ProgressionLab -destination 'platform=macOS'
```

### Deployment

**Xcode Cloud auto-deploys every push to `main` to TestFlight.** Treat `main` as a release branch — anything pushed ships to internal testers automatically. Direct pushes to `main` are allowed; PRs are optional.

### Local-dev caveats

- **HealthKit features require a physical device** — they will not function in the simulator.
- **CloudKit sync** requires an iCloud account and the CloudKit entitlement. For local-only development, configure your own iCloud container or temporarily disable the entitlement in `strength-training.entitlements`.

## Architecture

**MVVM** with SwiftUI's `@Observable` macro.

```
Models/        -> SwiftData @Model classes (Exercise, WorkoutSession, ExerciseRecord, SetRecord,
                  SplitDay, BodyMetricEntry) + day/rotation types, SeedData
ViewModels/    -> @Observable classes managing state per feature (incl. BodyMetricsViewModel)
Views/         -> SwiftUI views by feature (DesignSystem, Today, Workout, History, Progress, Library, Settings)
Services/      -> Backup, progression, E1RM, PRs, rest timer, body composition (Navy/FFMI),
                  HealthKit, CloudKit status, gym pass, split schedule
Utilities/     -> PreviewSampleData (preview helpers only)
```

### Key Patterns

- **State:** Use `@Observable` for ViewModels. Use `@Query` for reactive SwiftData reads. Use `@Bindable` for mutable ViewModel bindings. Use `@State` for local view state only.
- **Dependency injection:** Pass `ModelContext` via initializer into ViewModels — never access it directly from views.
- **SwiftData relationships:** Always define cascade delete rules on parent-side relationships.
- **CloudKit sync:** This build uses a local-only store (`cloudKitDatabase: .none`). `CloudKitSyncService` can monitor sync when CloudKit is re-enabled with a paid team.
- **HealthKit:** `HealthKitWorkoutService` handles authorization, starting/stopping Apple Fitness workouts, and saving workout metadata. Always check authorization status before performing HealthKit operations.
- **Adding a new SwiftData `@Model`:** the model must be registered in the `Schema([...])` array in `strength_trainingApp.swift` and also added to `PreviewSampleData`. Forgetting either causes runtime crashes — the schema in the app entry point is the source of truth for what CloudKit syncs.

## SwiftUI Conventions

### Design System ("Refined Native")

All screens compose the shared design system in `Views/DesignSystem/` — do not introduce ad-hoc styling:

- **Colors:** `Color.uplift.*` tokens only (surfaces, foregrounds, ice accent, day-type inks/washes, semantic up/down/pr, Apple-Health greens). Never hardcode hex values outside `Tokens.swift`.
- **Typography:** `Font.uplift.display/text/mono`. Hero/stat numerals use the `Num` component (SF Pro Display + tabular digits); small data numerals and live-ticking values use `Font.uplift.mono`.
- **Components:** `DayChip`, `UpliftStepper`, `UpliftSegmentedControl`, `GlassHeader`, `PillBottomBar`, `SectionHeader`, `HealthKitCard`, `Stat`/`SummaryStat`/`BigStat`, `FilterChip`, `SearchField`, `CircleButton`, `AddItemRow`, `EmptyListState`, `swipeToDelete`, reorder helpers in `ListMutationPatterns.swift`.
- **Appearance:** the app is locked to dark (`.preferredColorScheme(.dark)` + ice `.tint` in `ContentView`). Cards use continuous-corner rounded rectangles (14–20pt).
- **Shared math:** the Epley estimate lives in `E1RM.estimate` and per-session aggregates in `SessionMath` — never re-inline the formula.

### List mutation patterns

Keep remove / reorder / add **identical** across ordered lists (day plan, training split days, etc.):

| Action | Pattern |
|--------|---------|
| **Remove (soft)** | Verb **Remove** (from day / workout). Swipe reveals trash, then tap — `swipeToDelete(fullSwipeDeletes: false)` or List `allowsFullSwipe: false`. No confirm for soft unassign/session hide. |
| **Delete (hard)** | Verb **Delete** (library exercise, workout history, day type). Always **confirmation dialog** with a one-line consequence. Never full-swipe-commit hard deletes. |
| **Reorder** | Long-press + drag whole row (no Edit/Done, no system move handles). Shared `UUIDListDropDelegate` / `reorderDragSource` / `reorderDropTarget`. Hint: `ListMutationCopy.reorderAndRemove`. |
| **Add to context** | Dashed `AddItemRow` (“Add exercise” / “Add day”). Exercise-in-context uses `AddExerciseSheet` (Library \| New). Library toolbar `+` is create-only. |
| **Empty lists** | `EmptyListState` with optional primary `AddItemRow`. |

Copy constants live in `ListMutationCopy` — do not invent parallel labels.

### Previews

Use `PreviewSampleData` (in `Utilities/`) for all SwiftUI previews that require a `ModelContainer`. Do not create inline preview data — extend `PreviewSampleData` if new models need preview support.

```swift
#Preview {
    SomeView()
        .modelContainer(PreviewSampleData.container)
}
```

## App Icon

The icon source is `strength-training/strength_training.icon/` (Apple Icon Composer bundle). Xcode 16+ compiles `.icon` bundles directly — there is no PNG export step and no `AppIcon.appiconset`. The build setting `ASSETCATALOG_COMPILER_APPICON_NAME` is set to `strength_training` to match the bundle's stem name. To edit the icon, open the `.icon` bundle in Icon Composer and save; the next build picks it up automatically.

## Git Conventions

Use conventional commits:

```
feat: adds X feature
fix: resolves Y bug
refactor: improves Z
```

Direct pushes to `main` are allowed (every push auto-deploys to TestFlight, so confirm work is ready before pushing). Use feature branches + PRs when you want review before shipping. Keep work focused — one feature or fix per commit/PR.
