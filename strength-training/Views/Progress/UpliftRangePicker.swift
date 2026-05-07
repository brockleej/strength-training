//
//  UpliftRangePicker.swift
//  strength-training
//

import SwiftUI

/// Themed segmented control matching the refined-native spec: 5 equal segments,
/// surface1 track, surface3 active fill, fg active text, fgMuted inactive text,
/// 12pt corner radius outer / 9pt inner pill, 4pt padding.
struct UpliftRangePicker: View {
    @Binding var selection: ProgressTimeRange

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ProgressTimeRange.allCases) { range in
                segment(range)
            }
        }
        .padding(4)
        .background(Color.uplift.surface1, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func segment(_ range: ProgressTimeRange) -> some View {
        let active = (range == selection)
        return Button {
            selection = range
        } label: {
            Text(range.rawValue)
                .font(.uplift.text(12, weight: .semibold))
                .kerning(-0.1)
                .foregroundStyle(active ? Color.uplift.fg : Color.uplift.fgMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    active
                        ? Color.uplift.surface3
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview("UpliftRangePicker") {
    @Previewable @State var sel: ProgressTimeRange = .threeMonths
    return UpliftRangePicker(selection: $sel)
        .padding(20)
        .background(Color.uplift.bgElev)
}
