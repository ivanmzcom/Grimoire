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
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Game.title), SortDescriptor(\Game.platform)]) private var games: [Game]

    @SceneStorage("librarySearchText") private var searchText = ""
    @SceneStorage("selectedPlatformFilter") private var selectedPlatform = "Todas"
    @State private var selectedGame: Game?
    @State private var navigationPath = [PersistentIdentifier]()
    @State private var showingAddSheet = false

    private var platformOptions: [String] {
        ["Todas"] + GameCatalog.platforms
    }

    private var filteredGames: [Game] {
        games.filter { game in
            let matchesPlatform = selectedPlatform == "Todas" || game.platform == selectedPlatform
            let matchesSearch = searchText.isEmpty
                || game.title.localizedCaseInsensitiveContains(searchText)
                || game.platform.localizedCaseInsensitiveContains(searchText)
                || game.genre.localizedCaseInsensitiveContains(searchText)
            return matchesPlatform && matchesSearch
        }
    }

    var body: some View {
        Group {
#if os(macOS)
            MacLibraryView(
                allGames: games,
                games: filteredGames,
                totalCount: games.count,
                searchText: $searchText,
                selectedPlatform: $selectedPlatform,
                selectedGame: $selectedGame,
                showingAddSheet: $showingAddSheet,
                platformOptions: platformOptions,
                onDeleteSelected: deleteSelectedGame
            )
#else
            IOSLibraryView(
                games: filteredGames,
                totalCount: games.count,
                searchText: $searchText,
                selectedPlatform: $selectedPlatform,
                navigationPath: $navigationPath,
                showingAddSheet: $showingAddSheet,
                platformOptions: platformOptions,
                onDelete: deleteGames
            )
#endif
        }
        .sheet(isPresented: $showingAddSheet) {
            GameFormView()
        }
        .onAppear {
            syncSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openNewGame)) { _ in
            showingAddSheet = true
        }
        .onChange(of: filteredGames.map(\.persistentModelID)) {
            syncSelection()
            syncNavigationPath()
        }
    }

    private func deleteGames(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let game = filteredGames[index]
                if selectedGame?.persistentModelID == game.persistentModelID {
                    selectedGame = nil
                }
                modelContext.delete(game)
            }
        }
    }

    private func deleteSelectedGame() {
        guard let selectedGame else { return }

        withAnimation {
            modelContext.delete(selectedGame)
            self.selectedGame = nil
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

    private func syncNavigationPath() {
#if !os(macOS)
        navigationPath.removeAll { id in
            !filteredGames.contains(where: { $0.persistentModelID == id })
        }
#endif
    }
}

#if os(macOS)
private struct MacLibraryView: View {
    let allGames: [Game]
    let games: [Game]
    let totalCount: Int
    @Binding var searchText: String
    @Binding var selectedPlatform: String
    @Binding var selectedGame: Game?
    @Binding var showingAddSheet: Bool
    let platformOptions: [String]
    let onDeleteSelected: () -> Void

    private var availablePlatforms: [String] {
        Array(platformOptions.dropFirst())
    }

    private func count(for platform: String) -> Int {
        allGames.count { $0.platform == platform }
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
                    .tag("Todas")
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
            }
            .listStyle(.sidebar)
            .navigationTitle("Biblioteca")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240)
        } content: {
            Group {
                if games.isEmpty {
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
            .navigationTitle(selectedPlatform == "Todas" ? "Juegos" : selectedPlatform)
            .onDeleteCommand(perform: onDeleteSelected)
            .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 380)
        } detail: {
            if let selectedGame {
                GameDetailView(game: selectedGame)
            } else {
                GameSelectionPlaceholderView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $searchText, prompt: "Buscar por titulo, plataforma o genero")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Nuevo juego", systemImage: "plus")
                }
            }

            ToolbarItem {
                Button(role: .destructive, action: onDeleteSelected) {
                    Label("Eliminar", systemImage: "trash")
                }
                .disabled(selectedGame == nil)
            }
        }
    }
}
#else
private struct IOSLibraryView: View {
    let games: [Game]
    let totalCount: Int
    @Binding var searchText: String
    @Binding var selectedPlatform: String
    @Binding var navigationPath: [PersistentIdentifier]
    @Binding var showingAddSheet: Bool
    let platformOptions: [String]
    let onDelete: (IndexSet) -> Void

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if games.isEmpty {
                    GameEmptyStateView(searchText: searchText, selectedPlatform: selectedPlatform)
                        .padding(.horizontal, 24)
                } else {
                    List {
                        Section {
                            LibraryHeroCard(
                                totalCount: totalCount,
                                visibleCount: games.count,
                                selectedPlatform: selectedPlatform,
                                platformOptions: platformOptions
                            ) { platform in
                                selectedPlatform = platform
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                        }

                        Section("Juegos") {
                            ForEach(games) { game in
                                NavigationLink(value: game.persistentModelID) {
                                    GameRowContent(game: game)
                                }
                            }
                            .onDelete(perform: onDelete)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Juegos")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Buscar por titulo, plataforma o genero")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Nuevo juego", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: PersistentIdentifier.self) { identifier in
                if let game = games.first(where: { $0.persistentModelID == identifier }) {
                    GameDetailView(game: game)
                        .navigationBarTitleDisplayMode(.inline)
                } else {
                    GameEmptyStateView(searchText: searchText, selectedPlatform: selectedPlatform)
                }
            }
        }
    }
}
#endif

#Preview {
    ContentView()
        .modelContainer(for: Game.self, inMemory: true)
}
