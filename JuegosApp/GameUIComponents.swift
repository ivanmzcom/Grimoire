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
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Text(monogram.isEmpty ? "?" : monogram)
                .font(.system(size: 12, weight: .bold, design: .rounded))
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

struct MacGameListRow: View {
    let game: Game

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            GameCoverPlaceholder(title: game.title)

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
        VStack(alignment: .leading, spacing: 8) {
            Text(game.title)
                .font(.headline)
                .lineLimit(2)

            Text(game.platformSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                GamePill(text: game.platformSummary)
                GamePill(text: game.copyCount == 1 ? "1 copia" : "\(game.copyCount) copias")
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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

struct GameEmptyStateView: View {
    let searchText: String
    let selectedPlatform: String

    private var isDefaultState: Bool {
        searchText.isEmpty && selectedPlatform == "Todas"
    }

    var body: some View {
        ContentUnavailableView(
            isDefaultState ? "Tu coleccion de videojuegos" : "No hay resultados",
            systemImage: isDefaultState ? "rectangle.stack.fill.badge.plus" : "magnifyingglass",
            description: Text(
                isDefaultState
                    ? "Empieza anadiendo tu primer juego y ve construyendo tu inventario."
                    : "Prueba con otra busqueda o cambia el filtro de plataforma."
            )
        )
    }
}

struct GameSelectionPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Selecciona un juego",
            systemImage: "rectangle.stack.person.crop",
            description: Text("Elige un titulo de la tabla para ver su ficha y sus detalles.")
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
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
