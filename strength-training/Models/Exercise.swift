//
//  Exercise.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    /// Primary home day name (e.g. "Push"), or "" if unassigned to any day.
    var dayType: String = ""
    /// Extra home days beyond `dayType`, comma-separated (e.g. "Pull,Legs").
    var extraDayTypes: String = ""
    var muscleGroup: String = ""
    var sortOrder: Int = 0
    var isCustom: Bool = false
    var notes: String = ""
    /// A/B week label: "" = every week, "A" or "B" = only that rotation.
    var rotationTrack: String = ""
    /// Per-day list order: "Push:0,Legs:3". Falls back to `sortOrder` when missing.
    var daySortOrdersRaw: String = ""

    @Relationship(deleteRule: .cascade, inverse: \ExerciseRecord.exercise)
    var records: [ExerciseRecord]?

    var recordsArray: [ExerciseRecord] { records ?? [] }

    // MARK: - History helpers

    /// Most recent completed session record for this exercise in the given mode.
    func lastCompletedRecord(mode: TrainingMode) -> ExerciseRecord? {
        recordsArray
            .filter { $0.trainingMode == mode && $0.session?.isCompleted == true }
            .max { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }
    }

    /// Completed records for mode, newest-first (excludes incomplete sessions).
    func completedRecords(mode: TrainingMode) -> [ExerciseRecord] {
        recordsArray
            .filter { $0.trainingMode == mode && $0.session?.isCompleted == true }
            .sorted { ($0.session?.date ?? .distantPast) > ($1.session?.date ?? .distantPast) }
    }

    // MARK: - Per-day order

    func sortIndex(for day: DayType) -> Int {
        let map = Self.parseDaySortMap(daySortOrdersRaw)
        return map[day.rawValue] ?? sortOrder
    }

    func setSortIndex(_ index: Int, for day: DayType) {
        var map = Self.parseDaySortMap(daySortOrdersRaw)
        map[day.rawValue] = index
        daySortOrdersRaw = Self.encodeDaySortMap(map)
        if day.rawValue == dayType {
            sortOrder = index
        }
    }

    static func applyOrder(_ exercises: [Exercise], for day: DayType) {
        for (index, exercise) in exercises.enumerated() {
            exercise.setSortIndex(index, for: day)
        }
    }

    private static func parseDaySortMap(_ raw: String) -> [String: Int] {
        var map: [String: Int] = [:]
        for part in raw.split(separator: ",") {
            let bits = part.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard bits.count == 2, let value = Int(bits[1]), !bits[0].isEmpty else { continue }
            map[bits[0]] = value
        }
        return map
    }

    private static func encodeDaySortMap(_ map: [String: Int]) -> String {
        map.keys.sorted().compactMap { key in
            guard let value = map[key] else { return nil }
            return "\(key):\(value)"
        }
        .joined(separator: ",")
    }

    // MARK: - Day membership

    /// True when this lift is not on any day plan.
    var isUnassigned: Bool { dayTypeNames.isEmpty }

    /// All home day names, primary first, then extras (deduped). Empty = library only.
    var dayTypeNames: [String] {
        var names: [String] = []
        let primary = dayType.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty { names.append(primary) }
        for part in extraDayTypes.split(separator: ",") {
            let name = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, !names.contains(name) {
                names.append(name)
            }
        }
        return names
    }

    /// Primary day for chips; unassigned uses a neutral fallback label.
    var day: DayType {
        if let first = dayTypeNames.first {
            return DayType(rawValue: first)
        }
        return DayType.unassigned
    }

    var days: [DayType] {
        dayTypeNames.map { DayType(rawValue: $0) }
    }

    func belongs(to day: DayType) -> Bool {
        guard !day.rawValue.isEmpty else { return isUnassigned }
        return dayTypeNames.contains(day.rawValue)
    }

    /// Replace membership. Empty array = not on any day plan (library only).
    func setDayTypes(_ days: [DayType]) {
        let unique = days.reduce(into: [DayType]()) { result, day in
            guard !day.rawValue.isEmpty else { return }
            if !result.contains(where: { $0.rawValue == day.rawValue }) {
                result.append(day)
            }
        }
        if unique.isEmpty {
            dayType = ""
            extraDayTypes = ""
            daySortOrdersRaw = ""
            return
        }
        dayType = unique[0].rawValue
        extraDayTypes = unique.dropFirst().map(\.rawValue).joined(separator: ",")
        // Drop sort keys for days no longer assigned.
        let keep = Set(unique.map(\.rawValue))
        var map = Self.parseDaySortMap(daySortOrdersRaw)
        map = map.filter { keep.contains($0.key) }
        daySortOrdersRaw = Self.encodeDaySortMap(map)
    }

    func addDayType(_ day: DayType) {
        guard !day.rawValue.isEmpty else { return }
        var current = days
        if !current.contains(where: { $0.rawValue == day.rawValue }) {
            current.append(day)
            setDayTypes(current)
        }
    }

    /// Pin to a day and place at the end of that day's list when newly added.
    func addDayType(_ day: DayType, atEndOf peers: [Exercise]) {
        let already = belongs(to: day)
        addDayType(day)
        if !already {
            let maxIndex = peers
                .filter { $0.id != id && $0.belongs(to: day) }
                .map { $0.sortIndex(for: day) }
                .max() ?? -1
            setSortIndex(maxIndex + 1, for: day)
        }
    }

    /// Remove from a day. If it was the last day, the exercise becomes unassigned
    /// (still in the library, not on any workout plan).
    func removeDayType(_ day: DayType) {
        let remaining = days.filter { $0.rawValue != day.rawValue }
        setDayTypes(remaining)
        var map = Self.parseDaySortMap(daySortOrdersRaw)
        map.removeValue(forKey: day.rawValue)
        daySortOrdersRaw = Self.encodeDaySortMap(map)
    }

    var track: RotationTrack {
        get { RotationTrack(storage: rotationTrack) }
        set { rotationTrack = newValue.rawValue }
    }

    init(
        name: String,
        dayType: DayType? = nil,
        muscleGroup: String = "",
        sortOrder: Int = 0,
        isCustom: Bool = false,
        rotationTrack: RotationTrack = .every,
        additionalDayTypes: [DayType] = []
    ) {
        self.id = UUID()
        self.name = name
        let primary = dayType?.rawValue ?? ""
        self.dayType = primary
        self.extraDayTypes = additionalDayTypes
            .map(\.rawValue)
            .filter { !$0.isEmpty && $0 != primary }
            .joined(separator: ",")
        self.muscleGroup = muscleGroup
        self.sortOrder = sortOrder
        self.isCustom = isCustom
        self.notes = ""
        self.rotationTrack = rotationTrack.rawValue
        self.daySortOrdersRaw = ""
        self.records = []
    }
}
