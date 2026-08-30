//
//  IncomingRockLogFile.swift
//  strength-training
//
//  Peek a JSON file from Files / a share sheet: planned workouts vs backup.
//

import Foundation

enum IncomingRockLogFile {
    case program(ProgramDocument)
    case backup(Data)

    enum IncomingFileError: LocalizedError {
        case unrecognized

        var errorDescription: String? {
            "This file isn’t a planned-workout file or a RockLog backup."
        }
    }

    static func parse(_ data: Data) throws -> IncomingRockLogFile {
        let format = ProgramCodec.peekFormat(data)
        if format == ProgramFormat.formatName {
            return .program(try ProgramCodec.decode(data))
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
