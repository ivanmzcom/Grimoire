//
//  GameUIComponents.swift
//  JuegosApp
//
//  Created by Codex on 23/4/26.
//

import SwiftUI

struct LibraryHeroCard: View {
    let totalCount: Int
    let visibleCount: Int
    let selectedPlatform: String
    let platformOptions: [String]
    let onPlatformChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Biblioteca")
                    .font(.title2.weight(.semibold))
                Text("\(totalCount) juegos registrados")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                LibraryStatCard(title: "Visibles", value: "\(visibleCount)", systemImage: "line.3.horizontal.decrease.circle")
                LibraryStatCard(title: "Total", value: "\(totalCount)", systemImage: "shippingbox.fill")
            }

            Menu {
                ForEach(platformOptions, id: \.self) { platform in
                    Button(platform) {
                        onPlatformChange(platform)
                    }
                }
            } label: {
                HStack {
                    Label(selectedPlatform, systemImage: "gamecontroller")
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
    }
}

struct SidebarFilterRow: View {
    let title: String
    let systemImage: String
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(title)
                .lineLimit(1)

            Spacer()

            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

struct GameListRowContent: View {
    let list: GameList

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(list.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(list.gameCountLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct GameCoverPlaceholder: View {
    let title: String
    var size: CGSize = CGSize(width: 28, height: 40)
    var cornerRadius: CGFloat = 7

    private var monogram: String {
        String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
    }

    private var topColor: Color {
#if os(macOS)
        Color(nsColor: .quaternaryLabelColor).opacity(0.45)
#else
        Color(uiColor: .quaternaryLabel).opacity(0.45)
#endif
    }

    private var bottomColor: Color {
#if os(macOS)
        Color(nsColor: .tertiaryLabelColor).opacity(0.24)
#else
        Color(uiColor: .tertiaryLabel).opacity(0.24)
#endif
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            topColor,
                            bottomColor
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "gamecontroller.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Text(monogram.isEmpty ? "?" : monogram)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
        }
        .frame(width: size.width, height: size.height)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.quaternary)
        }
        .accessibilityHidden(true)
    }
}

struct GameCoverArtwork: View {
    let title: String
    var coverURL: String = ""
    var size: CGSize = CGSize(width: 28, height: 40)
    var cornerRadius: CGFloat = 7

    private var imageURL: URL? {
        URL(string: coverURL)
    }

    var body: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    GameCoverPlaceholder(title: title, size: size, cornerRadius: cornerRadius)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(.quaternary)
                        }
                        .accessibilityHidden(true)
                case .failure:
                    GameCoverPlaceholder(title: title, size: size, cornerRadius: cornerRadius)
                @unknown default:
                    GameCoverPlaceholder(title: title, size: size, cornerRadius: cornerRadius)
                }
            }
            .frame(width: size.width, height: size.height)
        } else {
            GameCoverPlaceholder(title: title, size: size, cornerRadius: cornerRadius)
        }
    }
}

struct GameHeroBackdrop: View {
    let game: Game
    var height: CGFloat = 220

    private var heroURL: String {
        if !game.heroImageURL.isEmpty {
            return game.heroImageURL
        }

        if !game.screenshotURL.isEmpty {
            return game.screenshotURL
        }

        return game.coverURL
    }

    private var imageURL: URL? {
        URL(string: heroURL)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backgroundImage

            LinearGradient(
                colors: [
                    .black.opacity(0.10),
                    .black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    .black.opacity(0.50),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.quaternary)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var backgroundImage: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    fallback
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        ZStack {
            Rectangle()
                .fill(Color.primary.opacity(0.07))

            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.45))
        }
    }
}

struct MacGameListRow: View {
    let game: Game

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            GameCoverArtwork(title: game.title, coverURL: game.coverURL)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(game.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)

                    Spacer(minLength: 8)

                    Text(game.copyCount == 1 ? "1 copia" : "\(game.copyCount) copias")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }

                Text(game.librarySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(game.libraryFootnote)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct LibraryStatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

struct GameRowContent: View {
    let game: Game

    var body: some View {
#if os(macOS)
        VStack(alignment: .leading, spacing: 4) {
            Text(game.title)
                .font(.body.weight(.medium))
                .lineLimit(1)

            Text(game.librarySubtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            Text(game.libraryFootnote)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
#else
        HStack(alignment: .center, spacing: 12) {
            GameCoverArtwork(
                title: game.title,
                coverURL: game.coverURL,
                size: CGSize(width: 42, height: 56),
                cornerRadius: 8
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(game.platformSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(game.detailSummary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
#endif
    }
}

struct GamePill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.08))
            )
            .lineLimit(1)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if lineWidth > 0 && lineWidth + spacing + size.width > maxWidth {
                totalHeight += lineHeight + spacing
                totalWidth = max(totalWidth, lineWidth)
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += lineWidth == 0 ? size.width : spacing + size.width
                lineHeight = max(lineHeight, size.height)
            }
        }

        totalHeight += lineHeight
        totalWidth = max(totalWidth, lineWidth)

        return CGSize(
            width: proposal.width ?? totalWidth,
            height: totalHeight
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )

            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

struct GameEmptyStateView: View {
    let searchText: String
    let selectedPlatform: String

    private var isDefaultState: Bool {
        searchText.isEmpty && selectedPlatform == "Todas"
    }

    private var isWishlistState: Bool {
        selectedPlatform == "__wishlist__"
    }

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(
                description
            )
        )
    }

    private var title: String {
        if isDefaultState {
            return "Tu colección de videojuegos"
        }

        if isWishlistState && searchText.isEmpty {
            return "Wishlist vacía"
        }

        return "No hay resultados"
    }

    private var systemImage: String {
        if isDefaultState {
            return "rectangle.stack.fill.badge.plus"
        }

        if isWishlistState && searchText.isEmpty {
            return "sparkles.rectangle.stack"
        }

        return "magnifyingglass"
    }

    private var description: String {
        if isDefaultState {
            return "Empieza añadiendo tu primer juego y ve construyendo tu inventario."
        }

        if isWishlistState && searchText.isEmpty {
            return "Los juegos sin copia registrada aparecerán aquí automáticamente."
        }

        return "Prueba con otra búsqueda o cambia el filtro."
    }
}

struct GameSelectionPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Selecciona un juego",
            systemImage: "rectangle.stack.person.crop",
            description: Text("Elige un título de la lista para ver su ficha y sus detalles.")
        )
    }
}

struct DetailCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
    }
}

struct DetailBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.08))
            )
    }
}
