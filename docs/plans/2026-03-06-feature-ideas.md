---
title: Feature Ideas — Mar 6, 2026
date: 2026-03-06
tags:
  - feature-ideas
  - brainstorm
  - strength-training
status: draft
---

# Feature Ideas — Mar 6, 2026

Two new feature concepts and one UI improvement, based on a fresh review of the codebase and current trends in strength training apps and iOS 26 capabilities. These are distinct from the Feb 27 batch (Recovery Readiness, RPE Suggestions, Liquid Glass/Haptics).

---

## Feature 1: Intelligent Rest Timer with Live Activities

### The Problem

The app currently has no rest timer between sets. After logging a set, the user has to switch to a separate timer app or watch the clock — breaking flow and often leading to inconsistent rest periods. Rest duration is one of the most important training variables: too short and performance suffers on the next set, too long and the workout drags on for hours. Every major competing app (Hevy, Strong, Stronglifts, Setgraph) includes a rest timer as a core feature, and its absence is the single most noticeable gap in this app's workout flow.

### The Idea

Add a **context-aware rest timer** that auto-starts after each logged set, with duration recommendations based on training mode and exercise type, and surfaces on the Lock Screen via iOS Live Activities.

**How it works:**

1. **Auto-start on set completion** — When the user logs a set, a countdown timer begins immediately. A compact timer bar appears at the bottom of `ActiveWorkoutView`, showing time remaining with a circular progress ring. Tapping it expands to a larger view with +15s / -15s adjustment buttons.

2. **Smart default durations** — Rest periods default based on training mode and exercise category:
   - **Strength mode, compound lifts** (squat, deadlift, bench): 3:00
   - **Strength mode, isolation**: 2:00
   - **Endurance mode**: 1:00–1:30
   - Users can override per-exercise in the Exercise Library, or globally in Settings.

3. **Live Activity on Lock Screen** — Use `ActivityKit` to display the timer as a Live Activity. The user can lock their phone between sets and still see the countdown on their Lock Screen and Dynamic Island. When the timer hits zero, a gentle haptic pulse and notification alert them. This is the killer UX detail — users don't have to keep the app open.

4. **Adaptive nudging** — If the user consistently logs their next set well before the timer expires (e.g., within 60% of the rest period), the app surfaces a one-time suggestion: "You usually rest about 1:30 for this exercise. Want to update the default?" This learns from behavior without being pushy.

5. **Session rest summary** — After finishing a workout, include average rest duration and total rest time in the `SessionDetailView`. This is useful data that's currently invisible.

### Value Add

Rest timers are the #1 most-requested feature in strength training app reviews. The Live Activity integration is a genuine differentiator — most competing apps only show the timer in-app. Having it on the Lock Screen means the phone can stay in a pocket or on a bench between sets, which is how people actually train. The adaptive defaults eliminate the "one-size-fits-all" problem that makes static timers annoying.

### Implementation Notes

- **New `RestTimerService`** (`@Observable`) — manages countdown state, fires haptics on completion, starts/stops Live Activities via `ActivityKit`.
- **`RestTimerConfiguration`** — stored in `UserDefaults`. Maps exercise categories to default durations. Per-exercise overrides stored as an optional `restDurationSeconds: Int?` on the `Exercise` model (minor schema addition).
- **UI additions**: compact timer bar in `ActiveWorkoutView` (floating at bottom), expanded timer overlay, rest stats in `SessionDetailView`.
- **Live Activity**: define an `ActivityAttributes` struct for the timer, a simple `ActivityContent` with countdown and exercise name. Uses `ActivityKit` — no networking needed, purely local.
- **Haptics**: reuse existing `HapticService`, add a `restComplete()` pattern (double tap notification).
- **Data**: optionally log rest durations on `SetRecord` as `restBeforeSeconds: Int?` for the session summary. This is the only schema change beyond the exercise-level override.

---

## Feature 2: Plate Calculator & Warm-Up Ramp Generator

### The Problem

When a user's suggested working weight is, say, 185 lbs on bench press, they have to mentally figure out which plates to load on each side of a 45 lb bar (that's a 45 + 25 + a 2.5 per side — not trivial mental math mid-gym). Then they need to figure out warm-up sets: jumping straight from an empty bar to 185 lbs is a recipe for injury, but figuring out a sensible ramp (bar → 95 → 135 → 165 → 185) requires planning that most people skip. The app currently has no concept of warm-up programming or load visualization.

### The Idea

Add a **visual plate calculator** and **automatic warm-up ramp generator** that integrates directly into the workout logging flow.

**How it works:**

1. **Plate calculator visualization** — When the user taps on a weight value (or a new "plates" icon) in `SetInputView`, a bottom sheet slides up showing a barbell diagram with color-coded plates on each side. Standard plate inventory: 45, 35, 25, 10, 5, 2.5 lbs (configurable in Settings for gyms with different plates or kg users).

2. **Barbell visualization** — A horizontal SVG/SwiftUI drawing of a barbell with proportionally-sized, color-coded plates stacked on each side. Red for 45s, blue for 35s, yellow for 25s, green for 10s, etc. (matching common gym plate colors). The bar weight (default 45 lbs) is shown in the center and is configurable.

3. **Warm-up ramp generation** — Before the first working set of a compound exercise, the app generates 3–4 warm-up sets that progressively ramp to the target weight:
   - Set 1: empty bar × 10 reps
   - Set 2: ~50% working weight × 5 reps
   - Set 3: ~75% working weight × 3 reps
   - Set 4: ~90% working weight × 1 rep
   - These appear as pre-populated "warm-up" sets in `SetInputView` (using the existing `isWarmup` flag on `SetRecord`). Each shows its plate breakdown inline.

4. **Weight rounding** — The ramp auto-rounds to the nearest loadable weight (e.g., 50% of 185 = 92.5, rounds to 95 because you can't load 92.5 with standard plates). The plate calculator handles this math.

5. **Unit support** — Settings toggle between lbs and kg, with plate inventories for each system (kg plates: 20, 15, 10, 5, 2.5, 1.25).

### Value Add

This is a gym-floor utility feature that users reach for every single session. The mental overhead of plate math is a real friction point, especially for newer lifters or anyone working with non-round numbers. The warm-up ramp solves a safety problem — it encourages proper warm-up sets that the app currently ignores entirely. Together, these features make the app feel like it was built by someone who actually lifts, not just someone who builds software. The warm-up ramp also generates more data points (warm-up sets are tracked), enriching the volume analytics.

### Implementation Notes

- **`PlateCalculator` utility** — pure function: takes target weight, bar weight, and available plate inventory → returns array of plate values per side. Greedy algorithm: largest plates first, with a fallback if exact match isn't possible (show nearest loadable weight).
- **`WarmUpRampGenerator`** — takes working weight, exercise type, and training mode → returns array of `(weight, reps)` tuples. Compound lifts get 4 warm-up sets; isolation exercises get 2 or none (configurable).
- **Barbell view** — custom SwiftUI view using `HStack` of colored `RoundedRectangle` elements proportional to plate weight. Lightweight, no external dependencies.
- **UI integration**: plate icon button in `SetInputView` → bottom sheet with barbell diagram. Warm-up sets injected as pre-filled rows above working sets, visually distinguished with a lighter background and "Warm-up" label. Existing `isWarmup` flag on `SetRecord` already supports this.
- **Settings additions**: bar weight, plate inventory (with presets for "Standard lbs" / "Standard kg" / "Custom"), unit toggle (lbs/kg), warm-up generation toggle.
- **Data model**: no schema changes needed. `SetRecord.isWarmup` already exists. Plate/bar settings go in `UserDefaults`.

---

## Improvement: 3D Progress Visualization with Chart3D

### Context

iOS 26 introduced `Chart3D` in Swift Charts — a new API for interactive 3D data visualization that shipped at WWDC 2025. The app's Progress tab already has excellent 2D charts (e1RM trends, volume per session, muscle group volume bars, mode split pie chart), but none of them answer a question that lifters constantly have: "How has my training volume been distributed across muscle groups **over time**?"

The existing `MuscleGroupVolumeChart` shows a snapshot for the selected time range but collapses the time dimension. The existing `TopSetTrendChart` shows time but only for one exercise. There's no single view that shows the full picture.

### What to Do

Add a **3D surface/bar chart** to the Progress Dashboard that visualizes volume across both muscle groups (x-axis) and time periods (z-axis), with volume as the y-axis.

**Specifically:**

1. **Chart3D bar chart** — Each bar represents one muscle group's volume for one week (or month, depending on time range). The x-axis is muscle groups, the z-axis is time periods, and the y-axis is total volume. Users can rotate and interact with the chart using standard gestures.

2. **Color coding** — Bars are colored by training mode (Strength vs Endurance) or by volume intensity (gradient from cool to warm based on relative volume), matching the app's existing color language.

3. **Interactive rotation** — Chart3D supports gesture-based rotation out of the box. Users can rotate to view muscle group comparison (side view) or time progression (front view), essentially getting three charts in one.

4. **Placement** — Add as a new card in `ProgressDashboardContent`, positioned after the existing `MuscleGroupVolumeChart`. Title: "Volume Over Time" with a "3D" badge to highlight the new capability.

5. **Fallback** — Since Chart3D requires iOS 26+, and the app already targets iOS 26.2, no backward compatibility is needed. However, wrap the view in an `if #available` check for future-proofing.

### Value Add

This is a "wow factor" feature that showcases the app's modernity. 3D charts are brand new in iOS 26 and very few apps have adopted them yet — this would make the Progress tab feel cutting-edge. More practically, the 3D view answers a real analytical question (volume distribution over time across all muscle groups) that currently requires mentally cross-referencing multiple 2D charts. It's also a natural conversation piece — users showing their training data to friends in a 3D interactive chart is organic word-of-mouth marketing.

### Implementation Notes

- **Import**: `Chart3D` is part of `Charts` framework, already used throughout the app. No new dependencies.
- **Data source**: reuse `ProgressDashboardViewModel`'s existing `muscleGroupVolumes` logic, but bucket by week/month instead of aggregating the full range. Add a `volumeOverTime()` method that returns `[(muscleGroup: String, period: Date, volume: Double)]`.
- **View**: new `VolumeOverTimeChart3D` view using `Chart3D { ForEach(data) { BarMark3D(x:, y:, z:) } }`. Apply `.chartXAxis`, `.chartZAxis` labels for muscle groups and dates.
- **Camera**: use `.chartCameraProjection(.perspective)` for depth perception. Set a reasonable default angle that shows all three dimensions clearly.
- **Performance**: Chart3D is GPU-accelerated. For the typical data volume (6–8 muscle groups × 4–52 weeks), performance will be excellent.
- **No schema changes** — all data already exists in the models.

---

*Generated 2026-03-06 by scheduled brainstorm task.*
