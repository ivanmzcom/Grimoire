//
//  GameCopyEditFormView.swift
//  JuegosApp
//
//  Created by Codex on 23/4/26.
//

import SwiftUI
import SwiftData

struct GameCopyEditFormView: View {
    @Environment(\.dismiss) private var dismiss

    let copy: GameCopy

    @State private var platform: String
    @State private var format: String
    @State private var notes: String

    init(copy: GameCopy) {
        self.copy = copy
        _platform = State(initialValue: copy.platform)
        _format = State(initialValue: copy.format)
        _notes = State(initialValue: copy.notes)
    }

    private var platformOptions: [String] {
        options(from: GameCatalog.platforms, including: platform)
    }

    private var formatOptions: [String] {
        options(from: GameCatalog.formats, including: format)
    }

    private var cleanedNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var notesPreview: String {
        cleanedNotes.isEmpty
            ? "Añade detalles de esta unidad si quieres distinguirla del resto."
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
                Text("Editar copia")
                    .font(.title3.weight(.semibold))

                if let title = copy.game?.title {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    EditCopySheetSection(title: "Copia", help: "Actualiza los datos de esta unidad.") {
                        EditCopySheetRow(label: "Plataforma") {
                            Picker("", selection: $platform) {
                                ForEach(platformOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 220, alignment: .leading)
                        }

                        EditCopySheetRow(label: "Formato") {
                            Picker("", selection: $format) {
                                ForEach(formatOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180, alignment: .leading)
                        }
                    }

                    EditCopySheetSection(title: "Notas de la copia", help: "Datos opcionales para distinguir esta unidad.") {
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
                            .foregroundStyle(cleanedNotes.isEmpty ? .tertiary : .secondary)
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
                    saveCopy()
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
                Section("Copia") {
                    Picker("Plataforma", selection: $platform) {
                        ForEach(platformOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }

                    Picker("Formato", selection: $format) {
                        ForEach(formatOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

                Section("Notas de la copia") {
                    TextField("Edicion, estado de la caja, procedencia...", text: $notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle("Editar copia")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveCopy()
                    }
                }
            }
        }
    }
#endif

    private func saveCopy() {
        copy.platform = platform
        copy.format = format
        copy.notes = cleanedNotes
        dismiss()
    }

    private func options(from catalogOptions: [String], including currentValue: String) -> [String] {
        guard !currentValue.isEmpty, !catalogOptions.contains(currentValue) else {
            return catalogOptions
        }

        return [currentValue] + catalogOptions
    }
}

#if os(macOS)
private struct EditCopySheetSection<Content: View>: View {
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

private struct EditCopySheetRow<Content: View>: View {
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
    let game = Game(title: "Metaphor: ReFantazio", releaseYear: 2024)
    let copy = GameCopy(
        platform: "PlayStation 5",
        format: "Fisico",
        notes: "Edicion estándar con caja en buen estado."
    )

    game.copies.append(copy)

    return GameCopyEditFormView(copy: copy)
        .modelContainer(for: [Game.self, GameCopy.self, GamePlaythrough.self], inMemory: true)
}
