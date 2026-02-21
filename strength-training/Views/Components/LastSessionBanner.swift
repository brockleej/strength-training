//
//  LastSessionBanner.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

struct LastSessionBanner: View {
    let record: ExerciseRecord

    var body: some View {
        if let summary = bestSetSummary {
            Text(summary)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(Capsule())
        }
    }

    private var bestSetSummary: String? {
        let sorted = record.sets.sorted { $0.setNumber < $1.setNumber }
        guard let first = sorted.first else { return nil }

        if sorted.count == 1 {
            return "\(formattedWeight(first.weightLbs)) lbs x \(first.reps)"
        }

        // Show the heaviest set
        guard let heaviest = sorted.max(by: { $0.weightLbs < $1.weightLbs }) else {
            return nil
        }
        return "\(formattedWeight(heaviest.weightLbs)) lbs x \(heaviest.reps) (\(sorted.count) sets)"
    }

    private func formattedWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }
}
