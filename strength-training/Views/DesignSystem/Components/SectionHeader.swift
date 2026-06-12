//
//  SectionHeader.swift
//  strength-training
//

import SwiftUI

/// Uppercase eyebrow section header with an optional trailing view.
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .textCase(.uppercase)
                .font(.uplift.text(13, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgMuted)
            Spacer()
            trailing
        }
        .padding(.horizontal, 4)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

#Preview("SectionHeader") {
    VStack(spacing: 0) {
        SectionHeader("This week")
        SectionHeader("Recent sessions") {
            Text("March")
                .font(.uplift.text(13, weight: .medium))
                .foregroundStyle(Color.uplift.accent)
        }
    }
    .padding(.horizontal, 20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
