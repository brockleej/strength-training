//
//  DayType.swift
//  strength-training
//
//  Freeform day-type identity. The *name* is what Exercise / WorkoutSession
//  store; color, icon, and subtitle come from DayTypeRegistry (backed by the
//  user's SplitDay configuration).
//

import Foundation
import SwiftUI

/// A training-day identity. Equality and hashing are by `rawValue` (name) only,
/// so "Arms" from history matches the live Arms split day even if styling changes.
struct DayType: Hashable, Identifiable, Codable, Sendable, Comparable {
    let rawValue: String

    var id: String { rawValue }
    var name: String { rawValue }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ name: String) {
        self.rawValue = name
    }

    // MARK: Well-known names (presets + defaults)

    static let arms = DayType("Arms")
    static let legs = DayType("Legs")
    static let fullBody = DayType("Full Body")
    static let push = DayType("Push")
    static let pull = DayType("Pull")
    static let posteriorChain = DayType("Posterior Chain")
    static let upper = DayType("Upper")
    static let lower = DayType("Lower")
    /// Library-only lift — not on any day plan.
    static let unassigned = DayType("Unassigned")

    // MARK: Resolved presentation (from registry)

    private var definition: DayTypeDefinition {
        DayTypeRegistry.shared.definition(for: rawValue)
    }

    var systemImage: String { definition.systemImage }
    var subtitle: String { definition.subtitle }
    var colorHex: UInt32 { definition.colorHex }
    var includesAllExercises: Bool { definition.includesAllExercises }
    var sortOrder: Int { definition.sortOrder }

    var upliftInk: Color { Color(hex: colorHex) }
    var upliftWash: Color { Color(hex: colorHex, opacity: 0.14) }

    /// Legacy SwiftUI `Color` used in a few call sites before the design system.
    var color: Color { upliftInk }

    // MARK: Active split (user-configured)

    /// Days in the user's current split, sorted.
    static var allCases: [DayType] {
        DayTypeRegistry.shared.activeDays
    }

    /// Days that own exercises (excludes "Full Body"-style catch-alls).
    static var exerciseHomeDays: [DayType] {
        DayTypeRegistry.shared.exerciseHomeDays
    }

    static var defaultSelection: DayType {
        DayTypeRegistry.shared.defaultSelection
    }

    // MARK: Comparable

    static func < (lhs: DayType, rhs: DayType) -> Bool {
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        return lhs.rawValue.localizedCaseInsensitiveCompare(rhs.rawValue) == .orderedAscending
    }
}

// MARK: - Definition (metadata)

struct DayTypeDefinition: Hashable, Sendable {
    var name: String
    var systemImage: String
    var subtitle: String
    var colorHex: UInt32
    var includesAllExercises: Bool
    var sortOrder: Int

    var asDayType: DayType { DayType(rawValue: name) }
}

// MARK: - Palette helpers

enum DayTypePalette {
    /// Rotating ink colors for custom / preset days.
    static let inks: [UInt32] = [
        0xFF4D88, // pink — Arms
        0x3F9CFF, // blue — Legs
        0xB569FF, // purple — Full Body / Posterior
        0xFF8C42, // orange — Push
        0x34C759, // green
        0x5AB8F5, // ice
        0xFFB547, // amber
        0xFF6B6B, // coral
    ]

    static func ink(at index: Int) -> UInt32 {
        inks[index % inks.count]
    }

    static func fallback(for name: String) -> DayTypeDefinition {
        if name.isEmpty || name == "Unassigned" {
            return DayTypeDefinition(
                name: "Unassigned",
                systemImage: "tray",
                subtitle: "Not on a day plan",
                colorHex: 0x8E8E93,
                includesAllExercises: false,
                sortOrder: 9_999
            )
        }
        if let known = knownDefaults[name] { return known }
        // Stable color from name hash so unknown historical names still look ok.
        let hash = abs(name.utf8.reduce(0) { ($0 &* 31) &+ Int($1) })
        return DayTypeDefinition(
            name: name,
            systemImage: "dumbbell.fill",
            subtitle: "",
            colorHex: ink(at: hash),
            includesAllExercises: false,
            sortOrder: 1_000 + hash % 100
        )
    }

    /// Built-in definitions used by presets and first-launch seed.
    /// Icons chosen to read as the movement pattern, not generic “person standing.”
    static let knownDefaults: [String: DayTypeDefinition] = {
        let list: [DayTypeDefinition] = [
            // Arms open silhouette → upper-body isolation day
            .init(name: "Arms", systemImage: "figure.arms.open",
                  subtitle: "Shoulders, Chest, Back, Biceps, Triceps",
                  colorHex: 0xFF4D88, includesAllExercises: false, sortOrder: 0),
            // Stair stepper → quads/legs drive (not a stroll)
            .init(name: "Legs", systemImage: "figure.stair.stepper",
                  subtitle: "Quads, Hamstrings, Glutes, Calves, Core",
                  colorHex: 0x3F9CFF, includesAllExercises: false, sortOrder: 1),
            // Cross-training figure → whole-body session
            .init(name: "Full Body", systemImage: "figure.cross.training",
                  subtitle: "All exercises across your split",
                  colorHex: 0xB569FF, includesAllExercises: true, sortOrder: 2),
            // Dumbbell → press / push load
            .init(name: "Push", systemImage: "dumbbell.fill",
                  subtitle: "Chest, Shoulders, Triceps",
                  colorHex: 0xFF8C42, includesAllExercises: false, sortOrder: 0),
            // Indoor rowing → horizontal/vertical pull pattern
            .init(name: "Pull", systemImage: "figure.indoor.rowing",
                  subtitle: "Back, Biceps, Rear Delts",
                  colorHex: 0x3F9CFF, includesAllExercises: false, sortOrder: 1),
            // Functional strength (hinge) → deadlift / RDL / posterior
            .init(name: "Posterior Chain", systemImage: "figure.strengthtraining.functional",
                  subtitle: "Hamstrings, Glutes, Lower Back, Calves",
                  colorHex: 0xB569FF, includesAllExercises: false, sortOrder: 2),
            // Traditional barbell figure → upper compound work
            .init(name: "Upper", systemImage: "figure.strengthtraining.traditional",
                  subtitle: "Chest, Back, Shoulders, Arms",
                  colorHex: 0xFF4D88, includesAllExercises: false, sortOrder: 0),
            .init(name: "Lower", systemImage: "figure.stair.stepper",
                  subtitle: "Quads, Hamstrings, Glutes, Calves",
                  colorHex: 0x3F9CFF, includesAllExercises: false, sortOrder: 1),
        ]
        return Dictionary(uniqueKeysWithValues: list.map { ($0.name, $0) })
    }()

    /// Curated icon set for the day editor — grouped by how they read at a glance.
    static let iconChoices: [(symbol: String, label: String)] = [
        ("dumbbell.fill", "Push / load"),
        ("figure.indoor.rowing", "Pull / row"),
        ("figure.stair.stepper", "Legs"),
        ("figure.strengthtraining.functional", "Hinge / posterior"),
        ("figure.strengthtraining.traditional", "Barbell / upper"),
        ("figure.arms.open", "Arms open"),
        ("figure.cross.training", "Full body"),
        ("figure.core.training", "Core"),
        ("figure.climbing", "Climb / pull-up"),
        ("figure.step.training", "Step / lunges"),
        ("figure.flexibility", "Hinge stretch"),
        ("figure.highintensity.intervaltraining", "Intense"),
        ("figure.run", "Run / cardio"),
        ("figure.cooldown", "Recovery"),
        ("figure.yoga", "Mobility"),
        ("figure.boxing", "Upper strike"),
    ]
}

// MARK: - Split presets

enum SplitPreset: String, CaseIterable, Identifiable {
    case broSplit = "Bro Split"
    case pushPullLegs = "Push / Pull / Legs"
    case pplPosterior = "PPL + Posterior"
    case upperLower = "Upper / Lower"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .broSplit: "Arms, Legs, Full Body"
        case .pushPullLegs: "Push, Pull, Legs"
        case .pplPosterior: "Push, Pull, Legs, Posterior Chain"
        case .upperLower: "Upper, Lower, Full Body"
        }
    }

    var definitions: [DayTypeDefinition] {
        switch self {
        case .broSplit:
            return [
                DayTypePalette.knownDefaults["Arms"]!,
                DayTypePalette.knownDefaults["Legs"]!,
                DayTypePalette.knownDefaults["Full Body"]!,
            ]
        case .pushPullLegs:
            return [
                DayTypePalette.knownDefaults["Push"]!,
                DayTypePalette.knownDefaults["Pull"]!,
                DayTypeDefinition(
                    name: "Legs",
                    systemImage: "figure.stair.stepper",
                    subtitle: "Quads, Hamstrings, Glutes, Calves",
                    colorHex: 0x34C759,
                    includesAllExercises: false,
                    sortOrder: 2
                ),
            ]
        case .pplPosterior:
            return [
                DayTypePalette.knownDefaults["Push"]!,
                DayTypePalette.knownDefaults["Pull"]!,
                DayTypeDefinition(
                    name: "Legs",
                    systemImage: "figure.stair.stepper",
                    subtitle: "Quads, Glutes, Calves",
                    colorHex: 0x34C759,
                    includesAllExercises: false,
                    sortOrder: 2
                ),
                DayTypePalette.knownDefaults["Posterior Chain"]!,
            ]
        case .upperLower:
            return [
                DayTypePalette.knownDefaults["Upper"]!,
                DayTypePalette.knownDefaults["Lower"]!,
                DayTypePalette.knownDefaults["Full Body"]!,
            ]
        }
    }
}
