//
//  PRsThisMonthCard.swift
//  strength-training
//

import SwiftUI

struct PRsThisMonthCard: View {
    let prs: [PersonalRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.uplift.pr.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.uplift.pr)
                }
                Text("PRs This Month")
                    .font(.uplift.text(15, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                Spacer()
                Num("\(prs.count)", size: 22, weight: .bold,
                    color: prs.isEmpty ? Color.uplift.fgDim : Color.uplift.pr)
            }

            if prs.isEmpty {
                Text("No new personal records this month. Keep training!")
                    .font(.uplift.text(12, weight: .regular))
                    .foregroundStyle(Color.uplift.fgMuted)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(prs.prefix(5)) { pr in
                        HStack(spacing: 10) {
                            Image(systemName: pr.type.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.uplift.pr)
                                .frame(width: 18)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(pr.exerciseName)
                                    .font(.uplift.text(13, weight: .medium))
                                    .foregroundStyle(Color.uplift.fg)
                                Text("\(pr.type.rawValue): \(pr.value, specifier: "%.0f") lbs")
                                    .font(.uplift.text(11, weight: .regular))
                                    .foregroundStyle(Color.uplift.fgMuted)
                            }

                            Spacer()

                            Text(pr.date, format: .dateTime.month(.abbreviated).day())
                                .font(.uplift.mono(11, weight: .medium))
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        )
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
