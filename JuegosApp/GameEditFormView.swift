//
//  GameEditFormView.swift
//  JuegosApp
//
//  Created by Codex on 23/4/26.
//

import SwiftUI
import SwiftData

struct GameEditFormView: View {
    private enum Field {
        case title
    }

    @Environment(\.dismiss) private var dismiss

    let game: Game

    @State private var title: String
    @State private var releaseYearText: String
    @FocusState private var focusedField: Field?

    init(game: Game) {
        self.game = game
        _title = State(initialValue: game.title)
        _releaseYearText = State(initialValue: game.releaseYear.map(String.init) ?? "")
    }

    private var cleanedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var releaseYear: Int? {
        let trimmed = releaseYearText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
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
                Text("Editar juego")
                    .font(.title3.weight(.semibold))

                Text("Actualiza la informacion general del titulo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                GameEditSheetSection(title: "Juego", help: "Estos datos se aplican a todas las copias del juego.") {
                    GameEditSheetRow(label: "Titulo") {
                        TextField("The Legend of Zelda", text: $title)
                            .focused($focusedField, equals: .title)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 320, alignment: .leading)
                    }

                    GameEditSheetRow(label: "Ano") {
                        TextField("2024", text: $releaseYearText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100, alignment: .leading)
                    }
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
                    saveGame()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(cleanedTitle.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 520, idealWidth: 580, minHeight: 300, idealHeight: 340)
        .task {
            focusedField = .title
        }
    }
#else
    private var iosForm: some View {
        NavigationStack {
            Form {
                Section("Juego") {
                    TextField("Titulo", text: $title)

                    TextField("Ano de lanzamiento", text: $releaseYearText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Editar juego")
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
        game.title = cleanedTitle
        game.releaseYear = releaseYear
        dismiss()
    }
}

#if os(macOS)
private struct GameEditSheetSection<Content: View>: View {
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

private struct GameEditSheetRow<Content: View>: View {
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

    return GameEditFormView(game: game)
        .modelContainer(for: [Game.self, GameCopy.self, GamePlaythrough.self], inMemory: true)
}
