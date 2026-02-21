//
//  Enums.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import Foundation

enum DayType: String, Codable, CaseIterable, Identifiable {
    case arms = "Arms"
    case legs = "Legs"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .arms: "figure.arms.open"
        case .legs: "figure.walk"
        }
    }
}

enum TrainingMode: String, Codable, CaseIterable, Identifiable {
    case lowWeightHighReps = "Endurance"
    case highWeightLowReps = "Strength"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .lowWeightHighReps: "Low/High"
        case .highWeightLowReps: "High/Low"
        }
    }

    var description: String {
        switch self {
        case .lowWeightHighReps: "Low Weight · High Reps"
        case .highWeightLowReps: "High Weight · Low Reps"
        }
    }

    var systemImage: String {
        switch self {
        case .lowWeightHighReps: "hare"
        case .highWeightLowReps: "tortoise"
        }
    }
}
