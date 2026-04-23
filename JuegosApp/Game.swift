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
    var platform: String
    var format: String
    var status: String
    var genre: String
    var releaseYear: Int?
    var notes: String
    var createdAt: Date

    init(
        title: String,
        platform: String,
        format: String,
        status: String,
        genre: String,
        releaseYear: Int? = nil,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.title = title
        self.platform = platform
        self.format = format
        self.status = status
        self.genre = genre
        self.releaseYear = releaseYear
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
