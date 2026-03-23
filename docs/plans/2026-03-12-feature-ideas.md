# Strength Training App — Feature Ideas

**Generated:** March 12, 2026

---

## Feature 1: Smart Rest Timer with Training-Mode Awareness

### The Problem

The app currently has no rest period tracking between sets. Users either guess when to start their next set, switch to a separate timer app (breaking their flow), or just wing it. Rest periods are one of the most critical variables in strength training — too short and you compromise the next set, too long and you lose the metabolic stimulus for hypertrophy.

### The Idea

A context-aware rest timer that auto-starts when a set is logged and adapts its default duration based on the active **training mode**:

- **Strength mode:** defaults to 3 minutes (heavier loads need full neural recovery)
- **Endurance mode:** defaults to 45 seconds (shorter rest maintains metabolic stress)

The timer would live as a persistent, non-intrusive banner at the top of the `ActiveWorkoutView` — appearing immediately after a set is logged and counting down with a circular progress ring. Key UX details:

- **Auto-start on set log.** The moment `SetInputView` saves a set, the timer begins. No extra tap required.
- **Quick-adjust buttons** (+15s / -15s) for on-the-fly changes when fatigue is higher or lower than expected.
- **Per-exercise overrides.** A long-press on the timer (or a setting in the exercise library) lets users set a custom rest duration for specific exercises. Compound lifts like squats might warrant 4 minutes even in an endurance block.
- **Haptic + optional audio alert** when rest is complete, using the existing `HapticService` pattern (a new `restComplete()` method with a distinctive double-tap pattern). Works even when the phone is locked or the app is backgrounded via local notifications.
- **Timer state persists across exercise switches.** If the user collapses one exercise row and opens another mid-rest, the timer keeps counting in the banner.

### Why It Matters

Every serious lifting app (Strong, Hevy, Fitbod) has a rest timer — it's table stakes for workout tracking. But what makes this version distinctive is the training-mode integration that already exists in the app. Instead of a generic countdown, the timer speaks the same language as the rest of the UX (Strength vs. Endurance), reinforcing the purpose of each session. This feature directly improves workout quality without adding complexity.

### Data Model Impact

Minimal. A new `restDuration` optional field on `Exercise` (for per-exercise overrides) and a `defaultRestSeconds` stored in `UserDefaults` per training mode. No new SwiftData entities required — the timer is ephemeral UI state managed by `WorkoutViewModel`.

---

## Feature 2: Workout Templates & Program Builder

### The Problem

Right now, the app treats every workout as a blank slate. Users pick a day type (Arms, Legs, Full Body) and see all exercises for that category. There's no way to pre-plan a workout — say, "Monday is bench press, overhead press, and tricep pushdowns" — and load that up with a single tap. Users who follow structured programs (PPL, Upper/Lower, 5/3/1) have to mentally track which exercises to do each session and manually scroll past the ones they're skipping.

### The Idea

A **template system** that lets users save a curated list of exercises (with optional pre-set training modes and target set counts) as a reusable workout template. The flow:

1. **Create a template** from the Exercise Library or from a completed workout session. Users name it ("Push Day A", "Leg Hypertrophy", "Deadlift Focus"), pick exercises in order, and optionally set a target number of sets and default training mode per exercise.
2. **Start a workout from a template.** A new entry point on the Workout tab: instead of (or alongside) the day-type picker, users see their saved templates as cards. Tapping one creates a new `WorkoutSession` pre-populated with only those exercises, in the saved order, with the saved training modes. The current day-type picker still works for freeform sessions.
3. **Template suggestions.** After completing a session, the app could suggest "Save as template?" if the user trained a combination of exercises they haven't saved before.
4. **Program rotation.** For users running multi-week programs, templates could be tagged with a sequence (Week 1 / Week 2) and the app highlights which one is "next" based on history.

### Why It Matters

This bridges the gap between a workout *logger* and a workout *planner*. The app already has strong tracking and analytics — but the pre-workout experience is undifferentiated. Templates reduce decision fatigue ("what should I do today?") and make the app stickier for intermediate and advanced lifters who follow structured programs. It's also the most-requested feature category across competing apps like Hevy and Strong.

### Data Model Impact

One new SwiftData model: `WorkoutTemplate` with a name, optional `DayType`, and an ordered list of `TemplateExerciseEntry` (linking to an `Exercise` with optional `trainingMode` and `targetSets`). Templates have a cascade delete to their entries. The `WorkoutSession` model gets an optional `templateID` reference so history can show which template was used.

---

## UI Improvement: Liquid Glass Redesign for the Workout Tab

### The Problem

The Workout tab's day-type picker and active workout chrome use standard opaque backgrounds and flat card styling. With iOS 26 shipping Liquid Glass as the new system-wide design language, the app's primary interaction surface — where users spend 90% of their time — will look dated compared to native Apple apps and competitors who adopt the new aesthetic.

### The Idea

Apply iOS 26's **Liquid Glass** material to the key interactive surfaces of the Workout tab:

- **Day-type picker cards.** Replace the current flat colored cards with `glassEffect`-backed panels. The existing color coding (pink for Arms, blue for Legs, purple for Full Body) becomes the `tint` parameter, giving each card a distinctive hue while letting the translucent glass material show through. The SF Symbol icons sit prominently on top.
- **Training mode selector.** The Strength/Endurance toggle at the top of `ActiveWorkoutView` becomes a segmented glass pill using `GlassEffectContainer` so the active segment morphs smoothly between options with the Liquid Glass lensing effect.
- **Floating "Finish Workout" button.** Move the finish action from a toolbar item to a floating Liquid Glass action button in the bottom-right corner — a pattern Apple is promoting for primary actions. The glass material makes it visually distinct without being heavy.
- **Exercise row headers.** Apply a subtle glass effect to the sticky section headers so they blur the content scrolling beneath them, reinforcing the curtain-reveal animation that's already a signature of the app.

### Why It Matters

This is a relatively contained visual refresh — it doesn't require rearchitecting any views or changing data flow. The `glassEffect` modifier is additive, so the changes can be feature-flagged behind `if #available(iOS 26, *)` while keeping the existing design for iOS 25 and earlier. It keeps the app feeling current with platform conventions, which matters for retention — users notice when an app feels "native" vs. stale. And since the app already targets iOS 26.2+, there's no backward-compatibility cost.

### Implementation Notes

Key SwiftUI APIs to use: `.glassEffect()` for individual views, `GlassEffectContainer` to group related glass elements, and `.glassEffectID()` for smooth morphing transitions (especially useful on the training mode toggle). Testing should verify that the curtain-reveal animation in `ExerciseRowView` still works correctly with glass headers, since clipping behavior may interact with the material's blur radius.

---

*These ideas are listed in rough priority order — the rest timer fills the most immediate functional gap, templates add the most long-term value, and the Liquid Glass refresh keeps the visual layer fresh.*
