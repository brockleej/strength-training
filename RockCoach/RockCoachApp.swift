//
//  RockCoachApp.swift
//  RockCoach
//

import SwiftUI
import SwiftData

@main
struct RockCoachApp: App {
    @State private var container: ModelContainer?
    @State private var storeError: String?
    @State private var inbox = ImportInbox.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RosterView()
                        .modelContainer(container)
                        .environment(inbox)
                        .onOpenURL { inbox.receive($0) }
                } else if let storeError {
                    RockCoachLaunchPlaceholder(showsProgress: false)
                        .overlay(alignment: .bottom) {
                            VStack(spacing: 12) {
                                Text(storeError)
                                    .font(.footnote)
                                    .foregroundStyle(Color.coach.muted)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 28)
                                Button("Try again") {
                                    self.storeError = nil
                                }
                                .font(.headline)
                                .foregroundStyle(Color.coach.accent)
                            }
                            .padding(.bottom, 48)
                        }
                } else {
                    RockCoachLaunchPlaceholder(showsProgress: true)
                        .task { await openStore() }
                }
            }
            .preferredColorScheme(.dark)
            .tint(Color.coach.accent)
            .background(Color.coach.bg.ignoresSafeArea())
        }
    }

    @MainActor
    private func openStore() async {
        await Task.yield()
        let schema = Schema([CoachClient.self, CoachStoredSession.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try await Task.detached(priority: .userInitiated) {
                try ModelContainer(for: schema, configurations: [config])
            }.value
        } catch {
            storeError = "Couldn’t open the coach store. \(error.localizedDescription)"
        }
    }
}

private struct RockCoachLaunchPlaceholder: View {
    var showsProgress: Bool

    var body: some View {
        ZStack {
            Color.coach.bg.ignoresSafeArea()
            VStack(spacing: 10) {
                Text("RockCoach")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.coach.accent)
                Text("COACHING COMPANION")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Color.coach.dim)
                if showsProgress {
                    ProgressView()
                        .tint(Color.coach.accent)
                        .padding(.top, 8)
                }
            }
        }
    }
}
