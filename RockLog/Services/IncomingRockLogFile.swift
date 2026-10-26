//
//  IncomingRockLogFile.swift
//  RockLog
//
//  Peek a JSON file from Files / a share sheet: planned workouts vs backup.
//

import Foundation

enum IncomingRockLogFile {
    case program(ProgramDocument)
    case split(ProgramDocument)
    case backup(Data)

    enum IncomingFileError: LocalizedError {
        case unrecognized

        var errorDescription: String? {
            "This file isn’t a planned-workout file, a training split, or a RockLog backup."
        }
    }

    static func parse(_ data: Data) throws -> IncomingRockLogFile {
        if InterchangeCodec.isInterchange(data) {
            switch try InterchangeCodec.kind(of: data) {
            case .program:
                return .program(try ProgramCodec.decode(data))
            case .split:
                return .split(try ProgramCodec.decode(data))
            case .backup:
                return .backup(data)
            case .coachSession, .coachBatch:
                throw IncomingFileError.unrecognized
            }
        }
        let format = ProgramCodec.peekFormat(data)
        if format == ProgramFormat.formatName {
            return .program(try ProgramCodec.decode(data))
        }
        if format == ProgramFormat.splitFormatName {
            return .split(try ProgramCodec.decode(data))
        }
        if format == CoachFormat.formatName || format == CoachFormat.batchFormatName {
            throw IncomingFileError.unrecognized
        }
        do {
            _ = try BackupService.decode(data)
            return .backup(data)
        } catch {
            throw IncomingFileError.unrecognized
        }
    }
}
