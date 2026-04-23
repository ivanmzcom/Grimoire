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
    @State private var hasStartedAt: Bool
    @State private var startedAt: Date
    @State private var hasCompletedAt: Bool
    @State private var completedAt: Date
    @State private var hoursPlayed: String
    @State private var personalRating: Int
    @State private var difficulty: String

    init(playthrough: GamePlaythrough) {
        self.playthrough = playthrough
        _status = State(initialValue: playthrough.status)
        _notes = State(initialValue: playthrough.notes)
        _hasStartedAt = State(initialValue: playthrough.startedAt != nil)
        _startedAt = State(initialValue: playthrough.startedAt ?? .now)
        _hasCompletedAt = State(initialValue: playthrough.completedAt != nil)
        _completedAt = State(initialValue: playthrough.completedAt ?? .now)
        _hoursPlayed = State(initialValue: playthrough.hoursPlayed.map { Self.hoursFormatter.string(from: NSNumber(value: $0)) ?? "\($0)" } ?? "")
        _personalRating = State(initialValue: playthrough.personalRating ?? 0)
        _difficulty = State(initialValue: playthrough.difficulty)
    }

    private static let hoursFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.numberStyle = .decimal
        return formatter
    }()

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
            ? "Añade contexto de esta partida, ruta, personaje o cualquier detalle útil."
            : cleanedNotes
    }

    private var difficultyOptions: [String] {
        if difficulty.isEmpty || GameCatalog.difficulties.contains(difficulty) {
            return GameCatalog.difficulties
        }

        return [difficulty] + GameCatalog.difficulties
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
                    title: "Fechas",
                    help: "Marca cuándo empezó o terminó esta partida si quieres llevar histórico."
                ) {
                    PlaythroughEditSheetDateRow(
                        label: "Inicio",
                        isEnabled: $hasStartedAt,
                        date: $startedAt
                    )

                    PlaythroughEditSheetDateRow(
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

                PlaythroughEditSheetSection(
                    title: "Experiencia",
                    help: "Registra duración, valoración personal y dificultad elegida."
                ) {
                    PlaythroughEditSheetRow(label: "Horas") {
                        TextField("Opcional", text: $hoursPlayed)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }

                    if !hasValidHoursPlayed {
                        Text("Introduce un número de horas válido.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    PlaythroughEditSheetRow(label: "Valoración") {
                        Picker("", selection: $personalRating) {
                            Text("Sin valorar").tag(0)

                            ForEach(1...10, id: \.self) { rating in
                                Text("\(rating)/10").tag(rating)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160, alignment: .leading)
                    }

                    PlaythroughEditSheetRow(label: "Dificultad") {
                        Picker("", selection: $difficulty) {
                            Text("Sin definir").tag("")

                            ForEach(difficultyOptions, id: \.self) { option in
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
                        if status.isEmpty {
                            Text("Sin estado").tag("")
                        }

                        ForEach(statusOptions, id: \.self) { option in
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

                        ForEach(difficultyOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

                Section("Notas") {
                    TextField("Ruta, personaje, contexto...", text: $notes, axis: .vertical)
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
                    .disabled(!canSave)
                }
            }
        }
    }
#endif

    private func savePlaythrough() {
        playthrough.status = status
        playthrough.notes = cleanedNotes
        playthrough.startedAt = hasStartedAt ? startedAt : nil
        playthrough.completedAt = hasCompletedAt ? completedAt : nil
        playthrough.hoursPlayed = parsedHoursPlayed
        playthrough.personalRating = personalRating == 0 ? nil : personalRating
        playthrough.difficulty = cleanedDifficulty
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

private struct PlaythroughEditSheetDateRow: View {
    let label: String
    @Binding var isEnabled: Bool
    @Binding var date: Date

    var body: some View {
        PlaythroughEditSheetRow(label: label) {
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
    let game = Game(title: "Metroid Prime Remastered", releaseYear: 2023)
    let copy = GameCopy(platform: "Nintendo Switch", format: "Físico", notes: "Edición launch")
    let playthrough = GamePlaythrough(status: "Jugando", notes: "Ruta casual al 63%.")

    game.addCopy(copy)
    copy.addPlaythrough(playthrough)

    return GamePlaythroughEditFormView(playthrough: playthrough)
        .modelContainer(for: [Game.self, GameCopy.self, GamePlaythrough.self, GameTag.self, GameTagAssignment.self], inMemory: true)
}
