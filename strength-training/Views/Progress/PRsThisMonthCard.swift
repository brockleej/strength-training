//
//  PRsThisMonthCard.swift
//  strength-training
//

import SwiftUI

struct PRsThisMonthCard: View {
    let prs: [PersonalRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("PRs This Month", systemImage: "trophy")
                    .font(.headline)
                Spacer()
                Text("\(prs.count)")
                    .font(.title2.bold())
                    .foregroundStyle(prs.isEmpty ? Color.secondary : Color.orange)
            }

            if prs.isEmpty {
                Text("No new personal records this month. Keep training!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(prs.prefix(5)) { pr in
                    HStack(spacing: 8) {
                        Image(systemName: pr.type.systemImage)
                            .foregroundStyle(.orange)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(pr.exerciseName)
                                .font(.subheadline.weight(.medium))
                            Text("\(pr.type.rawValue): \(pr.value, specifier: "%.0f") lbs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(pr.date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if prs.count > 5 {
                    Text("+\(prs.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
