//
//  RecentFilesStore.swift
//  ProgressionLab
//

import Foundation

/// Persists recently-opened dataset URLs as app-scoped security bookmarks
/// in UserDefaults so the loader screen can offer one-click reopening.
struct RecentFilesStore {
    static let maxEntries = 5
    private static let defaultsKey = "ProgressionLab.recentFiles.bookmarks.v1"

    /// Load the bookmarks and resolve them to URLs. Stale or unresolvable
    /// bookmarks are silently dropped.
    static func load() -> [URL] {
        guard let bookmarksData = UserDefaults.standard.array(forKey: defaultsKey) as? [Data] else {
            return []
        }
        var resolved: [URL] = []
        for bookmark in bookmarksData {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmark,
                    options: [.withSecurityScope],
                    bookmarkDataIsStale: &isStale
                )
                if !isStale {
                    resolved.append(url)
                }
            } catch {
                continue
            }
        }
        return resolved
    }

    /// Add `url` to the front of the recents list. The caller must already have
    /// security-scoped access to `url`.
    static func remember(_ url: URL) {
        guard let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }

        var existing = (UserDefaults.standard.array(forKey: defaultsKey) as? [Data]) ?? []
        existing.removeAll { existingData in
            var isStale = false
            return (try? URL(
                resolvingBookmarkData: existingData,
                options: [.withSecurityScope],
                bookmarkDataIsStale: &isStale
            )) == url
        }
        existing.insert(bookmarkData, at: 0)
        if existing.count > maxEntries {
            existing = Array(existing.prefix(maxEntries))
        }
        UserDefaults.standard.set(existing, forKey: defaultsKey)
    }
}
