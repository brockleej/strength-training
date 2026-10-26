//
//  BackupMigration.swift
//  Shared by RockLog and its tests.
//
//  Backup payload version 2 is the file this build writes. Version 1 still
//  opens. Version 0 and anything newer than 2 are refused. The step from 1
//  to 2 does not invent rows and does not drop keys.
//

import Foundation

nonisolated enum BackupMigrationError: Error, Equatable {
    case malformed
    case unsupportedVersion(Int)
}

nonisolated enum BackupMigration {
    static let minimumVersion = 1
    static let currentVersion = 2

    /// Pure v1 → v2. A v2 object is returned unchanged. Unknown keys stay.
    /// Missing gyms, blocks, and measurements stay missing.
    static func promoteToCurrent(_ object: [String: JSONValue]) throws -> [String: JSONValue] {
        guard let number = object["version"]?.number, number.isFinite, number == number.rounded() else {
            throw BackupMigrationError.malformed
        }
        let version = Int(number)
        if version < minimumVersion || version > currentVersion {
            throw BackupMigrationError.unsupportedVersion(version)
        }
        guard version < currentVersion else { return object }
        var copy = object
        copy["version"] = .number(Double(currentVersion))
        return copy
    }
}

/// Keys and enum strings this build did not declare. Counted so a restore
/// can say what it left behind. The count is the whole set; the path list
/// is capped so a huge file cannot fill the prompt.
nonisolated struct BackupInspection: Equatable, Sendable {
    var unknownKeyCount: Int
    var unknownKeyPaths: [String]
    var unknownEnumCount: Int
    var unknownEnums: [String]

    static let empty = BackupInspection(
        unknownKeyCount: 0,
        unknownKeyPaths: [],
        unknownEnumCount: 0,
        unknownEnums: []
    )

    static func inspect(_ object: [String: JSONValue]) -> BackupInspection {
        let found = InspectionBox()
        walk(object, known: rootKeys, path: "", found: found) { key, value, path in
            switch key {
            case "exercises":
                walkEach(value, path: path, known: exerciseKeys, found: found) { item, itemPath in
                    noteEnum(item["loadModeRaw"], allowed: loadModes, path: "\(itemPath).loadModeRaw", found: found)
                }
            case "sessions":
                walkEach(value, path: path, known: sessionKeys, found: found) { session, sessionPath in
                    walkEach(session["exerciseRecords"] ?? .null, path: "\(sessionPath).exerciseRecords", known: recordKeys, found: found) { record, recordPath in
                        noteEnum(record["trainingMode"], allowed: trainingModes, path: "\(recordPath).trainingMode", found: found, allowEmpty: false)
                        walkEach(record["sets"] ?? .null, path: "\(recordPath).sets", known: setKeys, found: found) { set, setPath in
                            noteEnum(set["loadModeRaw"], allowed: loadModes, path: "\(setPath).loadModeRaw", found: found)
                        }
                    }
                }
            case "splitDays":
                walkEach(value, path: path, known: splitDayKeys, found: found) { _, _ in }
            case "dayPlans":
                walkEach(value, path: path, known: dayPlanKeys, found: found) { _, _ in }
            case "trainingBlocks":
                walkEach(value, path: path, known: blockKeys, found: found) { _, _ in }
            case "bodyMetrics":
                walkEach(value, path: path, known: metricKeys, found: found) { metric, metricPath in
                    noteEnum(metric["kindRaw"], allowed: metricKinds, path: "\(metricPath).kindRaw", found: found, allowEmpty: false)
                }
            case "gyms":
                walkEach(value, path: path, known: gymKeys, found: found) { _, _ in }
            case "stackProfiles":
                walkEach(value, path: path, known: stackKeys, found: found) { profile, profilePath in
                    noteEnum(profile["pinUnitRaw"], allowed: pinUnits, path: "\(profilePath).pinUnitRaw", found: found, allowEmpty: false)
                    noteEnum(profile["policyRaw"], allowed: policies, path: "\(profilePath).policyRaw", found: found, allowEmpty: false)
                    noteEnum(profile["originRaw"], allowed: origins, path: "\(profilePath).originRaw", found: found)
                }
            default:
                break
            }
        }
        return found.value
    }

    var summarySentence: String? {
        var parts: [String] = []
        if unknownKeyCount > 0 {
            let noun = unknownKeyCount == 1 ? "field" : "fields"
            parts.append("\(unknownKeyCount) \(noun) this version does not use")
        }
        if unknownEnumCount > 0 {
            let noun = unknownEnumCount == 1 ? "value" : "values"
            parts.append("\(unknownEnumCount) \(noun) this version does not know")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " and ") + " and will be reported, not applied."
    }
}

private nonisolated let pathCap = 12

private nonisolated let rootKeys: Set<String> = [
    "version", "exportedAt", "exercises", "sessions", "splitDays", "dayPlans",
    "trainingBlocks", "bodyMetrics", "gyms", "stackProfiles",
]
private nonisolated let exerciseKeys: Set<String> = [
    "id", "name", "dayType", "muscleGroup", "sortOrder", "isCustom", "notes",
    "rotationTrack", "extraDayTypes", "daySortOrdersRaw", "defaultRestSeconds",
    "autoRestEnabled", "loadModeRaw", "suggestWarmupRamp",
]
private nonisolated let sessionKeys: Set<String> = [
    "id", "date", "dayType", "notes", "isCompleted", "exerciseRecords",
    "rotationTrack", "durationSeconds", "planState", "followsSessionRoster", "planOrder",
    "gymID", "gymName",
]
private nonisolated let recordKeys: Set<String> = [
    "id", "exerciseID", "trainingMode", "sortOrder", "isCompleted", "notes", "sets",
    "groupID", "groupPosition",
]
private nonisolated let setKeys: Set<String> = [
    "id", "setNumber", "weightLbs", "reps", "isWarmup", "isEachSide", "isAssisted",
    "completedAt", "isTarget", "offeredWeightLbs", "loadModeRaw", "bodyWeightUsedLbs",
    "plannedRestSeconds", "actualRestSeconds",
]
private nonisolated let splitDayKeys: Set<String> = [
    "id", "name", "systemImage", "subtitle", "colorHex", "includesAllExercises", "sortOrder",
]
private nonisolated let dayPlanKeys: Set<String> = ["dayName", "exerciseIDs"]
private nonisolated let blockKeys: Set<String> = ["id", "name", "notes", "startDate", "importedAt", "sessionIDs"]
private nonisolated let metricKeys: Set<String> = ["id", "date", "kindRaw", "value", "note"]
private nonisolated let gymKeys: Set<String> = [
    "id", "name", "isHome", "createdAt", "sortOrder", "latitude", "longitude", "radiusMeters",
]
private nonisolated let stackKeys: Set<String> = [
    "id", "gymID", "exerciseID", "stepPounds", "offsetPounds", "pinsRaw", "pinUnitRaw", "addOnsRaw",
    "policyRaw", "originRaw", "learnedSessionIDsRaw", "clearedAt", "learningEnabled",
    "rangeMin", "rangeMax", "updatedAt",
]

private nonisolated let loadModes: Set<String> = ["bar", "assist", "added"]
private nonisolated let trainingModes: Set<String> = ["Endurance", "Strength"]
private nonisolated let metricKinds: Set<String> = ["weight", "waist", "neck", "chest", "arm", "hips"]
private nonisolated let pinUnits: Set<String> = ["lb", "kg"]
private nonisolated let policies: Set<String> = ["nearest", "down", "up"]
private nonisolated let origins: Set<String> = ["learned", "typed"]

/// One place the walk can record into. A struct passed `inout` cannot also
/// be written from the nested closures; those two accesses overlap.
private nonisolated final class InspectionBox {
    var value = BackupInspection.empty
}

private nonisolated func walk(
    _ object: [String: JSONValue],
    known: Set<String>,
    path: String,
    found: InspectionBox,
    nested: (String, JSONValue, String) -> Void
) {
    for key in object.keys.sorted() {
        let child = path.isEmpty ? key : "\(path).\(key)"
        guard known.contains(key) else {
            rememberKey(child, found: found)
            continue
        }
        if let value = object[key] {
            nested(key, value, child)
        }
    }
}

private nonisolated func walkEach(
    _ value: JSONValue,
    path: String,
    known: Set<String>,
    found: InspectionBox,
    nested: ([String: JSONValue], String) -> Void
) {
    guard case .array(let items) = value else { return }
    for (index, item) in items.enumerated() {
        guard let object = item.object else { continue }
        let itemPath = "\(path)[\(index)]"
        walk(object, known: known, path: itemPath, found: found) { _, _, _ in }
        nested(object, itemPath)
    }
}

private nonisolated func noteEnum(
    _ value: JSONValue?,
    allowed: Set<String>,
    path: String,
    found: InspectionBox,
    allowEmpty: Bool = true
) {
    guard case .string(let raw) = value else { return }
    if raw.isEmpty, allowEmpty { return }
    guard !allowed.contains(raw) else { return }
    var next = found.value
    next.unknownEnumCount += 1
    if next.unknownEnums.count < pathCap {
        next.unknownEnums.append("\(path)=\(raw)")
    }
    found.value = next
}

private nonisolated func rememberKey(_ path: String, found: InspectionBox) {
    var next = found.value
    next.unknownKeyCount += 1
    if next.unknownKeyPaths.count < pathCap {
        next.unknownKeyPaths.append(path)
    }
    found.value = next
}
