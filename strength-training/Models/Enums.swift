//
//  Enums.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import Foundation
import SwiftUI

enum DayType: String, Codable, CaseIterable, Identifiable {
    case arms = "Arms"
    case legs = "Legs"
    case fullBody = "Full Body"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .arms: "figure.arms.open"
        case .legs: "figure.walk"
        case .fullBody: "figure.strengthtraining.functional"
        }
    }

    var color: Color {
        switch self {
        case .arms: .pink
        case .legs: .blue
        case .fullBody: .purple
        }
    }

    var subtitle: String {
        switch self {
        case .arms: "Shoulders, Chest, Back, Biceps, Triceps"
        case .legs: "Quads, Hamstrings, Glutes, Calves, Core"
        case .fullBody: "All exercises across Arms and Legs"
        }
    }
}

