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
    var onOpenList: ((GameList) -> Void)? = nil

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
                            .font(.title.weight(.semibold))
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
                }

                Divider()

                GameMetadataGrid(game: game)

                Divider()

                GameIncludedInSection(game: game, onOpenList: onOpenList)

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
        .toolbar {
            if hasGameActions {
                ToolbarItem(placement: .primaryAction) {
                    gameActionsMenu
                }
            }
        }
#else
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(game.title)
                        .font(.title2.weight(.semibold))
                        .lineLimit(3)

                    if !gameSummary.isEmpty {
                        Text(gameSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Ficha") {
                DetailRow(label: "Año", value: game.releaseYear.map(String.init) ?? "Sin indicar")
                DetailRow(label: "Copias", value: copyCountLabel)
                DetailRow(label: "Partidas", value: game.playthroughCountLabel)
                DetailRow(label: "Añadido", value: game.createdAt.formatted(date: .abbreviated, time: .omitted))
            }

            Section("Incluido en") {
                GameIncludedInSection(game: game, showsTitle: false, onOpenList: onOpenList)
            }

            Section("Copias") {
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
        .listStyle(.insetGrouped)
        .navigationTitle(game.title)
        .toolbar {
            if hasGameActions {
                ToolbarItem(placement: .primaryAction) {
                    gameActionsMenu
                }
            }
        }
#endif
    }

    private var hasGameActions: Bool {
        onEditGame != nil || onAddCopy != nil
    }

    private var gameActionsMenu: some View {
        Menu {
            if let onEditGame {
                Button(action: onEditGame) {
                    Label("Editar juego", systemImage: "pencil")
                }
            }

            if let onAddCopy {
                Button(action: onAddCopy) {
                    Label("Añadir copia", systemImage: "square.stack.badge.plus")
                }
            }
        } label: {
            Label("Acciones", systemImage: "ellipsis.circle")
        }
    }
}

#if os(macOS)
private struct GameMetadataGrid: View {
    let game: Game

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
            GridRow {
                Text("Año")
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
                Text("Añadido")
                    .foregroundStyle(.secondary)
                Text(game.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .textSelection(.enabled)
            }
        }
    }
}
#endif

private struct GameIncludedInSection: View {
    let game: Game
    var showsTitle = true
    var onOpenList: ((GameList) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsTitle {
                Text("Incluido en")
                    .font(.headline)
            }

            if game.includedLists.isEmpty {
                Text("Este juego no está incluido en ninguna lista.")
                    .foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(game.includedLists.enumerated()), id: \.element.persistentModelID) { index, list in
                        if index > 0 {
                            Divider()
                        }

                        if let onOpenList {
                            Button {
                                onOpenList(list)
                            } label: {
                                GameIncludedListRow(list: list, showsChevron: true)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 9)
                        } else {
                            GameIncludedListRow(list: list)
                                .padding(.vertical, 9)
                        }
                    }
                }
            }
        }
    }
}

private struct GameIncludedListRow: View {
    let list: GameList
    var showsChevron = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "list.bullet.rectangle")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(list.title)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(list.gameCountLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

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
                        Button(action: onAddCopy) {
                            Label("Añadir copia", systemImage: "plus")
                        }
                            .platformInlineActionButtonStyle()
                    }
                }
            }

            if game.sortedCopies.isEmpty {
                Text("Todavía no hay copias registradas para este juego.")
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
                    Button {
                        onEditCopy(copy)
                    } label: {
                        Label("Editar copia", systemImage: "pencil")
                    }
                    .labelStyle(.iconOnly)
                    .platformInlineActionButtonStyle()
                    .help("Editar copia")
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
                        Button {
                            onAddPlaythrough(copy)
                        } label: {
                            Label("Añadir partida", systemImage: "plus")
                        }
                        .platformInlineActionButtonStyle()
                    }
                }

                if copy.sortedPlaythroughs.isEmpty {
                    Text("Todavía no hay partidas registradas para esta copia.")
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
        .accessibilityElement(children: .contain)
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
                    Button {
                        onEdit(playthrough)
                    } label: {
                        Label("Editar partida", systemImage: "pencil")
                    }
                    .labelStyle(.iconOnly)
                    .platformInlineActionButtonStyle()
                    .help("Editar partida")
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
        .accessibilityElement(children: .combine)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        LabeledContent(label, value: value)
    }
}

private extension View {
    @ViewBuilder
    func platformInlineActionButtonStyle() -> some View {
#if os(macOS)
        buttonStyle(.link)
#else
        buttonStyle(.borderless)
#endif
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
            format: "Físico",
            notes: "Edición estándar con funda en buen estado."
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
