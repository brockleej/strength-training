//
//  LastSessionReferenceCard.swift
//  strength-training
//
//  Full set-by-set reference from the previous completed session for this
//  lift (including warm-up ramps). Tap a row to load weight × reps into the
//  steppers (including assist / each-side flags).
//

import SwiftUI

struct LastSessionReferenceCard: View {
    struct SetLine: Identifiable, Equatable {
        let id: Int           // set number / index
        let weight: Double
        let reps: Int
        let isWarmup: Bool
        var isEachSide: Bool = false
        var isAssisted: Bool = false
    }

    let dateLabel: String
    let sets: [SetLine]
    /// weight, reps, isWarmup, isEachSide, isAssisted
    var onSelectSet: ((Double, Int, Bool, Bool, Bool) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.uplift.accent)
                Text("Last time")
                    .font(.uplift.text(13, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                Text("·")
                    .foregroundStyle(Color.uplift.fgDim)
                Text(dateLabel)
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
                Spacer(minLength: 0)
                Text("\(sets.count) sets")
                    .font(.uplift.mono(11, weight: .semibold))
                    .foregroundStyle(Color.uplift.fgDim)
            }

            Text("Tap a set to load weight & reps")
                .font(.uplift.text(11, weight: .medium))
                .foregroundStyle(Color.uplift.fgDim)

            VStack(spacing: 0) {
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    Button {
                        onSelectSet?(set.weight, set.reps, set.isWarmup, set.isEachSide, set.isAssisted)
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.uplift.mono(12, weight: .semibold))
                                .foregroundStyle(Color.uplift.fgDim)
                                .frame(width: 20, alignment: .leading)

                            if set.isAssisted {
                                Text("−\(StepperLogic.format(set.weight)) × \(set.reps)")
                                    .font(.uplift.mono(14, weight: .semibold))
                                    .foregroundStyle(Color.uplift.weightTint)
                            } else {
                                PairText.pair(
                                    weight: set.weight,
                                    reps: set.reps,
                                    font: .uplift.mono(14, weight: .semibold)
                                )
                            }

                            if set.isWarmup {
                                Text("WARM")
                                    .font(.uplift.text(9, weight: .bold))
                                    .tracking(0.3)
                                    .foregroundStyle(Color.uplift.fgDim)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.uplift.surface2))
                            }
                            if set.isAssisted {
                                Text("ASSIST")
                                    .font(.uplift.text(9, weight: .bold))
                                    .tracking(0.3)
                                    .foregroundStyle(Color.uplift.fgDim)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.uplift.surface2))
                            }
                            if set.isEachSide {
                                Text("EA")
                                    .font(.uplift.text(9, weight: .bold))
                                    .tracking(0.3)
                                    .foregroundStyle(Color.uplift.fgDim)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.uplift.surface2))
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "arrow.down.left")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.uplift.fgDim)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel(for: set, index: index))

                    if index < sets.count - 1 {
                        Rectangle()
                            .fill(Color.uplift.hairline)
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.uplift.surface1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.uplift.accent.opacity(0.22), lineWidth: 1)
        }
    }

    private func accessibilityLabel(for set: SetLine, index: Int) -> String {
        var parts = [
            "Set \(index + 1)",
            "\(StepperLogic.format(set.weight)) pounds\(set.isAssisted ? " assistance" : "") by \(set.reps)",
        ]
        if set.isWarmup { parts.append("warmup") }
        if set.isAssisted { parts.append("assisted") }
        if set.isEachSide { parts.append("each side") }
        parts.append("load into steppers")
        return parts.joined(separator: ", ")
    }
}

#Preview {
    LastSessionReferenceCard(
        dateLabel: "3 days ago",
        sets: [
            .init(id: 1, weight: 135, reps: 5, isWarmup: true),
            .init(id: 2, weight: 225, reps: 4, isWarmup: true),
            .init(id: 3, weight: 285, reps: 3, isWarmup: true),
            .init(id: 4, weight: 295, reps: 1, isWarmup: true),
            .init(id: 5, weight: 305, reps: 5, isWarmup: false),
            .init(id: 6, weight: 50, reps: 8, isWarmup: false, isAssisted: true),
            .init(id: 7, weight: 30, reps: 12, isWarmup: false, isEachSide: true),
        ],
        onSelectSet: { _, _, _, _, _ in }
    )
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
