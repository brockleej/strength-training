# Feature Ideas — April 2, 2026 (Batch 2)

## Feature 1: Muscle Balance Radar & Imbalance Alerts

### The Problem

The app tracks volume per muscle group as a simple bar chart, but it doesn't help the user understand whether their training is *balanced*. Over weeks, it's easy to unconsciously over-train push muscles (chest, shoulders, triceps) while neglecting pull muscles (back, biceps) or lower-body stabilizers (glutes, calves). Imbalances like these are a leading cause of injury in recreational lifters and a common plateau trigger — but they develop slowly enough that you don't notice until something hurts.

### What It Does

A **Muscle Balance Radar Chart** on the Progress tab that plots relative volume across all trained muscle groups on a polar/radar axis, with an ideal-balance reference ring for comparison. When any muscle group's volume drops below a configurable threshold relative to its antagonist pair (e.g., chest vs. back, quads vs. hamstrings), the app surfaces an **Imbalance Alert** — a gentle, non-blocking banner that appears at the top of the Workout tab before starting a new session.

### Key Components

1. **Radar Chart View** (`MuscleBalanceRadarChart.swift`)
   - Swift Charts doesn't natively support radar/polar charts, so this would be a custom `Canvas` or `Shape`-based view.
   - Each axis represents a muscle group. The filled polygon shows actual relative volume over the selected time range; a dashed circle shows the "balanced" reference.
   - Tap any axis spoke to drill down into that muscle group's exercise list and volume trend.

2. **Antagonist Pair Mapping** (extend `Exercise` model or a new static config)
   - Define muscle group pairs: Chest↔Back, Quads↔Hamstrings, Biceps↔Triceps, Shoulders↔Core.
   - Compute a balance ratio per pair (e.g., 1.0 = perfectly balanced, >1.4 = notable imbalance).

3. **Imbalance Alert Banner** (`ImbalanceAlertView.swift`)
   - Shown on the Workout tab when an imbalance ratio exceeds threshold (configurable in Settings, default 1.4×).
   - Example: *"Your chest volume is 1.6× your back volume over the last 4 weeks. Consider adding a back exercise today."*
   - Dismissable per session; recalculated weekly.

4. **Settings Integration**
   - Toggle imbalance alerts on/off.
   - Sensitivity slider: Relaxed (1.6×) / Moderate (1.4×) / Strict (1.2×).

### Value Add

This transforms the app from a passive log into an **active training advisor**. No competing simple workout logger does muscle balance analysis — it's typically locked behind paid coaching apps like RP Hypertrophy or Juggernaut AI. Implementing it locally with the data already being collected (muscle group + volume per session) requires no new data entry from the user.

### Implementation Complexity

**Medium.** The hardest part is the custom radar chart (Canvas drawing, ~150 lines). The balance computation is straightforward math over existing `@Query` data. The alert banner is a simple conditional view. Estimated 4–6 files, no model migration needed.

---

## Feature 2: Session Intensity Scoring with Post-Workout Micro-Journal

### The Problem

Two workouts can look identical on paper (same exercises, same sets, same weight) but feel completely different. One session you're energized and hitting every rep cleanly; the next you're grinding through fatigue. The current app captures the *objective* data (weight × reps) but none of the *subjective* context — how hard the session felt, energy level, sleep quality, or mood. Over time, this missing context makes it difficult to understand *why* progress stalls or surges, and the user has no way to correlate life factors with gym performance.

### What It Does

After tapping "Finish Workout," instead of immediately returning to the day picker, the app presents a **quick micro-journal** — a single, fast-to-complete screen that captures:

1. **Session Intensity Score (SIS)**: A 1–10 rating using a custom slider styled as a gradient bar (green → yellow → red). This is essentially a session-level RPE (Rate of Perceived Exertion) — how hard the *overall session* felt, not per-set.
2. **Energy Tag** (optional): One-tap selection from a row of pills — "Well Rested," "Normal," "Tired," "Sore," "Stressed." Multiple selections allowed.
3. **Quick Note** (optional): A single-line text field for freeform context ("bad sleep," "new PR attempt," "tweaked shoulder").

This data is stored on the `WorkoutSession` model and surfaced in two places:

- **History tab**: Each session row shows a small colored intensity dot (green/yellow/red) next to the date, and the detail view shows the full journal entry.
- **Progress tab**: A new **Intensity Trend** mini-chart in the dashboard shows SIS over time as a line chart, overlaid with the Strength Score trend. This lets the user visually spot patterns like "my strength score rises when my intensity stays in the 7–8 range but plateaus when I consistently rate 9–10" (a classic overtraining signal).

### Key Components

1. **Model changes** (extend `WorkoutSession`):
   - `intensityScore: Int?` (1–10, nil for legacy sessions)
   - `energyTags: [String]` (stored as comma-separated or as a lightweight SwiftData transformable)
   - `quickNote: String` (reuse existing `notes` field or add a dedicated one)
   - Lightweight migration: all new fields are optional, so existing data is unaffected.

2. **Post-Workout Journal View** (`PostWorkoutJournalView.swift`):
   - Presented as a `.sheet` after `finishSession()`.
   - Gradient intensity slider, energy tag pills, single-line text input.
   - "Skip" button to dismiss without logging (respects user agency).
   - "Save" stores values on the session and dismisses.

3. **Intensity Trend Chart** (`IntensityTrendChart.swift`):
   - Small line chart on the Progress dashboard using Swift Charts.
   - Dual-axis or overlaid with Strength Score for correlation viewing.

4. **History Integration**:
   - Color-coded dot on `HistoryListView` rows.
   - Expanded section in `SessionDetailView` showing tags and note.

### Value Add

This is one of the most requested features in fitness app communities — the ability to track *how you felt*, not just what you lifted. Apps like Strong and Hevy have added RPE per set, but a per-session micro-journal is faster (one screen vs. rating every set) and captures broader context (sleep, stress) that per-set RPE misses. It also creates a data loop: the Intensity Trend chart gives users actionable insight into their recovery and programming without requiring them to use a separate journaling app.

### Implementation Complexity

**Medium-low.** The model changes are additive (optional fields, no migration headaches). The journal view is a single screen with standard SwiftUI controls. The trend chart reuses the existing Swift Charts patterns from the dashboard. Estimated 3–4 new files, 2–3 modified files.

---

## Optimization: Rich Text Editing for Exercise Notes with Inline Display

### The Problem

The app already has an `exercise.notes` field for form cues and technique reminders (e.g., "keep elbows tucked," "pause at bottom"), but it's underutilized for two reasons:

1. **Notes are invisible during workouts.** The Apr 2 feature ideas document proposed an info-icon tooltip to surface notes, but the notes themselves are still plain text entered via a basic `TextField` in `AddExerciseView`. There's no formatting, no structure, and no way to visually distinguish a safety warning ("don't lock knees") from a technique tip ("squeeze at the top").

2. **The exercise row feels information-sparse.** `ExerciseRowView` currently shows the exercise name, muscle group, and progression banner. When collapsed, there's no hint that notes exist at all — users forget they wrote them.

### What It Does

Leverage iOS 26's new **Rich Text Editing** SwiftUI APIs (introduced at WWDC 2025) to upgrade exercise notes from plain `String` to styled `AttributedString`. This is a small but high-polish improvement that takes advantage of a brand-new platform capability.

**Concrete changes:**

1. **`AddExerciseView` / `EditExerciseView`**: Replace the plain `TextField` for notes with SwiftUI's new rich text editor. Users can bold key cues, use bullet lists for multi-step form instructions, and highlight safety warnings. The rich text editor comes essentially free from the system — minimal custom code.

2. **`ExerciseRowView` inline note hint**: When an exercise has notes, show a small `info.circle` icon next to the muscle group label. This is the icon proposed in the Apr 2 ideas, but now tapping it presents the note as **formatted** `AttributedString` text in a compact popover — not a flat string dump.

3. **`SetInputView` persistent note strip**: When expanded, if the exercise has notes, render a compact, scrollable strip at the top of the input area showing the first line of the note (truncated, tappable to expand). This keeps the form cue visible *while the user is actually logging sets* — the moment it matters most.

### Why This Over Other Optimizations

- **Leverages a brand-new iOS 26 API** that the app's deployment target (iOS 26.2+) already supports. Rich text editing in SwiftUI was one of the headline announcements at WWDC 2025 and signals that the app is current with the platform.
- **Zero model migration risk**: `AttributedString` is `Codable` and can be stored as a SwiftData transformable. Existing plain-text notes can be auto-wrapped into an `AttributedString` on first read.
- **Solves a real usability gap**: Exercise notes are already in the data model but effectively invisible during the workout — the one time they're needed. This makes them visible and useful without adding a whole new feature.
- **Small surface area**: 2–3 files changed, no new screens, no new model entities. A clean afternoon PR.

### Implementation Notes

- Check `RichTextEditor` or the new `TextEditor` modifiers in iOS 26 SwiftUI — the exact API name may need verification against the latest beta docs.
- For backward compatibility of stored notes: store as `AttributedString` in SwiftData, with a computed property that falls back to plain `String` for any legacy data.
- The inline note strip in `SetInputView` should respect the expansion animation pattern documented in CLAUDE.md (frame clipping, not conditional insertion).
