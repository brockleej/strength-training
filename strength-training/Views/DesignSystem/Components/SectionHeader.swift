import SwiftUI

/// Uppercase muted section eyebrow with optional trailing content (accent link, count, etc).
/// Pads 20pt top, 10pt bottom, 4pt sides — matches the design's section-header padding.
///
/// ```swift
/// SectionHeader("Yesterday")
/// SectionHeader("Lift progression") {
///     Text("See all").foregroundStyle(.uplift.accent)
/// }
/// ```
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.uplift.text(13, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgMuted)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 4)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}

#Preview("SectionHeader — variants") {
    VStack(spacing: 0) {
        SectionHeader("Yesterday")
        SectionHeader("This week")
        SectionHeader("Lift progression") {
            Text("See all")
                .font(.uplift.text(13, weight: .medium))
                .foregroundStyle(Color.uplift.accent)
        }
        SectionHeader("Recent sessions") {
            Text("March")
                .font(.uplift.text(13, weight: .medium))
                .foregroundStyle(Color.uplift.accent)
        }
    }
    .padding(.horizontal, 16)
    .background(Color.uplift.bgElev)
}
