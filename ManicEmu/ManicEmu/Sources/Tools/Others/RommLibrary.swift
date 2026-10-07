//
//  RommLibrary.swift
//  ManicEmu
//
//  Created by Chris Habibi on 6/29/26.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import UIKit
import IceCream
import RealmSwift

/// Pending download links plus manual pull/push for games imported from a RomM service.
final class RommLibrary {
    static let shared = RommLibrary()
    private init() {}

    private static let pendingLinksKey = "RomMPendingSaveLinks"
    private static let stateFileSuffix = ".manicstate"

    struct TransferSummary {
        var succeeded = 0
        var failed = 0
    }

    // MARK: - Pending download → import bind

    func registerDownloadedRom(fileName: String, romId: Int, serviceId: String) {
        var map = pendingMap()
        map[fileName] = ["romId": romId, "serviceId": serviceId]
        UserDefaults.standard.set(map, forKey: Self.pendingLinksKey)
        Log.debug("[RomM] pending register file=\(fileName) romId=\(romId) serviceId=\(serviceId)")
    }

    func hasPendingLink(fileName: String) -> Bool {
        pendingMap()[fileName] != nil
    }

    func discardPendingLink(fileName: String) {
        var map = pendingMap()
        guard map[fileName] != nil else { return }
        map[fileName] = nil
        UserDefaults.standard.set(map, forKey: Self.pendingLinksKey)
        Log.debug("[RomM] pending discarded file=\(fileName)")
    }

    /// Bind extras and pull sidecar data after a newly created game import.
    func applyAfterImport(gameId: String, fileName: String? = nil) {
        Log.debug("[RomM] applyAfterImport start gameId=\(gameId) file=\(fileName ?? "nil") main=\(Thread.isMainThread)")
        let bound = bindPendingIfPossible(gameId: gameId, fileName: fileName)
        Task { @MainActor in
            await self.continueAfterImport(gameId: gameId, fileName: fileName, bound: bound)
        }
    }

    /// The importer writes the Game on a background Realm. Bind extras on that same thread
    /// so the link is not lost when the main Realm has not refreshed yet.
    private func bindPendingIfPossible(gameId: String, fileName: String?) -> (romId: Int, serviceId: String)? {
        let realm = Database.realm
        realm.refresh()
        guard let game = realm.object(ofType: Game.self, forPrimaryKey: gameId), !game.isDeleted else {
            Log.debug("[RomM] bind deferred; game not on caller Realm yet gameId=\(gameId)")
            return nil
        }
        let pendingName = fileName ?? game.fileName
        guard let pending = consumePendingLink(fileName: pendingName) ?? consumePendingLink(fileName: game.fileName) else {
            Log.debug("[RomM] bind skipped; no pending file=\(pendingName) gameFile=\(game.fileName)")
            return nil
        }
        persistLink(gameId: gameId, romId: pending.romId, serviceId: pending.serviceId)
        Log.debug("[RomM] bind on caller thread game=\(game.fileName) romId=\(pending.romId) serviceId=\(pending.serviceId)")
        return pending
    }

    @MainActor
    private func continueAfterImport(gameId: String, fileName: String?, bound: (romId: Int, serviceId: String)?) async {
        guard let game = await waitForGame(gameId: gameId) else {
            Log.debug("[RomM] applyAfterImport aborted; game still missing after refresh gameId=\(gameId) file=\(fileName ?? "nil")")
            return
        }
        let pending: (romId: Int, serviceId: String)
        if let bound {
            pending = bound
        } else if let consumed = consumePendingLink(fileName: fileName ?? game.fileName) ?? consumePendingLink(fileName: game.fileName) {
            persistLink(gameId: gameId, romId: consumed.romId, serviceId: consumed.serviceId)
            Log.debug("[RomM] bind on main after refresh game=\(game.fileName) romId=\(consumed.romId) serviceId=\(consumed.serviceId)")
            pending = consumed
        } else if let romId = game.rommRomId, let serviceId = game.rommServiceId {
            pending = (romId, serviceId)
            Log.debug("[RomM] applyAfterImport using existing bind romId=\(romId) serviceId=\(serviceId)")
        } else {
            Log.debug("[RomM] applyAfterImport skipped: no pending link file=\(fileName ?? game.fileName) gameFile=\(game.fileName) gameId=\(gameId)")
            return
        }
        guard let client = makeClient(serviceId: pending.serviceId) else {
            Log.debug("[RomM] applyAfterImport: client unavailable for service \(pending.serviceId)")
            return
        }
        do {
            try await pullSidecar(gameId: gameId, client: client, romId: pending.romId)
        } catch {
            Log.debug("[RomM] applyAfterImport failed for \(game.fileName): \(error)")
        }
    }

    @MainActor
    private func waitForGame(gameId: String) async -> Game? {
        let realm = Database.realm
        realm.refresh()
        if let game = realm.object(ofType: Game.self, forPrimaryKey: gameId), !game.isDeleted {
            return game
        }
        for attempt in 1...8 {
            try? await Task.sleep(nanoseconds: 50_000_000 * UInt64(attempt))
            realm.refresh()
            if let game = realm.object(ofType: Game.self, forPrimaryKey: gameId), !game.isDeleted {
                Log.debug("[RomM] game appeared on main Realm after attempt \(attempt) gameId=\(gameId)")
                return game
            }
        }
        return nil
    }

    @MainActor
    func linkedGameCount(service: ImportService) -> Int {
        linkedGameIds(serviceId: "\(service.id)").count
    }

    /// Makes a linked RomM game locally available immediately before launch.
    /// Existing local games are untouched. Remote files are streamed to a temporary
    /// URL first and atomically moved into Manic's normal ROM location so every
    /// emulator core can keep using its existing local-file launch path.
    @MainActor
    func prepareGameForLaunch(_ game: Game) async -> Bool {
        guard !inFlightGameIDs.contains(game.id) else { return false }

        if FileManager.default.fileExists(atPath: game.romUrl.path) {
            markUsed(game)
            return true
        }

        guard let serviceId = game.manicServerServiceId,
              let snapshot = serviceSnapshot(id: serviceId),
              let client = snapshot.makeClient() else {
            UIView.makeToast(message: "Manic Server is unavailable")
            return false
        }

        let expectedSize = game.manicServerFileSize
        if let expectedSize, expectedSize > Self.cacheLimitBytes {
            UIView.makeToast(message: "This game is larger than the 12 GB smart-cache limit")
            return false
        }

        inFlightGameIDs.insert(game.id)
        defer {
            inFlightGameIDs.remove(game.id)
            ManicServerDownloadProgressHUD.hide()
        }

        if let expectedSize, expectedSize > 0 {
            trimCache(toMaximumBytes: max(0, Self.cacheLimitBytes - expectedSize),
                      excludingGameID: game.id)
        }

        let displayName = game.displayName
        ManicServerDownloadProgressHUD.show(title: displayName)
        ManicServerDownloadProgressHUD.update(received: 0, expected: expectedSize ?? -1)

        do {
            let bundle = Self.bundleFiles(for: game)
            if !bundle.isEmpty {
                try await downloadBundle(bundle,
                                         game: game,
                                         client: client,
                                         expectedSize: expectedSize)
            } else {
                guard let downloadPath = game.manicServerDownloadPath,
                      let request = client.downloadRequest(path: downloadPath) else {
                    throw URLError(.badURL)
                }

                Log.debug("[ManicServer] download start game=\(displayName) path=\(downloadPath) expected=\(expectedSize ?? -1)")
                let temporaryURL = try await client.downloadFile(for: request) { received, responseExpected in
                    let total = responseExpected > 0 ? responseExpected : (expectedSize ?? -1)
                    Task { @MainActor in
                        ManicServerDownloadProgressHUD.update(received: received, expected: total)
                    }
                }

                let destination = game.romUrl
                let fm = FileManager.default
                try fm.createDirectory(at: destination.deletingLastPathComponent(),
                                       withIntermediateDirectories: true)
                if fm.fileExists(atPath: destination.path) {
                    try fm.removeItem(at: destination)
                }
                try fm.moveItem(at: temporaryURL, to: destination)

                if let expected = expectedSize,
                   expected > 0,
                   let attributes = try? fm.attributesOfItem(atPath: destination.path),
                   let number = attributes[.size] as? NSNumber,
                   number.int64Value != expected {
                    Log.debug("[ManicServer] size mismatch expected=\(expected) actual=\(number.int64Value) game=\(displayName)")
                }

                if game.gameType == .ps1 && game.fileExtension.lowercased() == "bin" {
                    game.ensurePS1BinCueSheet()
                }
            }

            guard FileManager.default.fileExists(atPath: game.romUrl.path) else {
                throw URLError(.cannotOpenFile)
            }

            markUsed(game)
            trimCache(toMaximumBytes: Self.cacheLimitBytes,
                      excludingGameID: game.id)
            ManicServerDownloadProgressHUD.update(received: expectedSize ?? 1,
                                                  expected: expectedSize ?? 1)
            Log.debug("[ManicServer] download complete game=\(displayName) destination=\(game.romUrl.lastPathComponent)")
            return true
        } catch {
            Log.debug("[ManicServer] download failed game=\(displayName) error=\(error)")
            UIView.makeToast(message: "Could not download \(displayName)")
            return false
        }
    }

    @MainActor
    private func downloadBundle(_ files: [RemoteBundleFile],
                                game: Game,
                                client: ManicServerClient,
                                expectedSize: Int64?) async throws {
        let fm = FileManager.default
        let root = game.romUrl.deletingLastPathComponent().standardizedFileURL
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        var completedBytes: Int64 = 0
        let total = expectedSize ?? files.compactMap(\.size).reduce(0, +)
        Log.debug("[ManicServer] bundle download start game=\(game.displayName) files=\(files.count) expected=\(total)")

        for member in files {
            guard let destination = Self.safeBundleDestination(root: root, relativeName: member.name),
                  let request = client.downloadRequest(path: member.download) else {
                throw URLError(.badURL)
            }

            if fm.fileExists(atPath: destination.path),
               let expected = member.size,
               let attrs = try? fm.attributesOfItem(atPath: destination.path),
               let actual = attrs[.size] as? NSNumber,
               actual.int64Value == expected {
                completedBytes += expected
                ManicServerDownloadProgressHUD.update(received: completedBytes,
                                                      expected: total > 0 ? total : -1)
                continue
            }

            let baseCompleted = completedBytes
            let temporaryURL = try await client.downloadFile(for: request) { received, responseExpected in
                let memberExpected = member.size ?? (responseExpected > 0 ? responseExpected : 0)
                let aggregateExpected = total > 0 ? total : (baseCompleted + memberExpected)
                Task { @MainActor in
                    ManicServerDownloadProgressHUD.update(received: baseCompleted + received,
                                                          expected: aggregateExpected > 0 ? aggregateExpected : -1)
                }
            }

            try fm.createDirectory(at: destination.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.moveItem(at: temporaryURL, to: destination)

            let actualBytes: Int64
            if let attrs = try? fm.attributesOfItem(atPath: destination.path),
               let number = attrs[.size] as? NSNumber {
                actualBytes = number.int64Value
            } else {
                actualBytes = member.size ?? 0
            }
            completedBytes += actualBytes

            if let expected = member.size, expected > 0, actualBytes != expected {
                throw URLError(.cannotDecodeContentData)
            }
        }
    }

    private static func safeBundleDestination(root: URL, relativeName: String) -> URL? {
        let normalizedName = relativeName.replacingOccurrences(of: "\\", with: "/")
        guard !normalizedName.hasPrefix("/"),
              !normalizedName.split(separator: "/").contains("..") else {
            return nil
        }
        let rootPath = root.standardizedFileURL.path
        let candidate = root.appendingPathComponent(normalizedName).standardizedFileURL
        guard candidate.path == rootPath || candidate.path.hasPrefix(rootPath + "/") else {
            return nil
        }
        return candidate
    }

    private static func bundleFiles(for game: Game) -> [RemoteBundleFile] {
        guard let raw = game.manicServerFilesJSON,
              let data = raw.data(using: .utf8),
              let files = try? JSONDecoder().decode([RemoteBundleFile].self, from: data) else {
            return []
        }
        return files
    }

    @MainActor
    func linkedGameCount(service: ImportService) -> Int {
        let serviceId = "\(service.id)"
        return Database.realm.objects(Game.self)
            .where { !$0.isDeleted }
            .filter { $0.manicServerServiceId == serviceId }
            .count
    }

    private struct MappedGame {
        let id: String
        let name: String
        let aliasName: String?
        let fileExtension: String
        let gameType: GameType
        let extras: Data?
        let coverURL: String?
    }

    private static func map(remote: ManicServerGame,
                            serviceId: String,
                            client: ManicServerClient) -> MappedGame? {
        let remoteFile = URL(fileURLWithPath: remote.file).lastPathComponent
        let ext = URL(fileURLWithPath: remoteFile).pathExtension.lowercased()
        guard !remoteFile.isEmpty, !ext.isEmpty else { return nil }

        let gameType = GameType(shortName: remote.system) ?? GameType(fileExtension: ext)
        guard gameType != .notSupport, gameType != .unknown else {
            Log.debug("[ManicServer] skip unsupported/ambiguous game system=\(remote.system) file=\(remote.file)")
            return nil
        }

        let stableSource = "manic-server:\(serviceId):\(remote.stableId)"
        guard let stableData = stableSource.data(using: .utf8) else { return nil }
        let id = stableData.md5String

        let baseName = URL(fileURLWithPath: remoteFile).deletingPathExtension().lastPathComponent
        let display = remote.displayTitle
        let alias = display == baseName ? nil : display
        let cacheFileName = "\(id).\(ext)"

        var extras: [String: Any] = [
            ExtraKey.manicServerGameId.rawValue: remote.stableId,
            ExtraKey.manicServerServiceId.rawValue: serviceId,
            ExtraKey.manicServerDownloadPath.rawValue: remote.effectiveDownloadPath,
            ExtraKey.manicServerCacheFileName.rawValue: cacheFileName
        ]
        if let size = remote.size {
            extras[ExtraKey.manicServerFileSize.rawValue] = String(size)
        }

        let bundle = remote.effectiveFiles
        if bundle.count > 1 {
            let files = bundle.map {
                RemoteBundleFile(name: $0.localName,
                                 download: $0.effectiveDownloadPath,
                                 size: $0.size)
            }
            if let data = try? JSONEncoder().encode(files),
               let json = String(data: data, encoding: .utf8) {
                extras[ExtraKey.manicServerFiles.rawValue] = json
            }
        }

        return MappedGame(id: id,
                          name: baseName,
                          aliasName: alias,
                          fileExtension: ext,
                          gameType: gameType,
                          extras: extras.jsonData(),
                          coverURL: client.absoluteURLString(path: remote.cover))
    }

    private static func apply(mapped: MappedGame,
                              to game: Game,
                              setPrimaryKey: Bool) {
        if setPrimaryKey {
            game.id = mapped.id
        } else if game.id != mapped.id {
            // This should be impossible because existing rows are looked up by mapped.id.
            // Log it instead of attempting an illegal Realm primary-key mutation.
            Log.debug("[ManicServer] primary-key mismatch existing=\(game.id) mapped=\(mapped.id)")
        }
        game.name = mapped.name
        game.aliasName = mapped.aliasName
        game.fileExtension = mapped.fileExtension
        game.gameType = mapped.gameType
        if game.importDate.timeIntervalSince1970 <= 0 {
            game.importDate = Date()
        }
        game.extras = merge(existing: game.extras, incoming: mapped.extras)
        if let coverURL = mapped.coverURL {
            game.onlineCoverUrl = coverURL
        }
        game.isDeleted = false
    }

    private static func merge(existing: Data?, incoming: Data?) -> Data? {
        var merged: [String: Any] = [:]
        if let existing,
           let values = try? existing.jsonObject() as? [String: Any] {
            merged = values
        }
        if let incoming,
           let values = try? incoming.jsonObject() as? [String: Any] {
            for (key, value) in values {
                merged[key] = value
            }
        }
        return merged.jsonData()
    }

    @MainActor
    private func markUsed(_ game: Game) {
        var usage = UserDefaults.standard.dictionary(forKey: Self.usageKey) as? [String: Double] ?? [:]
        usage[game.id] = Date().timeIntervalSince1970
        UserDefaults.standard.set(usage, forKey: Self.usageKey)
    }

    @MainActor
    func cacheUsage() -> CacheUsage {
        CacheUsage(usedBytes: currentCacheBytes(), limitBytes: Self.cacheLimitBytes)
    }

    @MainActor
    func clearSmartCache() {
        let fm = FileManager.default
        let games = Database.realm.objects(Game.self).where { !$0.isDeleted }
        for game in games where game.isManicServerGame {
            guard let url = cacheItemURL(for: game), fm.fileExists(atPath: url.path) else { continue }
            try? fm.removeItem(at: url)
            if game.gameType == .ps1,
               game.fileExtension.lowercased() == "bin",
               let cacheFileName = game.manicServerCacheFileName {
                let bin = URL(fileURLWithPath: R.Path.Data.appendingPathComponent(cacheFileName))
                let cue = bin.deletingPathExtension().appendingPathExtension("cue")
                try? fm.removeItem(at: cue)
            }
        }
        UserDefaults.standard.removeObject(forKey: Self.usageKey)
    }

    @MainActor
    private func currentCacheBytes() -> Int64 {
        let fm = FileManager.default
        let games = Database.realm.objects(Game.self).where { !$0.isDeleted }
        var seen = Set<String>()
        var total: Int64 = 0
        for game in games where game.isManicServerGame {
            guard let url = cacheItemURL(for: game),
                  seen.insert(url.standardizedFileURL.path).inserted,
                  fm.fileExists(atPath: url.path) else { continue }
            total += Self.sizeOfItem(at: url)
        }
        return total
    }

    @MainActor
    private func cacheItemURL(for game: Game) -> URL? {
        if game.isMultiFileGame {
            return game.romUrl.deletingLastPathComponent()
        }
        guard let cacheFileName = game.manicServerCacheFileName else { return nil }
        return URL(fileURLWithPath: R.Path.Data.appendingPathComponent(cacheFileName))
    }

    private static func sizeOfItem(at url: URL) -> Int64 {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        if !isDirectory.boolValue {
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        }

        var total: Int64 = 0
        if let enumerator = fm.enumerator(at: url,
                                          includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                                          options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                   values.isRegularFile == true {
                    total += Int64(values.fileSize ?? 0)
                }
            }
        }
        return total
    }

    /// Keep only remote ROM/disc cache files within the fixed 12 GB budget.
    /// Library rows, covers, metadata, BIOS, memory cards and saves are never touched.
    @MainActor
    private func trimCache(toMaximumBytes maximumBytes: Int64,
                           excludingGameID: String) {
        struct Entry {
            let gameID: String
            let url: URL
            let bytes: Int64
            let lastUsed: Double
            let isPS1Bin: Bool
        }

        let fm = FileManager.default
        var usage = UserDefaults.standard.dictionary(forKey: Self.usageKey) as? [String: Double] ?? [:]
        let games = Database.realm.objects(Game.self).where { !$0.isDeleted }

        var entries: [Entry] = []
        var total: Int64 = 0

        for game in games where game.isManicServerGame {
            guard let url = cacheItemURL(for: game),
                  fm.fileExists(atPath: url.path) else { continue }

            let bytes = Self.sizeOfItem(at: url)
            total += bytes
            entries.append(Entry(gameID: game.id,
                                 url: url,
                                 bytes: bytes,
                                 lastUsed: usage[game.id] ?? 0,
                                 isPS1Bin: !game.isMultiFileGame
                                    && game.gameType == .ps1
                                    && game.fileExtension.lowercased() == "bin"))
        }

        guard total > maximumBytes else { return }

        let candidates = entries
            .filter { $0.gameID != excludingGameID }
            .sorted { lhs, rhs in
                if lhs.lastUsed == rhs.lastUsed {
                    return lhs.gameID < rhs.gameID
                }
                return lhs.lastUsed < rhs.lastUsed
            }

        for entry in candidates where total > maximumBytes {
            do {
                try fm.removeItem(at: entry.url)
                if entry.isPS1Bin {
                    let cue = entry.url.deletingPathExtension().appendingPathExtension("cue")
                    if fm.fileExists(atPath: cue.path) {
                        try? fm.removeItem(at: cue)
                    }
                }
                total -= entry.bytes
                usage.removeValue(forKey: entry.gameID)
                Log.debug("[ManicServer] smart cache evicted game=\(entry.gameID) bytes=\(entry.bytes) remaining=\(total)")
            } catch {
                Log.debug("[ManicServer] smart cache eviction failed game=\(entry.gameID) error=\(error)")
            }
        }

        UserDefaults.standard.set(usage, forKey: Self.usageKey)
    }

    @MainActor
    private func serviceSnapshot(id: String) -> ServiceSnapshot? {
        guard let value = Int(id),
              let service = Database.realm.object(ofType: ImportService.self, forPrimaryKey: value),
              !service.isDeleted else { return nil }
        return ServiceSnapshot(service: service)
    }

    private struct ServiceSnapshot {
        let id: String
        let scheme: String
        let host: String
        let port: Int?
        let path: String?
        let user: String?
        let password: String?

        @MainActor
        init(service: ImportService) {
            id = "\(service.id)"
            scheme = service.scheme ?? "http"
            host = service.host ?? ""
            port = service.port
            path = service.path
            user = service.user
            password = service.password
        }

        func makeClient() -> ManicServerClient? {
            ManicServerClient(scheme: scheme,
                              host: host,
                              port: port,
                              user: user,
                              password: password,
                              path: path)
        }
    }
}


private final class ManicServerDownloadProgressHUD: UIView {
    private static var active: ManicServerDownloadProgressHUD?

    private let titleLabel = UILabel()
    private let percentLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let detailLabel = UILabel()

    private init(title: String) {
        super.init(frame: .zero)

        backgroundColor = UIColor.black.withAlphaComponent(0.88)
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor

        titleLabel.text = "Downloading \(title)"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        percentLabel.text = "0%"
        percentLabel.textColor = .white
        percentLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        percentLabel.textAlignment = .right

        progressView.progress = 0
        progressView.progressTintColor = R.Color.Main
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.18)

        detailLabel.textColor = UIColor.white.withAlphaComponent(0.68)
        detailLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)

        [titleLabel, percentLabel, progressView, detailLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: percentLabel.leadingAnchor, constant: -12),

            percentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            percentLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            percentLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),

            progressView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            detailLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 9),
            detailLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            detailLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor
    static func show(title: String) {
        active?.removeFromSuperview()

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else { return }

        let hud = ManicServerDownloadProgressHUD(title: title)
        hud.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(hud)
        NSLayoutConstraint.activate([
            hud.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            hud.leadingAnchor.constraint(greaterThanOrEqualTo: window.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            hud.trailingAnchor.constraint(lessThanOrEqualTo: window.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            hud.widthAnchor.constraint(lessThanOrEqualToConstant: 390),
            hud.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),
            hud.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
        active = hud
    }

    @MainActor
    static func update(received: Int64, expected: Int64) {
        guard let hud = active else { return }

        if expected > 0 {
            let value = min(max(Double(received) / Double(expected), 0), 1)
            hud.progressView.setProgress(Float(value), animated: true)
            hud.percentLabel.text = "\(Int((value * 100).rounded(.down)))%"

            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            hud.detailLabel.text = "\(formatter.string(fromByteCount: max(0, received))) of \(formatter.string(fromByteCount: expected))"
        } else {
            hud.progressView.setProgress(0, animated: false)
            hud.percentLabel.text = "…"
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            hud.detailLabel.text = formatter.string(fromByteCount: max(0, received))
        }
    }

    @MainActor
    static func hide() {
        active?.removeFromSuperview()
        active = nil
    }
}
