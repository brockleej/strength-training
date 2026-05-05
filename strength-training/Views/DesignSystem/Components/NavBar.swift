import SwiftUI

/// Custom nav bar — replaces system `.navigationTitle` chrome with a header that matches
/// the design's typography and spacing (large 34/38pt display titles, centered 17pt compact titles).
///
/// Two modes:
/// - `.compact` — centered title between leading and trailing slots (Session Detail, Exercise Detail)
/// - `.large(size:)` — title rendered below the button row, left-aligned (History, Progress, Library, Settings, Today)
///
/// Usage:
/// ```swift
/// VStack(spacing: 0) {
///     NavBar(title: "History", style: .large(size: 38),
///         leading: { CircleBtn(icon: "magnifyingglass") {} },
///         trailing: { CircleBtn(icon: "ellipsis") {} })
///     ScrollView { ... }
/// }
/// ```
struct NavBar<Leading: View, Trailing: View>: View {
    enum Style {
        case compact
        case large(size: CGFloat)
    }

    let title: String
    var style: Style = .compact
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            buttonRow
            if case let .large(size) = style {
                Text(title)
                    .font(.uplift.display(size, weight: .bold))
                    .kerning(-0.8)
                    .foregroundStyle(Color.uplift.fg)
                    .padding(.top, 6)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 60)
        .padding(.bottom, isLarge ? 8 : 14)
    }

    private var buttonRow: some View {
        HStack {
            HStack { leading() }.frame(width: 40, alignment: .leading)

            if !isLarge {
                Spacer()
                Text(title)
                    .font(.uplift.text(17, weight: .semibold))
                    .kerning(-0.3)
                    .foregroundStyle(Color.uplift.fg)
                Spacer()
            } else {
                Spacer()
            }

            HStack { trailing() }.frame(width: 40, alignment: .trailing)
        }
        .frame(minHeight: 36)
        .padding(.horizontal, isLarge ? 20 : 14)
    }

    private var isLarge: Bool {
        if case .large = style { return true }
        return false
    }
}

#Preview("NavBar — compact") {
    VStack(spacing: 0) {
        NavBar(title: "Push", style: .compact,
            leading: { CircleBtn(icon: "chevron.left") {} },
            trailing: { CircleBtn(icon: "ellipsis") {} })
        Spacer()
    }
    .background(Color.uplift.bgElev)
}

#Preview("NavBar — large 34pt (History)") {
    VStack(spacing: 0) {
        NavBar(title: "History", style: .large(size: 34),
            leading: { CircleBtn(icon: "magnifyingglass") {} },
            trailing: { CircleBtn(icon: "ellipsis") {} })
        Spacer()
    }
    .background(Color.uplift.bgElev)
}

#Preview("NavBar — large 38pt (Exercises)") {
    VStack(spacing: 0) {
        NavBar(title: "Exercises", style: .large(size: 38),
            leading: { EmptyView() },
            trailing: { CircleBtn(icon: "plus", size: .large) {} })
        Spacer()
    }
    .background(Color.uplift.bgElev)
}
