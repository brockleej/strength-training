//
//  CoachInbox.swift
//  Shared by RockCoach and the share extension.
//  Incoming files are copied immediately — Messages URLs expire.
//

import Foundation

enum CoachInbox {
    static let appGroupID = "group.com.lee.rockcoach"
    static let folderName = "Incoming"
    static let hostURL = URL(string: "rockcoach://inbox")!

    static var directory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(folderName, isDirectory: true)
    }

    static func readData(from url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        var coordinatorError: NSError?
        var data: Data?
        var readError: Error?
        NSFileCoordinator().coordinate(
            readingItemAt: url,
            options: [.withoutChanges],
            error: &coordinatorError
        ) { coordinated in
            do {
                data = try Data(contentsOf: coordinated, options: [.mappedIfSafe])
            } catch {
                readError = error
            }
        }
        if let data, !data.isEmpty { return unwrapIfFileURL(data) }
        if let fallback = try? Data(contentsOf: url), !fallback.isEmpty {
            return unwrapIfFileURL(fallback)
        }
        if let coordinatorError { throw coordinatorError }
        if let readError { throw readError }
        throw CocoaError(.fileReadUnknown)
    }

    /// Messages sometimes hands us a tiny file whose contents are another file URL.
    private static func unwrapIfFileURL(_ data: Data) -> Data {
        guard data.count < 2048,
              let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              let nested = URL(string: text),
              nested.isFileURL,
              let inner = try? Data(contentsOf: nested),
              !inner.isEmpty
        else { return data }
        return inner
    }

    @discardableResult
    static func stage(_ url: URL) throws -> URL {
        let data = try readData(from: url)
        let ext = url.pathExtension.isEmpty ? CoachFormat.pathExtension : url.pathExtension
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).\(ext)")
        try data.write(to: dest, options: .atomic)
        return dest
    }

    static func saveData(_ data: Data, suggestedName: String = "session.rocklogcoach") throws {
        let payload = unwrapIfFileURL(data)
        guard let directory else {
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedName)
            try payload.write(to: dest, options: .atomic)
            return
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let dest = directory.appendingPathComponent(suggestedName)
        try payload.write(to: dest, options: .atomic)
    }

    static func saveIncoming(_ url: URL) throws {
        let data = try readData(from: url)
        let name = url.lastPathComponent.isEmpty
            ? "\(UUID().uuidString).\(CoachFormat.pathExtension)"
            : url.lastPathComponent
        try saveData(data, suggestedName: name)
    }

    static func pendingURLs() -> [URL] {
        var urls: [URL] = []
        if let directory,
           FileManager.default.fileExists(atPath: directory.path),
           let files = try? FileManager.default.contentsOfDirectory(
               at: directory,
               includingPropertiesForKeys: nil
           ) {
            urls.append(contentsOf: files.filter { !$0.lastPathComponent.hasPrefix(".") })
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if let inbox = docs?.appendingPathComponent("Inbox", isDirectory: true),
           let files = try? FileManager.default.contentsOfDirectory(
               at: inbox,
               includingPropertiesForKeys: nil
           ) {
            urls.append(contentsOf: files.filter { !$0.lastPathComponent.hasPrefix(".") })
        }
        return urls
    }

    static func consume(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
