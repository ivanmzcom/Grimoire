//
//  GameDetailView.swift
//  JuegosApp
//
//  Created by Codex on 23/4/26.
//

import SwiftUI
import SwiftData

struct GameDetailView: View {
    let game: Game
    var onAddCopy: (() -> Void)? = nil
    var onAddPlaythrough: ((GameCopy) -> Void)? = nil
    var onEditGame: (() -> Void)? = nil
    var onEditCopy: ((GameCopy) -> Void)? = nil
    var onEditPlaythrough: ((GamePlaythrough) -> Void)? = nil

    private var copyCountLabel: String {
        game.copyCount == 1 ? "1 copia" : "\(game.copyCount) copias"
    }

    private var gameSummary: String {
        game.releaseYear.map(String.init) ?? ""
    }

    var body: some View {
#if os(macOS)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 18) {
                    GameCoverPlaceholder(
                        title: game.title,
                        size: CGSize(width: 84, height: 112),
                        cornerRadius: 14
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(game.title)
                            .font(.largeTitle.weight(.semibold))
                            .textSelection(.enabled)

                        if !gameSummary.isEmpty {
                            Text(gameSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Text("Añadido el \(game.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 0)

                    if let onEditGame {
                        Button("Editar", action: onEditGame)
                            .buttonStyle(.bordered)
                    }
                }

                Divider()

                GameMetadataGrid(game: game)

                Divider()

                GameCopiesSection(
                    game: game,
                    onAddCopy: onAddCopy,
                    onAddPlaythrough: onAddPlaythrough,
                    onEditCopy: onEditCopy,
                    onEditPlaythrough: onEditPlaythrough
                )
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(game.title)
#else
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(game.title)
                            .font(.system(size: 34, weight: .bold, design: .rounded))

                        Spacer()

                        if let onEditGame {
                            Button("Editar", action: onEditGame)
                        }
                    }

                    if !gameSummary.isEmpty {
                        Text(gameSummary)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                DetailCard(title: "Ficha") {
                    DetailRow(label: "Ano", value: game.releaseYear.map(String.init) ?? "Sin indicar")
                    DetailRow(label: "Copias", value: copyCountLabel)
                    DetailRow(label: "Partidas", value: game.playthroughCountLabel)
                    DetailRow(label: "Anadido", value: game.createdAt.formatted(date: .abbreviated, time: .omitted))
                }

                DetailCard(title: "Copias") {
                    GameCopiesSection(
                        game: game,
                        onAddCopy: onAddCopy,
                        onAddPlaythrough: onAddPlaythrough,
                        onEditCopy: onEditCopy,
                        onEditPlaythrough: onEditPlaythrough,
                        showsTitle: false
                    )
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle(game.title)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
#endif
    }
}

#if os(macOS)
private struct GameMetadataGrid: View {
    let game: Game

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
            GridRow {
                Text("Ano")
                    .foregroundStyle(.secondary)
                Text(game.releaseYear.map(String.init) ?? "Sin indicar")
                    .textSelection(.enabled)
            }

            GridRow {
                Text("Copias")
                    .foregroundStyle(.secondary)
                Text(game.copyCount == 1 ? "1 copia registrada" : "\(game.copyCount) copias registradas")
                    .textSelection(.enabled)
            }

            GridRow {
                Text("Partidas")
                    .foregroundStyle(.secondary)
                Text(game.playthroughCountLabel)
                    .textSelection(.enabled)
            }

            GridRow {
                Text("Anadido")
                    .foregroundStyle(.secondary)
                Text(game.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .textSelection(.enabled)
            }
        }
    }
}
#endif

private struct GameCopiesSection: View {
    let game: Game
    var onAddCopy: (() -> Void)?
    var onAddPlaythrough: ((GameCopy) -> Void)?
    var onEditCopy: ((GameCopy) -> Void)?
    var onEditPlaythrough: ((GamePlaythrough) -> Void)?
    var showsTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsTitle || onAddCopy != nil {
                HStack {
                    if showsTitle {
                        Text("Copias")
                            .font(.headline)
                    }

                    Spacer()

                    if let onAddCopy {
                        Button("Añadir copia", action: onAddCopy)
                            .buttonStyle(.link)
                    }
                }
            }

            if game.sortedCopies.isEmpty {
                Text("Todavia no hay copias registradas para este juego.")
                    .foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(game.sortedCopies.enumerated()), id: \.element.persistentModelID) { index, copy in
                        if index > 0 {
                            Divider()
                        }

                        GameCopyRow(
                            copy: copy,
                            onAddPlaythrough: onAddPlaythrough,
                            onEditCopy: onEditCopy,
                            onEditPlaythrough: onEditPlaythrough
                        )
                            .padding(.vertical, 12)
                    }
                }
            }
        }
    }
}

private struct GameCopyRow: View {
    let copy: GameCopy
    var onAddPlaythrough: ((GameCopy) -> Void)?
    var onEditCopy: ((GameCopy) -> Void)?
    var onEditPlaythrough: ((GamePlaythrough) -> Void)?

    private var subtitle: String {
        [
            copy.format,
            copy.createdAt.formatted(date: .abbreviated, time: .omitted)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(copy.platform)
                    .font(.body.weight(.semibold))

                Spacer(minLength: 8)

                if let onEditCopy {
                    Button("Editar") {
                        onEditCopy(copy)
                    }
                    .buttonStyle(.link)
                }

            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !copy.notes.isEmpty {
                Text(copy.notes)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(copy.playthroughCount == 0 ? "Sin partidas" : copy.playthroughCountLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let onAddPlaythrough {
                        Button("Añadir partida") {
                            onAddPlaythrough(copy)
                        }
                        .buttonStyle(.link)
                    }
                }

                if copy.sortedPlaythroughs.isEmpty {
                    Text("Todavia no hay partidas registradas para esta copia.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(copy.sortedPlaythroughs.enumerated()), id: \.element.persistentModelID) { index, playthrough in
                            GamePlaythroughRow(
                                playthrough: playthrough,
                                number: index + 1,
                                onEdit: onEditPlaythrough
                            )
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GamePlaythroughRow: View {
    let playthrough: GamePlaythrough
    let number: Int
    var onEdit: ((GamePlaythrough) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Partida \(number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)

                Text(playthrough.status)
                    .font(.body)

                Spacer(minLength: 8)

                if let onEdit {
                    Button("Editar") {
                        onEdit(playthrough)
                    }
                    .buttonStyle(.link)
                }

                Text(playthrough.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if !playthrough.notes.isEmpty {
                Text(playthrough.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 74)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    let game = Game(
        title: "The Legend of Zelda: Tears of the Kingdom",
        releaseYear: 2023
    )
    game.copies.append(
        GameCopy(
            platform: "Nintendo Switch",
            format: "Fisico",
            notes: "Edicion estandar con funda en buen estado."
        )
    )
    game.copies.append(
        GameCopy(
            platform: "Nintendo Switch",
            format: "Digital"
        )
    )

    game.copies[0].playthroughs.append(GamePlaythrough(status: "Jugando"))
    game.copies[0].playthroughs.append(GamePlaythrough(status: "Completado"))
    game.copies[1].playthroughs.append(GamePlaythrough(status: "Archivado"))

    return GameDetailView(game: game)
}
