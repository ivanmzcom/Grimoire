//
//  GameFormView.swift
//  JuegosApp
//
//  Created by Codex on 23/4/26.
//

import SwiftUI
import SwiftData

struct GameFormView: View {
    private enum Field {
        case title
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var platform = GameCatalog.platforms[0]
    @State private var format = GameCatalog.formats[0]
    @State private var status = GameCatalog.statuses[0]
    @State private var genre = GameCatalog.genres[0]
    @State private var releaseYearText = ""
    @State private var notes = ""
    @FocusState private var focusedField: Field?

    private var cleanedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var releaseYear: Int? {
        let trimmed = releaseYearText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    private var notesPreview: String {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Añade observaciones, edición, estado de la caja o cualquier detalle útil." : trimmed
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
                Text("Nuevo juego")
                    .font(.title3.weight(.semibold))

                Text("Completa la información básica de la ficha.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MacSheetSection(title: "Biblioteca", help: "Los campos principales que aparecerán en tu colección.") {
                        MacSheetRow(label: "Titulo") {
                            TextField("The Legend of Zelda", text: $title)
                                .focused($focusedField, equals: .title)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 320, alignment: .leading)
                        }

                        MacSheetRow(label: "Plataforma") {
                            Picker("", selection: $platform) {
                                ForEach(GameCatalog.platforms, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 220, alignment: .leading)
                        }

                        MacSheetRow(label: "Formato") {
                            Picker("", selection: $format) {
                                ForEach(GameCatalog.formats, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180, alignment: .leading)
                        }

                        MacSheetRow(label: "Estado") {
                            Picker("", selection: $status) {
                                ForEach(GameCatalog.statuses, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180, alignment: .leading)
                        }

                        MacSheetRow(label: "Genero") {
                            Picker("", selection: $genre) {
                                ForEach(GameCatalog.genres, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180, alignment: .leading)
                        }

                        MacSheetRow(label: "Ano") {
                            TextField("2024", text: $releaseYearText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100, alignment: .leading)
                        }
                    }

                    MacSheetSection(title: "Notas", help: "Detalles opcionales para recordar edición, estado o contexto.") {
                        TextEditor(text: $notes)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 150)
                            .background(Color(nsColor: .textBackgroundColor))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(.separator)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        Text(notesPreview)
                            .font(.caption)
                            .foregroundStyle(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .tertiary : .secondary)
                            .lineLimit(2)
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()

                Button("Cancelar") {
                    dismiss()
                }

                Button("Guardar") {
                    saveGame()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(cleanedTitle.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 500, idealHeight: 560)
        .task {
            focusedField = .title
        }
    }
#else
    private var iosForm: some View {
        NavigationStack {
            Form {
                Section("Informacion principal") {
                    TextField("Titulo", text: $title)
                    Picker("Plataforma", selection: $platform) {
                        ForEach(GameCatalog.platforms, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    Picker("Formato", selection: $format) {
                        ForEach(GameCatalog.formats, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    Picker("Estado", selection: $status) {
                        ForEach(GameCatalog.statuses, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    Picker("Genero", selection: $genre) {
                        ForEach(GameCatalog.genres, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    TextField("Ano de lanzamiento", text: $releaseYearText)
                        .keyboardType(.numberPad)
                }

                Section("Notas") {
                    TextField("Observaciones, edicion, estado de la caja...", text: $notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle("Nuevo juego")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveGame()
                    }
                    .disabled(cleanedTitle.isEmpty)
                }
            }
        }
    }
#endif

    private func saveGame() {
        let game = Game(
            title: cleanedTitle,
            platform: platform,
            format: format,
            status: status,
            genre: genre,
            releaseYear: releaseYear,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(game)
        dismiss()
    }
}

#Preview {
    GameFormView()
        .modelContainer(for: Game.self, inMemory: true)
}

#if os(macOS)
private struct MacSheetSection<Content: View>: View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MacSheetRow<Content: View>: View {
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
