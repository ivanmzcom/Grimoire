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
    var onDeleteGame: (() -> Void)? = nil
    var onImportMetadata: (() -> Void)? = nil
    var onAddPlaythrough: ((GameCopy) -> Void)? = nil
    var onEditCopy: ((GameCopy) -> Void)? = nil
    var onEditPlaythrough: ((GamePlaythrough) -> Void)? = nil
    var onDeleteCopy: ((GameCopy) -> Void)? = nil
    var onDeletePlaythrough: ((GamePlaythrough) -> Void)? = nil
    var onOpenList: ((GameList) -> Void)? = nil

    @State private var copyPendingDeletion: GameCopy?
    @State private var playthroughPendingDeletion: GamePlaythrough?
    @State private var selectedGalleryImage: GameGalleryImage?

    private var copyCountLabel: String {
        game.copyCount == 1 ? "1 copia" : "\(game.copyCount) copias"
    }

    private var gameSummary: String {
        game.releaseYear.map(String.init) ?? ""
    }

    var body: some View {
#if os(macOS)
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GameDetailHeroHeader(game: game)

                    Divider()

                    GameMetadataGrid(game: game)

                    if game.hasImportedMetadata {
                        Divider()

                        GameImportedMetadataSection(game: game)
                    }

                    if !game.galleryImageURLs.isEmpty {
                        Divider()

                        GameImageGallerySection(game: game) { imageURL in
                            selectedGalleryImage = GameGalleryImage(url: imageURL)
                        }
                    }

                    Divider()

                    GameTagsSection(game: game)

                    Divider()

                    GameExternalLinksSection(game: game)

                    Divider()

                    GameIncludedInSection(game: game, onOpenList: onOpenList)

                    Divider()

                    GameCopiesSection(
                        game: game,
                        onAddPlaythrough: onAddPlaythrough,
                        onEditCopy: onEditCopy,
                        onEditPlaythrough: onEditPlaythrough,
                        onDeleteCopy: { copyPendingDeletion = $0 },
                        onDeletePlaythrough: { playthroughPendingDeletion = $0 }
                    )
                }
                .padding(32)
                .frame(
                    maxWidth: min(max(proxy.size.width - 64, 760), 1160),
                    alignment: .leading
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }
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
        .confirmationDialog(
            "Eliminar copia",
            isPresented: Binding(
                get: { copyPendingDeletion != nil },
                set: { if !$0 { copyPendingDeletion = nil } }
            ),
            presenting: copyPendingDeletion
        ) { copy in
            Button("Eliminar copia", role: .destructive) {
                onDeleteCopy?(copy)
            }
        } message: { copy in
            Text("Se eliminará la copia de \(copy.platform) junto con sus partidas.")
        }
        .confirmationDialog(
            "Eliminar partida",
            isPresented: Binding(
                get: { playthroughPendingDeletion != nil },
                set: { if !$0 { playthroughPendingDeletion = nil } }
            ),
            presenting: playthroughPendingDeletion
        ) { playthrough in
            Button("Eliminar partida", role: .destructive) {
                onDeletePlaythrough?(playthrough)
            }
        } message: { playthrough in
            Text("Se eliminará la partida \"\(playthrough.status)\".")
        }
        .sheet(item: $selectedGalleryImage) { galleryImage in
            GameGalleryFullscreenImage(image: galleryImage)
        }
#else
        List {
            Section {
                GameDetailHeroHeader(game: game, compact: true)
                    .listRowInsets(EdgeInsets())
            }

            Section("Ficha") {
                DetailRow(label: "Año", value: game.releaseYear.map(String.init) ?? "Sin indicar")
                DetailRow(label: "Copias", value: copyCountLabel)
                DetailRow(label: "Partidas", value: game.playthroughCountLabel)
                DetailRow(label: "Añadido", value: game.createdAt.formatted(date: .abbreviated, time: .omitted))
            }

            if game.hasImportedMetadata {
                Section("IGDB") {
                    GameImportedMetadataSection(game: game, showsTitle: false)
                }
            }

            if !game.galleryImageURLs.isEmpty {
                Section("Galería") {
                    GameImageGallerySection(game: game, showsTitle: false) { imageURL in
                        selectedGalleryImage = GameGalleryImage(url: imageURL)
                    }
                }
            }

            Section("Etiquetas") {
                GameTagsSection(game: game, showsTitle: false)
            }

            Section("Enlaces") {
                GameExternalLinksSection(game: game, showsTitle: false)
            }

            Section("Incluido en") {
                GameIncludedInSection(game: game, showsTitle: false, onOpenList: onOpenList)
            }

            Section("Copias") {
                GameCopiesSection(
                    game: game,
                    onAddPlaythrough: onAddPlaythrough,
                    onEditCopy: onEditCopy,
                    onEditPlaythrough: onEditPlaythrough,
                    onDeleteCopy: { copyPendingDeletion = $0 },
                    onDeletePlaythrough: { playthroughPendingDeletion = $0 },
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
        .confirmationDialog(
            "Eliminar copia",
            isPresented: Binding(
                get: { copyPendingDeletion != nil },
                set: { if !$0 { copyPendingDeletion = nil } }
            ),
            presenting: copyPendingDeletion
        ) { copy in
            Button("Eliminar copia", role: .destructive) {
                onDeleteCopy?(copy)
            }
        } message: { copy in
            Text("Se eliminará la copia de \(copy.platform) junto con sus partidas.")
        }
        .confirmationDialog(
            "Eliminar partida",
            isPresented: Binding(
                get: { playthroughPendingDeletion != nil },
                set: { if !$0 { playthroughPendingDeletion = nil } }
            ),
            presenting: playthroughPendingDeletion
        ) { playthrough in
            Button("Eliminar partida", role: .destructive) {
                onDeletePlaythrough?(playthrough)
            }
        } message: { playthrough in
            Text("Se eliminará la partida \"\(playthrough.status)\".")
        }
        .fullScreenCover(item: $selectedGalleryImage) { galleryImage in
            GameGalleryFullscreenImage(image: galleryImage)
        }
#endif
    }

    private var hasGameActions: Bool {
        true
    }

    private var gameActionsMenu: some View {
        Menu {
            if let onImportMetadata {
                Button(action: onImportMetadata) {
                    Label(metadataActionTitle, systemImage: metadataActionSystemImage)
                }
            }

            if let onAddCopy {
                Button(action: onAddCopy) {
                    Label("Añadir copia", systemImage: "square.stack.badge.plus")
                }
            }

            if let onDeleteGame {
                Divider()

                Button(role: .destructive, action: onDeleteGame) {
                    Label("Eliminar juego", systemImage: "trash")
                }
            }
        } label: {
            Label("Acciones", systemImage: "ellipsis")
        }
    }

    private var metadataActionTitle: String {
        game.igdbID == nil ? "Importar desde IGDB" : "Actualizar metadatos"
    }

    private var metadataActionSystemImage: String {
        game.igdbID == nil ? "magnifyingglass" : "arrow.clockwise"
    }
}

private struct GameDetailHeroHeader: View {
    let game: Game
    var compact = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GameHeroBackdrop(game: game, height: compact ? 190 : 240)

            HStack(alignment: .bottom, spacing: 18) {
                GameCoverArtwork(
                    title: game.title,
                    coverURL: game.coverURL,
                    size: compact ? CGSize(width: 76, height: 102) : CGSize(width: 96, height: 128),
                    cornerRadius: 14
                )
                .shadow(color: .black.opacity(0.26), radius: 10, y: 6)

                VStack(alignment: .leading, spacing: 8) {
                    Text(game.title)
                        .font(compact ? .title2.weight(.semibold) : .title.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .textSelection(.enabled)

                    HStack(spacing: 8) {
                        if let releaseYear = game.releaseYear {
                            GameHeroPill(text: String(releaseYear))
                        }

                        GameHeroPill(text: game.copyCount == 1 ? "1 copia" : "\(game.copyCount) copias")

                        if let ratingLabel = game.ratingLabel {
                            GameHeroPill(text: ratingLabel)
                        }
                    }

                    Text("Añadido el \(game.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.76))
                }
                .padding(.bottom, 4)
            }
            .padding(compact ? 16 : 20)
        }
    }
}

private struct GameHeroPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.16), in: Capsule(style: .continuous))
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

private struct GameImportedMetadataSection: View {
    let game: Game
    var showsTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsTitle {
                Text("IGDB")
                    .font(.headline)
            }

            if !game.summary.isEmpty {
                Text(game.summary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                if !game.developersText.isEmpty {
                    DetailRow(label: "Desarrolladora", value: game.developersText)
                }

                if !game.publishersText.isEmpty {
                    DetailRow(label: "Editora", value: game.publishersText)
                }

                if !game.genresText.isEmpty {
                    DetailRow(label: "Géneros", value: game.genresText)
                }

                if let ratingLabel = game.ratingLabel {
                    DetailRow(label: "Rating", value: ratingLabel)
                }

                if let metadataImportedAt = game.metadataImportedAt {
                    DetailRow(
                        label: "Importado",
                        value: metadataImportedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
        }
    }
}

private struct GameGalleryImage: Identifiable, Hashable {
    let url: String

    var id: String {
        url
    }
}

private struct GameImageGallerySection: View {
    let game: Game
    var showsTitle = true
    let onSelectImage: (String) -> Void

    private var imageURLs: [String] {
        game.galleryImageURLs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsTitle {
                Text("Galería")
                    .font(.headline)
            }

            if imageURLs.isEmpty {
                GameGalleryFallback(title: game.title)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(imageURLs, id: \.self) { imageURL in
                            Button {
                                onSelectImage(imageURL)
                            } label: {
                                GameGalleryThumbnail(imageURL: imageURL, title: game.title)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Abrir imagen de \(game.title)")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct GameGalleryThumbnail: View {
    let imageURL: String
    let title: String

    private var url: URL? {
        URL(string: imageURL)
    }

    var body: some View {
        ZStack {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        GameGalleryFallback(title: title)
                    default:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.primary.opacity(0.06))
                    }
                }
            } else {
                GameGalleryFallback(title: title)
            }
        }
        .frame(width: 210, height: 118)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.quaternary)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct GameGalleryFallback: View {
    let title: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))

            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
        }
    }
}

private struct GameGalleryFullscreenImage: View {
    let image: GameGalleryImage

    @Environment(\.dismiss) private var dismiss

    private var url: URL? {
        URL(string: image.url)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let loadedImage):
                            loadedImage
                                .resizable()
                                .scaledToFit()
                                .frame(
                                    maxWidth: proxy.size.width - 48,
                                    maxHeight: proxy.size.height - 48
                                )
                        case .failure:
                            unavailableImage
                        default:
                            ProgressView()
                                .tint(.white)
                        }
                    }
                } else {
                    unavailableImage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Label("Cerrar", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                .keyboardShortcut(.cancelAction)
            }
        }
        .frame(minWidth: 960, idealWidth: 1200, minHeight: 720, idealHeight: 900)
    }

    private var unavailableImage: some View {
        ContentUnavailableView(
            "Imagen no disponible",
            systemImage: "photo",
            description: Text("No se pudo cargar esta imagen.")
        )
        .foregroundStyle(.white)
    }
}

private struct GameTagsSection: View {
    let game: Game
    var showsTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsTitle {
                Text("Etiquetas")
                    .font(.headline)
            }

            if game.sortedTags.isEmpty {
                Text("Este juego no tiene etiquetas.")
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(game.sortedTags) { tag in
                        NavigationLink(value: GameLibraryDetailRoute.tag(tag.persistentModelID)) {
                            GamePill(text: tag.name)
                        }
                        .buttonStyle(.plain)
                        .help("Ver juegos con la etiqueta \(tag.name)")
                    }
                }
            }
        }
    }
}

private struct GameExternalLinksSection: View {
    let game: Game
    var showsTitle = true

    private var links: [ExternalGameLink] {
        ExternalGameLink.links(for: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsTitle {
                Text("Enlaces")
                    .font(.headline)
            }

            if links.isEmpty {
                Text("No hay enlaces disponibles para este juego.")
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(links) { link in
                        Link(destination: link.url) {
                            Label(link.title, systemImage: link.systemImage)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

private struct ExternalGameLink: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let url: URL

    static func links(for game: Game) -> [ExternalGameLink] {
        var links = [ExternalGameLink]()

        if let igdbURL = URL(string: game.igdbURL), !game.igdbURL.isEmpty {
            links.append(
                ExternalGameLink(
                    id: "igdb",
                    title: "IGDB",
                    systemImage: "gamecontroller",
                    url: igdbURL
                )
            )
        }

        appendSearchLink(
            id: "steam",
            title: "Steam",
            systemImage: "bag",
            base: "https://store.steampowered.com/search/?term=",
            query: game.title,
            to: &links
        )
        appendSearchLink(
            id: "hltb",
            title: "HowLongToBeat",
            systemImage: "clock",
            base: "https://howlongtobeat.com/?q=",
            query: game.title,
            to: &links
        )
        appendSearchLink(
            id: "youtube",
            title: "YouTube",
            systemImage: "play.rectangle",
            base: "https://www.youtube.com/results?search_query=",
            query: "\(game.title) trailer gameplay",
            to: &links
        )
        appendSearchLink(
            id: "wiki",
            title: "Wiki",
            systemImage: "book",
            base: "https://duckduckgo.com/?q=",
            query: "\(game.title) wiki",
            to: &links
        )
        appendSearchLink(
            id: "guides",
            title: "Guías",
            systemImage: "map",
            base: "https://duckduckgo.com/?q=",
            query: "\(game.title) guide",
            to: &links
        )

        return links
    }

    private static func appendSearchLink(
        id: String,
        title: String,
        systemImage: String,
        base: String,
        query: String,
        to links: inout [ExternalGameLink]
    ) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: base + encodedQuery)
        else {
            return
        }

        links.append(ExternalGameLink(id: id, title: title, systemImage: systemImage, url: url))
    }
}

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
    var onAddPlaythrough: ((GameCopy) -> Void)?
    var onEditCopy: ((GameCopy) -> Void)?
    var onEditPlaythrough: ((GamePlaythrough) -> Void)?
    var onDeleteCopy: ((GameCopy) -> Void)?
    var onDeletePlaythrough: ((GamePlaythrough) -> Void)?
    var showsTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsTitle {
                Text("Copias")
                    .font(.headline)
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
                            onEditPlaythrough: onEditPlaythrough,
                            onDeleteCopy: onDeleteCopy,
                            onDeletePlaythrough: onDeletePlaythrough
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
    var onDeleteCopy: ((GameCopy) -> Void)?
    var onDeletePlaythrough: ((GamePlaythrough) -> Void)?

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

                if let onDeleteCopy {
                    Button(role: .destructive) {
                        onDeleteCopy(copy)
                    } label: {
                        Label("Eliminar copia", systemImage: "trash")
                    }
                    .labelStyle(.iconOnly)
                    .platformInlineActionButtonStyle()
                    .help("Eliminar copia")
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
                                onEdit: onEditPlaythrough,
                                onDelete: onDeletePlaythrough
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
    var onDelete: ((GamePlaythrough) -> Void)?

    private static let hoursFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.numberStyle = .decimal
        return formatter
    }()

    private var statusLabel: String {
        playthrough.status.isEmpty ? "Sin estado" : playthrough.status
    }

    private var createdAtLabel: String {
        playthrough.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    private var dateRangeLabel: String? {
        switch (playthrough.startedAt, playthrough.completedAt) {
        case let (startedAt?, completedAt?):
            return "\(startedAt.formatted(date: .abbreviated, time: .omitted)) - \(completedAt.formatted(date: .abbreviated, time: .omitted))"
        case let (startedAt?, nil):
            return "Inicio \(startedAt.formatted(date: .abbreviated, time: .omitted))"
        case let (nil, completedAt?):
            return "Fin \(completedAt.formatted(date: .abbreviated, time: .omitted))"
        case (nil, nil):
            return nil
        }
    }

    private var hoursPlayedLabel: String? {
        guard let hoursPlayed = playthrough.hoursPlayed else { return nil }

        let value = Self.hoursFormatter.string(from: NSNumber(value: hoursPlayed)) ?? "\(hoursPlayed)"
        return "\(value) h"
    }

    private var personalRatingLabel: String? {
        guard let personalRating = playthrough.personalRating else { return nil }
        return "\(personalRating)/10"
    }

    private var metadataItems: [String] {
        [
            dateRangeLabel,
            hoursPlayedLabel,
            personalRatingLabel,
            playthrough.difficulty.isEmpty ? nil : playthrough.difficulty
        ].compactMap(\.self)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Partida \(number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)

                Text(statusLabel)
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

                if let onDelete {
                    Button(role: .destructive) {
                        onDelete(playthrough)
                    } label: {
                        Label("Eliminar partida", systemImage: "trash")
                    }
                    .labelStyle(.iconOnly)
                    .platformInlineActionButtonStyle()
                    .help("Eliminar partida")
                }

                Text(createdAtLabel)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if !metadataItems.isEmpty {
                Text(metadataItems.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 74)
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
    game.addCopy(
        GameCopy(
            platform: "Nintendo Switch",
            format: "Físico",
            notes: "Edición estándar con funda en buen estado."
        )
    )
    game.addCopy(
        GameCopy(
            platform: "Nintendo Switch",
            format: "Digital"
        )
    )

    game.sortedCopies[0].addPlaythrough(GamePlaythrough(status: "Jugando"))
    game.sortedCopies[0].addPlaythrough(GamePlaythrough(status: "Completado"))
    game.sortedCopies[1].addPlaythrough(GamePlaythrough(status: "Archivado"))

    return GameDetailView(game: game)
}
