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

    private var copyCountLabel: String {
        game.copyCount == 1 ? "1 copia" : "\(game.copyCount) copias"
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

                        Text(game.detailSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(game.platformSummary)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Text("Añadido el \(game.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 0)
                }

                Divider()

                GameMetadataGrid(game: game)

                Divider()

                GameCopiesSection(game: game, onAddCopy: onAddCopy)
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
                    Text(game.title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text(game.detailSummary)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text(game.platformSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                DetailCard(title: "Ficha") {
                    DetailRow(label: "Genero", value: game.genre)
                    DetailRow(label: "Ano", value: game.releaseYear.map(String.init) ?? "Sin indicar")
                    DetailRow(label: "Plataformas", value: game.platformSummary)
                    DetailRow(label: "Copias", value: copyCountLabel)
                }

                DetailCard(title: "Copias") {
                    GameCopiesSection(game: game, onAddCopy: onAddCopy, showsTitle: false)
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
                Text("Genero")
                    .foregroundStyle(.secondary)
                Text(game.genre)
                    .textSelection(.enabled)
            }

            GridRow {
                Text("Ano")
                    .foregroundStyle(.secondary)
                Text(game.releaseYear.map(String.init) ?? "Sin indicar")
                    .textSelection(.enabled)
            }

            GridRow {
                Text("Plataformas")
                    .foregroundStyle(.secondary)
                Text(game.platformSummary)
                    .textSelection(.enabled)
            }

            GridRow {
                Text("Copias")
                    .foregroundStyle(.secondary)
                Text(game.copyCount == 1 ? "1 copia registrada" : "\(game.copyCount) copias registradas")
                    .textSelection(.enabled)
            }
        }
    }
}
#endif

private struct GameCopiesSection: View {
    let game: Game
    var onAddCopy: (() -> Void)?
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

                        GameCopyRow(copy: copy)
                            .padding(.vertical, 12)
                    }
                }
            }
        }
    }
}

private struct GameCopyRow: View {
    let copy: GameCopy

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

                Text(copy.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        genre: "Aventura",
        releaseYear: 2023
    )
    game.copies.append(
        GameCopy(
            platform: "Nintendo Switch",
            format: "Fisico",
            status: "Jugando",
            notes: "Edicion estandar con funda en buen estado."
        )
    )
    game.copies.append(
        GameCopy(
            platform: "Nintendo Switch",
            format: "Digital",
            status: "Archivado"
        )
    )

    return GameDetailView(game: game)
}
