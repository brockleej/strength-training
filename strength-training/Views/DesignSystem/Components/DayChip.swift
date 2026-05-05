import SwiftUI

/// Square day-type chip used throughout the redesign — Today picker cards, exercise list
/// header, history rows, session detail headers, library section headers.
///
/// Sizes (per design):
/// - `.sm` — 36pt, 18pt icon
/// - `.md` — 44pt, 22pt icon
/// - `.lg` — 56pt, 28pt icon
///
/// Corner radius is `size × 0.32` (10/14/18pt respectively) for the squircle feel.
struct DayChip: View {
    enum Size {
        case sm, md, lg
        var px: CGFloat   { switch self { case .sm: 36; case .md: 44; case .lg: 56 } }
        var icon: CGFloat { switch self { case .sm: 18; case .md: 22; case .lg: 28 } }
    }

    let dayType: DayType
    var size: Size = .md

    var body: some View {
        let px = size.px
        let radius = px * 0.32

        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(wash)
            .frame(width: px, height: px)
            .overlay {
                Image(systemName: dayType.systemImage)
                    .font(.system(size: size.icon, weight: .semibold))
                    .foregroundStyle(ink)
            }
    }

    private var ink: Color {
        switch dayType {
        case .arms:     .uplift.armsInk
        case .legs:     .uplift.legsInk
        case .fullBody: .uplift.fullInk
        }
    }

    private var wash: Color {
        switch dayType {
        case .arms:     .uplift.armsWash
        case .legs:     .uplift.legsWash
        case .fullBody: .uplift.fullWash
        }
    }
}

#Preview("DayChip — all types & sizes") {
    VStack(spacing: 20) {
        HStack(spacing: 12) {
            ForEach([DayType.arms, .legs, .fullBody], id: \.self) { dt in
                DayChip(dayType: dt, size: .lg)
            }
        }
        HStack(spacing: 12) {
            ForEach([DayType.arms, .legs, .fullBody], id: \.self) { dt in
                DayChip(dayType: dt, size: .md)
            }
        }
        HStack(spacing: 12) {
            ForEach([DayType.arms, .legs, .fullBody], id: \.self) { dt in
                DayChip(dayType: dt, size: .sm)
            }
        }
    }
    .padding(40)
    .background(Color.uplift.bgElev)
}
