//
//  Game.swift
//  JuegosApp
//
//  Created by Codex on 23/4/26.
//

import Foundation
import SwiftData

@Model
final class Game {
    var title: String = ""
    var releaseYear: Int?
    var igdbID: Int?
    var coverURL: String = ""
    var heroImageURL: String = ""
    var screenshotURL: String = ""
    var galleryImageURLsText: String = ""
    var summary: String = ""
    var genresText: String = ""
    var developersText: String = ""
    var publishersText: String = ""
    var igdbURL: String = ""
    var totalRating: Double?
    var metadataImportedAt: Date?
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .cascade, inverse: \GameCopy.game) var copies: [GameCopy]?
    @Relationship(deleteRule: .cascade, inverse: \GameListEntry.game) var listEntries: [GameListEntry]?
    @Relationship(deleteRule: .cascade, inverse: \GameTagAssignment.game) var tagAssignments: [GameTagAssignment]?

    init(
        title: String,
        releaseYear: Int? = nil,
        createdAt: Date = .now
    ) {
        self.title = title
        self.releaseYear = releaseYear
        self.createdAt = createdAt
    }

    func addCopy(_ copy: GameCopy) {
        var currentCopies = copies ?? []
        currentCopies.append(copy)
        copies = currentCopies
        copy.game = self
    }

    var sortedCopies: [GameCopy] {
        (copies ?? []).sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.platform < rhs.platform
            }

            return lhs.createdAt < rhs.createdAt
        }
    }

    var copyCount: Int {
        sortedCopies.count
    }

    var isWishlistItem: Bool {
        copyCount == 0
    }

    func hasTag(_ tag: GameTag) -> Bool {
        sortedTags.contains { existingTag in
            existingTag.persistentModelID == tag.persistentModelID
        }
    }

    var sortedTags: [GameTag] {
        var uniqueTags = [GameTag]()

        for assignment in tagAssignments ?? [] {
            guard let tag = assignment.tag,
                  !uniqueTags.contains(where: { $0.persistentModelID == tag.persistentModelID })
            else {
                continue
            }

            uniqueTags.append(tag)
        }

        return uniqueTags.sorted { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    var tagsText: String {
        joinedSummary(for: sortedTags.map(\.name), fallback: "")
    }

    var platformSummary: String {
        joinedSummary(for: sortedCopies.map(\.platform), fallback: "Sin plataforma")
    }

    var formatSummary: String {
        joinedSummary(for: sortedCopies.map(\.format), fallback: "Sin formato")
    }

    var playthroughCount: Int {
        sortedCopies.reduce(into: 0) { partialResult, copy in
            partialResult += copy.playthroughCount
        }
    }

    var playthroughCountLabel: String {
        playthroughCount == 1 ? "1 partida" : "\(playthroughCount) partidas"
    }

    var statusSummary: String {
        joinedSummary(
            for: sortedCopies.flatMap { copy in
                if copy.sortedPlaythroughs.isEmpty && !copy.status.isEmpty {
                    return [copy.status]
                }

                return copy.sortedPlaythroughs.map(\.status)
            },
            fallback: "Sin partidas"
        )
    }

    var searchableCopyText: String {
        (
            [summary, genresText, developersText, publishersText]
            + sortedCopies.map(\.searchableText)
            + sortedTags.map(\.name)
        )
        .joined(separator: " ")
    }

    var primaryCopy: GameCopy? {
        sortedCopies.first
    }

    var includedLists: [GameList] {
        var uniqueLists = [GameList]()

        for entry in listEntries ?? [] {
            guard let list = entry.list,
                  !uniqueLists.contains(where: { $0.persistentModelID == list.persistentModelID })
            else {
                continue
            }

            uniqueLists.append(list)
        }

        return uniqueLists.sorted { lhs, rhs in
            let titleComparison = lhs.title.localizedStandardCompare(rhs.title)

            if titleComparison == .orderedSame {
                return lhs.createdAt < rhs.createdAt
            }

            return titleComparison == .orderedAscending
        }
    }

    var detailSummary: String {
        var pieces = [String]()

        if let releaseYear {
            pieces.append(String(releaseYear))
        }

        pieces.append(copyCount == 1 ? "1 copia" : "\(copyCount) copias")

        if playthroughCount > 0 {
            pieces.append(playthroughCountLabel)
        }

        return pieces
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var librarySubtitle: String {
        if !developersText.isEmpty {
            return developersText
        }

        return platformSummary
    }

    var libraryFootnote: String {
        if playthroughCount == 0 {
            return "\(formatSummary) · Sin partidas"
        }

        if playthroughCount == 1 {
            return "\(formatSummary) · \(statusSummary)"
        }

        return "\(playthroughCountLabel) · \(statusSummary)"
    }

    private func joinedSummary(for values: [String], fallback: String) -> String {
        var uniqueValues = [String]()

        for value in values where !value.isEmpty && !uniqueValues.contains(value) {
            uniqueValues.append(value)
        }

        return uniqueValues.isEmpty ? fallback : uniqueValues.joined(separator: ", ")
    }

    var hasImportedMetadata: Bool {
        igdbID != nil
            || !coverURL.isEmpty
            || !summary.isEmpty
            || !genresText.isEmpty
            || !developersText.isEmpty
            || !publishersText.isEmpty
            || !heroImageURL.isEmpty
            || !screenshotURL.isEmpty
            || !galleryImageURLsText.isEmpty
            || totalRating != nil
    }

    var ratingLabel: String? {
        guard let totalRating else { return nil }
        return "\(Int(totalRating.rounded()))/100"
    }

    var galleryImageURLs: [String] {
        let importedURLs = galleryImageURLsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        return uniqueImageURLs(importedURLs + [heroImageURL, screenshotURL])
    }

    private func uniqueImageURLs(_ urls: [String]) -> [String] {
        var uniqueURLs = [String]()

        for url in urls {
            guard !url.isEmpty, !uniqueURLs.contains(url) else {
                continue
            }

            uniqueURLs.append(url)
        }

        return uniqueURLs
    }
}

@Model
final class GameTag {
    var name: String = ""
    var normalizedName: String = ""
    var colorHex: String = ""
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .cascade, inverse: \GameTagAssignment.tag) var assignments: [GameTagAssignment]?

    init(
        name: String,
        colorHex: String = "",
        createdAt: Date = .now
    ) {
        self.name = name
        self.normalizedName = Self.normalized(name)
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    var gameCount: Int {
        (assignments ?? []).filter { $0.game != nil }.count
    }

    static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }
}

@Model
final class GameTagAssignment {
    var addedAt: Date = Date.now
    var game: Game?
    var tag: GameTag?

    init(
        game: Game? = nil,
        tag: GameTag? = nil,
        addedAt: Date = .now
    ) {
        self.game = game
        self.tag = tag
        self.addedAt = addedAt
    }
}

@Model
final class GameList {
    var title: String = ""
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .cascade, inverse: \GameListEntry.list) var entries: [GameListEntry]?

    init(
        title: String,
        createdAt: Date = .now
    ) {
        self.title = title
        self.createdAt = createdAt
    }

    func addEntry(_ entry: GameListEntry) {
        var currentEntries = entries ?? []
        currentEntries.append(entry)
        entries = currentEntries
        entry.list = self
    }

    var sortedEntries: [GameListEntry] {
        (entries ?? []).sorted { lhs, rhs in
            if lhs.sortIndex == rhs.sortIndex {
                return lhs.addedAt < rhs.addedAt
            }

            return lhs.sortIndex < rhs.sortIndex
        }
    }

    var games: [Game] {
        sortedEntries.compactMap(\.game)
    }

    var gameCount: Int {
        games.count
    }

    var gameCountLabel: String {
        gameCount == 1 ? "1 juego" : "\(gameCount) juegos"
    }

    var nextSortIndex: Int {
        (sortedEntries.last?.sortIndex ?? -1) + 1
    }

    func contains(_ game: Game) -> Bool {
        entries?.contains { entry in
            entry.game?.persistentModelID == game.persistentModelID
        } ?? false
    }
}

@Model
final class GameListEntry {
    var sortIndex: Int = 0
    var addedAt: Date = Date.now
    var list: GameList?
    var game: Game?

    init(
        game: Game? = nil,
        sortIndex: Int,
        addedAt: Date = .now
    ) {
        self.game = game
        self.sortIndex = sortIndex
        self.addedAt = addedAt
    }
}

@Model
final class GameCopy {
    var platform: String = ""
    var format: String = ""
    var notes: String = ""
    var createdAt: Date = Date.now
    // Legacy field kept temporarily to migrate existing copy statuses into playthroughs.
    var status: String = ""
    var game: Game?
    @Relationship(deleteRule: .cascade, inverse: \GamePlaythrough.copy) var playthroughs: [GamePlaythrough]?

    init(
        platform: String,
        format: String,
        notes: String = "",
        createdAt: Date = .now,
        status: String = ""
    ) {
        self.platform = platform
        self.format = format
        self.notes = notes
        self.createdAt = createdAt
        self.status = status
    }

    func addPlaythrough(_ playthrough: GamePlaythrough) {
        var currentPlaythroughs = playthroughs ?? []
        currentPlaythroughs.append(playthrough)
        playthroughs = currentPlaythroughs
        playthrough.copy = self
    }

    var sortedPlaythroughs: [GamePlaythrough] {
        (playthroughs ?? []).sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.status < rhs.status
            }

            return lhs.createdAt < rhs.createdAt
        }
    }

    var playthroughCount: Int {
        if sortedPlaythroughs.isEmpty && !status.isEmpty {
            return 1
        }

        return sortedPlaythroughs.count
    }

    var playthroughCountLabel: String {
        playthroughCount == 1 ? "1 partida" : "\(playthroughCount) partidas"
    }

    var statusSummary: String {
        var statuses = [String]()

        for status in sortedPlaythroughs.map(\.status) where !statuses.contains(status) {
            statuses.append(status)
        }

        if statuses.isEmpty {
            return status.isEmpty ? "Sin partidas" : status
        }

        return statuses.joined(separator: ", ")
    }

    var searchableText: String {
        (
            [platform, format, notes, status]
            + sortedPlaythroughs.flatMap { [$0.status, $0.difficulty, $0.notes] }
        )
        .joined(separator: " ")
    }

    var needsLegacyPlaythroughMigration: Bool {
        (playthroughs ?? []).isEmpty && !status.isEmpty
    }
}

@Model
final class GamePlaythrough {
    var status: String = ""
    var notes: String = ""
    var createdAt: Date = Date.now
    var startedAt: Date?
    var completedAt: Date?
    var hoursPlayed: Double?
    var personalRating: Int?
    var difficulty: String = ""
    var copy: GameCopy?

    init(
        status: String,
        notes: String = "",
        createdAt: Date = .now,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        hoursPlayed: Double? = nil,
        personalRating: Int? = nil,
        difficulty: String = ""
    ) {
        self.status = status
        self.notes = notes
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.hoursPlayed = hoursPlayed
        self.personalRating = personalRating
        self.difficulty = difficulty
    }
}

enum GameCatalog {
    static let platforms = [
        "Nintendo Switch",
        "PlayStation 5",
        "PlayStation 4",
        "Xbox Series X|S",
        "Xbox One",
        "PC",
        "Steam Deck",
        "Nintendo 3DS",
        "Retro",
        "Otra"
    ]

    static let formats = [
        "Físico",
        "Digital",
        "Edición coleccionista"
    ]

    static let statuses = [
        "Pendiente",
        "Jugando",
        "Completado",
        "Archivado"
    ]

    static let difficulties = [
        "Fácil",
        "Normal",
        "Difícil",
        "Muy difícil",
        "Experto"
    ]

}
