//
//  EffortRatingView.swift
//  strength-training
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
            headerRow
            Text("Rate Your Effort")
                .font(.uplift.display(22, weight: .bold))
                .kerning(-0.4)
                .foregroundStyle(Color.uplift.fg)

            Spacer()

            barRail

            ratingLabel

            Spacer()

            skipButton
        }
        .background(backgroundGradient)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    // MARK: - Sections

    private var headerRow: some View {
        HStack {
            Button {
                onSkip()
            } label: {
                ZStack {
                    Circle().fill(Color.uplift.surface1)
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
                .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                if let rating = selectedRating {
                    onSave(rating)
                }
            } label: {
                ZStack {
                    Circle().fill(selectedRating != nil ? Color.uplift.accent : Color.uplift.surface1)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(selectedRating != nil ? Color.uplift.onAccent : Color.uplift.fgDim)
                }
                .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(selectedRating == nil)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var barRail: some View {
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

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? effortColor(for: index) : Color.uplift.fgFaint)
                        .frame(width: barWidth, height: height)
                        .overlay(alignment: .center) {
                            if isSelected {
                                Capsule()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 4, height: min(height * 0.4, 30))
                            }
                        }

                    if sectionBreaks.contains(index) {
                        Circle()
                            .fill(Color.uplift.fgDim)
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
    }

    private var ratingLabel: some View {
        HStack(spacing: 6) {
            if let rating = selectedRating {
                Num("\(rating)", size: 17, weight: .bold, color: .uplift.fg)
                Text(effortLabel(for: rating))
                    .font(.uplift.text(15, weight: .medium))
                    .foregroundStyle(Color.uplift.fg)
            } else {
                Text("Rate your effort")
                    .font(.uplift.text(15, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var skipButton: some View {
        Button("Skip") {
            onSkip()
        }
        .font(.uplift.text(14, weight: .medium))
        .foregroundStyle(Color.uplift.fgMuted)
        .padding(.bottom, 12)
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

    /// Mapping of rating → band color, using design tokens semantically:
    /// - Easy (1-3) → up green (positive/light)
    /// - Moderate (4-6) → pr amber (mid-tier, attention)
    /// - Hard (7-8) → endurance orange (sustained intensity)
    /// - All Out (9-10) → down red (max effort)
    private func effortColor(for rating: Int) -> Color {
        switch rating {
        case 1...3: return Color.uplift.up
        case 4...6: return Color.uplift.pr
        case 7, 8:  return Color.uplift.endurance
        default:    return Color.uplift.down
        }
    }

    private func effortLabel(for rating: Int) -> String {
        switch rating {
        case 1...3: return "Easy"
        case 4...6: return "Moderate"
        case 7, 8:  return "Hard"
        case 9, 10: return "All Out"
        default:    return ""
        }
    }

    /// Section boundaries: after bar 3, 6, and 8
    private let sectionBreaks: Set<Int> = [3, 6, 8]

    /// Sheet background tints to the selected band's color (subtle gradient).
    private var backgroundGradient: some ShapeStyle {
        if let rating = selectedRating {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [effortColor(for: rating).opacity(0.3), Color.uplift.bgElev],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        return AnyShapeStyle(Color.uplift.bgElev)
    }
}
