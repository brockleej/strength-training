//
//  InterchangeCodec.swift
//  Shared by RockLog and RockCoach.
//
//  One JSON envelope for backups, coach files, and program / split files.
//  Older files migrate forward. The envelope migrates backward to those
//  shapes. Unknown keys are kept on the object and written back out.
//

import Foundation

nonisolated enum InterchangeFormat {
    static let name = "rocklog.interchange"
    static let currentVersion = 1
    /// A compatible next stamp. Stepping up or down does not drop keys.
    static let walkableVersion = 2
    static let weightUnitKey = "weightUnit"
    static let canonicalUnit = "lb"
}

nonisolated enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    var object: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    var string: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var number: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    var int: Int? {
        guard let number else { return nil }
        return Int(number)
    }

    subscript(key: String) -> JSONValue? {
        object?[key]
    }
}

nonisolated enum InterchangeKind: String, Codable, Sendable {
    case backup
    case coachSession = "coach.session"
    case coachBatch = "coach.batch"
    case program
    case split
}

nonisolated struct InterchangeIssue: Equatable, Sendable {
    var path: String
    var message: String
}

nonisolated enum InterchangeError: Error, Equatable {
    case malformed
    case unsupportedVersion(Int)
    case wrongKind
    case invalid(InterchangeIssue)
}

nonisolated enum InterchangeCodec {
    static func isInterchange(_ data: Data) -> Bool {
        guard let object = try? parseObject(data) else { return false }
        return object["format"]?.string == InterchangeFormat.name
    }

    static func parseObject(_ data: Data) throws -> [String: JSONValue] {
        let cleaned = stripBOM(data)
        let raw = try JSONSerialization.jsonObject(with: cleaned, options: [.fragmentsAllowed])
        guard let object = JSONValue.from(raw).object else { throw InterchangeError.malformed }
        return object
    }

    /// Forward migration into the version RockLog writes.
    static func toLatest(_ data: Data) throws -> [String: JSONValue] {
        var object = try parseObject(data)
        try migrate(&object, to: InterchangeFormat.currentVersion)
        return object
    }

    /// Move an envelope or a legacy file to `version` (1 or 2).
    static func migrate(_ object: inout [String: JSONValue], to version: Int) throws {
        guard version == InterchangeFormat.currentVersion || version == InterchangeFormat.walkableVersion else {
            throw InterchangeError.unsupportedVersion(version)
        }
        if object["format"]?.string != InterchangeFormat.name {
            object = liftLegacy(object)
        }
        guard let versionNumber = object["formatVersion"]?.number,
              versionNumber.isFinite,
              versionNumber == versionNumber.rounded()
        else {
            throw InterchangeError.unsupportedVersion(object["formatVersion"]?.int ?? -1)
        }
        var current = Int(versionNumber)
        if current < 1 || current > InterchangeFormat.walkableVersion {
            throw InterchangeError.unsupportedVersion(current)
        }
        while current < version {
            current = stepUp(&object, from: current)
        }
        while current > version {
            current = stepDown(&object, from: current)
        }
    }

    static func encode(_ object: [String: JSONValue]) throws -> Data {
        let raw = object.mapValues { $0.foundation }
        return try JSONSerialization.data(
            withJSONObject: raw,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    static func wrap(kind: InterchangeKind, payload: [String: JSONValue], exportedAt: String) -> [String: JSONValue] {
        [
            "format": .string(InterchangeFormat.name),
            "formatVersion": .number(Double(InterchangeFormat.currentVersion)),
            "weightUnit": .string(InterchangeFormat.canonicalUnit),
            "exportedAt": .string(exportedAt),
            "kind": .string(kind.rawValue),
            "payload": .object(payload),
        ]
    }

    /// Bytes a legacy decoder already understands. Unknown envelope keys stay
    /// out of the legacy body; unknown keys inside the payload stay in it.
    static func downgradeToLegacy(_ data: Data) throws -> Data {
        let latest = try toLatest(data)
        guard let payload = latest["payload"]?.object else { throw InterchangeError.malformed }
        return try encode(payload)
    }

    static func kind(of data: Data) throws -> InterchangeKind {
        let latest = try toLatest(data)
        guard let raw = latest["kind"]?.string, let kind = InterchangeKind(rawValue: raw) else {
            throw InterchangeError.wrongKind
        }
        return kind
    }

    static func validate(_ object: [String: JSONValue]) -> [InterchangeIssue] {
        var issues: [InterchangeIssue] = []
        if object["format"]?.string != InterchangeFormat.name {
            issues.append(InterchangeIssue(path: "format", message: "Expected \(InterchangeFormat.name)."))
        }
        let version = object["formatVersion"]?.int ?? -1
        if version != 1 && version != 2 {
            issues.append(InterchangeIssue(path: "formatVersion", message: "formatVersion must be 1 or 2."))
        }
        let unit = object["weightUnit"]?.string ?? ""
        if unit != "lb" && unit != "kg" {
            issues.append(InterchangeIssue(path: "weightUnit", message: "weightUnit must be lb or kg. Numbers stay pounds."))
        }
        if object["kind"]?.string.flatMap(InterchangeKind.init(rawValue:)) == nil {
            issues.append(InterchangeIssue(path: "kind", message: "kind is not a known document."))
        }
        guard let payload = object["payload"]?.object else {
            issues.append(InterchangeIssue(path: "payload", message: "payload must be an object."))
            return issues
        }
        walk(.object(payload), path: "payload", issues: &issues)
        return issues
    }

    // MARK: - Legacy lift

    static func liftLegacy(_ object: [String: JSONValue]) -> [String: JSONValue] {
        let kind = detectKind(object)
        let exported = object["exportedAt"]?.string ?? ISO8601DateFormatter().string(from: Date())
        var envelope = wrap(kind: kind, payload: object, exportedAt: exported)
        // Keep keys the legacy file had that are not the payload itself.
        // The whole legacy object is the payload, so there is nothing else to copy.
        if let unit = object["weightUnit"]?.string {
            envelope["weightUnit"] = .string(unit)
        }
        return envelope
    }

    static func detectKind(_ object: [String: JSONValue]) -> InterchangeKind {
        switch object["format"]?.string {
        case CoachFormat.formatName: return .coachSession
        case CoachFormat.batchFormatName: return .coachBatch
        case "rocklog.program": return .program
        case "rocklog.split": return .split
        default:
            if object["version"] != nil && object["exercises"] != nil { return .backup }
            return .backup
        }
    }

    // MARK: - Version walk

    /// v1 → v2 copies `weightUnit` into `unitSystem` and leaves every other key.
    private static func stepUp(_ object: inout [String: JSONValue], from version: Int) -> Int {
        if version == 1 {
            if object["unitSystem"] == nil {
                object["unitSystem"] = object["weightUnit"] ?? .string(InterchangeFormat.canonicalUnit)
            }
            object["formatVersion"] = .number(2)
            return 2
        }
        object["formatVersion"] = .number(Double(version + 1))
        return version + 1
    }

    /// v2 → v1 keeps `unitSystem` (an unknown key to a v1 reader) and restores
    /// `weightUnit` when the newer file only had the alias.
    private static func stepDown(_ object: inout [String: JSONValue], from version: Int) -> Int {
        if version == 2 {
            if object["weightUnit"] == nil, let alias = object["unitSystem"] {
                object["weightUnit"] = alias
            }
            object["formatVersion"] = .number(1)
            return 1
        }
        object["formatVersion"] = .number(Double(max(1, version - 1)))
        return max(1, version - 1)
    }

    // MARK: - Validation walk

    private static func walk(_ value: JSONValue, path: String, issues: inout [InterchangeIssue]) {
        switch value {
        case .object(let object):
            for (key, child) in object {
                let childPath = "\(path).\(key)"
                if key == "id" || key.hasSuffix("ID") || key.hasSuffix("Id") {
                    if case .string(let raw) = child, UUID(uuidString: raw) == nil {
                        issues.append(InterchangeIssue(path: childPath, message: "Expected a UUID."))
                    }
                }
                if key == "weightLbs" || key == "bodyWeightLbs" || key == "offeredWeightLbs" {
                    if case .number(let number) = child {
                        if !number.isFinite || number < 0 || number > 10_000 {
                            issues.append(InterchangeIssue(
                                path: childPath,
                                message: "Weight must be a finite number from 0 through 10000 lb."
                            ))
                        }
                    }
                }
                walk(child, path: childPath, issues: &issues)
            }
        case .array(let values):
            for (index, child) in values.enumerated() {
                walk(child, path: "\(path)[\(index)]", issues: &issues)
            }
        default:
            break
        }
    }

    private static func stripBOM(_ data: Data) -> Data {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { return data.dropFirst(3) }
        return data
    }
}

nonisolated extension JSONValue {
    static func from(_ any: Any) -> JSONValue {
        switch any {
        case is NSNull:
            return .null
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            return .number(number.doubleValue)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            return .array(array.map { from($0) })
        case let object as [String: Any]:
            return .object(object.mapValues { from($0) })
        default:
            return .null
        }
    }

    var foundation: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let value): return value
        case .number(let value): return value
        case .string(let value): return value
        case .array(let values): return values.map(\.foundation)
        case .object(let object): return object.mapValues { $0.foundation }
        }
    }
}
