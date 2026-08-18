//
//  RosterView.swift
//  RockCoach
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RosterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ImportInbox.self) private var inbox
    @Query(sort: \CoachClient.displayName) private var clients: [CoachClient]

    @State private var isImporting = false
    @State private var draftClientName = ""
    @State private var showAddClient = false
    @State private var newClientName = ""
    @State private var showImported = false

    var body: some View {
        NavigationStack {
            Group {
                if clients.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(clients) { client in
                            NavigationLink {
                                ClientDetailView(client: client)
                            } label: {
                                clientRow(client)
                            }
                            .listRowBackground(Color.coach.surface)
                        }
                        .onDelete(perform: delete)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.coach.bg.ignoresSafeArea())
            .navigationTitle("RockCoach")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isImporting = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Import session")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newClientName = ""
                        showAddClient = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add client")
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [
                    UTType(filenameExtension: CoachFormat.pathExtension) ?? .json,
                    .json,
                    .data,
                ],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .sheet(item: Binding(
                get: { inbox.pending },
                set: { inbox.pending = $0 }
            )) { pending in
                ImportNameSheet(
                    defaultName: pending.athlete.displayName,
                    name: $draftClientName,
                    sessionCount: pending.documents.count
                ) {
                    importPending(pending)
                }
            }
            .alert("Add client", isPresented: $showAddClient) {
                TextField("Name", text: $newClientName)
                Button("Add") { addBlankClient() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You’ll attach imported sessions to this folder.")
            }
            .alert("Couldn’t import", isPresented: Binding(
                get: { inbox.errorMessage != nil },
                set: { if !$0 { inbox.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(inbox.errorMessage ?? "")
            }
            .alert("Imported", isPresented: $showImported) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(inbox.importedCount > 1
                     ? "\(inbox.importedCount) workouts saved to the roster."
                     : "Session saved to the roster.")
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: inbox.pending?.id) { _, _ in
                applyKnownClientIfPossible()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 36))
                .foregroundStyle(Color.coach.accent)
            Text("No clients yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.coach.fg)
            Text("In Messages, tap the file, then Open in RockCoach — or share it and choose RockCoach. You can also import from Files.")
                .font(.subheadline)
                .foregroundStyle(Color.coach.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button {
                isImporting = true
            } label: {
                Text("Import session")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.coach.accent, in: Capsule())
                    .foregroundStyle(Color.coach.onAccent)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func clientRow(_ client: CoachClient) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(client.displayName)
                .font(.headline)
                .foregroundStyle(Color.coach.fg)
            if let date = client.lastSessionAt {
                Text("\(client.lastSessionDayType) · \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(Color.coach.muted)
            } else if client.sessionCount > 0 {
                Text("\(client.sessionCount) sessions")
                    .font(.subheadline)
                    .foregroundStyle(Color.coach.muted)
            } else {
                Text("No sessions yet")
                    .font(.subheadline)
                    .foregroundStyle(Color.coach.dim)
            }
        }
        .padding(.vertical, 4)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                inbox.receive(url)
            }
        case .failure(let error):
            inbox.errorMessage = error.localizedDescription
        }
    }

    private func matchingClient(for pending: PendingCoachImport) -> CoachClient? {
        CoachImportService.matchingClient(for: pending.athlete, in: modelContext)
    }

    private func applyKnownClientIfPossible() {
        guard let pending = inbox.pending,
              let existing = matchingClient(for: pending) else {
            if let pending = inbox.pending {
                draftClientName = pending.athlete.displayName
            }
            return
        }
        do {
            try CoachImportService.upsert(pending.documents, into: modelContext, client: existing)
            inbox.importedCount = pending.documents.count
            inbox.pending = nil
            showImported = true
        } catch {
            inbox.errorMessage = error.localizedDescription
        }
    }

    private func importPending(_ pending: PendingCoachImport) {
        do {
            let client = try CoachImportService.makeClient(
                named: draftClientName,
                athleteID: pending.athlete.id,
                in: modelContext
            )
            try CoachImportService.upsert(pending.documents, into: modelContext, client: client)
            inbox.importedCount = pending.documents.count
            inbox.pending = nil
            showImported = true
        } catch {
            inbox.errorMessage = error.localizedDescription
        }
    }

    private func addBlankClient() {
        let name = newClientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        modelContext.insert(CoachClient(displayName: name))
        try? modelContext.save()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(clients[index])
        }
        try? modelContext.save()
    }
}
