---
title: Feature Ideas — Apr 9, 2026
date: 2026-04-09
tags:
  - feature-ideas
  - brainstorm
  - strength-training
status: draft
---

# Feature Ideas — Apr 9, 2026

Two new feature concepts and one UI improvement. These are fully distinct from all prior batches (Recovery Tracker, RPE Suggestions, Liquid Glass, Rest Timer ×3, Plate Calculator, 3D Charts, Templates, SF Symbols Draw Animations, Superset Grouping, WidgetKit, Shareable Summary Card, Exercise Notes Tooltip/Rich Text, Muscle Balance Radar, Session Intensity Micro-Journal).

---

## Feature 1: Exercise Goal Setting & Milestone Tracker

### Problem

The smart progression system is excellent at suggesting the *next realistic increment* — but there's no way to set an explicit *aspirational target*. A user who wants to bench 225 lbs by summer has no place to record that goal in the app, no progress indicator showing how close they are, and no moment of recognition when they finally hit it. Without goals, the app only reflects where you are, not where you're trying to go. Users who do have goals track them externally in Notes or a whiteboard, which disconnects their motivation from their training data.

### Idea

A lightweight goal system attached per-exercise. On `ExerciseDrillDownView`, a **"Set Goal"** button (toolbar item or section footer) lets the user enter a target weight, optional reps, and an optional target date. One goal per exercise at a time (v1 is simple; goal history is not needed initially).

Once a goal is set:

1. **Goal Progress Arc** — a compact circular progress indicator appears at the top of `ExerciseDrillDownView`, showing current best weight vs. goal weight as a percentage. Tapping it reveals: target weight, target date (if set), days remaining, and a "Clear Goal" option.

2. **Progress Dashboard Badge** — exercises with active goals appear with a small target icon in `ExerciseListSection`. Exercises within 10% of their goal get an amber highlight; achieved goals get a green fill.

3. **Goal Achieved Celebration** — when `WorkoutViewModel.finishSet()` detects that a new best `weightLbs` meets or exceeds `exercise.goalWeight` for the first time, it triggers:
   - A `HapticService` burst (the heaviest notification pattern — distinct from the existing progression haptics)
   - A full-screen overlay "Goal Achieved" card with the `checkmark.seal.fill` SF Symbol using `.drawOn` effect, the goal name, and the date achieved
   - The goal is automatically marked `isAchieved = true` and a new `achievedAt: Date` timestamp is stored

4. **Achieved Goals Archive** — a separate section in `ExerciseDrillDownView` (collapsed by default) showing past achieved goals for that exercise as a timeline — a simple but meaningful personal record of what you've accomplished.

### Value Add

Goal setting is the single strongest predictor of training adherence in the behavioral science literature. The smart progression system tells you what to do next; goals tell you *why*. No simple no-subscription workout tracker surfaces this in a clean per-exercise way. The feature also creates a natural "second use" for the Progress tab — not just reviewing what happened, but checking where you're headed.

### Implementation Notes

- **Model change:** Store goals directly on `Exercise` for v1: `goalWeight: Double?`, `goalReps: Int?`, `goalTargetDate: Date?`, `goalAchievedAt: Date?`. Four optional fields — no migration risk, no new model entity required.
- **Goal completion check:** In `WorkoutViewModel`, after saving a `SetRecord`, check `if let goal = exercise.goalWeight, set.weightLbs >= goal, exercise.goalAchievedAt == nil`. If true, set `exercise.goalAchievedAt = .now` and post a notification to trigger the celebration overlay. The notification can use `NotificationCenter` — no new SwiftData queries needed.
- **Progress arc:** A custom `ArcProgressView` using `SwiftUI.Canvas` — a simple filled arc from 0% to `min(currentBest / goalWeight, 1.0)`. Approximately 40 lines; no external dependency.
- **Goal UI in `ExerciseDrillDownView`:** A single new `GoalSectionView` composable — an `if exercise.goalWeight != nil` branch with the arc, details, and clear button. Falls back to a "Set Goal" `Button` if no goal is set.
- **No networking, no new SwiftData entities, no migration headaches.** Purely additive.

---

## Feature 2: Retroactive Rest Time Analysis

### Problem

Every `SetRecord` already stores `completedAt: Date`, but this timestamp data is completely unused in the UI. Between any two consecutive sets within an `ExerciseRecord`, the difference in `completedAt` is the actual rest interval the user took. Over hundreds of sessions, this data answers questions that weight/rep tracking alone cannot: *How long do I actually rest between sets? Do I rest shorter in endurance mode vs. strength mode? Am I chronically under-resting on heavy compound movements, which could explain why my progress on those lifts has stalled?*

This feature has nothing to do with a prospective rest timer (proposed three times previously). It is purely retroactive analysis of rest behavior that is already recorded.

### Idea

Surface the latent timestamp data in two places:

**1. Session Detail — Rest Times Inline**

In `SessionDetailView`, each set row currently shows "Set 2: 175 lbs × 8". Add a small secondary label showing the computed rest before that set: "Set 2 · rested 2:15". The first set of each exercise shows no rest label (there's no prior set to diff against). Rest is computed from `sets[n].completedAt - sets[n-1].completedAt`, capped at 15 minutes to exclude cases where the user paused the app mid-session.

This is a zero-schema change, display-only enhancement to an existing view.

**2. Progress Dashboard — "Rest Habits" Card**

A new compact card on `ProgressDashboardView` (below the Mode Split chart) titled "Rest Habits":

- Two `BarMark` columns (Swift Charts): average rest per set in **Strength mode** vs. **Endurance mode**, computed over the selected time range
- A subtle annotation line at 90s and 3:00 as reference ranges (science-backed minimums for endurance vs. strength)
- If the user's Strength mode average is below 90s: a gentle callout — *"Your average strength rest is 1:04. Consider longer rests for heavier sets."*
- If averages are within healthy ranges: a neutral display with no callout (don't nag users who don't need it)

Tapping the card opens a full `RestAnalysisView` with a per-exercise breakdown: which exercises have the longest/shortest average rests, and a trend showing whether rests are getting longer (potential fatigue) or shorter (potential fitness improvement) over time.

### Value Add

The app is already collecting this data — it just throws it away visually. This feature turns `completedAt` into a meaningful behavioral metric at no new cost to the user (no new inputs, no new schema). Rest time intelligence is typically only found in high-end coaching apps (TrainHeroic, Eleiko Coach). The dual-mode comparison is particularly novel: users often have no intuition about whether they actually rest differently between their strength and endurance sessions.

### Implementation Notes

- **Data access:** `ExerciseRecord.sets` sorted by `setNumber` → `zip(sets, sets.dropFirst())` → `($1.completedAt.timeIntervalSince($0.completedAt))`. Cap at `15 * 60` seconds. Skip warmup sets (`SetRecord.isWarmup == true`) to avoid polluting average with warm-up → work set gaps.
- **`SessionDetailView` change:** The set list rows (likely a `ForEach` over `exerciseRecord.sets`) get a secondary label computed inline — no ViewModel changes needed. The rest delta is cheap to compute.
- **`ProgressDashboardViewModel` addition:** `averageRestByMode: [TrainingMode: TimeInterval]` — a single pass over all `ExerciseRecord`s in the selected time range, grouping by `trainingMode` and averaging inter-set deltas. O(n) over `SetRecord` count; negligible for any realistic dataset.
- **`RestHabitsCard.swift`:** New card view with a `Chart { BarMark(...) }` showing the two averages. Optional `RuleMark` annotations at 90s and 180s. Approx. 80 lines including the callout logic.
- **`RestAnalysisView.swift`:** Full detail view accessible by tapping the card. Per-exercise table (exercise name, avg rest, trend arrow). Uses existing `ExerciseListSection` patterns.
- **Zero schema migration.** Zero new user input. Purely analytical.

---

## UI Improvement: Training Consistency Heatmap in History Tab

### Problem

The History tab is a reverse-chronological session list — excellent for looking up a specific workout, but completely blind to *patterns*. A user who trained consistently for six weeks then had a two-week gap has no way to see that at a glance. Counting sessions in a list to assess frequency is mentally taxing. Users who care about consistency — which is everyone trying to build a habit — have to go to a separate app (Apple Fitness, Streaks, etc.) for the visual feedback this app's own data could provide.

### What It Would Change

Add a **compact consistency heatmap** as a collapsible section at the top of `HistoryListView`, showing the last 16 weeks (≈ 4 months) in a GitHub-style grid:

- **Grid layout:** `LazyHGrid` with 7 rows (Monday → Sunday), scrollable horizontally. Each column = one week, newest on the right. Each cell ≈ 26pt square, 3pt gap.
- **Cell color:** Empty day = `.systemFill` (grey). Trained day = tinted with `DayType.color` (pink for Arms, blue for Legs, purple for Full Body). For sessions where multiple day types occurred on the same day (rare), use the highest-volume session's day type.
- **Color intensity:** Modulated by relative volume — lighter tint for low-volume sessions, full saturation for high-volume sessions. Uses `opacity` scaled from 0.35 to 1.0 against the base `DayType.color`.
- **Tap interaction:** Tapping a colored cell jumps the session list (via `ScrollViewReader`) to that session. A brief highlight ring pulses on the cell when tapped.
- **Collapse toggle:** A `disclosure` chevron in the section header lets users who prefer the plain list collapse the heatmap persistently (stored in `@AppStorage`).
- **Month labels:** Subtle month abbreviations (Jan, Feb…) float above the grid at each month boundary, computed from the cell dates.

### Value Add

The heatmap makes training consistency *viscerally visible*. A grey gap of 10 days is emotionally legible in a way that scrolling through a list of dates is not. The visual density of a full training block — a wall of colored squares — is genuinely motivating and reinforces the habit loop the app is trying to support. This pattern (used by GitHub, Duolingo, Apple Fitness) is immediately understood by users without any explanation.

The feature is also fully additive: the session list is unchanged below the heatmap. Users who don't want the heatmap can collapse it. Existing behavior is fully preserved.

### Implementation Notes

- **`ConsistencyHeatmapView`**: A standalone `View` that takes `[(date: Date, dayType: DayType, volumeScore: Double)]` — computed from the existing `@Query` sessions already loaded by `HistoryListView`. No separate fetch required.
- **Cell computation:** Generate an array of `Date` objects for the last 16 weeks × 7 days = 112 cells. Map each to a session (if any) using a `Dictionary<DateComponents, WorkoutSession>` keyed on year/month/day for O(1) lookup.
- **`LazyHGrid` layout:**
  ```swift
  LazyHGrid(rows: Array(repeating: GridItem(.fixed(26), spacing: 3), count: 7), spacing: 3) {
      ForEach(cells) { cell in
          HeatmapCellView(cell: cell)
              .onTapGesture { selectedDate = cell.date }
      }
  }
  .scrollIndicators(.hidden)
  ```
- **`ScrollViewReader` integration:** Wrap the session `List` in `ScrollViewReader`. When `selectedDate` changes, call `proxy.scrollTo(session.id, anchor: .top)`.
- **Volume normalization:** Scale `volumeScore` to 0–1 relative to the max session volume in the displayed 16-week window. This prevents a single outlier session from washing out all other cells.
- **Accessibility:** Each cell gets `.accessibilityLabel` formatted as "Trained Arms on March 15" or "Rest day, March 16". The entire heatmap section has `.accessibilityElement(children: .contain)`.
- **No schema changes. No ViewModel changes.** The heatmap is a self-contained display component.

---

*Generated by the weekly scheduled brainstorm task. Ideas are grounded in the existing SwiftData schema (Exercise, WorkoutSession, ExerciseRecord, SetRecord), MVVM architecture with `@Observable`, no-networking constraint, and iOS 26.2+ deployment target.*
