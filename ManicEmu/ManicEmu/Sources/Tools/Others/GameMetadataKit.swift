//
//  GameMetadataKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/8.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import SQLite
import SmartCodable
import CryptoKit
import zlib

struct GameMetadata: SmartCodable {
    var developer: String = ""
    var publisher: String = ""
    var ratingId: Int = 0
    var users: Int = 0
    var franchise: String = ""
    var releaseYear: Int = 0
    var releaseMonth: Int = 0
    var region: String = ""
    var genre: String = ""
    var displayName: String = ""
    var fullName: String = ""
    var platform: String = ""
    var overview: String = ""
    
    var ESRPRating: ESRP? {
        switch ratingId {
        case 1:
            return .T
        case 2:
            return .M
        case 3:
            return .K_A
        case 4:
            return .E10
        case 5:
            return .E
        case 7:
            return .EC
        case 8:
            return .AO
        case 9:
            return .RP
        case 10:
            return .RP17
        default:
            return nil
        }
    }
    
    /// extras → DB → 空实例，保证编辑页始终可打开
    static func resolved(for game: Game) -> GameMetadata {
        if let metadata = getGameMetadata(game: game) {
            return metadata
        }
        if let metadata = GameMetadataKit.getGameInfo(game: game) {
            return metadata
        }
        return GameMetadata()
    }
    
    var releaseDateDisplay: String {
        if releaseYear > 0, (1...12).contains(releaseMonth) {
            return String(format: "%d-%02d", releaseYear, releaseMonth)
        }
        if releaseYear > 0 {
            return "\(releaseYear)"
        }
        return "—"
    }
    
    var esrpDisplay: String {
        ESRPRating?.abbr ?? "—"
    }
    
    mutating func setESRP(_ esrp: ESRP?) {
        ratingId = esrp?.ratingId ?? 0
    }
    
    func persist(to game: Game) {
        if let json = toJSONString() {
            game.updateExtra(key: ExtraKey.gameMetadata.rawValue, value: json)
            NotificationCenter.default.post(name: R.NotificationName.GameMetadataChange, object: game.id)
        }
    }
    
    static func getGameMetadata(game: Game) -> Self? {
        guard let metadataString = game.getExtraString(key: ExtraKey.gameMetadata.rawValue) else {
            return nil
        }
        guard let metadata = GameMetadata.deserialize(from: metadataString) else {
            return nil
        }
        return metadata
    }
}

struct GameMetadataKit {
    private static let dbQueue = DispatchQueue(label: "com.manicemu.gameMetadatakit.db")
    private static var cachedConnection: Connection?
    private static var cachedDbPath: String?
    
    private static let gameInfoColumnsSQL = """
        SELECT
            g.rating_id,
            g.users,
            g.release_year,
            g.release_month,
            g.display_name,
            g.full_name,
            d.name,
            p.name,
            f.name,
            reg.name,
            ge.name,
            pl.name,
            o.data
        """
    
    private static let gameInfoSQL = """
        \(gameInfoColumnsSQL)
        FROM rom_md5 r
        JOIN game_rom_md5 gr ON gr.md5_id = r.id
        JOIN games g ON g.id = gr.game_id
        LEFT JOIN developers d ON d.id = g.developer_id
        LEFT JOIN publishers p ON p.id = g.publisher_id
        LEFT JOIN franchises f ON f.id = g.franchise_id
        LEFT JOIN regions reg ON reg.id = g.region_id
        LEFT JOIN genres ge ON ge.id = g.genre_id
        LEFT JOIN platforms pl ON pl.id = g.platform_id
        LEFT JOIN overviews o ON o.id = g.overview_id
        WHERE r.md5 = ?
        ORDER BY (g.overview_id IS NOT NULL) DESC
        LIMIT 1
        """
    
    private static let searchByDisplayNameSQL = """
        \(gameInfoColumnsSQL)
        FROM games g
        LEFT JOIN developers d ON d.id = g.developer_id
        LEFT JOIN publishers p ON p.id = g.publisher_id
        LEFT JOIN franchises f ON f.id = g.franchise_id
        LEFT JOIN regions reg ON reg.id = g.region_id
        LEFT JOIN genres ge ON ge.id = g.genre_id
        LEFT JOIN platforms pl ON pl.id = g.platform_id
        LEFT JOIN overviews o ON o.id = g.overview_id
        WHERE g.display_name LIKE ? ESCAPE '\\'
        ORDER BY
            CASE WHEN g.display_name LIKE ? ESCAPE '\\' THEN 0 ELSE 1 END,
            g.display_name COLLATE NOCASE
        LIMIT 50
        """
    
    static func getGameInfo(game: Game) -> GameMetadata? {
        guard let md5 = md5Hash(for: game.romUrl) else { return nil }
        game.updateExtra(key: ExtraKey.hasQueryMetadata.rawValue, value: true)
        return getGameInfo(md5: md5)
    }
    
    static func getGameInfo(md5: String) -> GameMetadata? {
        let dbPath = R.Path.ExtrasDB
        guard FileManager.default.fileExists(atPath: dbPath) else {
            Log.error("[GameMetadataKit] Extras.db not found at \(dbPath). System.bundle may be stale — reinstall the app or bump build number to refresh resources.")
            return nil
        }
        
        return dbQueue.sync {
            do {
                let db = try connection(for: dbPath)
                let normalizedMD5 = md5.uppercased()
                for row in try db.prepare(gameInfoSQL, normalizedMD5) {
                    return mapGameInfo(from: row)
                }
                return nil
            } catch {
                invalidateConnection()
                Log.error("[GameMetadataKit] query failed for path \(dbPath): \(error)")
                return nil
            }
        }
    }
    
    /// 按 display_name 模糊搜索元数据
    static func searchGameInfo(displayName query: String) -> [GameMetadata] {
        let trimmed = query.trimmed
        guard !trimmed.isEmpty else { return [] }
        
        let dbPath = R.Path.ExtrasDB
        guard FileManager.default.fileExists(atPath: dbPath) else {
            Log.error("[GameMetadataKit] Extras.db not found at \(dbPath). System.bundle may be stale — reinstall the app or bump build number to refresh resources.")
            return []
        }
        
        let escaped = escapeLIKEPattern(trimmed)
        let fuzzyPattern = "%\(escaped)%"
        let prefixPattern = "\(escaped)%"
        
        return dbQueue.sync {
            do {
                let db = try connection(for: dbPath)
                var results = [GameMetadata]()
                for row in try db.prepare(searchByDisplayNameSQL, fuzzyPattern, prefixPattern) {
                    results.append(mapGameInfo(from: row))
                }
                return results
            } catch {
                invalidateConnection()
                Log.error("[GameMetadataKit] search failed for query \(trimmed): \(error)")
                return []
            }
        }
    }
    
    private static func escapeLIKEPattern(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
    
    private static func connection(for dbPath: String) throws -> Connection {
        if cachedDbPath != dbPath {
            invalidateConnection()
        }
        if let cachedConnection {
            return cachedConnection
        }
        let db = try Connection(dbPath, readonly: true)
        try db.key(R.Cipher.ManicKey)
        cachedConnection = db
        cachedDbPath = dbPath
        return db
    }
    
    private static func invalidateConnection() {
        cachedConnection = nil
        cachedDbPath = nil
    }
    
    private static func mapGameInfo(from row: [Binding?]) -> GameMetadata {
        var info = GameMetadata()
        info.ratingId = intValue(row[0])
        info.users = intValue(row[1])
        info.releaseYear = intValue(row[2])
        info.releaseMonth = intValue(row[3])
        info.displayName = stringValue(row[4])
        info.fullName = stringValue(row[5])
        info.developer = stringValue(row[6])
        info.publisher = stringValue(row[7])
        info.franchise = stringValue(row[8])
        info.region = stringValue(row[9])
        info.genre = stringValue(row[10])
        info.platform = stringValue(row[11])
        if let overviewData = dataValue(row[12]) {
            info.overview = decodeOverviewData(overviewData) ?? ""
        }
        return info
    }
    
    private static func intValue(_ value: Binding?) -> Int {
        if let int64 = value as? Int64 {
            return Int(int64)
        }
        if let int = value as? Int {
            return int
        }
        return 0
    }
    
    private static func stringValue(_ value: Binding?) -> String {
        value as? String ?? ""
    }
    
    private static func dataValue(_ value: Binding?) -> Data? {
        guard let blob = value as? Blob else { return nil }
        return Data(blob.bytes)
    }
    
    private static func decodeOverviewData(_ data: Data) -> String? {
        if let decompressed = decompressZlib(data),
           let text = String(data: decompressed, encoding: .utf8) {
            return text
        }
        return String(data: data, encoding: .utf8)
    }
    
    private static func decompressZlib(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        
        return data.withUnsafeBytes { inputBuffer -> Data? in
            guard let inputBase = inputBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self) else { return nil }
            
            var stream = z_stream()
            stream.next_in = UnsafeMutablePointer(mutating: inputBase)
            stream.avail_in = uInt(data.count)
            
            guard inflateInit2_(&stream, MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
                return nil
            }
            defer { inflateEnd(&stream) }
            
            var output = Data()
            var buffer = [UInt8](repeating: 0, count: 16384)
            var status: Int32 = Z_OK
            
            repeat {
                let produced = buffer.withUnsafeMutableBufferPointer { bufferPointer -> Int in
                    stream.next_out = bufferPointer.baseAddress
                    stream.avail_out = uInt(bufferPointer.count)
                    status = inflate(&stream, Z_SYNC_FLUSH)
                    return bufferPointer.count - Int(stream.avail_out)
                }
                if produced > 0 {
                    output.append(buffer, count: produced)
                }
            } while status == Z_OK
            
            guard status == Z_STREAM_END else { return nil }
            return output
        }
    }
    
    private static func md5Hash(for url: URL) -> String? {
        guard url.isFileURL else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let bufferSize = 1024 * 1024
            let file = try FileHandle(forReadingFrom: url)
            defer { file.closeFile() }
            var hasher = Insecure.MD5()
            while autoreleasepool(invoking: {
                let data = file.readData(ofLength: bufferSize)
                if !data.isEmpty {
                    hasher.update(data: data)
                    return true
                }
                return false
            }) { }
            let digest = hasher.finalize()
            return digest.map { String(format: "%02X", $0) }.joined()
        } catch {
            return nil
        }
    }
}
