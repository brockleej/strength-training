//
//  SeedData.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import Foundation
import SwiftData

struct SeedData {
    /// One-time, idempotent display-name corrections for seeded exercises.
    /// Runs on every launch and after every backup restore — existing records
    /// keep their relationships (rename only), and restoring an old backup
    /// re-applies the fix on the spot.
    static func migrateExerciseNames(context: ModelContext) {
        let renames = [
            "Hip Abduction (Inner)": "Hip Adduction (Inner)",
            "Rear Deltoid": "Rear Delt Fly",
            "Pulldown": "Lat Pulldown",
            "Row": "Seated Cable Row",
            "Glute": "Glute Bridge",
            "Calf Extension": "Standing Calf Raise",
            "Abdominal": "Cable Crunch",
            "Leg Curl": "Lying Hamstring Curl",
            "Seated Leg Curl": "Seated Hamstring Curl",
        ]
        let descriptor = FetchDescriptor<Exercise>()
        guard let all = try? context.fetch(descriptor) else { return }
        var changed = false
        for exercise in all {
            if let newName = renames[exercise.name] {
                // Only rename if the target name isn't already taken (avoid merge clashes).
                let targetExists = all.contains { $0.id != exercise.id && $0.name == newName }
                if !targetExists {
                    exercise.name = newName
                    changed = true
                }
            }
        }
        if changed { try? context.save() }
    }

    /// Removes duplicate exercises (same name + dayType), keeping the one with the most history.
    /// Records from duplicates are reassigned to the kept exercise before deletion.
    static func deduplicateExercises(context: ModelContext) {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var grouped: [String: [Exercise]] = [:]
        for exercise in exercises {
            let key = "\(exercise.name.lowercased())|\(exercise.dayTypeNames.joined(separator: "+"))"
            grouped[key, default: []].append(exercise)
        }
        for (_, group) in grouped where group.count > 1 {
            let sorted = group.sorted { $0.recordsArray.count > $1.recordsArray.count }
            let keeper = sorted[0]
            for duplicate in sorted.dropFirst() {
                for record in duplicate.recordsArray {
                    record.exercise = keeper
                }
                context.delete(duplicate)
            }
        }
        try? context.save()
    }

    /// Seeds the default bro-split day types when none exist yet.
    static func seedSplitDaysIfNeeded(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<SplitDay>())) ?? 0
        guard count == 0 else { return }
        for def in SplitPreset.broSplit.definitions {
            context.insert(SplitDay(definition: def))
        }
        try? context.save()
    }

    /// Upgrade stock day icons when the user still has the old defaults
    /// (does not overwrite a custom pick).
    static func migrateDayTypeIcons(context: ModelContext) {
        let upgrades: [String: (legacy: Set<String>, preferred: String)] = [
            "Push": (["figure.strengthtraining.traditional"], "dumbbell.fill"),
            "Pull": (["figure.climbing"], "figure.indoor.rowing"),
            "Legs": (["figure.walk"], "figure.stair.stepper"),
            "Posterior Chain": (
                ["figure.strengthtraining.functional", "figure.walk"],
                "figure.strengthtraining.functional"
            ),
            "Full Body": (
                ["figure.strengthtraining.functional", "figure.arms.open"],
                "figure.cross.training"
            ),
            "Arms": (["figure.arms.open"], "figure.arms.open"),
            "Upper": (["figure.arms.open"], "figure.strengthtraining.traditional"),
            "Lower": (["figure.walk"], "figure.stair.stepper"),
        ]

        let rows = (try? context.fetch(FetchDescriptor<SplitDay>())) ?? []
        var changed = false
        for row in rows {
            guard let upgrade = upgrades[row.name] else { continue }
            if upgrade.legacy.contains(row.systemImage), row.systemImage != upgrade.preferred {
                row.systemImage = upgrade.preferred
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    // MARK: - Exercise catalog

    /// (name, muscle group, default home day). Home day is a starting tag only —
    /// users reassign freely. Prefer PPL-PC-friendly homes; bro-split users still
    /// see everything in the full library picker.
    static let exerciseCatalog: [(name: String, muscle: String, day: DayType)] = {
        var items: [(String, String, DayType)] = []

        // MARK: Chest (Push)
        items += [
            ("Barbell Bench Press", "Chest", .push),
            ("Incline Barbell Bench Press", "Chest", .push),
            ("Decline Barbell Bench Press", "Chest", .push),
            ("Dumbbell Bench Press", "Chest", .push),
            ("Incline Dumbbell Press", "Chest", .push),
            ("Decline Dumbbell Press", "Chest", .push),
            ("Chest Press", "Chest", .push),
            ("Machine Chest Press", "Chest", .push),
            ("Pectoral Fly", "Chest", .push),
            ("Cable Fly", "Chest", .push),
            ("Pec Deck", "Chest", .push),
            ("Push-Up", "Chest", .push),
            ("Dip (Chest)", "Chest", .push),
        ]

        // MARK: Shoulders (Push)
        items += [
            ("Overhead Press", "Shoulders", .push),
            ("Shoulder Press", "Shoulders", .push),
            ("Seated Dumbbell Shoulder Press", "Shoulders", .push),
            ("Arnold Press", "Shoulders", .push),
            ("Lateral Raise", "Shoulders", .push),
            ("Cable Lateral Raise", "Shoulders", .push),
            ("Front Raise", "Shoulders", .push),
            ("Upright Row", "Shoulders", .push),
            ("Machine Shoulder Press", "Shoulders", .push),
        ]

        // MARK: Triceps (Push)
        items += [
            ("Triceps Press", "Triceps", .push),
            ("Triceps Pushdown", "Triceps", .push),
            ("Overhead Triceps Extension", "Triceps", .push),
            ("Skull Crusher", "Triceps", .push),
            ("Close-Grip Bench Press", "Triceps", .push),
            ("Dip (Triceps)", "Triceps", .push),
            ("Kickback", "Triceps", .push),
        ]

        // MARK: Back — vertical / horizontal pull (Pull)
        items += [
            ("Pull-Up", "Back", .pull),
            ("Chin-Up", "Back", .pull),
            ("Lat Pulldown", "Back", .pull),
            ("Wide-Grip Lat Pulldown", "Back", .pull),
            ("Neutral-Grip Lat Pulldown", "Back", .pull),
            ("Straight-Arm Pulldown", "Back", .pull),
            ("Seated Cable Row", "Back", .pull),
            ("Chest-Supported Row", "Back", .pull),
            ("Chest-Supported T-Bar Row", "Back", .pull),
            ("Barbell Bent-Over Row", "Back", .pull),
            ("Pendlay Row", "Back", .pull),
            ("One-Arm Dumbbell Row", "Back", .pull),
            ("Meadows Row", "Back", .pull),
            ("Machine Row", "Back", .pull),
            ("Inverted Row", "Back", .pull),
            ("Face Pull", "Rear Delts", .pull),
            ("Rear Delt Fly", "Rear Delts", .pull),
            ("Reverse Pec Deck", "Rear Delts", .pull),
            ("Band Pull-Apart", "Rear Delts", .pull),
        ]

        // MARK: Biceps (Pull)
        items += [
            ("Biceps Curl", "Biceps", .pull),
            ("Barbell Curl", "Biceps", .pull),
            ("Dumbbell Curl", "Biceps", .pull),
            ("Hammer Curl", "Biceps", .pull),
            ("Incline Dumbbell Curl", "Biceps", .pull),
            ("Preacher Curl", "Biceps", .pull),
            ("Cable Curl", "Biceps", .pull),
            ("Concentration Curl", "Biceps", .pull),
        ]

        // MARK: Quads / knee-dominant (Legs)
        items += [
            ("Barbell Back Squat", "Quads", .legs),
            ("Front Squat", "Quads", .legs),
            ("Smith Machine Squat", "Quads", .legs),
            ("Hack Squat", "Quads", .legs),
            ("Pendulum Squat", "Quads", .legs),
            ("Safety Bar Squat", "Quads", .legs),
            ("Goblet Squat", "Quads", .legs),
            ("Leg Press", "Quads", .legs),
            ("Seated Leg Press", "Quads", .legs),
            ("Leg Extension", "Quads", .legs),
            ("Poliquin Step-Up", "Quads", .legs),
            ("Bulgarian Split Squat", "Quads", .legs),
            ("Walking Lunge", "Quads", .legs),
            ("Reverse Lunge", "Quads", .legs),
            ("Sissy Squat", "Quads", .legs),
            ("Belt Squat", "Quads", .legs),
        ]

        // MARK: Hamstrings / posterior (Posterior Chain)
        items += [
            ("Conventional Deadlift", "Hamstrings", .posteriorChain),
            ("Sumo Deadlift", "Hamstrings", .posteriorChain),
            ("Romanian Deadlift", "Hamstrings", .posteriorChain),
            ("Stiff-Leg Deadlift", "Hamstrings", .posteriorChain),
            ("Trap Bar Deadlift", "Hamstrings", .posteriorChain),
            ("Single-Leg Romanian Deadlift", "Hamstrings", .posteriorChain),
            ("Lying Hamstring Curl", "Hamstrings", .posteriorChain),
            ("Seated Hamstring Curl", "Hamstrings", .posteriorChain),
            ("Standing Hamstring Curl", "Hamstrings", .posteriorChain),
            ("Nordic Hamstring Curl", "Hamstrings", .posteriorChain),
            ("Seated Good Morning", "Hamstrings", .posteriorChain),
            ("Standing Good Morning", "Hamstrings", .posteriorChain),
            ("Back Extension", "Lower Back", .posteriorChain),
            ("45° Back Extension", "Lower Back", .posteriorChain),
            ("Reverse Hyper", "Lower Back", .posteriorChain),
            ("QL Extension", "Lower Back", .posteriorChain),
            ("Cable Pull-Through", "Glutes", .posteriorChain),
            ("Hip Thrust", "Glutes", .posteriorChain),
            ("Barbell Hip Thrust", "Glutes", .posteriorChain),
            ("Glute Bridge", "Glutes", .posteriorChain),
            ("Single-Leg Glute Bridge", "Glutes", .posteriorChain),
            ("Kickback (Glute)", "Glutes", .posteriorChain),
            ("Hip Abduction (Glute)", "Glutes", .posteriorChain),
            ("Cable Kickback", "Glutes", .posteriorChain),
        ]

        // MARK: Hips / adductors / flexors
        items += [
            ("Hip Adduction (Inner)", "Adductors", .legs),
            ("Copenhagen Plank", "Adductors", .legs),
            ("Hip Flexor Raise", "Hip Flexors", .legs),
            ("Hanging Knee Raise", "Hip Flexors", .legs),
            ("Captain's Chair Knee Raise", "Hip Flexors", .legs),
            ("Cable Hip Flexion", "Hip Flexors", .legs),
        ]

        // MARK: Calves / tibialis
        items += [
            ("Standing Calf Raise", "Calves", .legs),
            ("Seated Calf Raise", "Calves", .legs),
            ("Leg Press Calf Raise", "Calves", .legs),
            ("Donkey Calf Raise", "Calves", .legs),
            ("Tibialis Raise", "Tibialis", .legs),
            ("Wall Tibialis Raise", "Tibialis", .legs),
        ]

        // MARK: Core
        items += [
            ("Cable Crunch", "Core", .push),
            ("Hanging Leg Raise", "Core", .pull),
            ("Ab Wheel Rollout", "Core", .posteriorChain),
            ("Plank", "Core", .legs),
            ("Side Plank", "Core", .legs),
            ("Pallof Press", "Core", .push),
            ("Torso Rotation", "Core", .pull),
            ("Russian Twist", "Core", .pull),
            ("Dead Bug", "Core", .legs),
            ("Bird Dog", "Core", .posteriorChain),
        ]

        // MARK: Traps / upper back extras
        items += [
            ("Barbell Shrug", "Traps", .pull),
            ("Dumbbell Shrug", "Traps", .pull),
            ("Farmer Carry", "Traps", .pull),
            ("Y-Raise", "Rear Delts", .pull),
            ("Prone Y-T-W", "Rear Delts", .pull),
        ]

        return items
    }()

    // MARK: - Seed / top-up

    static func seedIfNeeded(context: ModelContext) {
        seedSplitDaysIfNeeded(context: context)

        let hasSeeded = UserDefaults.standard.bool(forKey: "hasSeededExercises")
        let count = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0

        if !hasSeeded && count == 0 {
            insertCatalogExercises(context: context, existingNames: [])
            try? context.save()
            UserDefaults.standard.set(true, forKey: "hasSeededExercises")
            UserDefaults.standard.set(catalogVersion, forKey: catalogVersionKey)
            return
        }

        // Existing install (or iCloud data): still top up missing catalog names.
        UserDefaults.standard.set(true, forKey: "hasSeededExercises")
        topUpCatalogIfNeeded(context: context)
    }

    /// Bump when the stock catalog gains new exercises so installs re-scan.
    private static let catalogVersion = 2
    private static let catalogVersionKey = "exerciseCatalogVersion"

    /// Insert any catalog lifts not already in the library (by name, case-insensitive).
    static func topUpCatalogIfNeeded(context: ModelContext) {
        let installedVersion = UserDefaults.standard.integer(forKey: catalogVersionKey)
        // Always allow top-up if version is behind OR library is thinner than catalog.
        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let existingNames = Set(existing.map { $0.name.lowercased() })

        let missing = exerciseCatalog.filter { !existingNames.contains($0.name.lowercased()) }
        guard !missing.isEmpty || installedVersion < catalogVersion else { return }

        if !missing.isEmpty {
            let baseOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
            insertCatalogExercises(
                context: context,
                existingNames: existingNames,
                sortOrderBase: baseOrder,
                only: missing
            )
            try? context.save()
        }
        UserDefaults.standard.set(catalogVersion, forKey: catalogVersionKey)
    }

    private static func insertCatalogExercises(
        context: ModelContext,
        existingNames: Set<String>,
        sortOrderBase: Int = 0,
        only: [(name: String, muscle: String, day: DayType)]? = nil
    ) {
        let source = only ?? exerciseCatalog
        var order = sortOrderBase
        for item in source {
            if existingNames.contains(item.name.lowercased()) { continue }
            context.insert(
                Exercise(
                    name: item.name,
                    dayType: item.day,
                    muscleGroup: item.muscle,
                    sortOrder: order,
                    isCustom: false
                )
            )
            order += 1
        }
    }
}
