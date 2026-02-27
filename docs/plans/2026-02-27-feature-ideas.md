---
title: Feature Ideas — Feb 27, 2026
date: 2026-02-27
tags:
  - feature-ideas
  - brainstorm
  - strength-training
status: draft
---

# Feature Ideas — Feb 27, 2026

Two new feature concepts and one UI/performance improvement, based on a review of the current codebase and the latest trends in strength training apps and iOS development.

---

## Feature 1: Recovery Readiness & Fatigue Tracker

### The Problem

The app tracks *what* you did, but gives no guidance on *what you should do next*. Users have to mentally estimate which muscle groups are fresh versus fatigued. Over time this leads to imbalanced training, accidental overtraining, or under-recovery — all of which plateau progress.

### The Idea

Introduce a **per-muscle-group fatigue model** built entirely from existing local data. No HealthKit, no networking — just smart math on top of the workout history already being logged.

**How it works:**

1. **Rolling volume accumulation** — For each muscle group, sum total volume (weight × reps) over a sliding 7-day window. Compare this to the user's 4-week rolling average for that muscle group.
2. **Recovery decay curve** — After a session, a muscle group's fatigue score starts high and decays over 48–72 hours (configurable). The decay rate adjusts based on the user's historical training frequency for that group.
3. **Readiness heatmap** — On the `WorkoutDayPickerView`, overlay each day type card (Arms / Legs / Full Body) with a color-coded readiness indicator (green = fresh, yellow = moderate, red = fatigued). This gives an at-a-glance recommendation for which day type to train today.
4. **Overtraining detection** — If e1RM for a given exercise has declined over 3+ consecutive sessions while volume stayed the same or increased, surface a subtle warning: *"Your bench press e1RM has dropped 3 sessions in a row. Consider a lighter week."*

### Value Add

This turns the app from a passive logbook into an active training advisor. Competing apps like Fitbod charge subscriptions for AI-driven recovery recommendations — this feature provides similar intelligence using purely local heuristics, which aligns with the app's no-networking philosophy.

### Implementation Notes

- New `RecoveryViewModel` (`@Observable`) that fetches recent `SetRecord` data grouped by `Exercise.muscleGroup`.
- A `FatigueScore` utility struct with the decay math (exponential decay from session volume, parameterized by hours since session).
- UI additions: colored badge/bar on each `WorkoutDayPickerView` card, and an optional detail sheet showing per-muscle-group breakdown.
- The e1RM regression detection can reuse logic from `ExerciseDrillDownViewModel`.
- Data model: no schema changes needed — all computed from existing `SetRecord`, `ExerciseRecord`, and `Exercise.muscleGroup` fields.

---

## Feature 2: Smart Set Suggestions with RPE Feedback

### The Problem

The current "Last" button auto-populates from the previous session, which is helpful but static. It doesn't account for progressive overload — the fundamental principle that you need to gradually increase stimulus to keep getting stronger. Users have to manually decide when to bump weight up or add a rep, and many either stagnate or progress too aggressively.

### The Idea

Replace the simple "Last" auto-fill with an **intelligent suggestion engine** that recommends target weight and reps for each set, then refines in real-time based on user feedback.

**How it works:**

1. **Baseline suggestion** — Pull the user's last completed sets for this exercise+mode. Apply a small linear progression: +2.5 lbs for upper body / +5 lbs for lower body (Strength mode), or +1 rep at the same weight (Endurance mode). These defaults are configurable in Settings.
2. **RPE micro-feedback** — After logging each set, show a quick 3-button prompt: 😤 Hard / ✅ Good / 💪 Easy. This takes under a second to tap and gives immediate signal.
3. **Intra-session adjustment** — If the user rates a set "Hard," the next set's suggestion drops weight by one increment or reduces target reps by 1. If "Easy," it bumps up. "Good" stays the course.
4. **Cross-session learning** — Over multiple sessions, the app builds a simple linear model of the user's progression rate per exercise. If a user consistently rates suggested weights as "Easy," the progression increment increases. If they frequently rate "Hard" and fail to hit targets, it slows down.
5. **Suggestion display** — In `SetInputView`, show the suggested weight/reps as ghost text in the input fields (light gray, pre-filled but editable). A small "Suggested" label distinguishes it from manually entered values.

### Value Add

This is the single most impactful coaching feature a strength app can have. Apps like SHRED and Fitbod charge premium subscriptions for adaptive progression. By keeping the algorithm simple (linear regression, not ML), it stays fast, transparent, and fully offline. The RPE feedback loop also generates valuable subjective data that enriches the analytics in the Progress tab over time.

### Implementation Notes

- New `SuggestionEngine` service class that takes an exercise, training mode, and recent session history, and returns suggested weight/reps.
- Small data model addition: add an optional `rpe: Int?` field to `SetRecord` (1 = Easy, 2 = Good, 3 = Hard). This is the only schema change needed.
- New `ProgressionSettings` stored in `UserDefaults` (weight increment per body region, toggle on/off).
- UI changes: ghost-text pre-fill in `SetInputView`, 3-button RPE strip after logging a set, "Suggested" badge.
- The cross-session learning can be a simple slope calculation on (session_number, achieved_weight) pairs — no ML framework needed.

---

## Improvement: Liquid Glass Adoption & Haptic Polish

### Context

The app targets iOS 26.2, which means it's running on Liquid Glass by default. However, standard SwiftUI components (TabView, NavigationStack, toolbars) auto-adopt Liquid Glass only at the system level — **custom UI elements need manual migration** to look intentional rather than half-updated. Additionally, the workout logging flow currently has no haptic feedback, which makes the repetitive tap-tap-tap of logging sets feel flat.

### What to Do

**Liquid Glass migration for custom elements:**

- The `WorkoutDayPickerView` cards (Arms / Legs / Full Body) use custom styling that won't auto-adopt Liquid Glass. Apply `.glassEffect()` to these cards so they match the system aesthetic — translucent, with light refraction and adaptive shadows.
- The `TrainingModePicker` segmented control is a custom HStack of buttons. Wrap it in a `GlassEffectContainer` so the selected state gets the characteristic Liquid Glass lensing effect.
- The expandable `ExerciseRowView` headers could benefit from a subtle `.glassEffect()` to visually separate them from the revealed content beneath (reinforcing the "curtain" metaphor).
- Review all `.background()` modifiers across the app — any that use solid colors or `Material.ultraThinMaterial` should be evaluated for replacement with `.glassEffect()` where they sit in the navigation layer.

**Haptic feedback throughout workout flow:**

- **Set logged** — Medium impact (`UIImpactFeedbackGenerator(.medium)`) when a set is saved. This is the most frequent action and deserves satisfying tactile confirmation.
- **Exercise completed** (all sets done) — Success notification (`UINotificationFeedbackGenerator().notificationOccurred(.success)`).
- **Workout completed** — Triple haptic burst (custom pattern via `CHHapticEngine` if available, fallback to sequential notification haptics).
- **Weight/rep stepper hold-to-repeat** — Light impact on each increment tick, matching the existing 200ms repeat interval. This makes the stepper feel mechanical and precise.
- **Swipe-to-delete** — Warning notification on the delete threshold.

**Quick win — Launch screen polish:**

- The app currently uses a default white launch screen. Add a simple `LaunchScreen.storyboard` with the app's accent color background and a centered SF Symbol (`figure.strengthtraining.traditional`) for a branded, instant-on feel.

### Value Add

These are low-effort, high-impact changes. Liquid Glass adoption ensures the app looks native and intentional on iOS 26 rather than "last-gen with a coat of paint." Haptics transform the workout logging experience from visual-only to multi-sensory — something users feel dozens of times per session. The launch screen is a 15-minute task that eliminates the jarring white flash on app open.

### Implementation Notes

- Liquid Glass: import `SwiftUI` (`.glassEffect()` is built-in on iOS 26). Wrap affected views in `GlassEffectContainer` where multiple glass elements need to interact. Test in both light and dark mode — Liquid Glass adapts automatically but custom colors underneath may need adjustment.
- Haptics: create a small `HapticService` utility with static methods (`setLogged()`, `exerciseCompleted()`, `workoutCompleted()`, `stepperTick()`). Call from ViewModels, not Views, to keep the separation clean.
- Launch screen: add `LaunchScreen.storyboard` to the Xcode project, set it in the target's General tab, use the app's existing accent color from the asset catalog.

---

*Generated 2026-02-27 by scheduled brainstorm task.*
