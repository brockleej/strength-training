import SwiftUI

/// Settings-screen section pattern — uppercase muted header + surface1 card + muted footer.
/// Matches `direction-x-library.jsx:372-389`'s `SettingsHeader` / `SettingsFooter`.
///
/// Usage:
/// ```swift
/// SettingsSection(header: "Apple Health", footer: "When connected, ...") {
///     // content card body — caller provides the inner view
///     Text("Apple Health Connected").foregroundStyle(.uplift.up)
/// }
/// ```
struct SettingsSection<Content: View>: View {
    let header: String
    let footer: String?
    @ViewBuilder var content: () -> Content

    init(header: String, footer: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.header = header
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(header.uppercased())
                .font(.uplift.text(11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Color.uplift.fgMuted)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

            content()
                .padding(.bottom, footer != nil ? 8 : 0)

            if let footer {
                Text(footer)
                    .font(.uplift.text(12, weight: .medium))
                    .lineSpacing(2)
                    .foregroundStyle(Color.uplift.fgDim)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.bottom, 26)
    }
}

#Preview("SettingsSection") {
    ScrollView {
        VStack(spacing: 0) {
            SettingsSection(
                header: "Apple Health",
                footer: "When connected, workouts are saved to Apple Health for Activity Ring credit and fitness tracking."
            ) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.uplift.ahkitGreen.opacity(0.18)).frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.uplift.ahkitGreen)
                    }
                    Text("Apple Health Connected")
                        .font(.uplift.text(15, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundStyle(Color.uplift.ahkitGreen)
                    Spacer()
                }
                .padding(14)
                .background(Color.uplift.surface1, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(20)
    }
    .background(Color.uplift.bgElev)
}
