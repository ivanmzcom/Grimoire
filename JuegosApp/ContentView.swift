//
//  ContentView.swift
//  JuegosApp
//
//  Created by Iván Moreno Zambudio on 23/4/26.
//

import SwiftUI
import SwiftData

extension Notification.Name {
    static let openNewGame = Notification.Name("OpenNewGame")
    static let openNewList = Notification.Name("OpenNewList")
}

private enum LibrarySidebarItem {
    static let allGames = "Todas"
    static let lists = "__lists__"
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Game.title)]) private var games: [Game]
    @Query(sort: [SortDescriptor(\GameList.createdAt)]) private var gameLists: [GameList]

    @SceneStorage("librarySearchText") private var searchText = ""
    @SceneStorage("selectedPlatformFilter") private var selectedPlatform = LibrarySidebarItem.allGames
    @State private var selectedGame: Game?
    @State private var selectedGameList: GameList?
    @State private var gamesNavigationPath = [GameLibraryDetailRoute]()
    @State private var listsNavigationPath = [GameLibraryDetailRoute]()
    @State private var showingAddSheet = false
    @State private var showingListSheet = false
    @State private var copyHostGame: Game?
    @State private var playthroughHostCopy: GameCopy?
    @State private var metadataImportGame: Game?
    @State private var copyToEdit: GameCopy?
    @State private var playthroughToEdit: GamePlaythrough?

    private var usedPlatforms: [String] {
        let platformsInLibrary = Set(
            games.flatMap { game in
                game.sortedCopies.map(\.platform)
            }
            .filter { !$0.isEmpty }
        )

        let catalogPlatforms = GameCatalog.platforms.filter { platform in
            platformsInLibrary.contains(platform)
        }

        let customPlatforms = platformsInLibrary
            .filter { platform in
                !GameCatalog.platforms.contains(platform)
            }
            .sorted { lhs, rhs in
                lhs.localizedStandardCompare(rhs) == .orderedAscending
            }

        return catalogPlatforms + customPlatforms
    }

    private var platformOptions: [String] {
        [LibrarySidebarItem.allGames] + usedPlatforms
    }

    private var isShowingLists: Bool {
        selectedPlatform == LibrarySidebarItem.lists
    }

    private var filteredGames: [Game] {
        games.filter { game in
            let matchesPlatform = selectedPlatform == LibrarySidebarItem.allGames
                || isShowingLists
                || game.sortedCopies.contains(where: { $0.platform == selectedPlatform })
            let matchesSearch = searchText.isEmpty
                || containsSearchText(in: game.title)
                || containsSearchText(in: game.searchableCopyText)
            return matchesPlatform && matchesSearch
        }
    }

    private var filteredGameLists: [GameList] {
        gameLists.filter { list in
            searchText.isEmpty
                || containsSearchText(in: list.title)
                || list.games.contains { game in
                    containsSearchText(in: game.title)
                }
        }
    }

    private var filteredGameIDs: [PersistentIdentifier] {
        filteredGames.map(\.persistentModelID)
    }

    private var filteredGameListIDs: [PersistentIdentifier] {
        filteredGameLists.map(\.persistentModelID)
    }

    private func containsSearchText(in value: String) -> Bool {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else { return true }

        return value.range(
            of: trimmedSearchText,
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        ) != nil
    }

    var body: some View {
        Group {
#if os(macOS)
            MacLibraryView(
                allGames: games,
                games: filteredGames,
                gameLists: filteredGameLists,
                allGameLists: gameLists,
                gameListCount: gameLists.count,
                totalCount: games.count,
                searchText: $searchText,
                selectedPlatform: $selectedPlatform,
                selectedGame: $selectedGame,
                selectedGameList: $selectedGameList,
                showingAddSheet: $showingAddSheet,
                showingListSheet: $showingListSheet,
                platformOptions: platformOptions,
                onDeleteGame: deleteGame,
                onDeleteList: deleteList,
                onAddCopy: openCopySheet,
                onAddPlaythrough: openPlaythroughSheet,
                onImportMetadata: openMetadataImporter,
                onEditCopy: openCopyEditSheet,
                onEditPlaythrough: openPlaythroughEditSheet
            )
#else
            IOSLibraryView(
                allGames: games,
                games: filteredGames,
                gameLists: filteredGameLists,
                allGameLists: gameLists,
                totalCount: games.count,
                searchText: $searchText,
                selectedPlatform: $selectedPlatform,
                gamesNavigationPath: $gamesNavigationPath,
                listsNavigationPath: $listsNavigationPath,
                showingAddSheet: $showingAddSheet,
                showingListSheet: $showingListSheet,
                platformOptions: platformOptions,
                onDeleteGame: deleteGame,
                onDeleteList: deleteList,
                onAddCopy: openCopySheet,
                onAddPlaythrough: openPlaythroughSheet,
                onImportMetadata: openMetadataImporter,
                onEditCopy: openCopyEditSheet,
                onEditPlaythrough: openPlaythroughEditSheet
            )
#endif
        }
        .sheet(isPresented: $showingAddSheet) {
            GameFormView { game in
                selectedPlatform = LibrarySidebarItem.allGames
                selectedGame = game
            }
        }
        .sheet(isPresented: $showingListSheet) {
            GameListFormView(onSave: createGameList)
        }
        .sheet(item: $copyHostGame) { game in
            GameCopyFormView(game: game)
        }
        .sheet(item: $playthroughHostCopy) { copy in
            GamePlaythroughFormView(copy: copy)
        }
        .sheet(item: $metadataImportGame) { game in
            IGDBMetadataImporterView(game: game)
        }
        .sheet(item: $copyToEdit) { copy in
            GameCopyEditFormView(copy: copy)
        }
        .sheet(item: $playthroughToEdit) { playthrough in
            GamePlaythroughEditFormView(playthrough: playthrough)
        }
        .onAppear {
            migrateLegacyPlaythroughsIfNeeded()
            syncSelectedPlatformIfNeeded()
            syncSelection()
            syncListSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openNewGame)) { _ in
            showingAddSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openNewList)) { _ in
            selectedPlatform = LibrarySidebarItem.lists
            showingListSheet = true
        }
        .onChange(of: selectedPlatform) {
            syncSelection()
            syncListSelection()
        }
        .onChange(of: games.map(\.persistentModelID)) {
            migrateLegacyPlaythroughsIfNeeded()
        }
        .onChange(of: gameLists.map(\.persistentModelID)) {
            syncListSelection()
        }
        .onChange(of: filteredGameListIDs) {
            handleFilteredGameListsChange()
        }
        .onChange(of: platformOptions) {
            syncSelectedPlatformIfNeeded()
        }
        .onChange(of: filteredGameIDs) {
            handleFilteredGamesChange()
        }
    }

    private func createGameList(_ title: String) {
        let list = GameList(title: title)
        modelContext.insert(list)
        selectedPlatform = LibrarySidebarItem.lists
        selectedGameList = list
    }

    private func deleteGame(_ game: Game) {
        withAnimation {
            if selectedGame?.persistentModelID == game.persistentModelID {
                selectedGame = nil
            }

            modelContext.delete(game)
        }
    }

    private func deleteList(_ list: GameList) {
        withAnimation {
            if selectedGameList?.persistentModelID == list.persistentModelID {
                selectedGameList = nil
            }

            modelContext.delete(list)
        }
    }

    private func openCopySheet(for game: Game) {
        copyHostGame = game
    }

    private func openPlaythroughSheet(for copy: GameCopy) {
        playthroughHostCopy = copy
    }

    private func openMetadataImporter(for game: Game) {
        metadataImportGame = game
    }

    private func openCopyEditSheet(for copy: GameCopy) {
        copyToEdit = copy
    }

    private func openPlaythroughEditSheet(for playthrough: GamePlaythrough) {
        playthroughToEdit = playthrough
    }

    private func migrateLegacyPlaythroughsIfNeeded() {
        var didInsertPlaythrough = false

        for game in games {
            for copy in game.sortedCopies where copy.needsLegacyPlaythroughMigration {
                let playthrough = GamePlaythrough(
                    status: copy.status,
                    createdAt: copy.createdAt
                )
                copy.addPlaythrough(playthrough)
                copy.status = ""
                modelContext.insert(playthrough)
                didInsertPlaythrough = true
            }
        }

        guard didInsertPlaythrough else { return }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Could not migrate legacy copy statuses into playthroughs: \(error)")
        }
    }

    private func syncSelection() {
#if os(macOS)
        if let selectedGame,
           filteredGames.contains(where: { $0.persistentModelID == selectedGame.persistentModelID }) {
            return
        }

        selectedGame = filteredGames.first
#endif
    }

    private func syncSelectedPlatformIfNeeded() {
        guard selectedPlatform != LibrarySidebarItem.allGames,
              selectedPlatform != LibrarySidebarItem.lists,
              !usedPlatforms.contains(selectedPlatform)
        else {
            return
        }

        selectedPlatform = LibrarySidebarItem.allGames
    }

    private func syncListSelection() {
#if os(macOS)
        guard isShowingLists else { return }

        if let selectedGameList,
           filteredGameLists.contains(where: { $0.persistentModelID == selectedGameList.persistentModelID }) {
            return
        }

        selectedGameList = filteredGameLists.first
#endif
    }

    private func handleFilteredGameListsChange() {
        syncListSelection()
#if !os(macOS)
        syncNavigationPaths()
#endif
    }

    private func handleFilteredGamesChange() {
        syncSelectedPlatformIfNeeded()
        syncSelection()
#if !os(macOS)
        syncNavigationPaths()
#endif
    }

    private func syncNavigationPaths() {
#if !os(macOS)
        func shouldRemove(_ route: GameLibraryDetailRoute) -> Bool {
            switch route {
            case .game(let id):
                return !filteredGames.contains(where: { $0.persistentModelID == id })
            case .list(let id):
                return !filteredGameLists.contains(where: { $0.persistentModelID == id })
            }
        }

        gamesNavigationPath.removeAll(where: shouldRemove)
        listsNavigationPath.removeAll(where: shouldRemove)
#endif
    }
}

#if os(macOS)
private struct MacLibraryView: View {
    let allGames: [Game]
    let games: [Game]
    let gameLists: [GameList]
    let allGameLists: [GameList]
    let gameListCount: Int
    let totalCount: Int
    @Binding var searchText: String
    @Binding var selectedPlatform: String
    @Binding var selectedGame: Game?
    @Binding var selectedGameList: GameList?
    @Binding var showingAddSheet: Bool
    @Binding var showingListSheet: Bool
    let platformOptions: [String]
    let onDeleteGame: (Game) -> Void
    let onDeleteList: (GameList) -> Void
    let onAddCopy: (Game) -> Void
    let onAddPlaythrough: (GameCopy) -> Void
    let onImportMetadata: (Game) -> Void
    let onEditCopy: (GameCopy) -> Void
    let onEditPlaythrough: (GamePlaythrough) -> Void

    @State private var detailNavigationPath = [GameLibraryDetailRoute]()
    @State private var gamePendingDeletion: Game?
    @State private var listPendingDeletion: GameList?

    private var availablePlatforms: [String] {
        Array(platformOptions.dropFirst())
    }

    private var isShowingLists: Bool {
        selectedPlatform == LibrarySidebarItem.lists
    }

    private func count(for platform: String) -> Int {
        allGames.count { game in
            game.sortedCopies.contains { $0.platform == platform }
        }
    }

    private var selectedGameID: Binding<PersistentIdentifier?> {
        Binding(
            get: { selectedGame?.persistentModelID },
            set: { newValue in
                selectedGame = games.first(where: { $0.persistentModelID == newValue })
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPlatform) {
                Section("Biblioteca") {
                    SidebarFilterRow(
                        title: "Todos los juegos",
                        systemImage: "square.stack.3d.up.fill",
                        count: totalCount
                    )
                    .tag(LibrarySidebarItem.allGames)
                }

                Section("Plataformas") {
                    ForEach(availablePlatforms, id: \.self) { platform in
                        SidebarFilterRow(
                            title: platform,
                            systemImage: "gamecontroller",
                            count: count(for: platform)
                        )
                        .tag(platform)
                    }
                }

                Section("Listas") {
                    SidebarFilterRow(
                        title: "Listas",
                        systemImage: "list.bullet.rectangle",
                        count: gameListCount
                    )
                    .tag(LibrarySidebarItem.lists)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Biblioteca")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240)
        } content: {
            Group {
                if isShowingLists {
                    GameListsColumnView(
                        lists: gameLists,
                        selectedList: $selectedGameList,
                        onCreateList: {
                            showingListSheet = true
                        }
                    )
                } else if games.isEmpty {
                    GameEmptyStateView(searchText: searchText, selectedPlatform: selectedPlatform)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: selectedGameID) {
                        ForEach(games) { game in
                            MacGameListRow(game: game)
                                .tag(game.persistentModelID)
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 54)
                }
            }
            .navigationTitle(isShowingLists ? "Listas" : selectedPlatform == LibrarySidebarItem.allGames ? "Juegos" : selectedPlatform)
            .onDeleteCommand(perform: requestDelete)
            .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 380)
        } detail: {
            if isShowingLists {
                if let selectedGameList {
                    GameListDetailView(
                        list: selectedGameList,
                        allGames: allGames,
                        allLists: allGameLists,
                        onDeleteList: {
                            listPendingDeletion = selectedGameList
                        },
                        onAddCopy: onAddCopy,
                        onAddPlaythrough: onAddPlaythrough,
                        onImportMetadata: onImportMetadata,
                        onEditCopy: onEditCopy,
                        onEditPlaythrough: onEditPlaythrough
                    )
                } else {
                    GameListSelectionPlaceholderView()
                }
            } else if let selectedGame {
                NavigationStack(path: $detailNavigationPath) {
                    GameDetailView(
                        game: selectedGame,
                        onAddCopy: {
                            onAddCopy(selectedGame)
                        },
                        onDeleteGame: {
                            gamePendingDeletion = selectedGame
                        },
                        onImportMetadata: {
                            onImportMetadata(selectedGame)
                        },
                        onAddPlaythrough: onAddPlaythrough,
                        onEditCopy: onEditCopy,
                        onEditPlaythrough: onEditPlaythrough,
                        onOpenList: openListInDetail
                    )
                    .navigationDestination(for: GameLibraryDetailRoute.self) { route in
                        detailDestination(for: route)
                    }
                }
                .onChange(of: selectedGame.persistentModelID) {
                    detailNavigationPath.removeAll()
                }
                .onChange(of: selectedPlatform) {
                    detailNavigationPath.removeAll()
                }
            } else {
                GameSelectionPlaceholderView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $searchText, prompt: isShowingLists ? "Buscar listas" : "Buscar por título, plataforma o estado")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if isShowingLists {
                        showingListSheet = true
                    } else {
                        showingAddSheet = true
                    }
                } label: {
                    Label(isShowingLists ? "Nueva lista" : "Nuevo juego", systemImage: "plus")
                }
            }
        }
        .confirmationDialog(
            "Eliminar juego",
            isPresented: Binding(
                get: { gamePendingDeletion != nil },
                set: { if !$0 { gamePendingDeletion = nil } }
            ),
            presenting: gamePendingDeletion
        ) { game in
            Button("Eliminar juego", role: .destructive) {
                onDeleteGame(game)
            }
        } message: { game in
            Text("Se eliminará \"\(game.title)\" junto con sus copias y partidas.")
        }
        .confirmationDialog(
            "Eliminar lista",
            isPresented: Binding(
                get: { listPendingDeletion != nil },
                set: { if !$0 { listPendingDeletion = nil } }
            ),
            presenting: listPendingDeletion
        ) { list in
            Button("Eliminar lista", role: .destructive) {
                onDeleteList(list)
            }
        } message: { list in
            Text("Se eliminará la lista \"\(list.title)\". Los juegos no se borrarán de la biblioteca.")
        }
    }

    @ViewBuilder
    private func detailDestination(for route: GameLibraryDetailRoute) -> some View {
        switch route {
        case .game(let gameID):
            if let game = allGames.first(where: { $0.persistentModelID == gameID }) {
                GameDetailView(
                    game: game,
                    onAddCopy: {
                        onAddCopy(game)
                    },
                    onDeleteGame: {
                        gamePendingDeletion = game
                    },
                    onImportMetadata: {
                        onImportMetadata(game)
                    },
                    onAddPlaythrough: onAddPlaythrough,
                    onEditCopy: onEditCopy,
                    onEditPlaythrough: onEditPlaythrough,
                    onOpenList: openListInDetail
                )
            } else {
                ContentUnavailableView(
                    "Juego no disponible",
                    systemImage: "questionmark.square",
                    description: Text("Este juego ya no está en la biblioteca.")
                )
            }
        case .list(let listID):
            if let list = allGameLists.first(where: { $0.persistentModelID == listID }) {
                GameListDetailContentView(
                    list: list,
                    allGames: allGames,
                    onOpenGame: openGameInDetail,
                    onAddCopy: onAddCopy,
                    onAddPlaythrough: onAddPlaythrough,
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

    private func openGameInDetail(_ game: Game) {
        detailNavigationPath.append(.game(game.persistentModelID))
    }

    private func openListInDetail(_ list: GameList) {
        detailNavigationPath.append(.list(list.persistentModelID))
    }

    private func requestDelete() {
        if isShowingLists {
            listPendingDeletion = selectedGameList
        } else {
            gamePendingDeletion = selectedGame
        }
    }
}
#else
private struct IOSLibraryView: View {
    let allGames: [Game]
    let games: [Game]
    let gameLists: [GameList]
    let allGameLists: [GameList]
    let totalCount: Int
    @Binding var searchText: String
    @Binding var selectedPlatform: String
    @Binding var gamesNavigationPath: [GameLibraryDetailRoute]
    @Binding var listsNavigationPath: [GameLibraryDetailRoute]
    @Binding var showingAddSheet: Bool
    @Binding var showingListSheet: Bool
    let platformOptions: [String]
    let onDeleteGame: (Game) -> Void
    let onDeleteList: (GameList) -> Void
    let onAddCopy: (Game) -> Void
    let onAddPlaythrough: (GameCopy) -> Void
    let onImportMetadata: (Game) -> Void
    let onEditCopy: (GameCopy) -> Void
    let onEditPlaythrough: (GamePlaythrough) -> Void

    var body: some View {
        TabView {
            IOSGamesLibraryTab(
                allGames: allGames,
                games: games,
                allGameLists: allGameLists,
                totalCount: totalCount,
                searchText: $searchText,
                selectedPlatform: $selectedPlatform,
                navigationPath: $gamesNavigationPath,
                showingAddSheet: $showingAddSheet,
                platformOptions: platformOptions,
                onDeleteGame: onDeleteGame,
                onAddCopy: onAddCopy,
                onAddPlaythrough: onAddPlaythrough,
                onImportMetadata: onImportMetadata,
                onEditCopy: onEditCopy,
                onEditPlaythrough: onEditPlaythrough
            )
            .tabItem {
                Label("Juegos", systemImage: "gamecontroller.fill")
            }

            IOSListsLibraryTab(
                allGames: allGames,
                gameLists: gameLists,
                allGameLists: allGameLists,
                searchText: $searchText,
                navigationPath: $listsNavigationPath,
                showingListSheet: $showingListSheet,
                onDeleteList: onDeleteList,
                onAddCopy: onAddCopy,
                onAddPlaythrough: onAddPlaythrough,
                onImportMetadata: onImportMetadata,
                onEditCopy: onEditCopy,
                onEditPlaythrough: onEditPlaythrough
            )
            .tabItem {
                Label("Listas", systemImage: "list.bullet.rectangle.fill")
            }
        }
    }
}

private struct IOSGamesLibraryTab: View {
    let allGames: [Game]
    let games: [Game]
    let allGameLists: [GameList]
    let totalCount: Int
    @Binding var searchText: String
    @Binding var selectedPlatform: String
    @Binding var navigationPath: [GameLibraryDetailRoute]
    @Binding var showingAddSheet: Bool
    let platformOptions: [String]
    let onDeleteGame: (Game) -> Void
    let onAddCopy: (Game) -> Void
    let onAddPlaythrough: (GameCopy) -> Void
    let onImportMetadata: (Game) -> Void
    let onEditCopy: (GameCopy) -> Void
    let onEditPlaythrough: (GamePlaythrough) -> Void

    @State private var gamePendingDeletion: Game?

    private var gameCountSummary: String {
        if selectedPlatform == LibrarySidebarItem.allGames {
            return totalCount == 1 ? "1 juego" : "\(totalCount) juegos"
        }

        let visible = games.count == 1 ? "1 juego" : "\(games.count) juegos"
        let total = totalCount == 1 ? "1 total" : "\(totalCount) totales"
        return "\(visible) de \(total)"
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if games.isEmpty {
                    GameEmptyStateView(searchText: searchText, selectedPlatform: selectedPlatform)
                        .padding(.horizontal, 24)
                } else {
                    List {
                        Section {
                            ForEach(games) { game in
                                NavigationLink {
                                    gameDestination(for: game)
                                } label: {
                                    GameRowContent(game: game)
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        gamePendingDeletion = game
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text(gameCountSummary)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Juegos")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Buscar por título, plataforma o estado")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    platformFilterMenu
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Nuevo juego", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: GameLibraryDetailRoute.self) { route in
                destination(for: route)
            }
        }
        .confirmationDialog(
            "Eliminar juego",
            isPresented: Binding(
                get: { gamePendingDeletion != nil },
                set: { if !$0 { gamePendingDeletion = nil } }
            ),
            presenting: gamePendingDeletion
        ) { game in
            Button("Eliminar juego", role: .destructive) {
                onDeleteGame(game)
            }
        } message: { game in
            Text("Se eliminará \"\(game.title)\" junto con sus copias y partidas.")
        }
    }

    private var platformFilterMenu: some View {
        Menu {
            ForEach(platformOptions, id: \.self) { platform in
                Button {
                    selectedPlatform = platform
                } label: {
                    if selectedPlatform == platform {
                        Label(displayName(for: platform), systemImage: "checkmark")
                    } else {
                        Text(displayName(for: platform))
                    }
                }
            }
        } label: {
            Label("Filtrar", systemImage: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filtrar por plataforma")
    }

    private func displayName(for platform: String) -> String {
        platform == LibrarySidebarItem.allGames ? "Todas las plataformas" : platform
    }

    private func gameDestination(for game: Game) -> some View {
        GameDetailView(
            game: game,
            onAddCopy: {
                onAddCopy(game)
            },
            onDeleteGame: {
                gamePendingDeletion = game
            },
            onImportMetadata: {
                onImportMetadata(game)
            },
            onAddPlaythrough: onAddPlaythrough,
            onEditCopy: onEditCopy,
            onEditPlaythrough: onEditPlaythrough,
            onOpenList: open
        )
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func destination(for route: GameLibraryDetailRoute) -> some View {
        switch route {
        case .game(let gameID):
            if let game = allGames.first(where: { $0.persistentModelID == gameID }) {
                gameDestination(for: game)
            } else {
                GameEmptyStateView(searchText: searchText, selectedPlatform: selectedPlatform)
            }
        case .list(let listID):
            if let list = allGameLists.first(where: { $0.persistentModelID == listID }) {
                GameListDetailContentView(
                    list: list,
                    allGames: allGames,
                    onOpenGame: open,
                    onAddCopy: onAddCopy,
                    onAddPlaythrough: onAddPlaythrough,
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

private struct IOSListsLibraryTab: View {
    let allGames: [Game]
    let gameLists: [GameList]
    let allGameLists: [GameList]
    @Binding var searchText: String
    @Binding var navigationPath: [GameLibraryDetailRoute]
    @Binding var showingListSheet: Bool
    let onDeleteList: (GameList) -> Void
    let onAddCopy: (Game) -> Void
    let onAddPlaythrough: (GameCopy) -> Void
    let onImportMetadata: (Game) -> Void
    let onEditCopy: (GameCopy) -> Void
    let onEditPlaythrough: (GamePlaythrough) -> Void

    @State private var listPendingDeletion: GameList?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if gameLists.isEmpty {
                    ContentUnavailableView {
                        Label("Tus listas", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("Crea listas para ordenar pendientes, favoritos o cualquier selección propia.")
                    } actions: {
                        Button("Nueva lista") {
                            showingListSheet = true
                        }
                    }
                    .padding(.horizontal, 24)
                } else {
                    List {
                        Section {
                            ForEach(gameLists) { list in
                                NavigationLink {
                                    listDestination(for: list)
                                } label: {
                                    GameListRowContent(list: list)
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        listPendingDeletion = list
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text(gameLists.count == 1 ? "1 lista" : "\(gameLists.count) listas")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Listas")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Buscar listas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingListSheet = true
                    } label: {
                        Label("Nueva lista", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: GameLibraryDetailRoute.self) { route in
                destination(for: route)
            }
        }
        .confirmationDialog(
            "Eliminar lista",
            isPresented: Binding(
                get: { listPendingDeletion != nil },
                set: { if !$0 { listPendingDeletion = nil } }
            ),
            presenting: listPendingDeletion
        ) { list in
            Button("Eliminar lista", role: .destructive) {
                onDeleteList(list)
            }
        } message: { list in
            Text("Se eliminará la lista \"\(list.title)\". Los juegos no se borrarán de la biblioteca.")
        }
    }

    @ViewBuilder
    private func destination(for route: GameLibraryDetailRoute) -> some View {
        switch route {
        case .game(let gameID):
            if let game = allGames.first(where: { $0.persistentModelID == gameID }) {
                gameDestination(for: game)
            } else {
                ContentUnavailableView(
                    "Juego no disponible",
                    systemImage: "questionmark.square",
                    description: Text("Este juego ya no está en la biblioteca.")
                )
            }
        case .list(let listID):
            if let list = allGameLists.first(where: { $0.persistentModelID == listID }) {
                GameListDetailContentView(
                    list: list,
                    allGames: allGames,
                    onDeleteList: {
                        listPendingDeletion = list
                    },
                    onOpenGame: open,
                    onAddCopy: onAddCopy,
                    onAddPlaythrough: onAddPlaythrough,
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

    private func gameDestination(for game: Game) -> some View {
        GameDetailView(
            game: game,
            onAddCopy: {
                onAddCopy(game)
            },
            onImportMetadata: {
                onImportMetadata(game)
            },
            onAddPlaythrough: onAddPlaythrough,
            onEditCopy: onEditCopy,
            onEditPlaythrough: onEditPlaythrough,
            onOpenList: open
        )
        .navigationBarTitleDisplayMode(.inline)
    }

    private func listDestination(for list: GameList) -> some View {
        GameListDetailContentView(
            list: list,
            allGames: allGames,
            onDeleteList: {
                listPendingDeletion = list
            },
            onOpenGame: open,
            onAddCopy: onAddCopy,
            onAddPlaythrough: onAddPlaythrough,
            onImportMetadata: onImportMetadata,
            onEditCopy: onEditCopy,
            onEditPlaythrough: onEditPlaythrough
        )
    }

    private func open(_ game: Game) {
        navigationPath.append(.game(game.persistentModelID))
    }

    private func open(_ list: GameList) {
        navigationPath.append(.list(list.persistentModelID))
    }
}
#endif

#Preview {
    ContentView()
        .modelContainer(for: [Game.self, GameList.self, GameListEntry.self, GameCopy.self, GamePlaythrough.self], inMemory: true)
}
