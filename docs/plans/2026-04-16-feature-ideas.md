---
title: Feature Ideas — Apr 16, 2026
date: 2026-04-16
tags:
  - feature-ideas
  - brainstorm
  - strength-training
status: draft
---

# Feature Ideas — Apr 16, 2026

Two new feature concepts and one UI improvement. These are fully distinct from all prior batches (Recovery Tracker, RPE Suggestions, Liquid Glass, Rest Timer ×3, Plate Calculator, 3D Charts, Templates, SF Symbols Draw Animations, Superset Grouping, WidgetKit, Shareable Summary Card, Exercise Notes Tooltip/Rich Text, Muscle Balance Radar, Session Intensity Micro-Journal, Progressive Overload Suggestions, WidgetKit Widgets, Goal Setting & Milestone Tracker, Retroactive Rest Time Analysis, Training Consistency Heatmap).

---

## Feature 1: Body Weight Log & Strength-to-Weight Ratios

### Problem

Every metric in the app is absolute: 185 lbs × 5 on bench press, 2,450 lbs total session volume. None of it is normalized to the user's body weight, which means the app can't tell you whether you're getting *stronger* or just *heavier*. A 10 lb increase on your squat means something very different if you gained 15 lbs of body mass vs. maintained the same weight. Strength-to-weight ratio is the single most universally understood relative strength metric in both recreational lifting and competitive powerlifting (e.g., "bodyweight bench," "2× squat"), yet no data is available in the app to compute it. Users who want this context currently maintain a separate Notes entry or health app — their core training log and their body composition data never talk to each other.

### Idea

Add a lightweight body weight tracking system, tightly integrated into the existing Progress tab rather than a separate tab or view.

**1. Log Weight Entry**

A new **"Log Weight"** button appears in the Progress tab toolbar (or as a persistent card at the top of `ProgressDashboardView` when no recent weight entry exists). Tapping presents a minimal sheet: a `Stepper`-based weight input pre-populated with the last logged value, and a "Save" button. The entry is stored as a new `WeightEntry` SwiftData model: `id: UUID`, `date: Date`, `weightLbs: Double`. No cascade rules needed — `WeightEntry` is standalone.

**2. Body Weight Trend Card**

A new `BodyWeightTrendCard` appears on `ProgressDashboardView` (after the Mode Split chart) when at least two weight entries exist. It renders a Swift Charts `LineMark` over the selected time range, with a subtle area fill beneath. If weight is trending upward: no annotation. If trending downward: a quiet callout ("−3.2 lbs over this period"). No judgment — purely informational.

**3. Strength-to-Weight Ratios in ExerciseDrillDownView**

When `WeightEntry` data exists and the current exercise is a primary compound movement (determined by a configurable `isCompound: Bool` flag on `Exercise`, defaulting to `false`), a new row appears in `ExerciseDrillDownView` below the e1RM trend chart:

```
Strength-to-Weight
Best e1RM 215 lbs · Your weight 178 lbs → 1.21× bodyweight
```

The ratio uses the most recent `WeightEntry` before the session date for historical accuracy. Tapping the row opens a small overlay explaining what the ratio means and common benchmarks (e.g., 1.5× is a commonly cited "intermediate" bench milestone).

**4. Strength Score Normalization Toggle**

In `StrengthScoreCard` and `VolumeScoreCard`, a small "÷ BW" toggle appears in the card header if body weight data exists. When enabled, scores are divided by body weight and displayed as relative metrics. This lets users whose absolute numbers fluctuate due to body composition changes see their progress more accurately. The toggle is ephemeral (`@AppStorage` for persistence).

### Value Add

Body weight tracking is one of the top-three most-requested features in strength app communities (consistently cited alongside rest timers and templates). The implementation is simple, but the analytical value — being able to see that your squat is improving *relative to your body weight* over a 6-month cut — is significant and something no purely log-based app can offer without this data. The strength-to-weight ratio display in `ExerciseDrillDownView` transforms absolute numbers into meaningful personal metrics without requiring the user to do any math.

### Implementation Notes

- **New model:** `WeightEntry` — three fields, no relationships, no cascade rules. A standard `@Model` class. `@Query(sort: \WeightEntry.date, order: .reverse)` in `ProgressDashboardViewModel` retrieves entries.
- **Log entry sheet:** A `@State var showingWeightEntry: Bool` on `ProgressDashboardView` and a simple `WeightEntrySheet` view with a `Stepper` (range 50–500 lbs, step 0.5). Approximately 30 lines.
- **`BodyWeightTrendCard`:** Swift Charts `LineMark` + `AreaMark` combo, identical pattern to existing `E1RMTrendChart`. ~60 lines.
- **Strength-to-weight computation:** `exercise.recordsArray.compactMap { rec in rec.session?.isCompleted == true ? rec : nil }.map { bestE1RM }` — same query the drilldown already performs. Weight lookup: `WeightEntry` nearest in time to session date. Pass `weightEntry: WeightEntry?` into `ExerciseDrillDownView` via its initializer.
- **`isCompound` flag on `Exercise`:** Seed data marks squats, bench, deadlift, overhead press, row as compound. Custom exercises default `false`. Optional `Bool` — zero migration risk, nil = `false` at display.
- **CloudKit compatible:** `WeightEntry` requires no special CloudKit handling beyond what the existing container already provides.

---

## Feature 2: All-Time Personal Records Hall of Fame

### Problem

The app shows personal records in two narrow windows: a pink "PR" badge on `SessionDetailView` (when a set beats all prior e1RMs) and a `PRsThisMonthCard` on the Progress tab (recent PRs only). Neither answers the fundamental question a dedicated lifter returns to most often: *"What are my actual all-time bests?"* A user who achieved a lifetime bench press PR eight months ago has no way to see it without scrolling back through History to find that specific session. There is no single place to review the full archive of peak performances across all exercises — a Hall of Fame. This gap means the app doesn't function as a *record* of athletic achievement; it's a log of recent activity with historical data that quietly accumulates and becomes invisible.

### Idea

A dedicated **Personal Records** view, accessible from the Progress tab, that presents every exercise's lifetime best performance in a scannable, celebratory format.

**1. Entry Point**

A new `PersonalRecordsCard` replaces (or augments) the existing `PRsThisMonthCard` on `ProgressDashboardView`. The card shows a summary: "14 lifetime PRs across 8 exercises" with a "View All" navigation link that pushes `PersonalRecordsView`.

**2. PersonalRecordsView Layout**

A `List` with sections grouped by `DayType` (Arms / Legs / Full Body), matching the visual language of `ExerciseListSection`. Each row shows:

- Exercise name (headline)
- Best performance (e.g., "225 lbs × 5, est. 1RM 242 lbs")
- Date achieved (caption, e.g., "Set Feb 14, 2026")
- A gold `trophy.fill` SF Symbol if this was set in the last 30 days (emphasizing recent PRs as "fresh gold")

Tapping any row navigates to `ExerciseDrillDownView` for that exercise — same destination as the existing `ExerciseListSection`.

**3. Sort & Filter**

A `Menu` toolbar button offers three sort orders:
- **By exercise** (alphabetical, default)
- **Most recently set** (PRs achieved in the last 30 days at top — useful to track "am I still making progress?")
- **Largest margin** (sorted by how much the current PR exceeds the previous PR — highlights exercises where the user made their biggest leap)

**4. PR Computation**

For each exercise: compute the all-time maximum `weightLbs * (1.0 + Double(reps) / 30.0)` across all completed, non-warmup `SetRecord`s. The `SetRecord` that produced this maximum determines the "achieved on" date via its `completedAt` timestamp. This is the same e1RM formula already used in `SessionDetailView`'s `ExerciseHeaderRow` — no new calculation logic.

**5. Empty State**

For exercises with no completed working sets, the row is omitted entirely. If the user has no completed sessions at all, the `ContentUnavailableView` pattern (already used in `HistoryListView`) shows "No Records Yet" with a trophy SF Symbol.

### Value Add

The Hall of Fame closes the most significant gap in the app's motivational loop: there is no "trophy shelf." Every other part of the app is ephemeral — today's workout, this month's PRs, the last 12 weeks of volume. The Hall of Fame is permanent. It answers "how far have I come?" not "what have I done recently?" This is the kind of view a user references when showing the app to a friend ("look what I hit last month") or when returning after a break ("what are my baselines?"). It requires no schema changes, no new queries, and no new computation beyond what's already scattered across `ExerciseHeaderRow` and `PRsThisMonthCard` — it simply aggregates it into one dedicated destination for the first time.

### Implementation Notes

- **`PersonalRecordsViewModel`:** A new `@Observable` class. Takes `ModelContext`, fetches all `Exercise` records with at least one completed `SetRecord`. For each exercise, computes `allTimePRSet: SetRecord?` (the set with the highest e1RM) and `previousBestSet: SetRecord?` (the second-highest, for "margin" sort). O(n) over total set count — negligible for any realistic dataset.
- **`PersonalRecordsView`:** ~100 lines. Uses the existing `ExerciseListSection` visual patterns. `List` with `ForEach` over `grouped: [(DayType, [PREntry])]`. `NavigationLink` per row to `ExerciseDrillDownView`.
- **`PREntry` type:** A local struct — `exercise: Exercise`, `bestSet: SetRecord`, `estimatedOneRM: Double`, `achievedOn: Date`, `prMargin: Double?`. Computed in `PersonalRecordsViewModel`, not stored in SwiftData.
- **`PersonalRecordsCard`:** A small card with a headline count and a horizontal preview of the 3 most recently set PRs (exercise name + weight). "View All" push navigation. ~50 lines.
- **Sort implementation:** Three `enum SortOrder` cases + a `computed var sortedEntries` in `PersonalRecordsViewModel` that re-sorts based on the selection. The `menu` toolbar button binds to `@State var sortOrder`.
- **No schema changes.** All data already exists — this feature is purely an aggregation and presentation layer over existing `SetRecord` data.

---

## UI Improvement: Visual Stats Summary Header in SessionDetailView

### Problem

The `SessionDetailView` opens with a plain `Section` of five `LabeledContent` rows: Date, Day Type, Exercises Completed, Total Sets, Total Volume. This is correct and complete, but it's visually indistinguishable from a form — small text, no hierarchy, no at-a-glance scan path. In practice, users open a session detail most often to answer one of two questions: "what was my total volume?" or "which exercises did I PR on?" Both are buried in a vertical text list that requires reading, not scanning. Every modern fitness app (Strava, Apple Fitness, Garmin Connect) presents session summary stats as visual metric chips with large numbers and small labels — a layout specifically designed to communicate at a glance. The current flat list was appropriate for v1; with the app now tracking rich session data (including effort rating and volume), the summary header deserves a visual upgrade.

### What It Would Change

Replace the current top `Section` in `SessionDetailView` with a **`SessionSummaryHeaderView`**: a non-scrollable header block rendered above the `List` (or as the first list section with a custom style) showing five stats in a 2+3 or 3+2 compact grid:

```
┌──────────────────────────────────────────────────────────┐
│  📅  Apr 5, 2026 · Arms Day                              │
├────────────────┬─────────────────┬───────────────────────┤
│  💪 4           │  🏋️ 16           │  📦 9,240 lbs         │
│  Exercises     │  Total Sets     │  Volume               │
├────────────────┴─────────────────┴───────────────────────┤
│  ⭐ 2 PRs                         🔥 Effort: 7/10         │
└──────────────────────────────────────────────────────────┘
```

Each stat chip shows:
- A large, bold number (using `.title2.bold()` or `.title3.bold()`)
- A small `.caption` label below
- A relevant SF Symbol inline (a subtle secondary-style icon, not colored)

The "2 PRs" chip only appears when `prCount > 0`. The "Effort" chip only appears when `session.effortRating != nil` — both conditions already computed by the view's existing properties. The date + day type header doubles as the view's `navigationTitle` context.

**Color usage:** The entire header uses the session's `dayType.color` as a tint source — a subtle `background(dayType.color.opacity(0.08))` on the header block ties it to the session's identity without being garish. This matches the `SessionRow` pattern already used in `HistoryListView`.

### Value Add

The change requires zero schema modifications and moves no data — it only reorganizes how the same data is presented. The impact is immediate and high: the first thing a user sees when reviewing a session goes from five rows of small form text to a compact, scannable summary that communicates the session's size and significance in under two seconds. The PR count chip in particular surfaces information that is currently invisible at the top of a session — you have to scroll through every exercise section to discover PRs. Seeing "2 PRs" at the top changes how you read the rest of the detail.

### Implementation Notes

- **`SessionSummaryHeaderView`:** A new `View` that takes `session: WorkoutSession`. Computes `prCount`, `totalSets`, `totalVolume`, and `exerciseCount` using the same logic already in `SessionDetailView`'s private computed properties. Extract these into a small helper or pass the computed values directly.
- **PR count computation:** `session.exerciseRecordsArray.filter { record in computeIsPR(for: record) }.count`. The `computeIsPR` logic is already implemented in `ExerciseHeaderRow` (private to that struct). Extract it into a standalone function or replicate it in `SessionSummaryHeaderView` — it's ~8 lines.
- **Layout:** A `VStack(spacing: 0)` with a date/dayType headline, then a `HStack(spacing: 0)` of three equal-width `StatChip` views, then a conditional `HStack` for the PR + effort chips. `StatChip` is a private struct (~15 lines) that takes `icon: String, value: String, label: String`.
- **Integration:** In `SessionDetailView`, prepend `SessionSummaryHeaderView(session: session)` as the `listSectionHeader` of the first `Section`, or place it outside the `List` in a `VStack` wrapper with `.listRowInsets(EdgeInsets())` to flush it to the full width.
- **Curtain-reveal / animation:** This view is static — no expansion animations, no state. Just a simple display header.
- **Accessibility:** Each `StatChip` gets an `.accessibilityLabel` combining value and label (e.g., `"4 exercises"`, `"9240 lbs total volume"`). The PR chip: `"2 personal records this session"`. The effort chip: `"Effort rating 7 out of 10"`.
- **Backward compatible:** The effort and PR chips are conditionally shown — sessions logged before `effortRating` was added display a clean 3-chip row without them. No empty state edge cases.

---

*Generated by the weekly scheduled brainstorm task. Ideas are grounded in the existing SwiftData schema (Exercise, WorkoutSession, ExerciseRecord, SetRecord), MVVM architecture with `@Observable`, no-networking constraint, and iOS 26.2+ deployment target.*
