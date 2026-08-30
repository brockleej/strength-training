//
//  ProgramUTType.swift
//  strength-training
//

internal import UniformTypeIdentifiers

extension UTType {
    static var rockLogProgram: UTType {
        UTType(filenameExtension: ProgramFormat.pathExtension)
            ?? UTType(exportedAs: ProgramFormat.utTypeIdentifier)
    }
}
