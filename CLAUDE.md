# CLAUDE.md — Strength Training iOS App

> **Note:** This is a Swift/iOS project. Global instructions referencing Angular/TypeScript best practices do **not** apply here.

## Project Overview

Native iOS fitness tracking app built with SwiftUI and SwiftData. Users log gym workouts, track sets/reps/weight, and visualize progress over time. Purely local — no networking layer, no external dependencies.

- **Language:** Swift 5.0+
- **Platform:** iOS 26.2+ (minimum deployment target)
- **Build:** Xcode 16+ (`.xcodeproj` — no SPM, CocoaPods, or package manager)
- **Frameworks:** SwiftUI, SwiftData, Swift Charts (all built-in)

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
Models/        → SwiftData @Model classes (Exercise, WorkoutSession, ExerciseRecord, SetRecord)
ViewModels/    → @Observable classes managing state per feature
Views/         → SwiftUI views, organized by feature
Services/      → BackupService (import/export)
Utilities/     → PreviewSampleData (preview helpers only)
```

### Key Patterns

- **State:** Use `@Observable` for ViewModels. Use `@Query` for reactive SwiftData reads. Use `@Bindable` for mutable ViewModel bindings. Use `@State` for local view state only.
- **Dependency injection:** Pass `ModelContext` via initializer into ViewModels — never access it directly from views.
- **SwiftData relationships:** Always define cascade delete rules on parent-side relationships.
- **No networking:** There is intentionally no network layer. Keep it that way unless explicitly asked to add one.

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

The icon source file is `strength_training.icon/` (Apple Icon Composer). Icon Composer exports 16-bit RGBA PNGs, but App Store rejects alpha channels (ITMS-90717). After exporting, always strip alpha before committing.

**Workflow after re-exporting from Icon Composer:**

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

## Git Conventions

Use conventional commits:

```
feat: adds X feature
fix: resolves Y bug
refactor: improves Z
```
