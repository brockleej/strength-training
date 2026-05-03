# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Note:** This is a Swift/iOS project. Global instructions referencing Angular/TypeScript best practices do **not** apply here.

# UpLift (Strength Training iOS App)

## Project Overview

UpLift is a native iOS fitness tracking app built with SwiftUI and SwiftData. Users log gym workouts, track sets/reps/weight, and visualize progress over time. Workout data syncs automatically to iCloud via CloudKit, and HealthKit integration allows starting/stopping Apple Fitness workouts directly from within the app.

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

No test target or lint commands are configured.

### Deployment

**Xcode Cloud auto-deploys every push to `main` to TestFlight.** Treat `main` as a release branch — anything merged ships to internal testers automatically. PRs are required; direct pushes to `main` are restricted.

### Local-dev caveats

- **HealthKit features require a physical device** — they will not function in the simulator.
- **CloudKit sync** requires an iCloud account and the CloudKit entitlement. For local-only development, configure your own iCloud container or temporarily disable the entitlement in `strength-training.entitlements`.

## Architecture

**MVVM** with SwiftUI's `@Observable` macro.

```
Models/        -> SwiftData @Model classes (Exercise, WorkoutSession, ExerciseRecord, SetRecord)
               -> Enums, ProgressionTypes, BackupModels, SeedData
ViewModels/    -> @Observable classes managing state per feature
Views/         -> SwiftUI views, organized by feature (Workout, History, Progress, Library, Settings, Components)
Services/      -> BackupService, CloudKitSyncService, HealthKitWorkoutService, ProgressionService, HapticService
Utilities/     -> PreviewSampleData (preview helpers only)
```

### Key Patterns

- **State:** Use `@Observable` for ViewModels. Use `@Query` for reactive SwiftData reads. Use `@Bindable` for mutable ViewModel bindings. Use `@State` for local view state only.
- **Dependency injection:** Pass `ModelContext` via initializer into ViewModels — never access it directly from views.
- **SwiftData relationships:** Always define cascade delete rules on parent-side relationships.
- **CloudKit sync:** SwiftData is configured with CloudKit integration for automatic iCloud backup. The `CloudKitSyncService` manages sync status monitoring.
- **HealthKit:** `HealthKitWorkoutService` handles authorization, starting/stopping Apple Fitness workouts, and saving workout metadata. Always check authorization status before performing HealthKit operations.
- **Adding a new SwiftData `@Model`:** the model must be registered in the `Schema([...])` array in `strength_trainingApp.swift` and also added to `PreviewSampleData`. Forgetting either causes runtime crashes — the schema in the app entry point is the source of truth for what CloudKit syncs.

## SwiftUI Conventions

### Expansion Panel Animation Pattern

The project uses a custom curtain-reveal pattern for expandable rows (e.g., `ExerciseRowView`). Key rules to preserve this behavior:

1. **Keep the row header static** — never move it or re-layout it during animation. The header must stay in a fixed position in the view hierarchy regardless of expanded state.
2. **Reveal content with frame clipping**, not opacity or conditional rendering:
   ```swift
   expandedContent
       .frame(height: isExpanded ? nil : 0)
       .clipped()
   ```
3. **Chevron rotation** via `rotationEffect`:
   ```swift
   Image(systemName: "chevron.down")
       .rotationEffect(.degrees(isExpanded ? 180 : 0))
       .animation(.easeInOut, value: isExpanded)
   ```
4. The content should reveal *behind* the header (curtain effect), not overlay it.

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

PRs against `main` are required; direct pushes are restricted. Keep PRs focused — one feature or fix per PR.
