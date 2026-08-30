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

    /// Upgrade stock compound lifts to multi-muscle labels (idempotent).
    /// Custom exercises are left alone. Only replaces when the stored muscle is a
    /// single legacy primary that matches the old catalog single-group tag.
    static func migrateCompoundMuscleGroups(context: ModelContext) {
        let byName = Dictionary(
            uniqueKeysWithValues: exerciseCatalog.map { ($0.name.lowercased(), $0.muscle) }
        )
        let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var changed = false
        for exercise in all {
            guard !exercise.isCustom else { continue }
            guard let catalogMuscle = byName[exercise.name.lowercased()] else { continue }
            // Skip if already multi-tagged the same way.
            let current = exercise.muscleGroupNames.map { $0.lowercased() }.sorted()
            let target = catalogMuscle
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
                .sorted()
            guard current != target else { continue }
            // Don't overwrite user-edited multi-muscle that diverged from catalog
            // unless still single-muscle (typical stock seed).
            if exercise.muscleGroupNames.count > 1, current != target {
                // Only upgrade when catalog is a strict expansion of the primary.
                guard let primary = exercise.muscleGroupNames.first?.lowercased(),
                      target.contains(primary),
                      target.count > current.count
                else { continue }
            }
            exercise.muscleGroup = catalogMuscle
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Removes duplicate exercises (same name), keeping the one with the most history.
    /// Grouping by name only — not name+days — so a seeded starter and the user's
    /// copy of the same lift collapse instead of both showing on the day.
    /// Safe to re-run after CloudKit import (second device can seed before iCloud lands).
    static func deduplicateExercises(context: ModelContext) {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var grouped: [String: [Exercise]] = [:]
        for exercise in exercises {
            let key = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            grouped[key, default: []].append(exercise)
        }
        let snapshotIDs = Set((loadDayPlanSnapshot() ?? []).flatMap(\.exerciseIDs))
        for (_, group) in grouped where group.count > 1 {
            let sorted = group.sorted { lhs, rhs in
                let lhsSnap = snapshotIDs.contains(lhs.id)
                let rhsSnap = snapshotIDs.contains(rhs.id)
                if lhsSnap != rhsSnap { return lhsSnap && !rhsSnap }
                if lhs.recordsArray.count != rhs.recordsArray.count {
                    return lhs.recordsArray.count > rhs.recordsArray.count
                }
                return lhs.dayTypeNames.count < rhs.dayTypeNames.count
            }
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

    /// Collapses duplicate split days (same name, case-insensitive) that can appear when
    /// a fresh install seeds before CloudKit imports an existing split from iCloud.
    static func deduplicateSplitDays(context: ModelContext, reloadCatalog: Bool = true) {
        let days = (try? context.fetch(FetchDescriptor<SplitDay>())) ?? []
        var grouped: [String: [SplitDay]] = [:]
        for day in days {
            let key = day.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            grouped[key, default: []].append(day)
        }
        var changed = false
        for (_, group) in grouped where group.count > 1 {
            // Prefer the row with the lowest sortOrder (canonical catalog order), then stable id.
            let sorted = group.sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.id.uuidString < $1.id.uuidString
            }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
                changed = true
            }
        }
        if changed {
            try? context.save()
            // reload() calls this with reloadCatalog: false to avoid recursion.
            if reloadCatalog {
                DayTypeRegistry.shared.reload(context: context)
            }
        }
    }

    /// Post-import hygiene after CloudKit merges remote rows with a local seed.
    static func reconcileAfterCloudKitImport(context: ModelContext) {
        migrateExerciseNames(context: context)
        migrateCompoundMuscleGroups(context: context)
        deduplicateExercises(context: context)
        deduplicateSplitDays(context: context)
        reconcileSplitToSnapshot(context: context)
        stripUnusedStarterExtrasIfNeeded(context: context)
        reconcileDayPlansToSnapshot(context: context)
        persistSplitSnapshotIfAuthoritative(context: context)
    }

    /// UserDefaults: once the user applies a preset or edits days, never re-seed
    /// a default split over an empty store (wait for CloudKit instead).
    static let hasConfiguredSplitKey = "hasConfiguredSplit"
    static let preferredSplitPresetKey = "preferredSplitPresetRaw"
    /// JSON array of `SplitDayBackup` — membership + order + styling.
    static let splitSnapshotKey = "configuredSplitDaysJSON"
    /// JSON array of `DayPlanBackup` — which lifts sit on each day, in order.
    static let dayPlanSnapshotKey = "configuredDayPlansJSON"
    static let hasSeededExercisesKey = "hasSeededExercises"
    static let strippedUnusedStarterExtrasKey = "strippedUnusedStarterExtrasV1"

    static func markSplitConfigured(preset: SplitPreset? = nil, context: ModelContext? = nil) {
        UserDefaults.standard.set(true, forKey: hasConfiguredSplitKey)
        let kvs = NSUbiquitousKeyValueStore.default
        kvs.set(true, forKey: hasConfiguredSplitKey)
        if let preset {
            UserDefaults.standard.set(preset.rawValue, forKey: preferredSplitPresetKey)
            kvs.set(preset.rawValue, forKey: preferredSplitPresetKey)
        }
        if let context {
            persistSplitSnapshot(context: context)
        }
    }

    /// Pull split prefs from iCloud KVS into local UserDefaults (call on launch).
    static func hydrateSplitPreferencesFromICloud() {
        let kvs = NSUbiquitousKeyValueStore.default
        if kvs.bool(forKey: hasConfiguredSplitKey) {
            UserDefaults.standard.set(true, forKey: hasConfiguredSplitKey)
        }
        if let raw = kvs.string(forKey: preferredSplitPresetKey), !raw.isEmpty {
            UserDefaults.standard.set(raw, forKey: preferredSplitPresetKey)
        }
        if let json = kvs.string(forKey: splitSnapshotKey), !json.isEmpty {
            UserDefaults.standard.set(json, forKey: splitSnapshotKey)
        }
        if let json = kvs.string(forKey: dayPlanSnapshotKey), !json.isEmpty {
            UserDefaults.standard.set(json, forKey: dayPlanSnapshotKey)
        }
    }

    static func loadSplitSnapshot() -> [SplitDayBackup]? {
        let json = UserDefaults.standard.string(forKey: splitSnapshotKey)
            ?? NSUbiquitousKeyValueStore.default.string(forKey: splitSnapshotKey)
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([SplitDayBackup].self, from: data)
    }

    /// Write the live Today split (days + order) to UserDefaults and iCloud KVS.
    static func persistSplitSnapshot(context: ModelContext) {
        let rows = fetchSplitDays(context: context)
        guard !rows.isEmpty else { return }
        let snaps = rows.enumerated().map { index, row in
            SplitDayBackup(
                id: row.id,
                name: row.name,
                systemImage: row.systemImage,
                subtitle: row.subtitle,
                colorHex: row.colorHex,
                includesAllExercises: row.includesAllExercises,
                sortOrder: index
            )
        }
        guard let data = try? JSONEncoder().encode(snaps),
              let json = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(json, forKey: splitSnapshotKey)
        UserDefaults.standard.set(true, forKey: hasConfiguredSplitKey)
        let kvs = NSUbiquitousKeyValueStore.default
        kvs.set(json, forKey: splitSnapshotKey)
        kvs.set(true, forKey: hasConfiguredSplitKey)
        persistDayPlanSnapshot(context: context)
    }

    /// Avoid publishing a local bro-split + real-split union over a good remote snapshot.
    static func persistSplitSnapshotIfAuthoritative(context: ModelContext) {
        let rows = fetchSplitDays(context: context)
        guard !rows.isEmpty else { return }
        if let remote = loadSplitSnapshot(), !remote.isEmpty {
            let localNames = Set(rows.map { $0.name.lowercased() })
            let remoteNames = Set(remote.map { $0.name.lowercased() })
            if remoteNames.isSubset(of: localNames), remoteNames != localNames {
                let extras = localNames.subtracting(remoteNames)
                if extras.isSubset(of: broSplitNameSet) { return }
            }
        }
        persistSplitSnapshot(context: context)
    }

    /// Write the live per-day rosters to UserDefaults and iCloud KVS.
    /// Skip when every day is empty — that is the reinstall window before
    /// CloudKit brings the user's lifts, not a real "cleared all days" plan.
    static func persistDayPlanSnapshot(context: ModelContext) {
        let plans = captureDayPlans(context: context)
        guard plans.contains(where: { !$0.exerciseIDs.isEmpty }) else { return }
        storeDayPlanSnapshot(plans)
    }

    /// Persist after the user adds/removes a lift from a day.
    static func persistUserPlan(context: ModelContext) {
        persistSplitSnapshot(context: context)
    }

    static func loadDayPlanSnapshot() -> [DayPlanBackup]? {
        let json = UserDefaults.standard.string(forKey: dayPlanSnapshotKey)
            ?? NSUbiquitousKeyValueStore.default.string(forKey: dayPlanSnapshotKey)
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([DayPlanBackup].self, from: data)
    }

    static func storeDayPlanSnapshot(_ plans: [DayPlanBackup]) {
        guard let data = try? JSONEncoder().encode(plans),
              let json = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(json, forKey: dayPlanSnapshotKey)
        NSUbiquitousKeyValueStore.default.set(json, forKey: dayPlanSnapshotKey)
    }

    static func captureDayPlans(context: ModelContext) -> [DayPlanBackup] {
        let splitDays = fetchSplitDays(context: context)
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        return captureDayPlans(from: exercises, splitDays: splitDays)
    }

    static func captureDayPlans(from exercises: [Exercise], splitDays: [SplitDay]) -> [DayPlanBackup] {
        splitDays.compactMap { row in
            guard !row.includesAllExercises else { return nil }
            let day = DayType(rawValue: row.name)
            let members = exercises
                .filter { $0.belongs(to: day) }
                .sorted {
                    let lhs = $0.sortIndex(for: day)
                    let rhs = $1.sortIndex(for: day)
                    if lhs != rhs { return lhs < rhs }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            return DayPlanBackup(dayName: row.name, exerciseIDs: members.map(\.id))
        }
    }

    /// Restore a backup's day rosters (or derive them from restored exercises).
    static func restoreDayPlans(from backup: AppBackup, context: ModelContext) {
        if let plans = backup.dayPlans, !plans.isEmpty {
            storeDayPlanSnapshot(plans)
            _ = applyDayPlanSnapshot(plans, context: context)
            return
        }
        persistDayPlanSnapshot(context: context)
    }

    /// Pin each snapshot day's roster to those IDs. Extra lifts (re-seeded starters
    /// that CloudKit re-imported) are removed from snapshot days only.
    /// - Parameter replaceAllMembership: When true, lifts not in the snapshot
    ///   become unassigned (library only). Used when a planned block replaces
    ///   the whole split — not a backup restore.
    @discardableResult
    static func applyDayPlanSnapshot(
        _ snapshot: [DayPlanBackup],
        context: ModelContext,
        replaceAllMembership: Bool = false
    ) -> Bool {
        guard !snapshot.isEmpty else { return false }
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        guard !exercises.isEmpty else { return false }
        let byID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        let snapshotDays = Set(snapshot.map { $0.dayName.lowercased() })

        var intended: [UUID: [DayType]] = [:]
        for plan in snapshot {
            let day = DayType(rawValue: plan.dayName)
            for (index, id) in plan.exerciseIDs.enumerated() {
                intended[id, default: []].append(day)
                byID[id]?.setSortIndex(index, for: day)
            }
        }

        var changed = false
        for exercise in exercises {
            let current = exercise.days
            let keepOutsideSnapshot = replaceAllMembership
                ? []
                : current.filter {
                    !snapshotDays.contains($0.rawValue.lowercased())
                }
            let snapshotMembership = intended[exercise.id] ?? []
            let next = snapshotMembership + keepOutsideSnapshot
            let currentNames = Set(current.map { $0.rawValue.lowercased() })
            let nextNames = Set(next.map { $0.rawValue.lowercased() })
            if currentNames != nextNames {
                exercise.setDayTypes(next)
                changed = true
            }
        }
        if changed {
            try? context.save()
        }
        return changed
    }

    @discardableResult
    static func reconcileDayPlansToSnapshot(context: ModelContext) -> Bool {
        guard let snapshot = loadDayPlanSnapshot(), !snapshot.isEmpty else { return false }
        return applyDayPlanSnapshot(snapshot, context: context)
    }

    /// Replace the local day list so it matches the saved snapshot (names + order).
    @discardableResult
    static func reconcileSplitToSnapshot(context: ModelContext) -> Bool {
        if let snapshot = loadSplitSnapshot(), !snapshot.isEmpty {
            return applySplitSnapshot(snapshot, context: context)
        }
        return stripSeedExtrasUsingPreset(context: context)
    }

    static func applySplitSnapshot(_ snapshot: [SplitDayBackup], context: ModelContext) -> Bool {
        let desired = snapshot.sorted { $0.sortOrder < $1.sortOrder }
        guard !desired.isEmpty else { return false }
        let existing = fetchSplitDays(context: context)
        var byName: [String: SplitDay] = [:]
        for row in existing {
            byName[row.name.lowercased()] = row
        }
        let wanted = Set(desired.map { $0.name.lowercased() })
        var changed = false

        for extra in existing where !wanted.contains(extra.name.lowercased()) {
            context.delete(extra)
            changed = true
        }

        for (index, snap) in desired.enumerated() {
            let key = snap.name.lowercased()
            if let row = byName[key] {
                if row.sortOrder != index
                    || row.systemImage != snap.systemImage
                    || row.subtitle != snap.subtitle
                    || row.colorHex != snap.colorHex
                    || row.includesAllExercises != snap.includesAllExercises
                    || row.name != snap.name
                {
                    row.name = snap.name
                    row.systemImage = snap.systemImage
                    row.subtitle = snap.subtitle
                    row.colorHex = snap.colorHex
                    row.includesAllExercises = snap.includesAllExercises
                    row.sortOrder = index
                    changed = true
                }
            } else {
                let day = SplitDay(
                    name: snap.name,
                    systemImage: snap.systemImage,
                    subtitle: snap.subtitle,
                    colorHex: UInt32(truncatingIfNeeded: snap.colorHex),
                    includesAllExercises: snap.includesAllExercises,
                    sortOrder: index
                )
                day.id = snap.id
                context.insert(day)
                changed = true
            }
        }

        if changed {
            try? context.save()
        }
        return changed
    }

    /// When KVS only knows the last preset, drop leftover bro-split days (Arms / Full Body)
    /// that CloudKit re-imported after a first-run seed.
    static func stripSeedExtrasUsingPreset(context: ModelContext) -> Bool {
        let raw = UserDefaults.standard.string(forKey: preferredSplitPresetKey) ?? ""
        guard let preset = SplitPreset(rawValue: raw), preset != .broSplit else { return false }
        let allowed = Set(preset.definitions.map { $0.name.lowercased() })
        let rows = fetchSplitDays(context: context)
        let names = Set(rows.map { $0.name.lowercased() })
        guard allowed.isSubset(of: names) else { return false }
        let extras = rows.filter { row in
            let key = row.name.lowercased()
            return !allowed.contains(key) && broSplitNameSet.contains(key)
        }
        guard !extras.isEmpty else { return false }
        extras.forEach { context.delete($0) }
        let remaining = fetchSplitDays(context: context)
        for (index, row) in remaining.enumerated() {
            row.sortOrder = index
        }
        try? context.save()
        persistSplitSnapshot(context: context)
        return true
    }

    /// Seeds day types only when the store is empty. Prefer the saved snapshot,
    /// then the last preset — never bro-split over a configured iCloud split.
    static func seedSplitDaysIfNeeded(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<SplitDay>())) ?? 0
        guard count == 0 else { return }

        if let snapshot = loadSplitSnapshot(), !snapshot.isEmpty {
            _ = applySplitSnapshot(snapshot, context: context)
            return
        }

        if UserDefaults.standard.bool(forKey: hasConfiguredSplitKey) {
            let raw = UserDefaults.standard.string(forKey: preferredSplitPresetKey) ?? ""
            if let preset = SplitPreset(rawValue: raw) {
                insertPresetDays(preset, context: context)
            }
            return
        }

        // Brand-new install: wait for the first-use picker. Do not invent Bro Split.
    }

    /// True when this phone has never chosen a split (first use, no iCloud snapshot).
    static func needsFirstUseSplitSetup(context: ModelContext) -> Bool {
        if UserDefaults.standard.bool(forKey: hasConfiguredSplitKey) { return false }
        if loadSplitSnapshot() != nil { return false }
        if loadDayPlanSnapshot() != nil { return false }
        let splitCount = (try? context.fetchCount(FetchDescriptor<SplitDay>())) ?? 0
        return splitCount == 0
    }

    private static let broSplitNameSet: Set<String> = ["arms", "legs", "full body"]

    private static func fetchSplitDays(context: ModelContext) -> [SplitDay] {
        (try? context.fetch(
            FetchDescriptor<SplitDay>(sortBy: [
                SortDescriptor(\SplitDay.sortOrder),
                SortDescriptor(\SplitDay.name),
            ])
        )) ?? []
    }

    private static func insertPresetDays(_ preset: SplitPreset, context: ModelContext) {
        for (index, def) in preset.definitions.enumerated() {
            let day = SplitDay(definition: def)
            day.sortOrder = index
            context.insert(day)
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

    /// (name, muscle group(s), default home day).
    /// `muscle` may be comma-separated for compounds: `"Chest, Triceps, Shoulders"`.
    /// Primary muscle is listed first (charts / section buckets use the primary).
    /// Home day is a starting tag only — users reassign freely.
    static let exerciseCatalog: [(name: String, muscle: String, day: DayType)] = {
        var items: [(String, String, DayType)] = []

        // MARK: Chest (Push)
        items += [
            ("Barbell Bench Press", "Chest, Triceps, Shoulders", .push),
            ("Incline Barbell Bench Press", "Chest, Triceps, Shoulders", .push),
            ("Decline Barbell Bench Press", "Chest, Triceps", .push),
            ("Dumbbell Bench Press", "Chest, Triceps, Shoulders", .push),
            ("Incline Dumbbell Press", "Chest, Triceps, Shoulders", .push),
            ("Decline Dumbbell Press", "Chest, Triceps", .push),
            ("Chest Press", "Chest, Triceps", .push),
            ("Machine Chest Press", "Chest, Triceps", .push),
            ("Pectoral Fly", "Chest", .push),
            ("Cable Fly", "Chest", .push),
            ("Pec Deck", "Chest", .push),
            ("Push-Up", "Chest, Triceps, Shoulders", .push),
            ("Dip (Chest)", "Chest, Triceps, Shoulders", .push),
        ]

        // MARK: Shoulders (Push)
        items += [
            ("Overhead Press", "Shoulders, Triceps", .push),
            ("Shoulder Press", "Shoulders, Triceps", .push),
            ("Seated Dumbbell Shoulder Press", "Shoulders, Triceps", .push),
            ("Arnold Press", "Shoulders, Triceps", .push),
            ("Lateral Raise", "Shoulders", .push),
            ("Cable Lateral Raise", "Shoulders", .push),
            ("Front Raise", "Shoulders", .push),
            ("Upright Row", "Shoulders, Traps", .push),
            ("Machine Shoulder Press", "Shoulders, Triceps", .push),
        ]

        // MARK: Triceps (Push)
        items += [
            ("Triceps Press", "Triceps", .push),
            ("Triceps Pushdown", "Triceps", .push),
            ("Overhead Triceps Extension", "Triceps", .push),
            ("Skull Crusher", "Triceps", .push),
            ("Close-Grip Bench Press", "Triceps, Chest", .push),
            ("Dip (Triceps)", "Triceps, Chest", .push),
            ("Kickback", "Triceps", .push),
        ]

        // MARK: Back — vertical / horizontal pull (Pull)
        items += [
            ("Pull-Up", "Back, Biceps", .pull),
            ("Chin-Up", "Back, Biceps", .pull),
            ("Lat Pulldown", "Back, Biceps", .pull),
            ("Wide-Grip Lat Pulldown", "Back, Biceps", .pull),
            ("Neutral-Grip Lat Pulldown", "Back, Biceps", .pull),
            ("Straight-Arm Pulldown", "Back", .pull),
            ("Seated Cable Row", "Back, Biceps", .pull),
            ("Chest-Supported Row", "Back, Biceps", .pull),
            ("Chest-Supported T-Bar Row", "Back, Biceps", .pull),
            ("Barbell Bent-Over Row", "Back, Biceps, Lower Back", .pull),
            ("Pendlay Row", "Back, Biceps, Lower Back", .pull),
            ("One-Arm Dumbbell Row", "Back, Biceps", .pull),
            ("Meadows Row", "Back, Biceps", .pull),
            ("Machine Row", "Back, Biceps", .pull),
            ("Inverted Row", "Back, Biceps", .pull),
            ("Face Pull", "Rear Delts, Traps", .pull),
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
            ("Barbell Back Squat", "Quads, Glutes, Lower Back", .legs),
            ("Front Squat", "Quads, Glutes, Core", .legs),
            ("Smith Machine Squat", "Quads, Glutes", .legs),
            ("Hack Squat", "Quads, Glutes", .legs),
            ("Pendulum Squat", "Quads, Glutes", .legs),
            ("Safety Bar Squat", "Quads, Glutes, Lower Back", .legs),
            ("Goblet Squat", "Quads, Glutes, Core", .legs),
            ("Leg Press", "Quads, Glutes", .legs),
            ("Seated Leg Press", "Quads, Glutes", .legs),
            ("Leg Extension", "Quads", .legs),
            ("Poliquin Step-Up", "Quads, Glutes", .legs),
            ("Bulgarian Split Squat", "Quads, Glutes", .legs),
            ("Walking Lunge", "Quads, Glutes", .legs),
            ("Reverse Lunge", "Quads, Glutes", .legs),
            ("Sissy Squat", "Quads", .legs),
            ("Belt Squat", "Quads, Glutes", .legs),
        ]

        // MARK: Hamstrings / posterior (Posterior Chain)
        items += [
            ("Conventional Deadlift", "Hamstrings, Glutes, Lower Back, Back", .posteriorChain),
            ("Sumo Deadlift", "Hamstrings, Glutes, Quads, Lower Back", .posteriorChain),
            ("Romanian Deadlift", "Hamstrings, Glutes, Lower Back", .posteriorChain),
            ("Stiff-Leg Deadlift", "Hamstrings, Glutes, Lower Back", .posteriorChain),
            ("Trap Bar Deadlift", "Quads, Hamstrings, Glutes, Lower Back", .posteriorChain),
            ("Single-Leg Romanian Deadlift", "Hamstrings, Glutes, Lower Back", .posteriorChain),
            ("Lying Hamstring Curl", "Hamstrings", .posteriorChain),
            ("Seated Hamstring Curl", "Hamstrings", .posteriorChain),
            ("Standing Hamstring Curl", "Hamstrings", .posteriorChain),
            ("Nordic Hamstring Curl", "Hamstrings", .posteriorChain),
            ("Seated Good Morning", "Hamstrings, Glutes, Lower Back", .posteriorChain),
            ("Standing Good Morning", "Hamstrings, Glutes, Lower Back", .posteriorChain),
            ("Back Extension", "Lower Back, Glutes, Hamstrings", .posteriorChain),
            ("45° Back Extension", "Lower Back, Glutes, Hamstrings", .posteriorChain),
            ("Reverse Hyper", "Glutes, Hamstrings, Lower Back", .posteriorChain),
            ("QL Extension", "Lower Back", .posteriorChain),
            ("Cable Pull-Through", "Glutes, Hamstrings", .posteriorChain),
            ("Hip Thrust", "Glutes, Hamstrings", .posteriorChain),
            ("Barbell Hip Thrust", "Glutes, Hamstrings", .posteriorChain),
            ("Glute Bridge", "Glutes, Hamstrings", .posteriorChain),
            ("Single-Leg Glute Bridge", "Glutes, Hamstrings", .posteriorChain),
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
            ("Farmer Carry", "Traps, Core, Forearms", .pull),
            ("Y-Raise", "Rear Delts, Shoulders", .pull),
            ("Prone Y-T-W", "Rear Delts, Shoulders", .pull),
        ]

        return items
    }()

    // MARK: - Starter day plans (3–5 lifts each)
    //
    // Full catalog still seeds into the **library** (unassigned). Only these short
    // templates land on each day so new users add/swap instead of deleting 15+.
    // Names must match `exerciseCatalog` exactly.

    /// Beginner-friendly templates (compound-first, common gym equipment).
    static let starterDayPlans: [String: [String]] = [
        // PPL / PPL+PC — Muscle&Strength / Hevy-style beginners
        "Push": [
            "Dumbbell Bench Press",
            "Overhead Press",
            "Lateral Raise",
            "Triceps Pushdown",
        ],
        "Pull": [
            "Lat Pulldown",
            "Seated Cable Row",
            "Face Pull",
            "Dumbbell Curl",
        ],
        "Legs": [
            "Goblet Squat",
            "Romanian Deadlift",
            "Leg Press",
            "Standing Calf Raise",
        ],
        // PPL + Posterior — hinge / glute focus day
        "Posterior Chain": [
            "Romanian Deadlift",
            "Hip Thrust",
            "Lying Hamstring Curl",
            "Back Extension",
        ],
        // Bro split (Arms / Legs / Full Body in preset)
        "Arms": [
            "Biceps Curl",
            "Triceps Pushdown",
            "Hammer Curl",
            "Lateral Raise",
        ],
        "Full Body": [
            "Goblet Squat",
            "Dumbbell Bench Press",
            "Seated Cable Row",
            "Overhead Press",
        ],
        // Upper / Lower
        "Upper": [
            "Dumbbell Bench Press",
            "Lat Pulldown",
            "Seated Cable Row",
            "Overhead Press",
            "Dumbbell Curl",
        ],
        "Lower": [
            "Goblet Squat",
            "Romanian Deadlift",
            "Leg Press",
            "Standing Calf Raise",
        ],
        // Orphan day names that may appear from older data
        "Chest": [
            "Dumbbell Bench Press",
            "Incline Dumbbell Press",
            "Cable Fly",
            "Triceps Pushdown",
        ],
        "Back": [
            "Lat Pulldown",
            "Seated Cable Row",
            "Face Pull",
            "Dumbbell Curl",
        ],
        "Shoulders": [
            "Overhead Press",
            "Lateral Raise",
            "Face Pull",
            "Rear Delt Fly",
        ],
    ]

    // MARK: - Seed / top-up

    /// - Parameter allowEmptyCatalogSeed: When false (iCloud still importing),
    ///   do not insert the full stock catalog into an empty store.
    static func seedIfNeeded(context: ModelContext, allowEmptyCatalogSeed: Bool = true) {
        seedSplitDaysIfNeeded(context: context)

        let hasSeeded = UserDefaults.standard.bool(forKey: hasSeededExercisesKey)
        let count = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0

        if !hasSeeded && count == 0 {
            // ContentView waits on CloudKit when a remote split/plan exists, then
            // calls here. allowEmptyCatalogSeed is the only empty-store skip —
            // do not also bail on a KVS snapshot, or a reinstall never gets a
            // catalog fallback. Starters stay off restored days (apply-preset only).
            guard allowEmptyCatalogSeed else { return }
            insertCatalogExercises(context: context, existingNames: [], assignCatalogDays: false)
            try? context.save()
            markCatalogSeeded()
            UserDefaults.standard.set(catalogVersion, forKey: catalogVersionKey)
            persistDayPlanSnapshot(context: context)
            return
        }

        // Existing install (or iCloud data): only add *new* catalog lifts on version bumps.
        // Never re-insert names the user deleted from the library.
        markCatalogSeeded()
        topUpCatalogIfNeeded(context: context)
        stripUnusedStarterExtrasIfNeeded(context: context)
    }

    static func markCatalogSeeded() {
        UserDefaults.standard.set(true, forKey: hasSeededExercisesKey)
    }

    /// Skip the unused-starter cleanup (restored backup or first-run templates).
    static func markDayPlansTrusted() {
        UserDefaults.standard.set(true, forKey: strippedUnusedStarterExtrasKey)
    }

    /// One-time repair: if a day already has the user's lifts, drop unused
    /// starter-template names that a reinstall / CloudKit merge pinned back on.
    static func stripUnusedStarterExtrasIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: strippedUnusedStarterExtrasKey) else { return }
        let changed = stripUnusedStarterExtras(context: context)
        UserDefaults.standard.set(true, forKey: strippedUnusedStarterExtrasKey)
        if changed {
            persistDayPlanSnapshot(context: context)
        }
    }

    /// Remove starter-template lifts that have no history from days that also
    /// contain at least one non-starter. Idempotent. Does not touch days that
    /// are only the starter template (true first-run).
    @discardableResult
    static func stripUnusedStarterExtras(context: ModelContext) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        guard !all.isEmpty else { return false }
        var changed = false
        for (dayName, starterNames) in starterDayPlans {
            let day = DayType(rawValue: dayName)
            let starterSet = Set(starterNames.map { $0.lowercased() })
            let onDay = all.filter { $0.belongs(to: day) }
            let nonStarter = onDay.filter { !starterSet.contains($0.name.lowercased()) }
            guard !nonStarter.isEmpty else { continue }
            for exercise in onDay {
                guard starterSet.contains(exercise.name.lowercased()) else { continue }
                guard !exercise.hasTrainingHistory() else { continue }
                exercise.removeDayType(day)
                changed = true
            }
        }
        if changed {
            try? context.save()
        }
        return changed
    }

    /// Pin 3–5 starter lifts onto each active split day.
    /// - Parameter onlyIfDayEmpty: When true, skip days that already have exercises
    ///   (preserves user plans). When false, still only adds missing starters (no wipe).
    static func applyStarterDayPlans(context: ModelContext, onlyIfDayEmpty: Bool = true) {
        let splitRows = (try? context.fetch(
            FetchDescriptor<SplitDay>(sortBy: [SortDescriptor(\SplitDay.sortOrder)])
        )) ?? []
        let dayNames = splitRows
            .filter { !$0.includesAllExercises }
            .map(\.name)

        let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var byName: [String: Exercise] = [:]
        for exercise in all {
            byName[exercise.name.lowercased()] = exercise
        }

        var changed = false
        for dayName in dayNames {
            let day = DayType(rawValue: dayName)
            let alreadyOnDay = all.filter { $0.belongs(to: day) }
            if onlyIfDayEmpty, !alreadyOnDay.isEmpty { continue }

            guard let plan = starterDayPlans[dayName], !plan.isEmpty else { continue }

            // Place starters at the start of the day list.
            for (index, exerciseName) in plan.enumerated() {
                guard let exercise = byName[exerciseName.lowercased()] else { continue }
                let wasOnDay = exercise.belongs(to: day)
                if !wasOnDay {
                    exercise.addDayType(day)
                    changed = true
                }
                let current = exercise.sortIndex(for: day)
                if current != index {
                    exercise.setSortIndex(index, for: day)
                    changed = true
                }
            }
        }

        if changed {
            try? context.save()
        }
    }

    /// Bump when the stock catalog gains new exercises so installs re-scan **once**.
    private static let catalogVersion = 2
    private static let catalogVersionKey = "exerciseCatalogVersion"

    /// Insert catalog lifts missing from the library **only when** the catalog version
    /// increased. If a user deletes a stock lift, it must not reappear on every launch.
    static func topUpCatalogIfNeeded(context: ModelContext) {
        let installedVersion = UserDefaults.standard.integer(forKey: catalogVersionKey)
        guard installedVersion < catalogVersion else { return }

        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let existingNames = Set(existing.map { $0.name.lowercased() })
        let missing = exerciseCatalog.filter { !existingNames.contains($0.name.lowercased()) }

        if !missing.isEmpty {
            let baseOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
            insertCatalogExercises(
                context: context,
                existingNames: existingNames,
                sortOrderBase: baseOrder,
                only: missing,
                assignCatalogDays: false
            )
            try? context.save()
        }
        UserDefaults.standard.set(catalogVersion, forKey: catalogVersionKey)
    }

    /// - Parameter assignCatalogDays: When true (legacy), tags every lift with its
    ///   catalog home day (huge day lists). Prefer false + `applyStarterDayPlans`.
    private static func insertCatalogExercises(
        context: ModelContext,
        existingNames: Set<String>,
        sortOrderBase: Int = 0,
        only: [(name: String, muscle: String, day: DayType)]? = nil,
        assignCatalogDays: Bool = false
    ) {
        let source = only ?? exerciseCatalog
        var order = sortOrderBase
        for item in source {
            if existingNames.contains(item.name.lowercased()) { continue }
            context.insert(
                Exercise(
                    name: item.name,
                    dayType: assignCatalogDays ? item.day : nil,
                    muscleGroup: item.muscle,
                    sortOrder: order,
                    isCustom: false
                )
            )
            order += 1
        }
    }
}
