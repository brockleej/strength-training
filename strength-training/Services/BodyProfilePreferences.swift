//
//  BodyProfilePreferences.swift
//  strength-training
//
//  Height + sex for Navy body-fat / FFMI. Weight is stored as BodyMetricEntry
//  and mirrored to BodyWeightPreferences for assisted lifts.
//

import Foundation

enum BiologicalSex: String, CaseIterable, Identifiable {
    case male
    case female

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        }
    }
}

enum BodyProfilePreferences {
    static let heightInchesKey = "bodyHeightInches"
    static let sexKey = "bodyBiologicalSex"

    /// Standing height in inches. 0 = not set.
    static var heightInches: Double {
        get {
            let v = UserDefaults.standard.double(forKey: heightInchesKey)
            return v > 0 ? v : 0
        }
        set {
            if newValue > 0 {
                UserDefaults.standard.set(newValue, forKey: heightInchesKey)
            } else {
                UserDefaults.standard.removeObject(forKey: heightInchesKey)
            }
        }
    }

    static var sex: BiologicalSex {
        get {
            BiologicalSex(rawValue: UserDefaults.standard.string(forKey: sexKey) ?? "") ?? .male
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: sexKey)
        }
    }

    static var hasHeight: Bool { heightInches > 0 }

    static func formatHeight(_ inches: Double = heightInches) -> String {
        guard inches > 0 else { return "—" }
        let total = Int(inches.rounded())
        let feet = total / 12
        let rem = total % 12
        return "\(feet)′\(rem)\""
    }
}
