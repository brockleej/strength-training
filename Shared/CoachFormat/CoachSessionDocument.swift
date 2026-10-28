//
//  CoachSessionDocument.swift
//  Shared by RockLog (export) and RockCoach (import).
//

import Foundation

nonisolated enum CoachFormat {
    static let formatName = "rocklog.coach.session"
    static let batchFormatName = "rocklog.coach.batch"
    static let schemaVersion = 2
    static let minimumSchemaVersion = 1
    static let batchSchemaVersion = 2
    static let minimumBatchSchemaVersion = 1

    static func accepts(_ version: Int, current: Int = schemaVersion, minimum: Int = minimumSchemaVersion) -> Bool {
        version >= minimum && version <= current
    }
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
                return "RockCoach file version \(v) is not supported by this app."
            }
        }
    }
}

nonisolated struct CoachAthlete: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var displayName: String
    /// "lb" or "kg" on the phone that exported. Missing files are pounds.
    var weightUnit: String? = nil
}

nonisolated struct CoachSessionPayload: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var startedAt: Date
    var dayType: String
    var rotationTrack: String?
    var notes: String?
    var effortRating: Int?
    var exercises: [CoachExercisePayload]
    /// Gym the athlete trained in. Missing on files from before the gym selector.
    var gymID: UUID? = nil
    /// Name at export time. History can still show it after the gym row is gone.
    var gymName: String? = nil
    /// IANA zone of the phone that logged the session. Missing on older files.
    var timeZoneIdentifier: String? = nil
}

nonisolated struct CoachExercisePayload: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var muscleGroup: String?
    var trainingMode: String?
    var notes: String?
    var sets: [CoachSetPayload]
    var groupID: UUID? = nil
    var groupPosition: Int? = nil
    var restSeconds: Int? = nil
    /// Learned or typed stack step, in pounds, when the phone sent one.
    var stackStepPounds: Double? = nil
    /// Shared remainder, in pounds. Missing means there was no profile.
    var stackOffsetLbs: Double? = nil
    /// Explicit pins, converted to pounds. Missing means a step, or the 5 lb snap.
    var stackPinsLbs: [Double]? = nil
}

nonisolated struct CoachSetPayload: Codable, Hashable, Sendable {
    var setNumber: Int
    var weightLbs: Double
    var reps: Int
    var isWarmup: Bool?
    var isEachSide: Bool?
    var isAssisted: Bool?
    var completedAt: Date?
    /// "bar", "assist", or "added". Missing means bar, or assist when `isAssisted` is true.
    var loadMode: String? = nil
    /// Body weight used that day, in pounds. Required for a fair assist / added comparison.
    var bodyWeightLbs: Double? = nil
    /// Unit of `enteredValue` when the phone stored the original entry.
    var enteredUnit: String? = nil
    var enteredValue: Double? = nil

    var resolvedWarmup: Bool { isWarmup ?? false }

    /// Effective load. Less assistance is a heavier load. Missing body weight contributes nothing for assist and added.
    var effectiveLoadLbs: Double {
        let mode = loadMode ?? (resolvedAssisted ? "assist" : "bar")
        let body = bodyWeightLbs ?? 0
        switch mode {
        case "assist":
            guard body > 0 else { return 0 }
            return max(0, body - weightLbs)
        case "added":
            guard body > 0 else { return 0 }
            return max(0, body + weightLbs)
        default:
            return max(0, weightLbs)
        }
    }
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
        guard CoachFormat.accepts(doc.schemaVersion) else {
            throw CoachSessionDocument.CoachFormatError.unsupportedVersion(doc.schemaVersion)
        }
        return doc
    }

    static func decodeBatch(_ data: Data) throws -> CoachBatchDocument {
        let doc = try decoder.decode(CoachBatchDocument.self, from: data)
        guard doc.format == CoachFormat.batchFormatName else {
            throw CoachSessionDocument.CoachFormatError.wrongFormat(doc.format)
        }
        guard CoachFormat.accepts(doc.schemaVersion, current: CoachFormat.batchSchemaVersion, minimum: CoachFormat.minimumBatchSchemaVersion) else {
            throw CoachSessionDocument.CoachFormatError.unsupportedVersion(doc.schemaVersion)
        }
        guard doc.sessions.count >= 2 else {
            throw CoachSessionDocument.CoachFormatError.wrongFormat(doc.format)
        }
        return doc
    }

    static func decodeFile(_ data: Data) throws -> CoachFile {
        let data = try legacyBytes(stripBOM(data))
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

    /// Interchange coach files unwrap to the legacy document. Older files pass through.
    static func legacyBytes(_ data: Data) throws -> Data {
        guard InterchangeCodec.isInterchange(data) else { return data }
        let kind = try InterchangeCodec.kind(of: data)
        guard kind == .coachSession || kind == .coachBatch else {
            throw CoachSessionDocument.CoachFormatError.wrongFormat(kind.rawValue)
        }
        return try InterchangeCodec.downgradeToLegacy(data)
    }

    static func interchangeData(for document: CoachSessionDocument) throws -> Data {
        try interchangeEnvelope(encode(document), kind: .coachSession, exportedAt: document.exportedAt)
    }

    static func interchangeData(for document: CoachBatchDocument) throws -> Data {
        try interchangeEnvelope(encode(document), kind: .coachBatch, exportedAt: document.exportedAt)
    }

    private static func interchangeEnvelope(_ payload: Data, kind: InterchangeKind, exportedAt: Date) throws -> Data {
        let object = try InterchangeCodec.parseObject(payload)
        let stamp = ISO8601DateFormatter().string(from: exportedAt)
        return try InterchangeCodec.encode(InterchangeCodec.wrap(kind: kind, payload: object, exportedAt: stamp))
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
