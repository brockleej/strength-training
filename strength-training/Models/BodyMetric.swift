//
//  BodyMetric.swift
//  strength-training
//
//  Home body-shape measurements for trends and muscularity (Navy BF% → FFMI).
//

import Foundation
import SwiftData

/// Metric kinds loggable at home. Values stored in lb (weight) or inches (girths).
enum BodyMetricKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case weight
    case waist
    case neck
    case chest
    case arm          // flexed upper arm (pick a consistent side)
    case hips         // needed for Navy BF% in female formula

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: "Weight"
        case .waist: "Waist"
        case .neck: "Neck"
        case .chest: "Chest"
        case .arm: "Arm (flexed)"
        case .hips: "Hips"
        }
    }

    /// Display title with sex-specific labeling for Navy girth sites.
    func title(for sex: BiologicalSex) -> String {
        switch self {
        case .waist:
            // Male Navy uses abdomen at navel; female uses natural (narrowest) waist.
            return sex == .male ? "Waist (male)" : "Waist (female)"
        case .hips:
            return "Hips (female)"
        default:
            return title
        }
    }

    /// Short badge for sex-specific metrics (nil = unisex).
    func sexLabel(for sex: BiologicalSex) -> String? {
        switch self {
        case .waist: return sex == .male ? "Male" : "Female"
        case .hips: return "Female"
        default: return nil
        }
    }

    var unitLabel: String {
        switch self {
        case .weight: "lb"
        default: "in"
        }
    }

    var systemImage: String {
        switch self {
        case .weight: "scalemass.fill"
        case .waist: "circle.dashed"
        case .neck: "person.crop.circle"
        case .chest: "figure.arms.open"
        case .arm: "figure.strengthtraining.traditional"
        case .hips: "figure.stand"
        }
    }

    /// One-line how-to so the same landmarks are used every check-in (sex-aware for waist/hips).
    func howTo(for sex: BiologicalSex) -> String {
        switch self {
        case .weight:
            "Morning, after the bathroom, before food or drink; same scale and light clothes each time."
        case .waist:
            switch sex {
            case .male:
                // US Navy male: abdomen circumference at navel.
                "Male: level tape at the navel (abdomen), standing relaxed—don’t suck in; snug but not digging in."
            case .female:
                // US Navy female: natural waist (narrowest).
                "Female: level tape at the natural waist (narrowest point), relaxed—don’t suck in; snug but not digging in."
            }
        case .neck:
            "Level tape just below the larynx (Adam’s apple), looking straight ahead; don’t flex the neck."
        case .chest:
            "Level tape at the fullest part of the chest, arms relaxed; read at the end of a normal exhale."
        case .arm:
            "Flex and tape the largest part of the upper arm; always use the same arm."
        case .hips:
            "Female: level tape at the fullest part of the hips/buttocks, feet together; snug but not compressing."
        }
    }

    /// Metrics shown in logging UI for the selected sex (hips only for female Navy formula).
    static func primary(for sex: BiologicalSex) -> [BodyMetricKind] {
        switch sex {
        case .male:
            // Navy male: weight + waist + neck. Chest/arm are optional trends. No hips.
            [.weight, .waist, .neck, .chest, .arm]
        case .female:
            // Navy female: weight + waist + hips + neck. Chest/arm optional.
            [.weight, .waist, .hips, .neck, .chest, .arm]
        }
    }

    /// Whether this metric is required for the Navy formula at the given sex.
    func isRequiredForIndex(sex: BiologicalSex) -> Bool {
        BodyMetricKind.requiredForIndex(sex: sex).contains(self)
    }

    static func requiredForIndex(sex: BiologicalSex) -> Set<BodyMetricKind> {
        switch sex {
        case .male: navyMaleRequired
        case .female: navyFemaleRequired
        }
    }

    /// Shared accuracy disclaimer for body-fat / muscularity estimates.
    static let accuracyDisclaimer =
        "Body fat % and FFMI are estimates from a tape-and-scale formula (US Navy method). Results can differ from DEXA, Bod Pod, or smart scales by several points—use them for trends, not diagnosis. Not medical advice."

    /// Required for Navy men: weight + waist + neck (+ height/sex in settings).
    static var navyMaleRequired: Set<BodyMetricKind> { [.weight, .waist, .neck] }

    /// Required for Navy women: weight + waist + hips + neck.
    static var navyFemaleRequired: Set<BodyMetricKind> { [.weight, .waist, .hips, .neck] }
}

@Model
final class BodyMetricEntry {
    var id: UUID = UUID()
    var date: Date = Date.now
    /// `BodyMetricKind.rawValue`
    var kindRaw: String = BodyMetricKind.weight.rawValue
    /// Weight in lb, girths in inches.
    var value: Double = 0
    var note: String = ""

    var kind: BodyMetricKind {
        get { BodyMetricKind(rawValue: kindRaw) ?? .weight }
        set { kindRaw = newValue.rawValue }
    }

    init(kind: BodyMetricKind, value: Double, date: Date = .now, note: String = "") {
        self.id = UUID()
        self.date = date
        self.kindRaw = kind.rawValue
        self.value = value
        self.note = note
    }
}
