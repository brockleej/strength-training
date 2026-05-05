import SwiftUI

/// Custom floating 5-tab capsule tab bar. Replaces system `TabView` chrome.
/// Built on top of `PillBottomBar` so it shares the same blur+border+shadow treatment.
///
/// Tabs are fixed: Today, History, Progress, Exercises, Settings.
/// Caller manages `selection` via `@State` or `@AppStorage`.
///
/// ```swift
/// @State private var tab: UpliftTab = .today
/// // ...
/// ZStack(alignment: .bottom) {
///     content(for: tab)
///     TabBar(selection: $tab)
/// }
/// ```
enum UpliftTab: String, CaseIterable, Hashable {
    case today, history, progress, exercises, settings

    var label: String {
        switch self {
        case .today:     "Today"
        case .history:   "History"
        case .progress:  "Progress"
        case .exercises: "Exercises"
        case .settings:  "Settings"
        }
    }

    var icon: String {
        switch self {
        case .today:     "dumbbell.fill"
        case .history:   "clock.fill"
        case .progress:  "chart.line.uptrend.xyaxis"
        case .exercises: "list.bullet"
        case .settings:  "gearshape.fill"
        }
    }
}

struct TabBar: View {
    @Binding var selection: UpliftTab

    var body: some View {
        PillBottomBar {
            HStack(spacing: 0) {
                ForEach(UpliftTab.allCases, id: \.self) { tab in
                    let active = (tab == selection)
                    Button {
                        selection = tab
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 22, weight: .semibold))
                            Text(tab.label)
                                .font(.uplift.text(10, weight: .semibold))
                                .kerning(-0.1)
                        }
                        .foregroundStyle(active ? Color.uplift.accent : Color.uplift.fgDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview("TabBar — Today active") {
    ZStack(alignment: .bottom) {
        Color.uplift.bgElev.ignoresSafeArea()
        TabBar(selection: .constant(.today))
    }
}

#Preview("TabBar — Progress active") {
    ZStack(alignment: .bottom) {
        Color.uplift.bgElev.ignoresSafeArea()
        TabBar(selection: .constant(.progress))
    }
}
