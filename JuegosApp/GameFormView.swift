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
    @State private var releaseYearText = ""
    @State private var platform = GameCatalog.platforms[0]
    @State private var format = GameCatalog.formats[0]
    @State private var copyNotes = ""
    @FocusState private var focusedField: Field?

    private var cleanedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var releaseYear: Int? {
        let trimmed = releaseYearText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    private var releaseYearValidationMessage: String? {
        let trimmed = releaseYearText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let year = Int(trimmed) else {
            return "Introduce un año con números."
        }

        let maximumYear = Calendar.current.component(.year, from: .now) + 5
        guard (1950...maximumYear).contains(year) else {
            return "Introduce un año entre 1950 y \(maximumYear)."
        }

        return nil
    }

    private var canSave: Bool {
        !cleanedTitle.isEmpty && releaseYearValidationMessage == nil
    }

    private var cleanedCopyNotes: String {
        copyNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var notesPreview: String {
        cleanedCopyNotes.isEmpty
            ? "Añade edición, procedencia o cualquier detalle útil de esta copia."
            : cleanedCopyNotes
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

                Text("Crea la ficha del título y registra su primera copia.")
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
                    MacSheetSection(title: "Juego", help: "Información general del título que compartirán todas sus copias.") {
                        MacSheetRow(label: "Título") {
                            TextField("The Legend of Zelda", text: $title)
                                .focused($focusedField, equals: .title)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 320, alignment: .leading)
                        }

                        MacSheetRow(label: "Año") {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("2024", text: $releaseYearText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100, alignment: .leading)

                                if let releaseYearValidationMessage {
                                    Text(releaseYearValidationMessage)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }

                    MacSheetSection(title: "Primera copia", help: "Datos de la unidad concreta que tienes en tu biblioteca.") {
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
                    }

                    MacSheetSection(title: "Notas de la copia", help: "Observaciones opcionales sobre caja, disco, procedencia o edición.") {
                        TextEditor(text: $copyNotes)
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
                            .foregroundStyle(cleanedCopyNotes.isEmpty ? .tertiary : .secondary)
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
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 520, idealHeight: 580)
        .task {
            focusedField = .title
        }
    }
#else
    private var iosForm: some View {
        NavigationStack {
            Form {
                Section("Juego") {
                    TextField("Título", text: $title)
                        .textInputAutocapitalization(.words)

                    TextField("Año de lanzamiento", text: $releaseYearText)
                        .keyboardType(.numberPad)

                    if let releaseYearValidationMessage {
                        Text(releaseYearValidationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Primera copia") {
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
                }

                Section("Notas de la copia") {
                    TextField("Edición, estado de la caja, procedencia...", text: $copyNotes, axis: .vertical)
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
                    .disabled(!canSave)
                }
            }
        }
    }
#endif

    private func saveGame() {
        let game = Game(
            title: cleanedTitle,
            releaseYear: releaseYear
        )
        let firstCopy = GameCopy(
            platform: platform,
            format: format,
            notes: cleanedCopyNotes
        )

        game.copies.append(firstCopy)

        modelContext.insert(game)
        modelContext.insert(firstCopy)
        dismiss()
    }
}

#Preview {
    GameFormView()
        .modelContainer(for: [Game.self, GameCopy.self, GamePlaythrough.self], inMemory: true)
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
