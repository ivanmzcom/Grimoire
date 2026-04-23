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
    @State private var hasStartedAt = false
    @State private var startedAt = Date.now
    @State private var hasCompletedAt = false
    @State private var completedAt = Date.now
    @State private var hoursPlayed = ""
    @State private var personalRating = 0
    @State private var difficulty = ""

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
            ? "Añade contexto de esta partida, ruta, personaje o cualquier detalle útil."
            : cleanedNotes
    }

    private var cleanedDifficulty: String {
        difficulty.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedHoursPlayed: Double? {
        let cleanedValue = hoursPlayed
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !cleanedValue.isEmpty else { return nil }
        return Double(cleanedValue)
    }

    private var hasValidHoursPlayed: Bool {
        guard let parsedHoursPlayed else {
            return hoursPlayed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return parsedHoursPlayed >= 0
    }

    private var hasValidDateRange: Bool {
        guard hasStartedAt, hasCompletedAt else { return true }
        return startedAt <= completedAt
    }

    private var canSave: Bool {
        hasValidHoursPlayed && hasValidDateRange
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
                    title: "Fechas",
                    help: "Marca cuándo empezó o terminó esta partida si quieres llevar histórico."
                ) {
                    PlaythroughSheetDateRow(
                        label: "Inicio",
                        isEnabled: $hasStartedAt,
                        date: $startedAt
                    )

                    PlaythroughSheetDateRow(
                        label: "Finalización",
                        isEnabled: $hasCompletedAt,
                        date: $completedAt
                    )

                    if !hasValidDateRange {
                        Text("La fecha de finalización no puede ser anterior a la de inicio.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                PlaythroughSheetSection(
                    title: "Experiencia",
                    help: "Registra duración, valoración personal y dificultad elegida."
                ) {
                    PlaythroughSheetRow(label: "Horas") {
                        TextField("Opcional", text: $hoursPlayed)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }

                    if !hasValidHoursPlayed {
                        Text("Introduce un número de horas válido.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    PlaythroughSheetRow(label: "Valoración") {
                        Picker("", selection: $personalRating) {
                            Text("Sin valorar").tag(0)

                            ForEach(1...10, id: \.self) { rating in
                                Text("\(rating)/10").tag(rating)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160, alignment: .leading)
                    }

                    PlaythroughSheetRow(label: "Dificultad") {
                        Picker("", selection: $difficulty) {
                            Text("Sin definir").tag("")

                            ForEach(GameCatalog.difficulties, id: \.self) { option in
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
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 660, idealHeight: 720)
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

                Section("Fechas") {
                    Toggle("Fecha de inicio", isOn: $hasStartedAt)

                    if hasStartedAt {
                        DatePicker("Inicio", selection: $startedAt, displayedComponents: .date)
                    }

                    Toggle("Fecha de finalización", isOn: $hasCompletedAt)

                    if hasCompletedAt {
                        DatePicker("Finalización", selection: $completedAt, displayedComponents: .date)
                    }

                    if !hasValidDateRange {
                        Text("La fecha de finalización no puede ser anterior a la de inicio.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Experiencia") {
                    TextField("Horas jugadas", text: $hoursPlayed)
                        .keyboardType(.decimalPad)

                    if !hasValidHoursPlayed {
                        Text("Introduce un número de horas válido.")
                            .foregroundStyle(.red)
                    }

                    Picker("Valoración", selection: $personalRating) {
                        Text("Sin valorar").tag(0)

                        ForEach(1...10, id: \.self) { rating in
                            Text("\(rating)/10").tag(rating)
                        }
                    }

                    Picker("Dificultad", selection: $difficulty) {
                        Text("Sin definir").tag("")

                        ForEach(GameCatalog.difficulties, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

                Section("Notas") {
                    TextField("Ruta, personaje, contexto...", text: $notes, axis: .vertical)
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
                    .disabled(!canSave)
                }
            }
        }
    }
#endif

    private func savePlaythrough() {
        let playthrough = GamePlaythrough(
            status: status,
            notes: cleanedNotes,
            startedAt: hasStartedAt ? startedAt : nil,
            completedAt: hasCompletedAt ? completedAt : nil,
            hoursPlayed: parsedHoursPlayed,
            personalRating: personalRating == 0 ? nil : personalRating,
            difficulty: cleanedDifficulty
        )
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

private struct PlaythroughSheetDateRow: View {
    let label: String
    @Binding var isEnabled: Bool
    @Binding var date: Date

    var body: some View {
        PlaythroughSheetRow(label: label) {
            HStack(spacing: 12) {
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()

                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .disabled(!isEnabled)
            }
        }
    }
}
#endif

#Preview {
    let copy = GameCopy(platform: "PlayStation 5", format: "Físico", notes: "Edición launch")

    return GamePlaythroughFormView(copy: copy)
        .modelContainer(for: [Game.self, GameCopy.self, GamePlaythrough.self, GameTag.self, GameTagAssignment.self], inMemory: true)
}
