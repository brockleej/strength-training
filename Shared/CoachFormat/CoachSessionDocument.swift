//
//  CoachSessionDocument.swift
//  Shared by RockLog (export) and RockCoach (import).
//

import Foundation

nonisolated enum CoachFormat {
    static let formatName = "rocklog.coach.session"
    static let batchFormatName = "rocklog.coach.batch"
    static let schemaVersion = 1
    static let batchSchemaVersion = 1
    static let utTypeIdentifier = "com.lee.rocklog.coach.session"
    static let pathExtension = "rocklogcoach"
}

/// A .rocklogcoach file is either one session (v1) or a catch-up batch.
nonisolated enum CoachFile: Equatable {
    case session(CoachSessionDocument)
    case batch(CoachBatchDocument)

    var athlete: CoachAthlete {
        switch self {
        case .session(let doc): doc.athlete
        case .batch(let doc): doc.athlete
        }
    }

    var sessionDocuments: [CoachSessionDocument] {
        switch self {
        case .session(let doc): [doc]
        case .batch(let doc): doc.sessionDocuments
        }
    }
}

nonisolated struct CoachBatchDocument: Codable, Hashable, Sendable {
    var format: String
    var schemaVersion: Int
    var exportedAt: Date
    var athlete: CoachAthlete
    var sessions: [CoachSessionPayload]

    var sessionDocuments: [CoachSessionDocument] {
        sessions.map { payload in
            CoachSessionDocument(
                format: CoachFormat.formatName,
                schemaVersion: CoachFormat.schemaVersion,
                exportedAt: exportedAt,
                athlete: athlete,
                session: payload
            )
        }
    }
}

nonisolated struct CoachSessionDocument: Codable, Hashable, Identifiable, Sendable {
    var format: String
    var schemaVersion: Int
    var exportedAt: Date
    var athlete: CoachAthlete
    var session: CoachSessionPayload

    var id: UUID { session.id }

    enum CoachFormatError: LocalizedError {
        case wrongFormat(String)
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .wrongFormat(let name):
                return "Not a RockCoach file (format \(name))."
            case .unsupportedVersion(let v):
                return "RockCoach file version \(v) is newer than this app."
            }
        }
    }
}

nonisolated struct CoachAthlete: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var displayName: String
}

nonisolated struct CoachSessionPayload: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var startedAt: Date
    var dayType: String
    var rotationTrack: String?
    var notes: String?
    var effortRating: Int?
    var exercises: [CoachExercisePayload]
}

nonisolated struct CoachExercisePayload: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var muscleGroup: String?
    var trainingMode: String?
    var notes: String?
    var sets: [CoachSetPayload]
}

nonisolated struct CoachSetPayload: Codable, Hashable, Sendable {
    var setNumber: Int
    var weightLbs: Double
    var reps: Int
    var isWarmup: Bool?
    var isEachSide: Bool?
    var isAssisted: Bool?
    var completedAt: Date?

    var resolvedWarmup: Bool { isWarmup ?? false }
    var resolvedEachSide: Bool { isEachSide ?? false }
    var resolvedAssisted: Bool { isAssisted ?? false }
}

nonisolated enum CoachSessionCodec {
    private static let iso8601 = ISO8601DateFormatter()
    private static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = iso8601.date(from: raw) { return date }
            if let date = iso8601Fractional.date(from: raw) { return date }
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

    static func decode(_ data: Data) throws -> CoachSessionDocument {
        let doc = try decoder.decode(CoachSessionDocument.self, from: data)
        guard doc.format == CoachFormat.formatName else {
            throw CoachSessionDocument.CoachFormatError.wrongFormat(doc.format)
        }
        guard doc.schemaVersion == CoachFormat.schemaVersion else {
            throw CoachSessionDocument.CoachFormatError.unsupportedVersion(doc.schemaVersion)
        }
        return doc
    }

    static func decodeBatch(_ data: Data) throws -> CoachBatchDocument {
        let doc = try decoder.decode(CoachBatchDocument.self, from: data)
        guard doc.format == CoachFormat.batchFormatName else {
            throw CoachSessionDocument.CoachFormatError.wrongFormat(doc.format)
        }
        guard doc.schemaVersion == CoachFormat.batchSchemaVersion else {
            throw CoachSessionDocument.CoachFormatError.unsupportedVersion(doc.schemaVersion)
        }
        guard doc.sessions.count >= 2 else {
            throw CoachSessionDocument.CoachFormatError.wrongFormat(doc.format)
        }
        return doc
    }

    static func decodeFile(_ data: Data) throws -> CoachFile {
        let data = stripBOM(data)
        let peek = try decoder.decode(FormatPeek.self, from: data)
        switch peek.format {
        case CoachFormat.formatName:
            return .session(try decode(data))
        case CoachFormat.batchFormatName:
            return .batch(try decodeBatch(data))
        default:
            throw CoachSessionDocument.CoachFormatError.wrongFormat(peek.format)
        }
    }

    static func encode(_ document: CoachSessionDocument) throws -> Data {
        try encoder.encode(document)
    }

    static func encode(_ document: CoachBatchDocument) throws -> Data {
        try encoder.encode(document)
    }

    static func suggestedFilename(for document: CoachSessionDocument) -> String {
        let day = document.session.dayType
            .replacingOccurrences(of: " ", with: "-")
        let stamp = document.session.startedAt.formatted(
            Date.ISO8601FormatStyle().year().month().day()
        )
        let name = sanitized(document.athlete.displayName)
        return "\(name)-\(day)-\(stamp).\(CoachFormat.pathExtension)"
    }

    static func suggestedFilename(for document: CoachBatchDocument) -> String {
        let stamp = document.exportedAt.formatted(
            Date.ISO8601FormatStyle().year().month().day()
        )
        let name = sanitized(document.athlete.displayName)
        return "\(name)-\(document.sessions.count)-sessions-\(stamp).\(CoachFormat.pathExtension)"
    }

    private static func sanitized(_ name: String) -> String {
        name.replacingOccurrences(of: " ", with: "-")
    }

    private static func stripBOM(_ data: Data) -> Data {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return data.dropFirst(3)
        }
        return data
    }

    private struct FormatPeek: Decodable {
        var format: String
    }
}
