//
//  GameListViews.swift
//  JuegosApp
//
//  Created by Codex on 23/4/26.
//

import SwiftUI
import SwiftData

struct GameListFormView: View {
    private enum Field {
        case title
    }

    @Environment(\.dismiss) private var dismiss

    let onSave: (String) -> Void

    @State private var title = ""
    @FocusState private var focusedField: Field?

    private var cleanedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
#if os(macOS)
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nueva lista")
                    .font(.title3.weight(.semibold))

                Text("Crea una lista para agrupar y ordenar juegos a tu manera.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                GameListSheetRow(label: "Nombre") {
                    TextField("Pendientes de jugar", text: $title)
                        .focused($focusedField, equals: .title)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320, alignment: .leading)
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
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(cleanedTitle.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 500, idealWidth: 540, minHeight: 220, idealHeight: 240)
        .task {
            focusedField = .title
        }
#else
        NavigationStack {
            Form {
                TextField("Nombre", text: $title)
                    .textInputAutocapitalization(.sentences)
            }
            .navigationTitle("Nueva lista")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                    }
                    .disabled(cleanedTitle.isEmpty)
                }
            }
        }
#endif
    }

    private func save() {
        onSave(cleanedTitle)
        dismiss()
    }
}

#if os(macOS)
private struct GameListSheetRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct GameListsColumnView: View {
    let lists: [GameList]
    @Binding var selectedList: GameList?
    let onCreateList: () -> Void

    private var selectedListID: Binding<PersistentIdentifier?> {
        Binding(
            get: { selectedList?.persistentModelID },
            set: { newValue in
                selectedList = lists.first(where: { $0.persistentModelID == newValue })
            }
        )
    }

    var body: some View {
        Group {
            if lists.isEmpty {
                ContentUnavailableView {
                    Label("Tus listas", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Crea una lista para ordenar juegos por pendientes, favoritos o cualquier criterio propio.")
                } actions: {
                    Button("Nueva lista", action: onCreateList)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: selectedListID) {
                    ForEach(lists) { list in
                        GameListRowContent(list: list)
                            .tag(list.persistentModelID)
                    }
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 54)
            }
        }
    }
}
#endif

enum GameLibraryDetailRoute: Hashable {
    case game(PersistentIdentifier)
    case list(PersistentIdentifier)
}

struct GameListDetailView: View {
    let list: GameList
    let allGames: [Game]
    let allLists: [GameList]
    var onDeleteList: (() -> Void)? = nil
    var onAddCopy: ((Game) -> Void)? = nil
    var onAddPlaythrough: ((GameCopy) -> Void)? = nil
    var onEditGame: ((Game) -> Void)? = nil
    var onImportMetadata: ((Game) -> Void)? = nil
    var onEditCopy: ((GameCopy) -> Void)? = nil
    var onEditPlaythrough: ((GamePlaythrough) -> Void)? = nil

    @State private var navigationPath = [GameLibraryDetailRoute]()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            GameListDetailContentView(
                list: list,
                allGames: allGames,
                onDeleteList: onDeleteList,
                onOpenGame: open,
                onAddCopy: onAddCopy,
                onAddPlaythrough: onAddPlaythrough,
                onEditGame: onEditGame,
                onImportMetadata: onImportMetadata,
                onEditCopy: onEditCopy,
                onEditPlaythrough: onEditPlaythrough
            )
            .navigationDestination(for: GameLibraryDetailRoute.self) { route in
                destination(for: route)
            }
            .onChange(of: list.persistentModelID) {
                navigationPath.removeAll()
            }
        }
    }

    @ViewBuilder
    private func destination(for route: GameLibraryDetailRoute) -> some View {
        switch route {
        case .game(let gameID):
            if let game = allGames.first(where: { $0.persistentModelID == gameID }) {
                GameDetailView(
                    game: game,
                    onAddCopy: {
                        onAddCopy?(game)
                    },
                    onImportMetadata: {
                        onImportMetadata?(game)
                    },
                    onAddPlaythrough: onAddPlaythrough,
                    onEditGame: {
                        onEditGame?(game)
                    },
                    onEditCopy: onEditCopy,
                    onEditPlaythrough: onEditPlaythrough,
                    onOpenList: open
                )
            } else {
                ContentUnavailableView(
                    "Juego no disponible",
                    systemImage: "questionmark.square",
                    description: Text("Este juego ya no está en la biblioteca.")
                )
            }
        case .list(let listID):
            if let list = allLists.first(where: { $0.persistentModelID == listID }) {
                GameListDetailContentView(
                    list: list,
                    allGames: allGames,
                    onOpenGame: open,
                    onAddCopy: onAddCopy,
                    onAddPlaythrough: onAddPlaythrough,
                    onEditGame: onEditGame,
                    onImportMetadata: onImportMetadata,
                    onEditCopy: onEditCopy,
                    onEditPlaythrough: onEditPlaythrough
                )
            } else {
                ContentUnavailableView(
                    "Lista no disponible",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Esta lista ya no está disponible.")
                )
            }
        }
    }

    private func open(_ game: Game) {
        navigationPath.append(.game(game.persistentModelID))
    }

    private func open(_ list: GameList) {
        navigationPath.append(.list(list.persistentModelID))
    }
}

struct GameListDetailContentView: View {
    @Environment(\.modelContext) private var modelContext

    let list: GameList
    let allGames: [Game]
    var onDeleteList: (() -> Void)? = nil
    var onOpenGame: (Game) -> Void
    var onAddCopy: ((Game) -> Void)? = nil
    var onAddPlaythrough: ((GameCopy) -> Void)? = nil
    var onEditGame: ((Game) -> Void)? = nil
    var onImportMetadata: ((Game) -> Void)? = nil
    var onEditCopy: ((GameCopy) -> Void)? = nil
    var onEditPlaythrough: ((GamePlaythrough) -> Void)? = nil

    private var entries: [GameListEntry] {
        list.sortedEntries
    }

    private var availableGames: [Game] {
        allGames.filter { game in
            !list.contains(game)
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 132, maximum: 168), spacing: 28, alignment: .top)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if entries.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        gridHeader

                        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                            ForEach(Array(entries.enumerated()), id: \.element.persistentModelID) { index, entry in
                                if let game = entry.game {
                                    GameListGridCard(
                                        game: game,
                                        position: index + 1,
                                        canMoveBackward: index > 0,
                                        canMoveForward: index < entries.count - 1,
                                        onOpen: {
                                            onOpenGame(game)
                                        },
                                        onMoveBackward: {
                                            move(entry, by: -1)
                                        },
                                        onMoveForward: {
                                            move(entry, by: 1)
                                        },
                                        onRemove: {
                                            remove(entry)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, detailHorizontalPadding)
            .padding(.vertical, 26)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(list.title)
    }

    private var detailHorizontalPadding: CGFloat {
#if os(macOS)
        32
#else
        20
#endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(list.title)
                    .font(.title.weight(.semibold))
                    .textSelection(.enabled)
                    .lineLimit(2)

                Spacer(minLength: 0)

                headerActions
            }

            ViewThatFits(in: .horizontal) {
                metricsRow
                metricsColumn
            }
        }
        .padding(.bottom, 8)
    }

    private var metricsRow: some View {
        HStack(spacing: 0) {
            GameListHeaderMetric(value: "\(list.gameCount)", label: list.gameCount == 1 ? "juego" : "juegos")

            Divider()
                .frame(height: 28)
                .padding(.horizontal, 14)

            GameListHeaderMetric(value: "\(availableGames.count)", label: availableGames.count == 1 ? "disponible" : "disponibles")

            Divider()
                .frame(height: 28)
                .padding(.horizontal, 14)

            Text(headerSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }

    private var metricsColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            GameListHeaderMetric(value: "\(list.gameCount)", label: list.gameCount == 1 ? "juego" : "juegos")
            GameListHeaderMetric(value: "\(availableGames.count)", label: availableGames.count == 1 ? "disponible" : "disponibles")

            Text(headerSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var headerSummary: String {
        let createdAt = list.createdAt.formatted(date: .abbreviated, time: .omitted)
        return "Creada el \(createdAt)"
    }

    private var headerActions: some View {
        ControlGroup {
            headerAddGameMenu

            if let onDeleteList {
                Menu {
                    Button(role: .destructive, action: onDeleteList) {
                        Label("Eliminar lista", systemImage: "trash")
                    }
                } label: {
                    Label("Más", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                }
                .menuIndicator(.hidden)
                .help("Más opciones")
            }
        }
        .controlSize(.small)
        .fixedSize()
    }

    private var headerAddGameMenu: some View {
        Menu {
            addGameMenuItems
        } label: {
            Label("Añadir juego", systemImage: "plus")
                .labelStyle(.iconOnly)
        }
        .menuIndicator(.hidden)
        .help("Añadir juego")
        .disabled(availableGames.isEmpty)
    }

    private var emptyAddGameMenu: some View {
        Menu {
            addGameMenuItems
        } label: {
            Label("Añadir juego", systemImage: "plus")
        }
        .disabled(availableGames.isEmpty)
    }

    @ViewBuilder
    private var addGameMenuItems: some View {
        if availableGames.isEmpty {
            Text("No hay juegos disponibles")
        } else {
            ForEach(availableGames) { game in
                Button(game.title) {
                    add(game)
                }
            }
        }
    }

    private var gridHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Contenido")
                .font(.subheadline.weight(.semibold))

            Text("Orden manual")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("Usa el menú de cada juego para reordenar.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Lista vacía", systemImage: "square.grid.2x2")
        } description: {
            Text("Añade juegos para empezar a ordenar esta lista.")
        } actions: {
            emptyAddGameMenu
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private func add(_ game: Game) {
        let entry = GameListEntry(game: game, sortIndex: list.nextSortIndex)
        list.addEntry(entry)
        modelContext.insert(entry)
    }

    private func remove(_ entry: GameListEntry) {
        modelContext.delete(entry)
        normalizeOrder(excluding: entry)
    }

    private func move(_ entry: GameListEntry, by offset: Int) {
        var reorderedEntries = entries
        guard let currentIndex = reorderedEntries.firstIndex(where: { $0.persistentModelID == entry.persistentModelID }) else {
            return
        }

        let targetIndex = max(0, min(reorderedEntries.count - 1, currentIndex + offset))
        guard targetIndex != currentIndex else { return }

        let movedEntry = reorderedEntries.remove(at: currentIndex)
        reorderedEntries.insert(movedEntry, at: targetIndex)

        for (index, entry) in reorderedEntries.enumerated() {
            entry.sortIndex = index
        }
    }

    private func normalizeOrder(excluding deletedEntry: GameListEntry? = nil) {
        let remainingEntries = entries.filter { entry in
            entry.persistentModelID != deletedEntry?.persistentModelID
        }

        for (index, entry) in remainingEntries.enumerated() {
            entry.sortIndex = index
        }
    }
}

private struct GameListHeaderMetric: View {
    let value: String
    let label: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct GameListGridCard: View {
    let game: Game
    let position: Int
    let canMoveBackward: Bool
    let canMoveForward: Bool
    let onOpen: () -> Void
    let onMoveBackward: () -> Void
    let onMoveForward: () -> Void
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 9) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .topLeading) {
                    GameCoverArtwork(
                        title: game.title,
                        coverURL: game.coverURL,
                        size: CGSize(width: 104, height: 148),
                        cornerRadius: 14
                    )

                    Text("\(position)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.regularMaterial, in: Capsule(style: .continuous))
                        .padding(6)
                }
                .scaleEffect(isHovering ? 1.015 : 1)
                .shadow(color: .black.opacity(isHovering ? 0.10 : 0.045), radius: isHovering ? 9 : 5, y: 4)
                .onTapGesture(perform: onOpen)

                cardMenu
                    .padding(6)
                    .opacity(showsInlineMenu ? 1 : 0)
                    .allowsHitTesting(showsInlineMenu)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 3) {
                Text(game.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(game.platformSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !game.detailSummary.isEmpty {
                    Text(game.detailSummary)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .onTapGesture(perform: onOpen)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(minHeight: 228, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isHovering ? Color.accentColor.opacity(0.10) : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu {
            cardMenuItems
        }
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.16), value: isHovering)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(position). \(game.title)")
        .accessibilityHint("Abre la ficha del juego.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Abrir", onOpen)
        .accessibilityAction(named: "Mover antes", onMoveBackward)
        .accessibilityAction(named: "Mover después", onMoveForward)
    }

    private var showsInlineMenu: Bool {
#if os(macOS)
        isHovering
#else
        true
#endif
    }

    private var cardMenu: some View {
        Menu {
            cardMenuItems
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .background(.regularMaterial, in: Circle())
        }
        .menuIndicator(.hidden)
        .buttonStyle(.borderless)
        .help("Opciones de lista")
    }

    @ViewBuilder
    private var cardMenuItems: some View {
        Button {
            onMoveBackward()
        } label: {
            Label("Mover antes", systemImage: "arrow.left")
        }
        .disabled(!canMoveBackward)

        Button {
            onMoveForward()
        } label: {
            Label("Mover después", systemImage: "arrow.right")
        }
        .disabled(!canMoveForward)

        Divider()

        Button(role: .destructive, action: onRemove) {
            Label("Quitar de la lista", systemImage: "minus.circle")
        }
    }
}

struct GameListSelectionPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Selecciona una lista",
            systemImage: "list.bullet.rectangle",
            description: Text("Elige una lista para ver sus juegos.")
        )
    }
}

#Preview("Lista") {
    let game = Game(title: "The Legend of Zelda: Tears of the Kingdom", releaseYear: 2023)
    let anotherGame = Game(title: "Metroid Prime Remastered", releaseYear: 2023)
    let list = GameList(title: "Pendientes")
    list.addEntry(GameListEntry(game: game, sortIndex: 0))
    list.addEntry(GameListEntry(game: anotherGame, sortIndex: 1))

    return GameListDetailView(list: list, allGames: [game, anotherGame], allLists: [list])
        .modelContainer(for: [Game.self, GameList.self, GameListEntry.self, GameCopy.self, GamePlaythrough.self], inMemory: true)
}
