//
//  SearchField.swift
//  strength-training
//

import SwiftUI

/// Surface1 rounded search input (Exercise Library).
struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.uplift.fgDim)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .font(.uplift.text(14, weight: .medium))
                .foregroundStyle(Color.uplift.fg)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.uplift.fgDim)
                        .frame(width: 36, height: 36)   // hit region; glyph stays 15pt
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }
}

#Preview("SearchField") {
    @Previewable @State var empty = ""
    @Previewable @State var filled = "Squat"

    VStack(spacing: 16) {
        SearchField(placeholder: "Search exercises", text: $empty)
        SearchField(placeholder: "Search exercises", text: $filled)
    }
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
