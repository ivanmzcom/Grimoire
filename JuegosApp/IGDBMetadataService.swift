//
//  IGDBMetadataService.swift
//  JuegosApp
//
//  Created by Codex on 23/4/26.
//

import Foundation
import SwiftData

struct IGDBCredentials: Equatable {
    var clientID: String
    var clientSecret: String

    var isComplete: Bool {
        !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum IGDBCredentialsStore {
    private static let secretsFileName = "Secrets"
    private static let secretsFileExtension = "plist"
    private static let clientIDKey = "IGDBClientID"
    private static let clientSecretKey = "IGDBClientSecret"

    static func load() -> IGDBCredentials {
        guard let url = Bundle.main.url(forResource: secretsFileName, withExtension: secretsFileExtension),
              let data = try? Data(contentsOf: url),
              let rawSecrets = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let secrets = rawSecrets as? [String: Any]
        else {
            return IGDBCredentials(clientID: "", clientSecret: "")
        }

        return IGDBCredentials(
            clientID: (secrets[clientIDKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            clientSecret: (secrets[clientSecretKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }
}

enum IGDBMetadataError: LocalizedError {
    case missingCredentials
    case invalidAuthResponse
    case requestFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            "Configura IGDBClientID e IGDBClientSecret en Secrets.plist."
        case .invalidAuthResponse:
            "IGDB no devolvió un token válido."
        case .requestFailed(let message):
            message
        case .invalidResponse:
            "IGDB devolvió una respuesta inesperada."
        }
    }
}

struct IGDBMetadataService {
    let credentials: IGDBCredentials
    var session: URLSession = .shared

    private static let gameFields = "name,first_release_date,summary,total_rating,aggregated_rating,cover.url,cover.image_id,cover.width,cover.height,artworks.url,artworks.image_id,artworks.width,artworks.height,screenshots.url,screenshots.image_id,screenshots.width,screenshots.height,genres.name,themes.name,platforms.name,involved_companies.developer,involved_companies.publisher,involved_companies.company.name,url"

    func searchGames(matching searchText: String, limit: Int = 12, offset: Int = 0) async throws -> [IGDBGameMetadata] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard credentials.isComplete, !trimmedSearchText.isEmpty else {
            throw IGDBMetadataError.missingCredentials
        }

        let accessToken = try await accessToken()
        var request = URLRequest(url: URL(string: "https://api.igdb.com/v4/games")!)
        request.httpMethod = "POST"
        request.setValue(credentials.clientID.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "Client-ID")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.searchBody(for: trimmedSearchText, limit: limit, offset: offset).data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response, data: data)
        return try JSONDecoder().decode([IGDBGameMetadata].self, from: data)
    }

    func game(id: Int) async throws -> IGDBGameMetadata? {
        guard credentials.isComplete else {
            throw IGDBMetadataError.missingCredentials
        }

        let accessToken = try await accessToken()
        var request = URLRequest(url: URL(string: "https://api.igdb.com/v4/games")!)
        request.httpMethod = "POST"
        request.setValue(credentials.clientID.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "Client-ID")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.gameBody(for: id).data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response, data: data)
        return try JSONDecoder().decode([IGDBGameMetadata].self, from: data).first
    }

    private func accessToken() async throws -> String {
        let clientID = credentials.clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = credentials.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        if let token = IGDBTokenCache.token(for: clientID) {
            return token
        }

        guard credentials.isComplete else {
            throw IGDBMetadataError.missingCredentials
        }

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "grant_type", value: "client_credentials")
        ]

        var request = URLRequest(url: URL(string: "https://id.twitch.tv/oauth2/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response, data: data)

        let authResponse = try JSONDecoder().decode(IGDBAuthResponse.self, from: data)
        guard !authResponse.accessToken.isEmpty else {
            throw IGDBMetadataError.invalidAuthResponse
        }

        IGDBTokenCache.save(
            authResponse.accessToken,
            clientID: clientID,
            expiresIn: authResponse.expiresIn
        )

        return authResponse.accessToken
    }

    private static func searchBody(for searchText: String, limit: Int, offset: Int) -> String {
        let normalizedLimit = max(1, min(limit, 50))
        let normalizedOffset = max(0, offset)

        return """
        search "\(escapedSearchString(searchText))";
        fields \(gameFields);
        where version_parent = null;
        limit \(normalizedLimit);
        offset \(normalizedOffset);
        """
    }

    private static func gameBody(for id: Int) -> String {
        """
        fields \(gameFields);
        where id = \(id);
        limit 1;
        """
    }

    private static func escapedSearchString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IGDBMetadataError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseText = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw IGDBMetadataError.requestFailed(responseText)
        }
    }
}

struct IGDBGameMetadata: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String
    let firstReleaseDate: Int?
    let summary: String?
    let totalRating: Double?
    let aggregatedRating: Double?
    let cover: IGDBCover?
    let artworks: [IGDBImageAsset]?
    let screenshots: [IGDBImageAsset]?
    let genres: [IGDBNamedResource]?
    let themes: [IGDBNamedResource]?
    let platforms: [IGDBNamedResource]?
    let involvedCompanies: [IGDBInvolvedCompany]?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case summary
        case cover
        case artworks
        case screenshots
        case genres
        case themes
        case platforms
        case url
        case firstReleaseDate = "first_release_date"
        case totalRating = "total_rating"
        case aggregatedRating = "aggregated_rating"
        case involvedCompanies = "involved_companies"
    }

    var releaseYear: Int? {
        guard let firstReleaseDate else { return nil }

        let date = Date(timeIntervalSince1970: TimeInterval(firstReleaseDate))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.component(.year, from: date)
    }

    var normalizedCoverURL: String {
        if let imageID = cover?.imageID, !imageID.isEmpty {
            return Self.imageURL(for: imageID, size: "t_cover_big")
        }

        return Self.normalizedImageURL(cover?.url, replacingSizeWith: "t_cover_big")
    }

    var normalizedHeroImageURL: String {
        if let artwork = preferredHorizontalImage(in: artworks) {
            return artwork.normalizedURL(size: "t_1080p")
        }

        if let screenshot = preferredHorizontalImage(in: screenshots) {
            return screenshot.normalizedURL(size: "t_1080p")
        }

        return ""
    }

    var normalizedScreenshotURL: String {
        guard let screenshot = preferredHorizontalImage(in: screenshots) ?? screenshots?.first else {
            return ""
        }

        return screenshot.normalizedURL(size: "t_screenshot_big")
    }

    var normalizedGalleryImageURLs: [String] {
        uniqueURLs(
            ((screenshots ?? []) + (artworks ?? []))
                .map { $0.normalizedURL(size: "t_1080p") }
        )
    }

    private func preferredHorizontalImage(in assets: [IGDBImageAsset]?) -> IGDBImageAsset? {
        assets?.first { asset in
            guard let width = asset.width, let height = asset.height else { return true }
            return width >= height
        }
    }

    static func normalizedImageURL(_ url: String?, replacingSizeWith size: String) -> String {
        guard var imageURL = url, !imageURL.isEmpty else { return "" }

        if imageURL.hasPrefix("//") {
            imageURL = "https:\(imageURL)"
        }

        return imageURL.replacingOccurrences(of: "t_thumb", with: size)
    }

    private static func imageURL(for imageID: String, size: String) -> String {
        "https://images.igdb.com/igdb/image/upload/\(size)/\(imageID).jpg"
    }

    var genresText: String {
        joinedUnique(genres?.map(\.name) ?? [])
    }

    var importedTagNames: [String] {
        uniqueNames(
            (genres ?? [])
            + (themes ?? [])
        )
    }

    var platformsText: String {
        joinedUnique(platforms?.map(\.name) ?? [])
    }

    var developersText: String {
        companyText(where: \.developer)
    }

    var publishersText: String {
        companyText(where: \.publisher)
    }

    var rating: Double? {
        totalRating ?? aggregatedRating
    }

    var ratingLabel: String? {
        guard let rating else { return nil }
        return "\(Int(rating.rounded()))/100"
    }

    var resultSubtitle: String {
        [
            releaseYear.map(String.init),
            developersText.isEmpty ? nil : developersText,
            genresText.isEmpty ? nil : genresText
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private func companyText(where keyPath: KeyPath<IGDBInvolvedCompany, Bool?>) -> String {
        joinedUnique(
            (involvedCompanies ?? [])
                .filter { $0[keyPath: keyPath] == true }
                .compactMap { $0.company?.name }
        )
    }

    private func joinedUnique(_ values: [String]) -> String {
        uniqueNames(values).joined(separator: ", ")
    }

    private func uniqueNames(_ resources: [IGDBNamedResource]) -> [String] {
        uniqueNames(resources.map(\.name))
    }

    private func uniqueNames(_ values: [String]) -> [String] {
        var uniqueValues = [String]()

        for value in values {
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedValue.isEmpty,
                  !uniqueValues.contains(where: { $0.localizedCaseInsensitiveCompare(trimmedValue) == .orderedSame })
            else {
                continue
            }

            uniqueValues.append(trimmedValue)
        }

        return uniqueValues
    }

    private func uniqueURLs(_ values: [String]) -> [String] {
        var uniqueValues = [String]()

        for value in values {
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedValue.isEmpty, !uniqueValues.contains(trimmedValue) else {
                continue
            }

            uniqueValues.append(trimmedValue)
        }

        return uniqueValues
    }
}

struct IGDBImageAsset: Decodable, Hashable {
    let url: String?
    let imageID: String?
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case url
        case imageID = "image_id"
        case width
        case height
    }

    func normalizedURL(size: String) -> String {
        if let imageID, !imageID.isEmpty {
            return "https://images.igdb.com/igdb/image/upload/\(size)/\(imageID).jpg"
        }

        return IGDBGameMetadata.normalizedImageURL(url, replacingSizeWith: size)
    }
}

typealias IGDBCover = IGDBImageAsset

struct IGDBNamedResource: Decodable, Hashable {
    let name: String
}

struct IGDBInvolvedCompany: Decodable, Hashable {
    let developer: Bool?
    let publisher: Bool?
    let company: IGDBNamedResource?
}

private struct IGDBAuthResponse: Decodable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

private enum IGDBTokenCache {
    private static let key = "igdb.cachedToken"

    static func token(for clientID: String) -> String? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let cachedToken = try? JSONDecoder().decode(CachedToken.self, from: data),
              cachedToken.clientID == clientID,
              cachedToken.expiresAt > Date.now.addingTimeInterval(60)
        else {
            return nil
        }

        return cachedToken.value
    }

    static func save(_ token: String, clientID: String, expiresIn: Int) {
        let cachedToken = CachedToken(
            value: token,
            clientID: clientID,
            expiresAt: Date.now.addingTimeInterval(TimeInterval(max(0, expiresIn)))
        )

        if let data = try? JSONEncoder().encode(cachedToken) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private struct CachedToken: Codable {
        let value: String
        let clientID: String
        let expiresAt: Date
    }
}

extension Game {
    func applyIGDBMetadata(_ metadata: IGDBGameMetadata) {
        title = metadata.name

        if let releaseYear = metadata.releaseYear {
            self.releaseYear = releaseYear
        }

        igdbID = metadata.id
        let normalizedCoverURL = metadata.normalizedCoverURL
        let normalizedHeroImageURL = metadata.normalizedHeroImageURL
        let normalizedScreenshotURL = metadata.normalizedScreenshotURL
        let normalizedGalleryImageURLs = metadata.normalizedGalleryImageURLs

        if !normalizedCoverURL.isEmpty {
            coverURL = normalizedCoverURL
        }

        if !normalizedHeroImageURL.isEmpty {
            heroImageURL = normalizedHeroImageURL
        }

        if !normalizedScreenshotURL.isEmpty {
            screenshotURL = normalizedScreenshotURL
        }

        if !normalizedGalleryImageURLs.isEmpty {
            galleryImageURLsText = normalizedGalleryImageURLs.joined(separator: "\n")
        }

        summary = metadata.summary ?? ""
        genresText = metadata.genresText
        developersText = metadata.developersText
        publishersText = metadata.publishersText
        igdbURL = metadata.url ?? ""
        totalRating = metadata.rating
        metadataImportedAt = .now
    }

    func applyIGDBTags(from metadata: IGDBGameMetadata, in modelContext: ModelContext) throws {
        for tagName in metadata.importedTagNames {
            let normalizedName = GameTag.normalized(tagName)
            guard !normalizedName.isEmpty, !hasTag(normalizedName: normalizedName) else {
                continue
            }

            let tag = try existingTag(normalizedName: normalizedName, in: modelContext) ?? {
                let tag = GameTag(name: tagName)
                modelContext.insert(tag)
                return tag
            }()

            let assignment = GameTagAssignment(game: self, tag: tag)
            modelContext.insert(assignment)

            var currentAssignments = tagAssignments ?? []
            currentAssignments.append(assignment)
            tagAssignments = currentAssignments
        }
    }

    private func hasTag(normalizedName: String) -> Bool {
        sortedTags.contains { $0.normalizedName == normalizedName }
    }

    private func existingTag(normalizedName: String, in modelContext: ModelContext) throws -> GameTag? {
        var descriptor = FetchDescriptor<GameTag>(
            predicate: #Predicate<GameTag> { tag in
                tag.normalizedName == normalizedName
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
