//
//  ProgramDocument.swift
//  strength-training
//
//  rocklog.program v1 — a dated training block with target sets.
//  Import is a merge. This is not a backup and not a RockCoach file.
//

import Foundation

nonisolated enum ProgramFormat {
    static let formatName = "rocklog.program"
    static let schemaVersion = 1
    static let utTypeIdentifier = "com.lee.rocklog.program"
    static let pathExtension = "rocklogprogram"
}

nonisolated struct ProgramDocument: Codable, Hashable, Sendable {
    var format: String
    var schemaVersion: Int
    var exportedAt: Date
    var block: ProgramBlockPayload

    enum ProgramFormatError: LocalizedError {
        case wrongFormat(String)
        case unsupportedVersion(Int)
        case emptyBlock

        var errorDescription: String? {
            switch self {
            case .wrongFormat:
                return "This file is not a planned-workout file."
            case .unsupportedVersion:
                return "This planned-workout file is newer than this version of RockLog."
            case .emptyBlock:
                return "This file has no planned workouts to add."
            }
        }
    }
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
    private static let dayStamp: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = iso8601.date(from: raw) { return date }
            if let date = iso8601Fractional.date(from: raw) { return date }
            if let date = dayStamp.date(from: raw) { return date }
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
        let data = stripBOM(data)
        let doc = try decoder.decode(ProgramDocument.self, from: data)
        guard doc.format == ProgramFormat.formatName else {
            throw ProgramDocument.ProgramFormatError.wrongFormat(doc.format)
        }
        guard doc.schemaVersion == ProgramFormat.schemaVersion else {
            throw ProgramDocument.ProgramFormatError.unsupportedVersion(doc.schemaVersion)
        }
        guard !doc.block.sessions.isEmpty else {
            throw ProgramDocument.ProgramFormatError.emptyBlock
        }
        return doc
    }

    static func encode(_ document: ProgramDocument) throws -> Data {
        try encoder.encode(document)
    }

    static func peekFormat(_ data: Data) -> String? {
        struct FormatPeek: Decodable { var format: String? }
        return try? decoder.decode(FormatPeek.self, from: stripBOM(data)).format
    }

    private static func stripBOM(_ data: Data) -> Data {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return data.dropFirst(3)
        }
        return data
    }
}
