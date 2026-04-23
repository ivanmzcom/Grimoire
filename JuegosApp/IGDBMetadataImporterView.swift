//
//  IGDBMetadataImporterView.swift
//  JuegosApp
//
//  Created by Codex on 23/4/26.
//

import SwiftData
import SwiftUI

struct IGDBMetadataImporterView: View {
    private let pageSize = 12

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let game: Game

    @State private var searchText: String
    @State private var clientID: String
    @State private var clientSecret: String
    @State private var results = [IGDBGameMetadata]()
    @State private var isSearching = false
    @State private var isLoadingMore = false
    @State private var hasMoreResults = false
    @State private var nextOffset = 0
    @State private var activeSearchText = ""
    @State private var didSearch = false
    @State private var message: String?

    init(game: Game) {
        self.game = game

        let credentials = IGDBCredentialsStore.load()
        _searchText = State(initialValue: game.title)
        _clientID = State(initialValue: credentials.clientID)
        _clientSecret = State(initialValue: credentials.clientSecret)
    }

    private var credentials: IGDBCredentials {
        IGDBCredentials(clientID: clientID, clientSecret: clientSecret)
    }

    private var canSearch: Bool {
        credentials.isComplete && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSearching
    }

    private var canLoadMore: Bool {
        hasMoreResults && !isSearching && !isLoadingMore && !activeSearchText.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                credentialsSection
                searchSection
                resultsSection
            }
            .navigationTitle("IGDB")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 640, idealWidth: 700, minHeight: 560, idealHeight: 620)
#endif
    }

    private var credentialsSection: some View {
        Section("Credenciales") {
            TextField("Client ID", text: $clientID)
#if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
#endif

            SecureField("Client Secret", text: $clientSecret)

            Button("Guardar credenciales") {
                saveCredentials()
            }
            .disabled(!credentials.isComplete)
        }
    }

    private var searchSection: some View {
        Section("Búsqueda") {
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

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        Section("Resultados") {
            if results.isEmpty {
                Text(didSearch ? "No se encontraron resultados." : "Busca un juego para ver resultados de IGDB.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results) { result in
                    Button {
                        apply(result)
                    } label: {
                        IGDBMetadataResultRow(metadata: result)
                    }
                    .buttonStyle(.plain)
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

    private func saveCredentials() {
        do {
            try IGDBCredentialsStore.save(credentials)
            message = "Credenciales guardadas."
        } catch {
            message = error.localizedDescription
        }
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
            try IGDBCredentialsStore.save(credentials)
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

    private func apply(_ metadata: IGDBGameMetadata) {
        game.applyIGDBMetadata(metadata)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            message = "No se pudieron guardar los metadatos."
        }
    }
}

private struct IGDBMetadataResultRow: View {
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
                Text(metadata.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

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
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "checkmark.circle")
                .foregroundStyle(.secondary)
                .imageScale(.large)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Aplica estos metadatos al juego.")
    }
}

#if os(macOS)
struct IGDBSettingsView: View {
    @State private var clientID: String
    @State private var clientSecret: String
    @State private var message: String?

    init() {
        let credentials = IGDBCredentialsStore.load()
        _clientID = State(initialValue: credentials.clientID)
        _clientSecret = State(initialValue: credentials.clientSecret)
    }

    private var credentials: IGDBCredentials {
        IGDBCredentials(clientID: clientID, clientSecret: clientSecret)
    }

    var body: some View {
        Form {
            Section("Credenciales") {
                TextField("Client ID", text: $clientID)
                    .textFieldStyle(.roundedBorder)

                SecureField("Client Secret", text: $clientSecret)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Guardar") {
                        save()
                    }
                    .disabled(!credentials.isComplete)

                    Button("Borrar", role: .destructive) {
                        clear()
                    }

                    Spacer()

                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func save() {
        do {
            try IGDBCredentialsStore.save(credentials)
            message = "Guardado"
        } catch {
            message = error.localizedDescription
        }
    }

    private func clear() {
        do {
            try IGDBCredentialsStore.clear()
            clientID = ""
            clientSecret = ""
            message = "Borrado"
        } catch {
            message = error.localizedDescription
        }
    }
}
#endif

#Preview {
    let game = Game(title: "Metaphor: ReFantazio", releaseYear: 2024)

    return IGDBMetadataImporterView(game: game)
        .modelContainer(for: [Game.self, GameCopy.self, GamePlaythrough.self], inMemory: true)
}
