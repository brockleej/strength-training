---
title: Feature Ideas — Apr 2, 2026
date: 2026-04-02
tags:
  - feature-ideas
  - brainstorm
  - strength-training
status: draft
---

# Feature Ideas — Apr 2, 2026

Two new feature concepts and one UI improvement, based on a review of the current codebase and gap analysis against what has already been proposed. These are fully distinct from prior batches (Recovery Tracker, RPE Suggestions, Liquid Glass, Rest Timer, Plate Calculator, 3D Charts, Templates, SF Symbols Draw Animations, Superset Grouping).

---

## Feature 1: WidgetKit Home Screen & Lock Screen Widgets

### Problem

The app is a completely passive experience — it only exists when the user actively opens it. There is no ambient presence on the home screen or lock screen to prompt users to train, acknowledge a streak, or show recent progress. A user who hasn't logged a workout in three days gets zero signal from the app. Competing apps like Hevy and Strong retain users partly because the icon on the home screen reminds them; this app currently has no equivalent touchpoint.

### Idea

Add a **WidgetKit target** with three widget sizes tuned to the most useful information:

1. **Small widget — Training Streak**: A large number showing consecutive days with at least one completed session, plus the day-type icon (SF Symbol from `DayType.systemImage`) of the last session. Tapping deep-links into the Workout tab.
2. **Medium widget — Last Session Recap**: Date of last workout, day type, up to three exercises with their top set (weight × reps), and a "New PR" badge if any PRs were set. Tapping opens `HistoryListView` to that session.
3. **Lock Screen accessory widget — Days Since Last Workout**: A compact circular gauge showing days elapsed since the last completed session — zero-friction motivation to stay consistent. Green if ≤ 2 days, yellow if 3 days, red if 4+.

All three are read-only and update at system-scheduled intervals. No user interaction inside the widget beyond tapping to deep-link.

### Value Add

Widgets are the highest-ROI engagement surface on iOS: they're visible without an app launch, they reinforce habit formation, and they cost users nothing to set up. The streak widget in particular taps directly into loss-aversion psychology — a user who sees "6-day streak" will resist breaking it. This feature requires no new data — all three widgets read directly from completed `WorkoutSession` records.

### Implementation Notes

- **New Xcode target**: `StrengthTrainingWidget` (WidgetKit extension). Shares the SwiftData store via an **App Group** container identifier (e.g., `group.com.danielkuhlwein.strength-training`). Both the main app target and the widget target must set this App Group, and `ModelContainer` is initialized with `applicationGroupContainerIdentifier` in both.
- **Data reads**: the widget's `TimelineProvider` fetches the most recent completed `WorkoutSession` and its `exerciseRecords` for the recap widget; counts consecutive sessions ending on today for the streak widget. These are lightweight fetches on a small dataset — no performance concern.
- **Timeline refresh policy**: `.atEnd` for the lock screen widget (refresh every few hours) and `.after(Date(...))` for the streak widget at midnight to update the day count.
- **Deep linking**: use `.widgetURL()` modifier on each widget with a custom `URL` scheme (`strengthtraining://history`, `strengthtraining://workout`). Handle in `ContentView` via `.onOpenURL`.
- **No new SwiftData schema changes** — all data already exists.
- **App Group requirement**: this is the one non-trivial setup step. The `strength_trainingApp.swift` `ModelContainer` initializer must be updated to use the shared group container. This is a one-line change but requires an App Group entitlement in Xcode.

---

## Feature 2: Shareable Workout Summary Card

### Problem

Completing a workout is a meaningful accomplishment, but the app provides no way to mark or share it beyond the internal history log. Users who want to post about a workout on social media or send a screenshot to a training partner have to cobble together a plain screen grab of the session detail view — which is functional but not designed for sharing. There is no "moment of celebration" that makes finishing a workout feel like an event worth commemorating. Competing apps like Strava for running have shown that shareable summary cards drive organic user acquisition and improve retention through social accountability.

### Idea

After tapping "Finish Workout" (or when viewing any session in `SessionDetailView`), users can tap a **"Share" button** that renders a polished summary card as an image and presents it via the native share sheet.

The card layout:

- **Header**: app name + day type color gradient + date
- **Exercise list**: each exercise with its top set and total volume (e.g., "Bench Press — 185 lbs × 5, 3 sets, 2,775 lbs total")
- **PR badge**: a gold star next to any exercise where a new personal best was set
- **Session stats footer**: total volume, session duration (computed from first `SetRecord.completedAt` to last), number of PRs
- **Branding strip**: subtle "Logged with Strength Training" at the bottom

The card uses the existing `DayType.color` accent, matching the app's visual identity. It renders at a fixed size (e.g., 1080×1350px for Instagram portrait ratio) using SwiftUI's `ImageRenderer`.

### Value Add

This is purely local — `ImageRenderer` produces a `UIImage` with no network calls. `ShareLink` passes it to the native iOS share sheet. The feature doubles as word-of-mouth marketing (shared cards show the app name) and as a personal motivational artifact — users often save these to a fitness folder or share in group chats with training partners. The only framework needed is `ImageRenderer` (available since iOS 16) and the existing `ShareLink` SwiftUI API.

### Implementation Notes

- **New `WorkoutSummaryCardView`**: a standalone SwiftUI view that takes a `WorkoutSession` and renders the card layout. Sized with a fixed `frame` (e.g., 540×675 logical points, renders at 2× for @2x). Uses `DayType.color` for the header gradient, existing SF Symbols, and system fonts. Not placed in the view hierarchy — only used as a render target.
- **`ImageRenderer` integration**: in `SessionDetailView` (or the finish-workout confirmation sheet), an async button computes `ImageRenderer(content: WorkoutSummaryCardView(session: session)).uiImage` and passes the result to `ShareLink(item: image)`. `ImageRenderer` must be used on the main thread; wrap in `await MainActor.run {}` if called from an async context.
- **PR detection**: reuse whatever logic `PRsThisMonthCard` already uses to detect personal bests. If no centralized PR detection utility exists, add a `PersonalRecordService` with a single static method `isPersonalRecord(set: SetRecord, exercise: Exercise) -> Bool` that checks if this `weightLbs` exceeds all prior `SetRecord` entries for the same exercise and training mode.
- **"Share" button placement**: toolbar trailing item in `SessionDetailView`, and a secondary button in the finish-workout confirmation sheet on `ActiveWorkoutView`.
- **No schema changes** — purely a rendering and sharing feature.
- **Edge cases**: handle sessions with no sets (show placeholder text), and truncate the exercise list at 6 items with a "+N more" overflow label for very long workouts.

---

## UI Improvement: Exercise Notes Indicator and Inline Tooltip in Active Workout

### Problem

The `Exercise` model has a `notes: String` field — intended for form cues, coaching notes, and technique reminders like "keep chest up" or "pause at the bottom." But in the active workout view, this field is completely invisible. To see exercise notes, a user would need to leave the workout and navigate to the exercise library. In practice, this means notes are never read at the moment they are most useful: right before performing a set. The field exists in the data model but has no meaningful presence in the workout UX.

### What It Would Change

In `ExerciseRowView`, add a **notes indicator** to the row header: a small `info.circle` SF Symbol icon that appears only when `exercise.notes` is non-empty. Tapping it triggers a `.popover` (iPad/large display) or a `.sheet` with `presentationDetents([.fraction(0.25)])` (compact iPhone) showing the note text in a styled card with the exercise name as a title.

The indicator is subtly styled — secondary foreground color, small frame — so it doesn't crowd the row header. It sits to the right of the exercise name and left of the completion indicator.

```
┌─────────────────────────────────────────────────────┐
│  Barbell Bench Press    ⓘ          ○   ›             │
└─────────────────────────────────────────────────────┘
```

The tooltip content is the raw `exercise.notes` string, rendered in `Text` with `.multilineTextAlignment(.leading)` and a comfortable padding. If the user wants to edit the note mid-workout, a small "Edit" button in the sheet navigates to `AddExerciseView` (or a focused inline editing field).

### Value Add

This is a zero-schema-change, zero-impact-on-non-notes-exercises improvement that unlocks a feature that was already built at the data layer but never surfaced in the most important context. Coaches, athletes following a program, and users who've written their own technique reminders get meaningful utility. The change is fully additive — exercises without notes show no indicator, so the row layout is unchanged for the majority of exercises.

### Implementation Notes

- **Condition**: `if !exercise.notes.isEmpty` guards the entire indicator. No indicator rendered when notes are empty — no layout shift for most rows.
- **State**: `@State private var showingNotes: Bool = false` on `ExerciseRowView`. The `.sheet` or `.popover` is controlled by this local state.
- **Sheet presentation**: use `presentationDetents([.fraction(0.25), .medium])` for compact size classes; use `.popover` for regular width. Standard `#if` or `@Environment(\.horizontalSizeClass)` check.
- **Curtain-reveal preservation**: the notes indicator sits in the static header region (above the clipped content area), so it does not affect the curtain-reveal animation. No changes to the existing frame/clip logic.
- **Exercise notes editing**: the existing `AddExerciseView` already has a notes field. A "Edit Note" `NavigationLink` or `Button` in the sheet that pushes `AddExerciseView` is sufficient. No new editing UI required.
- **Accessibility**: add `.accessibilityLabel("Exercise notes: \(exercise.notes)")` to the indicator button so VoiceOver reads the content without requiring a tap.

---

*Generated by the weekly scheduled brainstorm task. Ideas are grounded in the existing SwiftData schema, MVVM architecture, no-networking constraint, and iOS 26.2+ deployment target.*
