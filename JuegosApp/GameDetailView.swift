//
//  GameDetailView.swift
//  JuegosApp
//
//  Created by Codex on 23/4/26.
//

import SwiftUI

struct GameDetailView: View {
    let game: Game

    private var metadataLine: String {
        [
            game.platform,
            game.format,
            game.status,
            game.genre
        ]
        .joined(separator: " · ")
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

                        Text(metadataLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Anadido el \(game.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 0)
                }

                Divider()

                GameMetadataGrid(game: game)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Notas")
                        .font(.headline)

                    if game.notes.isEmpty {
                        Text("Sin notas todavia.")
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(game.notes)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
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
                    Label(game.platform, systemImage: "gamecontroller.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    DetailBadge(text: game.format)
                    DetailBadge(text: game.status)
                    DetailBadge(text: game.genre)
                }

                DetailCard(title: "Ficha") {
                    DetailRow(label: "Formato", value: game.format)
                    DetailRow(label: "Estado", value: game.status)
                    DetailRow(label: "Genero", value: game.genre)
                    DetailRow(label: "Ano", value: game.releaseYear.map(String.init) ?? "Sin indicar")
                    DetailRow(
                        label: "Anadido",
                        value: game.createdAt.formatted(date: .abbreviated, time: .omitted)
                    )
                }

                if !game.notes.isEmpty {
                    DetailCard(title: "Notas") {
                        Text(game.notes)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.primary)
                    }
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
                Text("Plataforma")
                    .foregroundStyle(.secondary)
                Text(game.platform)
                    .textSelection(.enabled)
            }

            GridRow {
                Text("Formato")
                    .foregroundStyle(.secondary)
                Text(game.format)
                    .textSelection(.enabled)
            }

            GridRow {
                Text("Estado")
                    .foregroundStyle(.secondary)
                Text(game.status)
                    .textSelection(.enabled)
            }

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
        }
    }
}
#endif

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
    GameDetailView(
        game: Game(
            title: "The Legend of Zelda: Tears of the Kingdom",
            platform: "Nintendo Switch",
            format: "Fisico",
            status: "Jugando",
            genre: "Aventura",
            releaseYear: 2023,
            notes: "Edicion estandar"
        )
    )
}
