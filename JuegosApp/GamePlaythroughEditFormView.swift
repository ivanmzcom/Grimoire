//
//  GamePlaythroughEditFormView.swift
//  JuegosApp
//
//  Created by Codex on 23/4/26.
//

import SwiftUI
import SwiftData

struct GamePlaythroughEditFormView: View {
    @Environment(\.dismiss) private var dismiss

    let playthrough: GamePlaythrough

    @State private var status: String
    @State private var notes: String

    init(playthrough: GamePlaythrough) {
        self.playthrough = playthrough
        _status = State(initialValue: playthrough.status)
        _notes = State(initialValue: playthrough.notes)
    }

    private var copyLabel: String {
        guard let copy = playthrough.copy else {
            return "Partida sin copia asociada"
        }

        let label = [copy.platform, copy.format]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        return label.isEmpty ? "Copia sin detalles" : label
    }

    private var statusOptions: [String] {
        if status.isEmpty || GameCatalog.statuses.contains(status) {
            return GameCatalog.statuses
        }

        return [status] + GameCatalog.statuses
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
                Text("Editar partida")
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
                PlaythroughEditSheetSection(
                    title: "Partida",
                    help: "Actualiza el estado de esta partida sin modificar la copia asociada."
                ) {
                    PlaythroughEditSheetRow(label: "Estado") {
                        Picker("", selection: $status) {
                            if status.isEmpty {
                                Text("Sin estado").tag("")
                            }

                            ForEach(statusOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 180, alignment: .leading)
                    }
                }

                PlaythroughEditSheetSection(
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
                        if status.isEmpty {
                            Text("Sin estado").tag("")
                        }

                        ForEach(statusOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

                Section("Notas") {
                    TextField("Dificultad, ruta, personaje, contexto...", text: $notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle("Editar partida")
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
        playthrough.status = status
        playthrough.notes = cleanedNotes
        dismiss()
    }
}

#if os(macOS)
private struct PlaythroughEditSheetSection<Content: View>: View {
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

private struct PlaythroughEditSheetRow<Content: View>: View {
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
    let game = Game(title: "Metroid Prime Remastered", releaseYear: 2023)
    let copy = GameCopy(platform: "Nintendo Switch", format: "Físico", notes: "Edición launch")
    let playthrough = GamePlaythrough(status: "Jugando", notes: "Ruta casual al 63%.")

    game.addCopy(copy)
    copy.addPlaythrough(playthrough)

    return GamePlaythroughEditFormView(playthrough: playthrough)
        .modelContainer(for: [Game.self, GameCopy.self, GamePlaythrough.self], inMemory: true)
}
