//
//  ProgramDocument.swift
//  RockLog
//
//  rocklog.program v1 — an ordered training block with target sets.
//  File order is the queue. Import is a merge. Not a backup / RockCoach file.
//

import Foundation

nonisolated enum ProgramFormat {
    static let formatName = "rocklog.program"
    static let splitFormatName = "rocklog.split"
    static let schemaVersion = 1
    /// Oldest file this build still reads. Newer builds keep accepting this range.
    static let minimumSchemaVersion = 1

    static func accepts(
        _ version: Int,
        current: Int = schemaVersion,
        minimum: Int = minimumSchemaVersion
    ) -> Bool {
        version >= minimum && version <= current
    }
    static let utTypeIdentifier = "com.lee.rocklog.program"
    static let pathExtension = "rocklogprogram"
}

nonisolated struct ProgramDocument: Codable, Hashable, Sendable {
    var format: String
    var schemaVersion: Int
    var exportedAt: Date
    /// "lb" or "kg". Missing means the set numbers are pounds.
    var weightUnit: String? = nil
    var block: ProgramBlockPayload

    enum ProgramFormatError: LocalizedError {
        case wrongFormat(String)
        case unsupportedVersion(Int)
        case emptyBlock
        case fileTooLarge
        case weightOutOfRange
        case repsOutOfRange

        var errorDescription: String? {
            switch self {
            case .wrongFormat:
                return "This file is not a planned-workout file."
            case .unsupportedVersion(let version):
                if version > ProgramFormat.schemaVersion {
                    return "Planned-workout version \(version) is newer than this RockLog (reads \(ProgramFormat.minimumSchemaVersion)–\(ProgramFormat.schemaVersion)). Update RockLog, or ask for a file saved as version \(ProgramFormat.schemaVersion)."
                }
                return "Planned-workout version \(version) is not a version this RockLog reads (\(ProgramFormat.minimumSchemaVersion)–\(ProgramFormat.schemaVersion))."
            case .emptyBlock:
                return "This file has no planned workouts to add."
            case .fileTooLarge:
                return "This file is too large to import."
            case .weightOutOfRange:
                return "A set weight must be between 0 and 10000 lb."
            case .repsOutOfRange:
                return "A set’s reps must be between 0 and 100."
            }
        }
    }
}

nonisolated enum ProgramLimits {
    static let maxFileBytes = 5_000_000
    static let minWeightLbs = 0.0
    static let maxWeightLbs = 10_000.0
    static let minReps = 0
    static let maxReps = 100
}

nonisolated struct ProgramBlockPayload: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var notes: String?
    var startDate: Date
    var sessions: [ProgramSessionPayload]
}

nonisolated struct ProgramSessionPayload: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var date: Date
    var dayType: String
    var rotationTrack: String?
    var notes: String?
    var exercises: [ProgramExercisePayload]
}

nonisolated struct ProgramExercisePayload: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var muscleGroup: String?
    var trainingMode: String?
    var notes: String?
    var sets: [ProgramSetPayload]
}

nonisolated struct ProgramSetPayload: Codable, Hashable, Sendable {
    var setNumber: Int
    var weightLbs: Double
    var reps: Int
    var isWarmup: Bool?
    var isEachSide: Bool?
    var isAssisted: Bool?

    var resolvedWarmup: Bool { isWarmup ?? false }
    var resolvedEachSide: Bool { isEachSide ?? false }
    var resolvedAssisted: Bool { isAssisted ?? false }
}

nonisolated enum ProgramCodec {
    private static let iso8601 = ISO8601DateFormatter()
    private static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    /// `yyyy-MM-dd` is a calendar day in the phone’s time zone, not UTC midnight.
    private static func dateFromPlainDay(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = iso8601.date(from: raw) { return date }
            if let date = iso8601Fractional.date(from: raw) { return date }
            if let date = dateFromPlainDay(raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date \(raw)"
            )
        }
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static func decode(_ data: Data) throws -> ProgramDocument {
        guard data.count <= ProgramLimits.maxFileBytes else {
            throw ProgramDocument.ProgramFormatError.fileTooLarge
        }
        let data = try legacyProgramData(stripBOM(data))
        let doc = try decoder.decode(ProgramDocument.self, from: data)
        guard doc.format == ProgramFormat.formatName
            || doc.format == ProgramFormat.splitFormatName
        else {
            throw ProgramDocument.ProgramFormatError.wrongFormat(doc.format)
        }
        guard ProgramFormat.accepts(doc.schemaVersion) else {
            throw ProgramDocument.ProgramFormatError.unsupportedVersion(doc.schemaVersion)
        }
        guard !doc.block.sessions.isEmpty else {
            throw ProgramDocument.ProgramFormatError.emptyBlock
        }
        try validateValues(doc)
        return doc
    }

    /// Weight and rep bounds. Call this before any store delete.
    static func validateValues(_ document: ProgramDocument) throws {
        for session in document.block.sessions {
            for exercise in session.exercises {
                for set in exercise.sets {
                    guard set.weightLbs.isFinite,
                          set.weightLbs >= ProgramLimits.minWeightLbs,
                          set.weightLbs <= ProgramLimits.maxWeightLbs
                    else {
                        throw ProgramDocument.ProgramFormatError.weightOutOfRange
                    }
                    guard set.reps >= ProgramLimits.minReps, set.reps <= ProgramLimits.maxReps else {
                        throw ProgramDocument.ProgramFormatError.repsOutOfRange
                    }
                }
            }
        }
    }

    static func encode(_ document: ProgramDocument) throws -> Data {
        try encoder.encode(document)
    }

    static func peekFormat(_ data: Data) -> String? {
        struct FormatPeek: Decodable { var format: String? }
        return try? decoder.decode(FormatPeek.self, from: stripBOM(data)).format
    }

    static func legacyProgramData(_ data: Data) throws -> Data {
        guard InterchangeCodec.isInterchange(data) else { return data }
        let kind = try InterchangeCodec.kind(of: data)
        guard kind == .program || kind == .split else {
            throw ProgramDocument.ProgramFormatError.wrongFormat(kind.rawValue)
        }
        return try InterchangeCodec.downgradeToLegacy(data)
    }

    private static func stripBOM(_ data: Data) -> Data {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return data.dropFirst(3)
        }
        return data
    }
}
