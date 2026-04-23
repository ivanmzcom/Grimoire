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
    static let wishlist = "__wishlist__"
    static let lists = "__lists__"
}

private enum SmartLibraryCollection: String, CaseIterable, Identifiable {
    case missingCover = "__smart_missing_cover__"
    case missingPlaythroughs = "__smart_missing_playthroughs__"
    case playing = "__smart_playing__"
    case completed = "__smart_completed__"
    case recentlyAdded = "__smart_recently_added__"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .missingCover:
            return "Sin portada"
        case .missingPlaythroughs:
            return "Sin partidas"
        case .playing:
            return "Jugando"
        case .completed:
            return "Completados"
        case .recentlyAdded:
            return "Añadidos recientemente"
        }
    }

    var systemImage: String {
        switch self {
        case .missingCover:
            return "photo"
        case .missingPlaythroughs:
            return "flag.slash"
        case .playing:
            return "play.circle"
        case .completed:
            return "checkmark.circle"
        case .recentlyAdded:
            return "clock.badge.checkmark"
        }
    }

    static func collection(for value: String) -> SmartLibraryCollection? {
        SmartLibraryCollection(rawValue: value)
    }

    static func contains(_ value: String) -> Bool {
        collection(for: value) != nil
    }

    func matches(_ game: Game, in allGames: [Game]) -> Bool {
        switch self {
        case .missingCover:
            return game.coverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .missingPlaythroughs:
            return game.playthroughCount == 0
        case .playing:
            return game.hasPlaythroughStatus("Jugando")
        case .completed:
            return game.hasPlaythroughStatus("Completado")
        case .recentlyAdded:
            return game.createdAt >= Date.now.addingTimeInterval(-30 * 24 * 60 * 60)
        }
    }
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
    @State private var metadataUpdateMessage: String?

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
        [LibrarySidebarItem.allGames, LibrarySidebarItem.wishlist] + usedPlatforms
    }

    private var isShowingLists: Bool {
        selectedPlatform == LibrarySidebarItem.lists
    }

    private var wishlistGames: [Game] {
        games.filter(\.isWishlistItem)
    }

    private var filteredGames: [Game] {
        let filteredGames = games.filter { game in
            let matchesPlatform: Bool = switch selectedPlatform {
            case LibrarySidebarItem.allGames:
                true
            case LibrarySidebarItem.wishlist:
                game.isWishlistItem
            case LibrarySidebarItem.lists:
                true
            default:
                if let smartCollection = SmartLibraryCollection.collection(for: selectedPlatform) {
                    smartCollection.matches(game, in: games)
                } else {
                    game.sortedCopies.contains(where: { $0.platform == selectedPlatform })
                }
            }

            let matchesSearch = searchText.isEmpty
                || containsSearchText(in: game.title)
                || containsSearchText(in: game.searchableCopyText)
            return matchesPlatform && matchesSearch
        }

        if selectedPlatform == SmartLibraryCollection.recentlyAdded.rawValue {
            return filteredGames.sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }

                return lhs.createdAt > rhs.createdAt
            }
        }

        return filteredGames
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
                wishlistCount: wishlistGames.count,
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
                onEditPlaythrough: openPlaythroughEditSheet,
                onDeleteCopy: deleteCopy,
                onDeletePlaythrough: deletePlaythrough
            )
#else
            IOSLibraryView(
                allGames: games,
                games: filteredGames,
                gameLists: filteredGameLists,
                allGameLists: gameLists,
                totalCount: games.count,
                wishlistCount: wishlistGames.count,
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
                onEditPlaythrough: openPlaythroughEditSheet,
                onDeleteCopy: deleteCopy,
                onDeletePlaythrough: deletePlaythrough
            )
#endif
        }
        .sheet(isPresented: $showingAddSheet) {
            GameFormView(
                onCreate: { game in
                    selectedPlatform = LibrarySidebarItem.wishlist
                    selectedGame = game
                },
                onOpenExisting: { game in
                    selectedPlatform = game.isWishlistItem ? LibrarySidebarItem.wishlist : LibrarySidebarItem.allGames
                    selectedGame = game
                },
                onAddCopyToExisting: { game in
                    selectedPlatform = game.isWishlistItem ? LibrarySidebarItem.wishlist : LibrarySidebarItem.allGames
                    selectedGame = game
                    copyHostGame = game
                }
            )
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
        .alert("IGDB", isPresented: Binding(
            get: { metadataUpdateMessage != nil },
            set: { isPresented in
                if !isPresented {
                    metadataUpdateMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                metadataUpdateMessage = nil
            }
        } message: {
            Text(metadataUpdateMessage ?? "")
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

    private func deleteCopy(_ copy: GameCopy) {
        withAnimation {
            if copyToEdit?.persistentModelID == copy.persistentModelID {
                copyToEdit = nil
            }

            modelContext.delete(copy)
        }
    }

    private func deletePlaythrough(_ playthrough: GamePlaythrough) {
        withAnimation {
            if playthroughToEdit?.persistentModelID == playthrough.persistentModelID {
                playthroughToEdit = nil
            }

            modelContext.delete(playthrough)
        }
    }

    private func openCopySheet(for game: Game) {
        copyHostGame = game
    }

    private func openPlaythroughSheet(for copy: GameCopy) {
        playthroughHostCopy = copy
    }

    private func openMetadataImporter(for game: Game) {
        guard let igdbID = game.igdbID else {
            metadataImportGame = game
            return
        }

        Task {
            await updateMetadata(for: game, igdbID: igdbID)
        }
    }

    @MainActor
    private func updateMetadata(for game: Game, igdbID: Int) async {
        do {
            guard let metadata = try await IGDBMetadataService(credentials: IGDBCredentialsStore.load()).game(id: igdbID) else {
                metadataUpdateMessage = "IGDB no devolvió metadatos para este juego."
                return
            }

            game.applyIGDBMetadata(metadata)
            try game.applyIGDBTags(from: metadata, in: modelContext)
            try modelContext.save()
        } catch {
            metadataUpdateMessage = error.localizedDescription
        }
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
              selectedPlatform != LibrarySidebarItem.wishlist,
              selectedPlatform != LibrarySidebarItem.lists,
              !SmartLibraryCollection.contains(selectedPlatform),
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
            case .tag(let id):
                return tag(for: id) == nil
            }
        }

        gamesNavigationPath.removeAll(where: shouldRemove)
        listsNavigationPath.removeAll(where: shouldRemove)
#endif
    }

    private func tag(for id: PersistentIdentifier) -> GameTag? {
        for game in games {
            if let tag = game.sortedTags.first(where: { $0.persistentModelID == id }) {
                return tag
            }
        }

        return nil
    }
}

private extension Game {
    func hasPlaythroughStatus(_ expectedStatus: String) -> Bool {
        sortedCopies.contains { copy in
            if copy.status.localizedCaseInsensitiveCompare(expectedStatus) == .orderedSame {
                return true
            }

            return copy.sortedPlaythroughs.contains { playthrough in
                playthrough.status.localizedCaseInsensitiveCompare(expectedStatus) == .orderedSame
            }
        }
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
    let wishlistCount: Int
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
    let onDeleteCopy: (GameCopy) -> Void
    let onDeletePlaythrough: (GamePlaythrough) -> Void

    @State private var detailNavigationPath = [GameLibraryDetailRoute]()
    @State private var gamePendingDeletion: Game?
    @State private var listPendingDeletion: GameList?

    private var availablePlatforms: [String] {
        platformOptions.filter { option in
            option != LibrarySidebarItem.allGames && option != LibrarySidebarItem.wishlist
        }
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

                    SidebarFilterRow(
                        title: "Wishlist",
                        systemImage: "sparkles.rectangle.stack",
                        count: wishlistCount
                    )
                    .tag(LibrarySidebarItem.wishlist)
                }

                Section("Colecciones inteligentes") {
                    ForEach(SmartLibraryCollection.allCases) { collection in
                        SidebarFilterRow(
                            title: collection.title,
                            systemImage: collection.systemImage,
                            count: count(for: collection)
                        )
                        .tag(collection.rawValue)
                    }
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
            .navigationTitle(navigationTitle)
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
                        onEditPlaythrough: onEditPlaythrough,
                        onDeleteCopy: onDeleteCopy,
                        onDeletePlaythrough: onDeletePlaythrough
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
                        onDeleteCopy: onDeleteCopy,
                        onDeletePlaythrough: onDeletePlaythrough,
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
            ToolbarItem(placement: .automatic) {
                ICloudSyncStatusMenu()
            }

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
                    onDeleteCopy: onDeleteCopy,
                    onDeletePlaythrough: onDeletePlaythrough,
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
                    onEditPlaythrough: onEditPlaythrough,
                    onDeleteCopy: onDeleteCopy,
                    onDeletePlaythrough: onDeletePlaythrough
                )
            } else {
                ContentUnavailableView(
                    "Lista no disponible",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Esta lista ya no está disponible.")
                )
            }
        case .tag(let tagID):
            if let tag = tag(for: tagID) {
                GameTagDetailContentView(
                    tag: tag,
                    games: games(for: tag),
                    onOpenGame: openGameInDetail
                )
            } else {
                ContentUnavailableView(
                    "Etiqueta no disponible",
                    systemImage: "tag",
                    description: Text("Esta etiqueta ya no está disponible.")
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

    private func tag(for id: PersistentIdentifier) -> GameTag? {
        for game in allGames {
            if let tag = game.sortedTags.first(where: { $0.persistentModelID == id }) {
                return tag
            }
        }

        return nil
    }

    private func games(for tag: GameTag) -> [Game] {
        allGames
            .filter { $0.hasTag(tag) }
            .sorted { lhs, rhs in
                lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    private var navigationTitle: String {
        if isShowingLists {
            return "Listas"
        }

        if let smartCollection = SmartLibraryCollection.collection(for: selectedPlatform) {
            return smartCollection.title
        }

        if selectedPlatform == LibrarySidebarItem.allGames {
            return "Juegos"
        }

        if selectedPlatform == LibrarySidebarItem.wishlist {
            return "Wishlist"
        }

        return selectedPlatform
    }

    private func requestDelete() {
        if isShowingLists {
            listPendingDeletion = selectedGameList
        } else {
            gamePendingDeletion = selectedGame
        }
    }

    private func count(for collection: SmartLibraryCollection) -> Int {
        allGames.count { game in
            collection.matches(game, in: allGames)
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
    let wishlistCount: Int
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
    let onDeleteCopy: (GameCopy) -> Void
    let onDeletePlaythrough: (GamePlaythrough) -> Void

    var body: some View {
        TabView {
            IOSGamesLibraryTab(
                allGames: allGames,
                games: games,
                allGameLists: allGameLists,
                totalCount: totalCount,
                wishlistCount: wishlistCount,
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
                onEditPlaythrough: onEditPlaythrough,
                onDeleteCopy: onDeleteCopy,
                onDeletePlaythrough: onDeletePlaythrough
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
                onEditPlaythrough: onEditPlaythrough,
                onDeleteCopy: onDeleteCopy,
                onDeletePlaythrough: onDeletePlaythrough
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
    let wishlistCount: Int
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
    let onDeleteCopy: (GameCopy) -> Void
    let onDeletePlaythrough: (GamePlaythrough) -> Void

    @State private var gamePendingDeletion: Game?

    private var gameCountSummary: String {
        if selectedPlatform == LibrarySidebarItem.allGames {
            return totalCount == 1 ? "1 juego" : "\(totalCount) juegos"
        }

        if selectedPlatform == LibrarySidebarItem.wishlist {
            return wishlistCount == 1 ? "1 juego en wishlist" : "\(wishlistCount) juegos en wishlist"
        }

        if let smartCollection = SmartLibraryCollection.collection(for: selectedPlatform) {
            let visible = games.count == 1 ? "1 juego" : "\(games.count) juegos"
            return "\(visible) · \(smartCollection.title)"
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
            Section("Biblioteca") {
                filterButton(for: LibrarySidebarItem.allGames)
                filterButton(for: LibrarySidebarItem.wishlist)
            }

            Section("Colecciones inteligentes") {
                ForEach(SmartLibraryCollection.allCases) { collection in
                    filterButton(for: collection.rawValue, title: collection.title)
                }
            }

            Section("Plataformas") {
                ForEach(platformOptions.filter { $0 != LibrarySidebarItem.allGames && $0 != LibrarySidebarItem.wishlist }, id: \.self) { platform in
                    filterButton(for: platform)
                }
            }
        } label: {
            Label("Filtrar", systemImage: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filtrar por plataforma")
    }

    private func filterButton(for value: String, title: String? = nil) -> some View {
        Button {
            selectedPlatform = value
        } label: {
            if selectedPlatform == value {
                Label(title ?? displayName(for: value), systemImage: "checkmark")
            } else {
                Text(title ?? displayName(for: value))
            }
        }
    }

    private func displayName(for platform: String) -> String {
        switch platform {
        case LibrarySidebarItem.allGames:
            return "Todas las plataformas"
        case LibrarySidebarItem.wishlist:
            return "Wishlist"
        default:
            if let smartCollection = SmartLibraryCollection.collection(for: platform) {
                return smartCollection.title
            }

            return platform
        }
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
            onDeleteCopy: onDeleteCopy,
            onDeletePlaythrough: onDeletePlaythrough,
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
                    onEditPlaythrough: onEditPlaythrough,
                    onDeleteCopy: onDeleteCopy,
                    onDeletePlaythrough: onDeletePlaythrough
                )
            } else {
                ContentUnavailableView(
                    "Lista no disponible",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Esta lista ya no está disponible.")
                )
            }
        case .tag(let tagID):
            if let tag = tag(for: tagID) {
                GameTagDetailContentView(
                    tag: tag,
                    games: games(for: tag),
                    onOpenGame: open
                )
            } else {
                ContentUnavailableView(
                    "Etiqueta no disponible",
                    systemImage: "tag",
                    description: Text("Esta etiqueta ya no está disponible.")
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

    private func tag(for id: PersistentIdentifier) -> GameTag? {
        for game in allGames {
            if let tag = game.sortedTags.first(where: { $0.persistentModelID == id }) {
                return tag
            }
        }

        return nil
    }

    private func games(for tag: GameTag) -> [Game] {
        allGames
            .filter { $0.hasTag(tag) }
            .sorted { lhs, rhs in
                lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
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
    let onDeleteCopy: (GameCopy) -> Void
    let onDeletePlaythrough: (GamePlaythrough) -> Void

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
                    onEditPlaythrough: onEditPlaythrough,
                    onDeleteCopy: onDeleteCopy,
                    onDeletePlaythrough: onDeletePlaythrough
                )
            } else {
                ContentUnavailableView(
                    "Lista no disponible",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Esta lista ya no está disponible.")
                )
            }
        case .tag(let tagID):
            if let tag = tag(for: tagID) {
                GameTagDetailContentView(
                    tag: tag,
                    games: games(for: tag),
                    onOpenGame: open
                )
            } else {
                ContentUnavailableView(
                    "Etiqueta no disponible",
                    systemImage: "tag",
                    description: Text("Esta etiqueta ya no está disponible.")
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
            onDeleteCopy: onDeleteCopy,
            onDeletePlaythrough: onDeletePlaythrough,
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
            onEditPlaythrough: onEditPlaythrough,
            onDeleteCopy: onDeleteCopy,
            onDeletePlaythrough: onDeletePlaythrough
        )
    }

    private func open(_ game: Game) {
        navigationPath.append(.game(game.persistentModelID))
    }

    private func open(_ list: GameList) {
        navigationPath.append(.list(list.persistentModelID))
    }

    private func tag(for id: PersistentIdentifier) -> GameTag? {
        for game in allGames {
            if let tag = game.sortedTags.first(where: { $0.persistentModelID == id }) {
                return tag
            }
        }

        return nil
    }

    private func games(for tag: GameTag) -> [Game] {
        allGames
            .filter { $0.hasTag(tag) }
            .sorted { lhs, rhs in
                lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }
}
#endif

#Preview {
    ContentView()
        .modelContainer(for: [Game.self, GameList.self, GameListEntry.self, GameCopy.self, GamePlaythrough.self, GameTag.self, GameTagAssignment.self], inMemory: true)
}
