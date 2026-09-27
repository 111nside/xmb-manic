//
//  SteamGridDBKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/8.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Foundation
import SmartCodable

// MARK: - Models

struct SteamGridDBGame: SmartCodable {
    var id: Int = 0
    var name: String = ""
    var types: [String] = []
    var verified: Bool = false
    var release_date: Int = 0
    
    var listDetailText: String {
        var parts = [String]()
        if release_date > 0 {
            parts.append("\(R.string.localizable.releaseDate()): \(Date(timeIntervalSince1970: TimeInterval(release_date)).dateString(ofStyle: .medium))")
        }
        if !types.isEmpty {
            parts.append(types.map { $0.uppercased() }.joined(separator: " · "))
        }
        return parts.joined(separator: " · ")
    }
}

struct SteamGridDBPlatformEntry: SmartCodable {
    var id: String = ""
}

struct SteamGridDBGameDetail: SmartCodable {
    var id: Int = 0
    var name: String = ""
    var types: [String] = []
    var verified: Bool = false
    var releaseDate: Int = 0
    var externalPlatformData: [String: [SteamGridDBPlatformEntry]]?
}

struct SteamGridDBAuthor: SmartCodable {
    var name: String = ""
    var steam64: String = ""
    var avatar: String = ""
}

struct SteamGridDBImage: SmartCodable {
    var id: Int = 0
    var score: Int = 0
    var style: String = ""
    var url: String = ""
    var thumb: String = ""
    var tags: [String] = []
    var author: SteamGridDBAuthor = SteamGridDBAuthor()
    var language: String = ""
    var notes: String?
    var width: Int = 0
    var height: Int = 0
    var nsfw: Bool = false
    var humor: Bool = false
    var mime: String = ""
    var lock: Bool = false
    var epilepsy: Bool = false
    var upvotes: Int = 0
    var downvotes: Int = 0
}

// MARK: - Options

struct SteamGridDBImageOptions {
    var type: String
    var id: Int
    var styles: [String]?
    var dimensions: [String]?
    var mimes: [String]?
    var types: [String]?
    var nsfw: String?
    var epilepsy: String?
    var humor: String?
    var oneoftag: String?
    var page: Int?
}

struct SteamGridDBGetGameOptions {
    var platformdata: [String]?
}

struct SteamGridDBImagePage {
    var page: Int = 0
    var total: Int = 0
    var limit: Int = 50
    var images: [SteamGridDBImage] = []
    
    var totalPages: Int {
        guard limit > 0 else { return 0 }
        return Int(ceil(Double(total) / Double(limit)))
    }
    
    var hasPreviousPage: Bool {
        page > 0
    }
    
    var hasNextPage: Bool {
        guard limit > 0 else { return false }
        return (page + 1) * limit < total
    }
}

// MARK: - Error

enum SteamGridDBError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case apiError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "SteamGridDB API key is missing."
        case .invalidURL:
            return "Invalid SteamGridDB request URL."
        case .invalidResponse:
            return "Invalid SteamGridDB response."
        case let .httpError(statusCode, message):
            return "SteamGridDB HTTP \(statusCode): \(message)"
        case let .apiError(message):
            return message
        }
    }
}

// MARK: - Kit

struct SteamGridDBKit {
    static let defaultBaseURL = URL(string: "https://www.steamgriddb.com/api/v2")!
    
    // MARK: Search
    
    /**
     [{
     "id": 37382,
     "release_date": 495417600,
     "types":
     [
         "eshop"
     ],
     "name": "Super Mario Bros.",
     "verified": true
 }]
     */
    
    static func searchGame(apiKey: String, query: String) async throws -> [SteamGridDBGame] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await request(
            apiKey: apiKey,
            path: "/search/autocomplete/\(encodedQuery)",
            appendPathComponents: false
        )
    }
    
    // MARK: Game
    
    static func getGame(
        apiKey: String,
        type: String,
        id: Int,
        options: SteamGridDBGetGameOptions? = nil
    ) async throws -> SteamGridDBGameDetail {
        var queryItems: [URLQueryItem] = []
        if let platformdata = options?.platformdata, !platformdata.isEmpty {
            queryItems.append(URLQueryItem(name: "platformdata", value: platformdata.joined(separator: ",")))
        }
        return try await request(apiKey: apiKey, path: "/games/\(type)/\(id)", queryItems: queryItems)
    }
    
    static func getGameById(
        apiKey: String,
        id: Int,
        options: SteamGridDBGetGameOptions? = nil
    ) async throws -> SteamGridDBGameDetail {
        try await getGame(apiKey: apiKey, type: "id", id: id, options: options)
    }
    
    static func getGameBySteamAppId(
        apiKey: String,
        id: Int,
        options: SteamGridDBGetGameOptions? = nil
    ) async throws -> SteamGridDBGameDetail {
        try await getGame(apiKey: apiKey, type: "steam", id: id, options: options)
    }
    
    // MARK: Grids
    
    /**
     [{
     "id": 185819,
     "style": "alternate",
     "thumb": "https://cdn2.steamgriddb.com/thumb/75f29e87a3923053bde594667a5e33d3.jpg",
     "epilepsy": false,
     "mime": "image/png",
     "downvotes": 0,
     "width": 600,
     "url": "https://cdn2.steamgriddb.com/grid/75f29e87a3923053bde594667a5e33d3.png",
     "nsfw": false,
     "author":
     {
         "name": "nawavon",
         "steam64": "76561198042206255",
         "avatar": "https://avatars.steamstatic.com/b15f125a8007d8cd85ee1ab22cab7e55fcc69dcf_medium.jpg"
     },
     "notes": "Edited version of the original box art that extends the illustration and removes additional logos. Made by https://steamcommunity.com/id/nawavon/.",
     "upvotes": 0,
     "language": "en",
     "height": 900,
     "lock": false,
     "score": 0,
     "humor": false
 }]
     */
    
    static func getGrids(apiKey: String, options: SteamGridDBImageOptions) async throws -> SteamGridDBImagePage {
        try await getImages(apiKey: apiKey, pathPrefix: "grids", options: options)
    }
    
    static func getGridsById(
        apiKey: String,
        id: Int,
        styles: [String]? = nil,
        dimensions: [String]? = nil,
        mimes: [String]? = nil,
        types: [String]? = nil,
        nsfw: String? = nil,
        humor: String? = nil,
        page: Int? = nil
    ) async throws -> SteamGridDBImagePage {
        try await getGrids(apiKey: apiKey, options: SteamGridDBImageOptions(
            type: "game",
            id: id,
            styles: styles,
            dimensions: dimensions,
            mimes: mimes,
            types: types,
            nsfw: nsfw,
            humor: humor,
            page: page
        ))
    }
    
    static func getGridsBySteamAppId(
        apiKey: String,
        id: Int,
        styles: [String]? = nil,
        dimensions: [String]? = nil,
        mimes: [String]? = nil,
        types: [String]? = nil,
        nsfw: String? = nil,
        humor: String? = nil,
        page: Int? = nil
    ) async throws -> SteamGridDBImagePage {
        try await getGrids(apiKey: apiKey, options: SteamGridDBImageOptions(
            type: "steam",
            id: id,
            styles: styles,
            dimensions: dimensions,
            mimes: mimes,
            types: types,
            nsfw: nsfw,
            humor: humor,
            page: page
        ))
    }
    
    // MARK: Heroes
    
    /**
     [{
     "id": 26365,
     "style": "alternate",
     "thumb": "https://cdn2.steamgriddb.com/hero_thumb/105f777347c73908a23cbf0de0c33d3b.jpg",
     "epilepsy": false,
     "mime": "image/png",
     "downvotes": 0,
     "width": 3840,
     "url": "https://cdn2.steamgriddb.com/hero/105f777347c73908a23cbf0de0c33d3b.png",
     "nsfw": false,
     "author":
     {
         "name": "Fander",
         "steam64": "76561198393672878",
         "avatar": "https://avatars.steamstatic.com/d1759af8a4457122df0bcef4d4451379657394cb_medium.jpg"
     },
     "notes": "Some stars. Wanted to make a simple background resembling some of NES box art backgrounds.",
     "upvotes": 0,
     "language": "en",
     "height": 1240,
     "lock": false,
     "score": 0,
     "humor": false
 }]
     */
    
    static func getHeroes(apiKey: String, options: SteamGridDBImageOptions) async throws -> SteamGridDBImagePage {
        try await getImages(apiKey: apiKey, pathPrefix: "heroes", options: options)
    }
    
    static func getHeroesById(
        apiKey: String,
        id: Int,
        styles: [String]? = nil,
        dimensions: [String]? = nil,
        mimes: [String]? = nil,
        types: [String]? = nil,
        nsfw: String? = nil,
        humor: String? = nil,
        page: Int? = nil
    ) async throws -> SteamGridDBImagePage {
        try await getHeroes(apiKey: apiKey, options: SteamGridDBImageOptions(
            type: "game",
            id: id,
            styles: styles,
            dimensions: dimensions,
            mimes: mimes,
            types: types,
            nsfw: nsfw,
            humor: humor,
            page: page
        ))
    }
    
    static func getHeroesBySteamAppId(
        apiKey: String,
        id: Int,
        styles: [String]? = nil,
        dimensions: [String]? = nil,
        mimes: [String]? = nil,
        types: [String]? = nil,
        nsfw: String? = nil,
        humor: String? = nil,
        page: Int? = nil
    ) async throws -> SteamGridDBImagePage {
        try await getHeroes(apiKey: apiKey, options: SteamGridDBImageOptions(
            type: "steam",
            id: id,
            styles: styles,
            dimensions: dimensions,
            mimes: mimes,
            types: types,
            nsfw: nsfw,
            humor: humor,
            page: page
        ))
    }
    
    // MARK: Icons
    
    /**
     [{
     "id": 52875,
     "style": "official",
     "thumb": "https://cdn2.steamgriddb.com/icon/9c1202f4af69c9c722163a0f73d11c23/32/64x64.png",
     "epilepsy": false,
     "mime": "image/vnd.microsoft.icon",
     "downvotes": 0,
     "width": 0,
     "url": "https://cdn2.steamgriddb.com/icon/9c1202f4af69c9c722163a0f73d11c23.ico",
     "nsfw": false,
     "author":
     {
         "name": "Rabbid4240",
         "steam64": "76561198315448831",
         "avatar": "https://avatars.steamstatic.com/249967a8a0b31161c8ca2480af6f09e1cb1566de_medium.jpg"
     },
     "notes": null,
     "upvotes": 0,
     "language": "en",
     "height": 0,
     "lock": false,
     "score": 0,
     "humor": false
 }]
     */
    
    static func getIcons(apiKey: String, options: SteamGridDBImageOptions) async throws -> SteamGridDBImagePage {
        try await getImages(apiKey: apiKey, pathPrefix: "icons", options: options)
    }
    
    static func getIconsById(
        apiKey: String,
        id: Int,
        styles: [String]? = nil,
        dimensions: [String]? = nil,
        mimes: [String]? = nil,
        types: [String]? = nil,
        nsfw: String? = nil,
        humor: String? = nil,
        page: Int? = nil
    ) async throws -> SteamGridDBImagePage {
        try await getIcons(apiKey: apiKey, options: SteamGridDBImageOptions(
            type: "game",
            id: id,
            styles: styles,
            dimensions: dimensions,
            mimes: mimes,
            types: types,
            nsfw: nsfw,
            humor: humor,
            page: page
        ))
    }
    
    static func getIconsBySteamAppId(
        apiKey: String,
        id: Int,
        styles: [String]? = nil,
        dimensions: [String]? = nil,
        mimes: [String]? = nil,
        types: [String]? = nil,
        nsfw: String? = nil,
        humor: String? = nil,
        page: Int? = nil
    ) async throws -> SteamGridDBImagePage {
        try await getIcons(apiKey: apiKey, options: SteamGridDBImageOptions(
            type: "steam",
            id: id,
            styles: styles,
            dimensions: dimensions,
            mimes: mimes,
            types: types,
            nsfw: nsfw,
            humor: humor,
            page: page
        ))
    }
    
    // MARK: Logos
    
    /**
     [{
     "id": 1604,
     "style": "official",
     "thumb": "https://cdn2.steamgriddb.com/logo_thumb/a368b0de8b91cfb3f91892fbf1ebd4b2.png",
     "epilepsy": false,
     "mime": "image/png",
     "downvotes": 0,
     "width": 4585,
     "url": "https://cdn2.steamgriddb.com/logo/a368b0de8b91cfb3f91892fbf1ebd4b2.png",
     "nsfw": false,
     "author":
     {
         "name": "Jib",
         "steam64": "76561198394798289",
         "avatar": "https://cdn2.steamgriddb.com/profile/avatar_1882.png?1779617926"
     },
     "notes": null,
     "upvotes": 0,
     "language": "en",
     "height": 1440,
     "lock": false,
     "score": 0,
     "humor": false
 }]
     */
    
    static func getLogos(apiKey: String, options: SteamGridDBImageOptions) async throws -> SteamGridDBImagePage {
        try await getImages(apiKey: apiKey, pathPrefix: "logos", options: options)
    }
    
    static func getLogosById(
        apiKey: String,
        id: Int,
        styles: [String]? = nil,
        dimensions: [String]? = nil,
        mimes: [String]? = nil,
        types: [String]? = nil,
        nsfw: String? = nil,
        humor: String? = nil,
        page: Int? = nil
    ) async throws -> SteamGridDBImagePage {
        try await getLogos(apiKey: apiKey, options: SteamGridDBImageOptions(
            type: "game",
            id: id,
            styles: styles,
            dimensions: dimensions,
            mimes: mimes,
            types: types,
            nsfw: nsfw,
            humor: humor,
            page: page
        ))
    }
    
    static func getLogosBySteamAppId(
        apiKey: String,
        id: Int,
        styles: [String]? = nil,
        dimensions: [String]? = nil,
        mimes: [String]? = nil,
        types: [String]? = nil,
        nsfw: String? = nil,
        humor: String? = nil,
        page: Int? = nil
    ) async throws -> SteamGridDBImagePage {
        try await getLogos(apiKey: apiKey, options: SteamGridDBImageOptions(
            type: "steam",
            id: id,
            styles: styles,
            dimensions: dimensions,
            mimes: mimes,
            types: types,
            nsfw: nsfw,
            humor: humor,
            page: page
        ))
    }
}

// MARK: - Networking

private extension SteamGridDBKit {
    static func getImages(
        apiKey: String,
        pathPrefix: String,
        options: SteamGridDBImageOptions
    ) async throws -> SteamGridDBImagePage {
        let data = try await requestData(
            apiKey: apiKey,
            path: "/\(pathPrefix)/\(options.type)/\(options.id)",
            queryItems: buildImageQueryItems(from: options)
        )
        return try decodeImagePageResponse(data)
    }
    
    static func buildImageQueryItems(from options: SteamGridDBImageOptions) -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = []
        
        appendJoinedQueryItem(name: "styles", values: options.styles, to: &queryItems)
        appendJoinedQueryItem(name: "dimensions", values: options.dimensions, to: &queryItems)
        appendJoinedQueryItem(name: "mimes", values: options.mimes, to: &queryItems)
        appendJoinedQueryItem(name: "types", values: options.types, to: &queryItems)
        
        if let nsfw = options.nsfw {
            queryItems.append(URLQueryItem(name: "nsfw", value: nsfw))
        }
        if let epilepsy = options.epilepsy {
            queryItems.append(URLQueryItem(name: "epilepsy", value: epilepsy))
        }
        if let humor = options.humor {
            queryItems.append(URLQueryItem(name: "humor", value: humor))
        }
        if let oneoftag = options.oneoftag {
            queryItems.append(URLQueryItem(name: "oneoftag", value: oneoftag))
        }
        if let page = options.page {
            queryItems.append(URLQueryItem(name: "page", value: String(page)))
        }
        
        return queryItems
    }
    
    static func appendJoinedQueryItem(name: String, values: [String]?, to queryItems: inout [URLQueryItem]) {
        guard let values, !values.isEmpty else { return }
        queryItems.append(URLQueryItem(name: name, value: values.joined(separator: ",")))
    }
    
    static func request<T: SmartCodable>(
        apiKey: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        appendPathComponents: Bool = true,
        baseURL: URL = SteamGridDBKit.defaultBaseURL,
        session: URLSession = .shared
    ) async throws -> T {
        let data = try await requestData(
            apiKey: apiKey,
            path: path,
            queryItems: queryItems,
            appendPathComponents: appendPathComponents,
            baseURL: baseURL,
            session: session
        )
        return try decodeResponse(data)
    }
    
    static func requestData(
        apiKey: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        appendPathComponents: Bool = true,
        baseURL: URL = SteamGridDBKit.defaultBaseURL,
        session: URLSession = .shared
    ) async throws -> Data {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw SteamGridDBError.missingAPIKey
        }
        
        let url: URL
        if appendPathComponents {
            let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
            var builtURL = baseURL
            for component in normalizedPath.split(separator: "/") {
                builtURL = builtURL.appendingPathComponent(String(component))
            }
            url = builtURL
        } else {
            let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
            guard let builtURL = URL(string: baseURL.absoluteString + normalizedPath) else {
                throw SteamGridDBError.invalidURL
            }
            url = builtURL
        }
        
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw SteamGridDBError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let requestURL = components.url else {
            throw SteamGridDBError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SteamGridDBError.invalidResponse
        }
        
        let apiMessage = parseErrorMessage(from: data)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SteamGridDBError.httpError(
                statusCode: httpResponse.statusCode,
                message: apiMessage ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }
        
        return data
    }
    
    static func decodeImagePageResponse(_ data: Data) throws -> SteamGridDBImagePage {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SteamGridDBError.invalidResponse
        }
        
        if let errors = json["errors"] as? [String], !errors.isEmpty {
            throw SteamGridDBError.apiError(message: errors.joined(separator: ", "))
        }
        
        guard let success = json["success"] as? Bool, success else {
            throw SteamGridDBError.apiError(message: parseErrorMessage(from: data) ?? "Unknown SteamGridDB error.")
        }
        
        guard let payload = json["data"] else {
            throw SteamGridDBError.invalidResponse
        }
        
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        guard let payloadString = String(data: payloadData, encoding: .utf8),
              let images = [SteamGridDBImage].deserialize(from: payloadString) else {
            throw SteamGridDBError.invalidResponse
        }
        
        return SteamGridDBImagePage(
            page: json["page"] as? Int ?? 0,
            total: json["total"] as? Int ?? images.count,
            limit: json["limit"] as? Int ?? images.count,
            images: images
        )
    }
    
    static func decodeResponse<T: SmartCodable>(_ data: Data) throws -> T {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SteamGridDBError.invalidResponse
        }
        
        if let errors = json["errors"] as? [String], !errors.isEmpty {
            throw SteamGridDBError.apiError(message: errors.joined(separator: ", "))
        }
        
        guard let success = json["success"] as? Bool, success else {
            throw SteamGridDBError.apiError(message: parseErrorMessage(from: data) ?? "Unknown SteamGridDB error.")
        }
        
        guard let payload = json["data"] else {
            throw SteamGridDBError.invalidResponse
        }
        
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        guard let payloadString = String(data: payloadData, encoding: .utf8),
              let result = T.deserialize(from: payloadString) else {
            throw SteamGridDBError.invalidResponse
        }
        return result
    }
    
    static func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let errors = json["errors"] as? [String], !errors.isEmpty {
            return errors.joined(separator: ", ")
        }
        return nil
    }
}
