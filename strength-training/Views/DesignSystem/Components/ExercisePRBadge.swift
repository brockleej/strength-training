//
//  ExercisePRBadge.swift
//  strength-training
//
//  Compact “trained before” + personal-best set for library / day-plan / pickers.
//

import SwiftUI

/// History clock + optional PR (weight×reps) for exercise rows outside Focus.
struct ExercisePRBadge: View {
    let hasHistory: Bool
    var personalBestSummary: String? = nil
    /// When false, only the history icon is shown (tighter pickers).
    var showPRText: Bool = true

    var body: some View {
        if let personalBestSummary, !personalBestSummary.isEmpty, showPRText {
            VStack(alignment: .trailing, spacing: 2) {
                Text("PR")
                    .font(.uplift.text(9, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Color.uplift.up)
                Text(personalBestSummary)
                    .font(.uplift.mono(12, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Personal best \(personalBestSummary)")
        } else if hasHistory {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.uplift.fgDim)
                .accessibilityLabel("Trained before")
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        ExercisePRBadge(hasHistory: true, personalBestSummary: "305×5")
        ExercisePRBadge(hasHistory: true, personalBestSummary: nil)
        ExercisePRBadge(hasHistory: false)
    }
    .padding()
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
