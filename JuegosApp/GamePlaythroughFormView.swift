//
//  GamePlaythroughFormView.swift
//  JuegosApp
//
//  Created by Codex on 23/4/26.
//

import SwiftUI
import SwiftData

struct GamePlaythroughFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let copy: GameCopy

    @State private var status = GameCatalog.statuses[0]
    @State private var notes = ""

    private var copyLabel: String {
        [copy.platform, copy.format]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var cleanedNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var notesPreview: String {
        cleanedNotes.isEmpty
            ? "Añade contexto de esta partida, dificultad, ruta, personaje o cualquier detalle útil."
            : cleanedNotes
    }

    var body: some View {
#if os(macOS)
        macForm
#else
        iosForm
#endif
    }

#if os(macOS)
    private var macForm: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nueva partida")
                    .font(.title3.weight(.semibold))

                Text(copyLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                PlaythroughSheetSection(
                    title: "Partida",
                    help: "Registra el estado de esta nueva partida asociada a la copia seleccionada."
                ) {
                    PlaythroughSheetRow(label: "Estado") {
                        Picker("", selection: $status) {
                            ForEach(GameCatalog.statuses, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 180, alignment: .leading)
                    }
                }

                PlaythroughSheetSection(
                    title: "Notas",
                    help: "Detalles opcionales para recordar el contexto de esta partida."
                ) {
                    TextEditor(text: $notes)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 130)
                        .background(Color(nsColor: .textBackgroundColor))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(.separator)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    Text(notesPreview)
                        .font(.caption)
                        .foregroundStyle(cleanedNotes.isEmpty ? .tertiary : .secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Divider()

            HStack {
                Spacer()

                Button("Cancelar") {
                    dismiss()
                }

                Button("Guardar") {
                    savePlaythrough()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 520, idealWidth: 580, minHeight: 430, idealHeight: 500)
    }
#else
    private var iosForm: some View {
        NavigationStack {
            Form {
                Section("Partida") {
                    Picker("Estado", selection: $status) {
                        ForEach(GameCatalog.statuses, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

                Section("Notas") {
                    TextField("Dificultad, ruta, personaje, contexto...", text: $notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle("Nueva partida")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        savePlaythrough()
                    }
                }
            }
        }
    }
#endif

    private func savePlaythrough() {
        let playthrough = GamePlaythrough(status: status, notes: cleanedNotes)
        copy.addPlaythrough(playthrough)
        modelContext.insert(playthrough)
        dismiss()
    }
}

#if os(macOS)
private struct PlaythroughSheetSection<Content: View>: View {
    let title: String
    let help: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(help)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content
        }
    }
}

private struct PlaythroughSheetRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .trailing)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
#endif

#Preview {
    let copy = GameCopy(platform: "PlayStation 5", format: "Físico", notes: "Edición launch")

    return GamePlaythroughFormView(copy: copy)
        .modelContainer(for: [Game.self, GameCopy.self, GamePlaythrough.self], inMemory: true)
}
