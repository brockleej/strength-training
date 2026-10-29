//
//  CoachAthletePreferences.swift
//  Display name + stable athlete id for RockCoach files.
//  UserDefaults only — iCloud KVS synchronize() can stall the UI thread.
//

import Foundation

enum CoachAthletePreferences {
    nonisolated static let nameKey = "coachAthleteDisplayName"
    nonisolated static let idKey = "coachAthleteID"
    nonisolated static let enabledKey = "coachFeaturesEnabled"
    nonisolated static let shareAfterFinishKey = "coachShareAfterFinish"
    nonisolated static let defaultDisplayName = "Athlete"

    nonisolated static var displayName: String {
        get {
            let stored = AppDefaults.local.string(forKey: nameKey) ?? ""
            let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? defaultDisplayName : trimmed
        }
        set {
            AppDefaults.local.set(
                newValue.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: nameKey
            )
        }
    }

    /// Raw field for Settings — empty means the default label is used on export.
    nonisolated static var displayNameDraft: String {
        get { AppDefaults.local.string(forKey: nameKey) ?? "" }
        set { AppDefaults.local.set(newValue, forKey: nameKey) }
    }

    nonisolated static var athleteID: UUID {
        if let raw = AppDefaults.local.string(forKey: idKey), let id = UUID(uuidString: raw) {
            return id
        }
        let id = UUID()
        AppDefaults.local.set(id.uuidString, forKey: idKey)
        return id
    }

    /// Master switch. Off hides send controls and auto-send.
    nonisolated static var isEnabled: Bool {
        get { AppDefaults.local.bool(forKey: enabledKey) }
        set { AppDefaults.local.set(newValue, forKey: enabledKey) }
    }

    nonisolated static var shareAfterFinish: Bool {
        get { AppDefaults.local.bool(forKey: shareAfterFinishKey) }
        set { AppDefaults.local.set(newValue, forKey: shareAfterFinishKey) }
    }

    nonisolated static var shouldOfferAfterFinish: Bool {
        isEnabled && shareAfterFinish
    }

    nonisolated static var athlete: CoachAthlete {
        CoachAthlete(id: athleteID, displayName: displayName)
    }
}
