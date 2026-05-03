//
//  TrainingMode.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-05-03.
//

import Foundation

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
        case .lowWeightHighReps: "flame"
        case .highWeightLowReps: "bolt"
        }
    }
}
