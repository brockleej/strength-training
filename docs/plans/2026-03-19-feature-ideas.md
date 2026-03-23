# Strength Training App — Feature Ideas

**Generated:** March 19, 2026

---

## Feature 1: Rest Timer with Smart Defaults

### The Problem

The app currently has no rest period tracking between sets. Rest intervals are one of the most critical variables in strength training — they directly affect performance, recovery, and the type of adaptation stimulus. Without consistent rest periods, users can't accurately assess whether strength changes are due to programming or simply because they rested 5 minutes one session and 90 seconds the next. Every major competing app (Hevy, Strong, Fitbod, RepXP) treats the rest timer as a core feature, not an afterthought.

### What It Would Do

When a user logs a set via `addSet()` in `SetInputView`, a countdown timer automatically begins in the space between the logged sets list and the input controls. The timer is configurable per training mode:

- **Strength mode default:** 2:30 (heavier loads need longer phosphocreatine recovery)
- **Endurance mode default:** 0:45 (shorter rest maintains metabolic stress)
- Users can tap the timer to adjust ±15s, or long-press to set a custom default per exercise

The timer displays as a circular progress ring that drains as time passes. When it hits zero, the app fires a haptic notification (fitting naturally into the existing `HapticService` pattern) and optionally a subtle chime. If the user adds their next set before the timer expires, it simply resets — no friction.

### Architecture Fit

This feature slots cleanly into the existing codebase:

- **No new models needed.** Timer state is ephemeral (not persisted to SwiftData). A `RestTimerState` struct on `WorkoutViewModel` holding `duration`, `remainingSeconds`, and `isRunning` is sufficient. Per-exercise custom durations could be stored as an optional `restSeconds: Int?` property on `Exercise` if we want persistence.
- **View integration:** The timer UI lives inside `SetInputView`, appearing between the logged sets list and the weight/reps stepper area. It uses SwiftUI's `TimelineView` or a simple `Timer.publish` for the countdown animation.
- **Haptic integration:** Add a `restTimerComplete` case to `HapticService` — a double-tap notification pattern distinct from existing feedbacks.
- **Training mode awareness:** `WorkoutViewModel` already tracks the active `TrainingMode`, so switching modes mid-workout can automatically update the default rest duration.

### Value Add

Rest timers transform a logging app into a genuine training companion. Users no longer need to glance at a wall clock or run a separate timer app. Consistent rest tracking also makes the existing progress analytics (e1RM trends, volume scores) more meaningful, since the data was collected under controlled conditions.

---

## Feature 2: Superset & Circuit Grouping

### The Problem

The app currently treats every exercise as an independent, sequential item. In practice, many intermediate and advanced lifters use supersets (two exercises performed back-to-back with no rest between them, e.g., bench press + barbell row) and circuits (three or more exercises cycled through). This is one of the most common time-saving techniques in the gym, and without support for it, users either abandon accurate logging during supersets or avoid the feature entirely.

### What It Would Do

In the active workout view, users can long-press an exercise row and drag it onto another exercise to create a **group**. Grouped exercises are visually connected by a colored vertical bar on the left edge (a pattern used by Strong and Hevy that users recognize immediately). Within a group:

- Exercises alternate: after logging a set for Exercise A, the view auto-scrolls to Exercise B's input (similar to Hevy's "smart superset scrolling")
- The rest timer (from Feature 1) only starts after the *last* exercise in the group completes a round, not after each individual set
- Groups are labeled: "Superset" for 2 exercises, "Circuit" for 3+
- Users can tap a "break group" button to dissolve the grouping

### Architecture Fit

This requires a modest model addition:

- **New property on `ExerciseRecord`:** `groupId: UUID?` and `groupOrder: Int` — records sharing a `groupId` within the same session are displayed together. This avoids a new model class entirely; it's just two optional fields on an existing model.
- **ViewModel changes:** `WorkoutViewModel` gets methods like `createGroup(records:)`, `dissolveGroup(groupId:)`, and a computed property to return exercises organized by group. The `ActiveWorkoutView` reads groups and renders the vertical bar connector.
- **View changes:** `ExerciseRowView` gains a leading accent bar when `groupId != nil`. The curtain-reveal expansion pattern is preserved — only the grouping chrome changes. A new `GroupHeaderView` sits above each group showing "Superset" / "Circuit" and a dissolve button.
- **SwiftData migration:** Adding two optional properties to `ExerciseRecord` is a lightweight migration that SwiftData handles automatically.
- **Rest timer interaction:** The rest timer (Feature 1) checks whether the current record is part of a group. If so, it defers starting until the user has logged a set for every exercise in the group for that round.

### Value Add

Superset support unlocks a training methodology that a large segment of gym-goers use daily. It also opens the door to richer analytics later — e.g., tracking paired exercise performance (does supersetting bench with rows improve either lift over time?). The visual grouping makes workout logs in the History tab more readable and accurate representations of what actually happened in the gym.

---

## UI Improvement: SF Symbols 7 Draw Animations for Exercise Status

### The Problem

The exercise row currently shows three states: no icon (not started), a spinning gradient circle (in progress), and a green checkmark (completed). The spinning gradient is implemented as a custom `AngularGradient` rotating on a timer — functional but generic. Meanwhile, iOS 26 and SF Symbols 7 introduced **draw-on animations** at WWDC 2025, which simulate a pen-stroke effect when symbols appear. The checkmark is one of the symbols that looks most satisfying with this effect, and the app's minimum deployment target (iOS 26.2) means every user can see it.

### What It Would Change

Replace the current exercise completion animation sequence with SF Symbols 7 draw effects:

1. **Not started:** `circle` symbol, grey, static
2. **In progress:** `circle.dotted` with a `.pulse` symbol effect (replaces the custom AngularGradient spinner — fewer lines of code, consistent with system aesthetics)
3. **Completed:** `checkmark.circle.fill` with `.drawOn` symbol effect, green — the checkmark strokes itself into existence when the exercise is marked complete

The implementation is roughly:

```swift
Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle.dotted")
    .symbolEffect(.drawOn, isActive: justCompleted)
    .symbolEffect(.pulse, isActive: isInProgress && !isCompleted)
    .foregroundStyle(isCompleted ? .green : .secondary)
```

This replaces the current `AngularGradient` + `RotationEffect` + `Timer` approach with a single declarative modifier, removing ~20 lines of custom animation code from `ExerciseRowView`.

### Additional Polish Opportunities

- Apply the same `.drawOn` effect to the **workout completion** state — when the user taps "Finish Workout," a large checkmark draws itself in the confirmation dialog
- Use `.drawOn` for the **PR badge** that appears in `SessionDetailView` — the star/trophy symbol drawing itself feels celebratory and earned
- The chevron rotation on exercise row expansion could use `.symbolEffect(.rotate)` instead of manual `rotationEffect`, aligning with the system animation language

### Value

This is a small change with outsized perceptual impact. Draw animations feel handcrafted and premium. They signal to users that the app is modern and maintained. The code also becomes simpler — replacing a manual timer-driven gradient animation with a single Apple-provided modifier improves maintainability and performance (SF Symbol animations are GPU-accelerated and battery-efficient).

---

*These ideas were generated by analyzing the current codebase, reviewing 2026 strength training app trends (Hevy, Strong, Fitbod, RepXP, Setgraph), and evaluating new SwiftUI/SF Symbols capabilities from WWDC 2025.*
