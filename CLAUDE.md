# CLAUDE.md — UpLift (Strength Training iOS App)

> **Note:** This is a Swift/iOS project. Global instructions referencing Angular/TypeScript best practices do **not** apply here.

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

No separate test or lint commands are configured.

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

## Git Conventions

Use conventional commits:

```
feat: adds X feature
fix: resolves Y bug
refactor: improves Z
```
