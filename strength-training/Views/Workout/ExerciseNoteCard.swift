//
//  ExerciseNoteCard.swift
//  strength-training
//
//  Compact note on the Focus lift screen: difficulty, next time, modifications.
//  Stored on Exercise so it shows up next session.
//

import SwiftUI

struct ExerciseNoteCard: View {
    let exercise: Exercise
    @Binding var isEditing: Bool
    var onSave: (String) -> Void

    @State private var draft = ""
    /// Set when Cancel/Save already handled persist so `onChange(isEditing)` does not save twice.
    @State private var handledExit = false
    @FocusState private var fieldFocused: Bool

    private var stored: String {
        exercise.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditing {
                TextField("Difficulty, next time, modifications…", text: $draft, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.uplift.text(14, weight: .medium))
                    .foregroundStyle(Color.uplift.fg)
                    .focused($fieldFocused)
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.uplift.surface2)
                    }
                    .task {
                        try? await Task.sleep(for: .milliseconds(80))
                        fieldFocused = true
                    }

                HStack {
                    Button("Cancel") { close(save: false) }
                        .font(.uplift.text(13, weight: .semibold))
                        .foregroundStyle(Color.uplift.fgMuted)
                        .padding(.vertical, 8)
                        .padding(.trailing, 12)
                        .contentShape(Rectangle())

                    Spacer()

                    Button("Save") { close(save: true) }
                        .font(.uplift.text(13, weight: .semibold))
                        .foregroundStyle(Color.uplift.accent)
                        .padding(.vertical, 8)
                        .padding(.leading, 12)
                        .contentShape(Rectangle())
                }
            } else {
                Button {
                    draft = stored
                    isEditing = true
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: stored.isEmpty ? "note.text.badge.plus" : "note.text")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.uplift.fgMuted)
                            .padding(.top, 1)
                        Text(stored.isEmpty ? "Add a note" : stored)
                            .font(.uplift.text(13, weight: .medium))
                            .foregroundStyle(stored.isEmpty ? Color.uplift.fgDim : Color.uplift.fgMuted)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.uplift.surface1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(stored.isEmpty ? "Add a note" : "Exercise note")
                .accessibilityHint("Describe difficulty, next time, or a modification")
            }
        }
        .padding(.top, 4)
        .onChange(of: isEditing) { _, editing in
            if editing {
                if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    draft = stored
                }
                handledExit = false
            } else {
                if !handledExit { onSave(draft) }
                fieldFocused = false
                handledExit = false
            }
        }
        .onDisappear {
            if isEditing { onSave(draft) }
        }
    }

    private func close(save: Bool) {
        guard isEditing else { return }
        if save { onSave(draft) }
        handledExit = true
        isEditing = false
        fieldFocused = false
    }
}
