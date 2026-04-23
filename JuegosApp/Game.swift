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
    var title: String
    var genre: String
    var releaseYear: Int?
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \GameCopy.game) var copies: [GameCopy] = []

    init(
        title: String,
        genre: String,
        releaseYear: Int? = nil,
        createdAt: Date = .now
    ) {
        self.title = title
        self.genre = genre
        self.releaseYear = releaseYear
        self.createdAt = createdAt
    }

    var sortedCopies: [GameCopy] {
        copies.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.platform < rhs.platform
            }

            return lhs.createdAt < rhs.createdAt
        }
    }

    var copyCount: Int {
        sortedCopies.count
    }

    var platformSummary: String {
        joinedSummary(for: sortedCopies.map(\.platform), fallback: "Sin plataforma")
    }

    var formatSummary: String {
        joinedSummary(for: sortedCopies.map(\.format), fallback: "Sin formato")
    }

    var searchableCopyText: String {
        sortedCopies
            .flatMap { [$0.platform, $0.format, $0.status, $0.notes] }
            .joined(separator: " ")
    }

    var primaryCopy: GameCopy? {
        sortedCopies.first
    }

    var detailSummary: String {
        var pieces = [genre]

        if let releaseYear {
            pieces.append(String(releaseYear))
        }

        pieces.append(copyCount == 1 ? "1 copia" : "\(copyCount) copias")

        return pieces
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var librarySubtitle: String {
        platformSummary
    }

    var libraryFootnote: String {
        guard let primaryCopy else {
            return genre
        }

        let copySummary = [primaryCopy.format, primaryCopy.status]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        if copyCount == 1 {
            return primaryCopy.notes.isEmpty ? copySummary : copySummary + " · " + primaryCopy.notes
        }

        return "\(copyCount) copias · \(formatSummary)"
    }

    private func joinedSummary(for values: [String], fallback: String) -> String {
        var uniqueValues = [String]()

        for value in values where !value.isEmpty && !uniqueValues.contains(value) {
            uniqueValues.append(value)
        }

        return uniqueValues.isEmpty ? fallback : uniqueValues.joined(separator: ", ")
    }
}

@Model
final class GameCopy {
    var platform: String
    var format: String
    var status: String
    var notes: String
    var createdAt: Date
    var game: Game?

    init(
        platform: String,
        format: String,
        status: String,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.platform = platform
        self.format = format
        self.status = status
        self.notes = notes
        self.createdAt = createdAt
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
        "Fisico",
        "Digital",
        "Edicion coleccionista"
    ]

    static let statuses = [
        "Pendiente",
        "Jugando",
        "Completado",
        "Archivado"
    ]

    static let genres = [
        "Accion",
        "Aventura",
        "RPG",
        "Estrategia",
        "Deportes",
        "Carreras",
        "Plataformas",
        "Shooter",
        "Puzzle",
        "Otro"
    ]
}
