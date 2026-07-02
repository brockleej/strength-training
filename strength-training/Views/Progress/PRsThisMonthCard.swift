//
//  PRsThisMonthCard.swift
//  strength-training
//

import SwiftUI

struct PRsThisMonthCard: View {
    let prs: [PersonalRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("PRs this month")
                    .textCase(.uppercase)
                    .font(.uplift.text(11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Color.uplift.fgMuted)
                Spacer()
                Text("\(prs.count)")
                    .font(.uplift.mono(15, weight: .semibold))
                    .foregroundStyle(prs.isEmpty ? Color.uplift.fgDim : Color.uplift.pr)
            }

            if prs.isEmpty {
                Text("No new personal records this month. Keep training!")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
            } else {
                ForEach(prs.prefix(5)) { pr in
                    HStack(spacing: 8) {
                        Image(systemName: pr.type.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.uplift.pr)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(pr.exerciseName)
                                .font(.uplift.text(14, weight: .medium))
                                .foregroundStyle(Color.uplift.fg)
                            Text("\(pr.type.rawValue): \(pr.value, specifier: "%.0f") lbs")
                                .font(.uplift.text(11, weight: .medium))
                                .foregroundStyle(Color.uplift.fgMuted)
                        }

                        Spacer()

                        Text(pr.date, format: .dateTime.month(.abbreviated).day())
                            .font(.uplift.text(11, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }

                if prs.count > 5 {
                    Text("+\(prs.count - 5) more")
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }
}

extension PersonalRecord.PRType {
    var systemImage: String {
        switch self {
        case .estimatedOneRM: "flame"
        case .topSetWeight: "scalemass"
        case .mostRepsAtWeight: "repeat"
        }
    }
}
