//
//  DayTypeRegistry.swift
//  strength-training
//
//  In-memory catalog of the user's active split. Reloaded from SplitDay
//  rows on launch and whenever Settings edits the split.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class DayTypeRegistry {
    static let shared = DayTypeRegistry()

    /// Active split definitions, sorted by sortOrder then name.
    private(set) var definitions: [DayTypeDefinition] = SplitPreset.broSplit.definitions

    private var byName: [String: DayTypeDefinition] = [:]

    private init() {
        reindex()
    }

    // MARK: - Queries

    var activeDays: [DayType] {
        definitions.map(\.asDayType)
    }

    var exerciseHomeDays: [DayType] {
        definitions.filter { !$0.includesAllExercises }.map(\.asDayType)
    }

    var defaultSelection: DayType {
        exerciseHomeDays.first ?? activeDays.first ?? .arms
    }

    func definition(for name: String) -> DayTypeDefinition {
        byName[name] ?? DayTypePalette.fallback(for: name)
    }

    func resolve(_ name: String) -> DayType {
        DayType(rawValue: name)
    }

    func contains(_ name: String) -> Bool {
        byName[name] != nil
    }

    // MARK: - Load / seed

    /// Load SplitDay rows (or seed the bro-split default) and refresh the catalog.
    func reload(context: ModelContext) {
        SeedData.seedSplitDaysIfNeeded(context: context)
        SeedData.migrateDayTypeIcons(context: context)
        let descriptor = FetchDescriptor<SplitDay>(
            sortBy: [SortDescriptor(\SplitDay.sortOrder), SortDescriptor(\SplitDay.name)]
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        if rows.isEmpty {
            definitions = SplitPreset.broSplit.definitions
        } else {
            definitions = rows.map(\.definition)
        }
        reindex()
    }

    /// Replace all SplitDay rows with a preset and reload.
    func applyPreset(_ preset: SplitPreset, context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<SplitDay>())) ?? []
        existing.forEach { context.delete($0) }
        // Sequential sortOrder = list order on Today (user can drag to change).
        for (index, def) in preset.definitions.enumerated() {
            let day = SplitDay(definition: def)
            day.sortOrder = index
            context.insert(day)
        }
        try? context.save()
        reload(context: context)
    }

    /// Ensure every day-type name seen in exercises/sessions has a SplitDay
    /// (used after backup restore so historical names keep styling).
    func ensureDaysExist(names: Set<String>, context: ModelContext) {
        guard !names.isEmpty else { return }
        let existing = Set(((try? context.fetch(FetchDescriptor<SplitDay>())) ?? []).map(\.name))
        var nextOrder = (((try? context.fetch(FetchDescriptor<SplitDay>())) ?? []).map(\.sortOrder).max() ?? -1) + 1
        var inserted = false
        for name in names.sorted() where !existing.contains(name) {
            let def = DayTypePalette.fallback(for: name)
            let day = SplitDay(
                name: def.name,
                systemImage: def.systemImage,
                subtitle: def.subtitle,
                colorHex: def.colorHex,
                includesAllExercises: def.includesAllExercises,
                sortOrder: nextOrder
            )
            context.insert(day)
            nextOrder += 1
            inserted = true
        }
        if inserted {
            try? context.save()
            reload(context: context)
        }
    }

    /// Insert or update a single custom day, then reload.
    func upsert(
        id: UUID?,
        name: String,
        systemImage: String,
        subtitle: String,
        colorHex: UInt32,
        includesAllExercises: Bool,
        context: ModelContext
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let id,
           let existing = ((try? context.fetch(FetchDescriptor<SplitDay>())) ?? []).first(where: { $0.id == id }) {
            let oldName = existing.name
            existing.name = trimmed
            existing.systemImage = systemImage
            existing.subtitle = subtitle
            existing.colorHex = Int(colorHex)
            existing.includesAllExercises = includesAllExercises
            if oldName != trimmed {
                renameDayType(from: oldName, to: trimmed, context: context)
            }
        } else {
            let order = ((((try? context.fetch(FetchDescriptor<SplitDay>())) ?? []).map(\.sortOrder).max()) ?? -1) + 1
            context.insert(
                SplitDay(
                    name: trimmed,
                    systemImage: systemImage,
                    subtitle: subtitle,
                    colorHex: colorHex,
                    includesAllExercises: includesAllExercises,
                    sortOrder: order
                )
            )
        }
        try? context.save()
        reload(context: context)
    }

    func delete(id: UUID, context: ModelContext) {
        let rows = (try? context.fetch(FetchDescriptor<SplitDay>())) ?? []
        guard let row = rows.first(where: { $0.id == id }) else { return }
        // Keep at least one non-catch-all day so the app stays usable.
        let homes = rows.filter { !$0.includesAllExercises }
        if !row.includesAllExercises && homes.count <= 1 { return }
        context.delete(row)
        try? context.save()
        reload(context: context)
    }

    func move(from source: IndexSet, to destination: Int, context: ModelContext) {
        var rows = ((try? context.fetch(
            FetchDescriptor<SplitDay>(sortBy: [
                SortDescriptor(\SplitDay.sortOrder),
                SortDescriptor(\SplitDay.name),
            ])
        )) ?? [])
        rows.move(fromOffsets: source, toOffset: destination)
        for (index, row) in rows.enumerated() {
            row.sortOrder = index
        }
        try? context.save()
        reload(context: context)
    }

    /// Persist order from a long-press-drag list (same pattern as day-plan exercises).
    func applyOrder(ids: [UUID], context: ModelContext) {
        let rows = (try? context.fetch(FetchDescriptor<SplitDay>())) ?? []
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        for (index, id) in ids.enumerated() {
            byID[id]?.sortOrder = index
        }
        try? context.save()
        reload(context: context)
    }

    // MARK: - Private

    private func reindex() {
        byName = Dictionary(uniqueKeysWithValues: definitions.map { ($0.name, $0) })
    }

    private func renameDayType(from old: String, to new: String, context: ModelContext) {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        for exercise in exercises {
            let names = exercise.dayTypeNames.map { $0 == old ? new : $0 }
            if names != exercise.dayTypeNames {
                exercise.setDayTypes(names.map { DayType(rawValue: $0) })
            }
        }
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        for session in sessions where session.dayType == old {
            session.dayType = new
        }
    }
}
