//
//  GameFormView.swift
//  JuegosApp
//
//  Created by Codex on 23/4/26.
//

import SwiftData
import SwiftUI

struct GameFormView: View {
    private let pageSize = 12
    private let credentials = IGDBCredentialsStore.load()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Game.title)]) private var existingGames: [Game]

    @State private var searchText = ""
    @State private var results = [IGDBGameMetadata]()
    @State private var isSearching = false
    @State private var isLoadingMore = false
    @State private var hasMoreResults = false
    @State private var nextOffset = 0
    @State private var activeSearchText = ""
    @State private var didSearch = false
    @State private var message: String?

    var onCreate: ((Game) -> Void)? = nil

    private var canSearch: Bool {
        credentials.isComplete
            && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSearching
    }

    private var canLoadMore: Bool {
        hasMoreResults && !isSearching && !isLoadingMore && !activeSearchText.isEmpty
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
            header

            Divider()

            singleColumnContent

            Divider()

            footer
        }
        .frame(minWidth: 860, idealWidth: 940, minHeight: 640, idealHeight: 720)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "plus.square.on.square")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Nuevo juego")
                        .font(.title3.weight(.semibold))

                    Text(resultsCountLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    private var singleColumnContent: some View {
        VStack(spacing: 0) {
            searchBarSection

            Divider()

            resultsPane
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var searchBarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("Buscar en IGDB", systemImage: "magnifyingglass")
                    .font(.headline)

                if !activeSearchText.isEmpty {
                    Text(activeSearchText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if !credentials.isComplete {
                Label("Faltan credenciales de IGDB en `JuegosApp/Secrets.plist`.", systemImage: "key.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                TextField("Buscar en IGDB", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .onSubmit {
                        startSearch()
                    }

                Button {
                    startSearch()
                } label: {
                    Label("Buscar", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSearch)
                .keyboardShortcut(.defaultAction)

                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Buscando en IGDB")
                }
            }

            Text(searchHintText)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var resultsPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Resultados")
                    .font(.headline)

                Spacer()

                if isLoadingMore {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Cargando más")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if hasMoreResults {
                    Text("Más resultados disponibles")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            Divider()

            if results.isEmpty {
                MacResultsPlaceholder(
                    didSearch: didSearch,
                    hasCredentials: credentials.isComplete
                )
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                List {
                    ForEach(results) { result in
                        let duplicateGame = existingGame(for: result)

                        HStack(alignment: .center, spacing: 14) {
                            IGDBSearchResultRow(metadata: result)

                            Spacer(minLength: 12)

                            if duplicateGame == nil {
                                Button("Añadir") {
                                    createGame(from: result)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                            } else {
                                Label("Ya existe", systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .task {
                            await loadMoreIfNeeded(currentResult: result)
                        }
                    }

                    if isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Cargando más resultados de IGDB")
                            Spacer()
                        }
                    } else if hasMoreResults {
                        Button {
                            Task {
                                await loadMore()
                            }
                        } label: {
                            Label("Cargar más resultados", systemImage: "arrow.down.circle")
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var footer: some View {
        HStack {
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(messageHasError ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button("Cancelar") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
#else
    private var iosForm: some View {
        NavigationStack {
            List {
                searchSection
                resultsSection
            }
            .navigationTitle("Nuevo juego")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
    private var searchSection: some View {
        Section("Búsqueda") {
            if !credentials.isComplete {
                Text("Añade `JuegosApp/Secrets.plist` con `IGDBClientID` e `IGDBClientSecret` para activar la búsqueda.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("Nombre del juego", text: $searchText)
#if os(iOS)
                .textInputAutocapitalization(.words)
#endif
                .onSubmit {
                    startSearch()
                }

            HStack {
                Button {
                    startSearch()
                } label: {
                    Label("Buscar en IGDB", systemImage: "magnifyingglass")
                }
                .disabled(!canSearch)

                if isSearching {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Buscando en IGDB")
                }
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        Section("Resultados") {
            if results.isEmpty {
                Text(didSearch ? "No se encontraron resultados." : "Busca un juego para crearlo desde IGDB.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results) { result in
                    let duplicateGame = existingGame(for: result)

                    HStack(alignment: .center, spacing: 12) {
                        IGDBSearchResultRow(metadata: result)

                        Spacer(minLength: 12)

                        if duplicateGame == nil {
                            Button("Añadir") {
                                createGame(from: result)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Text("Ya existe")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .task {
                        await loadMoreIfNeeded(currentResult: result)
                    }
                }

                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Cargando más resultados de IGDB")
                        Spacer()
                    }
                } else if hasMoreResults {
                    Button {
                        Task {
                            await loadMore()
                        }
                    } label: {
                        Label("Cargar más resultados", systemImage: "arrow.down.circle")
                    }
                }
            }
        }
    }
#endif

    private var messageHasError: Bool {
        message == IGDBMetadataError.missingCredentials.localizedDescription
            || message == "No se pudo guardar el juego. Inténtalo de nuevo."
            || message == "Ese juego ya existe en tu biblioteca."
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resultsCountLabel: String {
        if results.isEmpty {
            return didSearch ? "Sin resultados" : "IGDB"
        }

        return results.count == 1 ? "1 resultado" : "\(results.count) resultados"
    }

    private var headerSubtitle: String {
        if !credentials.isComplete {
            return "Faltan las credenciales locales de IGDB para poder buscar y crear juegos."
        }

        if isSearching {
            return "Buscando coincidencias en IGDB…"
        }

        if !activeSearchText.isEmpty {
            return "Elige el resultado correcto para crear la ficha de “\(activeSearchText)”."
        }

        return "Busca el juego en IGDB y crea la ficha automáticamente."
    }

    private var searchHintText: String {
        if !credentials.isComplete {
            return "La búsqueda se activa cuando `JuegosApp/Secrets.plist` contiene `IGDBClientID` e `IGDBClientSecret`."
        }

        if didSearch && results.isEmpty {
            return "Prueba con el título principal del juego o con una variante menos específica."
        }

        return "Busca por título principal. Los resultados se crean directamente desde los metadatos de IGDB."
    }

    private func startSearch() {
        guard canSearch else {
            message = IGDBMetadataError.missingCredentials.localizedDescription
            return
        }

        Task {
            await search()
        }
    }

    @MainActor
    private func search() async {
        isSearching = true
        didSearch = true
        message = nil
        hasMoreResults = false
        nextOffset = 0

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        activeSearchText = query

        do {
            let page = try await IGDBMetadataService(credentials: credentials).searchGames(
                matching: query,
                limit: pageSize,
                offset: 0
            )
            results = page
            nextOffset = page.count
            hasMoreResults = page.count == pageSize
            message = results.isEmpty ? "Sin resultados para esta búsqueda." : nil
        } catch {
            results = []
            activeSearchText = ""
            message = error.localizedDescription
        }

        isSearching = false
    }

    @MainActor
    private func loadMoreIfNeeded(currentResult: IGDBGameMetadata) async {
        guard currentResult.id == results.last?.id else { return }
        await loadMore()
    }

    @MainActor
    private func loadMore() async {
        guard canLoadMore else { return }

        isLoadingMore = true
        message = nil

        do {
            let page = try await IGDBMetadataService(credentials: credentials).searchGames(
                matching: activeSearchText,
                limit: pageSize,
                offset: nextOffset
            )
            append(page)
            nextOffset += page.count
            hasMoreResults = page.count == pageSize
        } catch {
            message = error.localizedDescription
        }

        isLoadingMore = false
    }

    private func append(_ page: [IGDBGameMetadata]) {
        let existingIDs = Set(results.map(\.id))
        results.append(contentsOf: page.filter { !existingIDs.contains($0.id) })
    }

    private func createGame(from metadata: IGDBGameMetadata) {
        guard existingGame(for: metadata) == nil else {
            message = "Ese juego ya existe en tu biblioteca."
            return
        }

        let game = Game(
            title: metadata.name,
            releaseYear: metadata.releaseYear
        )
        game.applyIGDBMetadata(metadata)

        modelContext.insert(game)

        do {
            try modelContext.save()
            onCreate?(game)
            dismiss()
        } catch {
            message = "No se pudo guardar el juego. Inténtalo de nuevo."
        }
    }

    private func existingGame(for metadata: IGDBGameMetadata) -> Game? {
        if let game = existingGames.first(where: { $0.igdbID == metadata.id }) {
            return game
        }

        return existingGames.first { game in
            game.title.compare(
                metadata.name,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                range: nil,
                locale: .current
            ) == .orderedSame && game.releaseYear == metadata.releaseYear
        }
    }
}

private struct IGDBSearchResultRow: View {
    let metadata: IGDBGameMetadata

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GameCoverArtwork(
                title: metadata.name,
                coverURL: metadata.normalizedCoverURL,
                size: CGSize(width: 48, height: 64),
                cornerRadius: 8
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(metadata.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let year = metadata.releaseYear {
                        Text(String(year))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !metadata.resultSubtitle.isEmpty {
                    Text(metadata.resultSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let ratingLabel = metadata.ratingLabel {
                        Label(ratingLabel, systemImage: "star.fill")
                    }

                    if !metadata.platformsText.isEmpty {
                        Label(metadata.platformsText, systemImage: "gamecontroller")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#if os(macOS)
private struct MacResultsPlaceholder: View {
    let didSearch: Bool
    let hasCredentials: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: didSearch ? "magnifyingglass" : "text.magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(didSearch ? "No se encontraron resultados" : "Busca un juego en IGDB")
                .font(.title3.weight(.semibold))

            Text(placeholderText)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
    }

    private var placeholderText: String {
        if !hasCredentials {
            return "Configura las credenciales de IGDB para activar la búsqueda y crear juegos desde sus metadatos."
        }

        if didSearch {
            return "Prueba con otro nombre, una variante del título o la edición principal del juego."
        }

        return "Busca el título en IGDB y elige el resultado correcto para crear la ficha."
    }
}
#endif

#Preview {
    GameFormView()
        .modelContainer(for: [Game.self, GameCopy.self, GamePlaythrough.self], inMemory: true)
}
