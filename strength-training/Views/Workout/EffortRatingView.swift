//
//  EffortRatingView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-04-11.
//

import SwiftUI

struct EffortRatingView: View {
    var onSave: (Int) -> Void
    var onSkip: () -> Void

    @State private var selectedRating: Int?

    private let barCount = 10
    private let minBarHeight: CGFloat = 40
    private let maxBarHeight: CGFloat = 140
    private let barSpacing: CGFloat = 6

    var body: some View {
        VStack(spacing: 20) {
            // Header buttons
            HStack {
                Button {
                    onSkip()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Spacer()

                Button {
                    if let rating = selectedRating {
                        onSave(rating)
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.footnote.bold())
                        .foregroundStyle(selectedRating != nil ? .white : .secondary)
                        .frame(width: 30, height: 30)
                        .background {
                            if selectedRating != nil {
                                Circle().fill(Color.accentColor)
                            } else {
                                Circle().fill(.ultraThinMaterial)
                            }
                        }
                        .clipShape(Circle())
                }
                .disabled(selectedRating == nil)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Text("Rate Your Effort")
                .font(.title2.bold())

            Spacer()

            // Bars
            GeometryReader { geo in
                let dotCount = CGFloat(sectionBreaks.count)
                let dotSize: CGFloat = 4
                let dotAreaWidth = dotCount * (dotSize + barSpacing * 2)
                let totalBarSpacing = barSpacing * CGFloat(barCount - 1)
                let barWidth = (geo.size.width - totalBarSpacing - dotAreaWidth) / CGFloat(barCount)

                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(1...barCount, id: \.self) { index in
                        let height = barHeight(for: index)
                        let isSelected = selectedRating == index

                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? effortColor(for: index) : Color(.systemFill))
                            .frame(width: barWidth, height: height)
                            .overlay(alignment: .center) {
                                if isSelected {
                                    Capsule()
                                        .fill(.white.opacity(0.9))
                                        .frame(width: 4, height: min(height * 0.4, 30))
                                }
                            }

                        if sectionBreaks.contains(index) {
                            Circle()
                                .fill(Color(.tertiaryLabel))
                                .frame(width: dotSize, height: dotSize)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let index = barIndex(at: value.location.x, totalWidth: geo.size.width)
                            if index != selectedRating {
                                selectedRating = index
                                let generator = UISelectionFeedbackGenerator()
                                generator.selectionChanged()
                            }
                        }
                )
            }
            .frame(height: maxBarHeight)
            .padding(.horizontal, 20)

            // Label
            HStack {
                if let rating = selectedRating {
                    Text("\(rating)")
                        .font(.body.bold().monospacedDigit())
                    Text(effortLabel(for: rating))
                        .font(.body)
                } else {
                    Text("Rate your effort")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            Spacer()

            Button("Skip") {
                onSkip()
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 12)
        }
        .background(backgroundGradient)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    // MARK: - Bar Geometry

    private func barHeight(for index: Int) -> CGFloat {
        let fraction = CGFloat(index) / CGFloat(barCount)
        return minBarHeight + (maxBarHeight - minBarHeight) * fraction
    }

    private func barIndex(at x: CGFloat, totalWidth: CGFloat) -> Int {
        let fraction = x / totalWidth
        let index = Int(fraction * CGFloat(barCount)) + 1
        return min(max(index, 1), barCount)
    }

    // MARK: - Styling

    private func effortColor(for rating: Int) -> Color {
        switch rating {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7, 8: return .orange
        default: return .red
        }
    }

    private func effortLabel(for rating: Int) -> String {
        switch rating {
        case 1...3: return "Easy"
        case 4...6: return "Moderate"
        case 7, 8: return "Hard"
        case 9, 10: return "All Out"
        default: return ""
        }
    }

    /// Section boundaries: after bar 3, 6, and 8
    private let sectionBreaks: Set<Int> = [3, 6, 8]

    private var backgroundGradient: some ShapeStyle {
        if let rating = selectedRating {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [effortColor(for: rating).opacity(0.3), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        return AnyShapeStyle(Color(.systemBackground))
    }
}
