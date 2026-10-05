//
//  EmulatorInteractionKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/12/16.
//  Copyright © 2025 Manic EMU. All rights reserved.
//


import IceCream

#if canImport(ARMSX2Core)
import ARMSX2Core
#endif

extension GameType {
    static let ns = GameType("public.aoshuang.game.ns")
    static let xbox360 = GameType("public.aoshuang.game.xbox360")
    static let xbox = GameType("public.aoshuang.game.xbox")
    static let ps2 = GameType("public.aoshuang.game.ps2")
}

struct EmulatorInteractionKit {
    enum EmulatorType {
        case meloNX, xeniOS, dukeX, armsx2
    }
    
    /// Display name plus the public URL scheme. Extra ARMSX2 aliases stay in `supportedLaunchSchemes`.
    static let supportedLaunchers: [(name: String, scheme: String)] = [
        ("Delta", "delta"),
        ("RetroArch", "retroarch"),
        ("PPSSPP", "ppsspp"),
        ("Provenance", "provenance"),
        ("Gamma", "gamma"),
        ("GBA4iOS", "gba4ios"),
        ("MeloNX", "atariemulator"),
        ("XeniOS", "xenios"),
        ("DukeX", "dukex"),
        ("ARMSX2", "armsx2"),
        ("Consoles", "consolesapp"),
        ("MeloCafe", "melocafe")
    ]
    
    /// Schemes that must also be listed in `LSApplicationQueriesSchemes`.
    static let supportedLaunchSchemes: Set<String> = Set(supportedLaunchers.map(\.scheme)).union([
        "armsx2-ios",
        "armsx2ios"
    ])
    
    enum LaunchURLValidation {
        case ok(URL)
        case invalid
        case unsupportedScheme
    }
    
    /// Parse a pasted emulator deep link. Rejects http(s)/file and unknown schemes.
    static func validateLaunchURL(_ string: String) -> LaunchURLValidation {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .invalid }
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              !scheme.isEmpty else {
            return .invalid
        }
        if scheme == "http" || scheme == "https" || scheme == "file" || scheme == "ftp" {
            return .unsupportedScheme
        }
        guard supportedLaunchSchemes.contains(scheme) else {
            return .unsupportedScheme
        }
        if let url = components.url {
            return .ok(url)
        }
        if let url = URL(string: trimmed) {
            return .ok(url)
        }
        return .invalid
    }
    
    static func openExternalGameURL(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) ?? URLComponents(string: trimmed)?.url else {
            UIView.makeToast(message: R.string.localizable.addUrlGameInvalidUrl())
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            guard !success else { return }
            DispatchQueue.main.async {
                let scheme = url.scheme ?? ""
                UIView.makeToast(message: scheme.isEmpty
                                 ? R.string.localizable.addUrlGameInvalidUrl()
                                 : R.string.localizable.notInstall(scheme))
            }
        }
    }
    
    static func isInstalled(type: EmulatorType) -> Bool {
        switch type {
        case .meloNX:
            return UIApplication.shared.canOpenURL(R.URLs.FetchMeloNXGames)
        case .xeniOS:
            return UIApplication.shared.canOpenURL(R.URLs.FetchXeniOSGames)
        case .dukeX:
            return UIApplication.shared.canOpenURL(R.URLs.FetchDukeXGames)
        case .armsx2:
            return UIApplication.shared.canOpenURL(R.URLs.FetchARMSX2Games)
                || UIApplication.shared.canOpenURL(URL(string: "\(R.Strings.ARMSX2Scheme)-ios://library")!)
                || UIApplication.shared.canOpenURL(URL(string: "\(R.Strings.ARMSX2Scheme)ios://library")!)
        }
    }
    
    static func startGame(type: EmulatorType, id: String) {
        if isInstalled(type: type) {
            switch type {
            case .meloNX:
                UIApplication.shared.open(R.URLs.MeloNXGameLaunch(gameId: id))
            case .xeniOS:
                UIApplication.shared.open(R.URLs.XeniOSGameLaunch(gameId: id))
            case .dukeX:
                UIApplication.shared.open(R.URLs.DukeXGameLaunch(gameId: id))
            case .armsx2:
                UIApplication.shared.open(R.URLs.ARMSX2GameLaunch(gameId: id))
            }
        } else {
            DispatchQueue.main.asyncAfter(delay: 0.35) {
                switch type {
                case .meloNX:
                    UIView.makeToast(message: R.string.localizable.notInstallMeloNX())
                case .xeniOS:
                    UIView.makeToast(message: R.string.localizable.notInstall("XeniOS"))
                case .dukeX:
                    UIView.makeToast(message: R.string.localizable.notInstall("DukeX"))
                case .armsx2:
                    UIView.makeToast(message: R.string.localizable.notInstall("ARMSX2"))
                }
            }
        }
    }
    
    static func fetchGames(type: EmulatorType) {
        if isInstalled(type: type) {
            switch type {
            case .meloNX:
                UIApplication.shared.open(R.URLs.FetchMeloNXGames)
            case .xeniOS:
                UIApplication.shared.open(R.URLs.FetchXeniOSGames)
            case .dukeX:
                UIApplication.shared.open(R.URLs.FetchDukeXGames)
            case .armsx2:
                UIApplication.shared.open(R.URLs.FetchARMSX2Games)
            }
            
        } else {
            switch type {
            case .meloNX:
                UIView.makeToast(message: R.string.localizable.notInstallMeloNX())
            case .xeniOS:
                UIView.makeToast(message: R.string.localizable.notInstall("XeniOS"))
            case .dukeX:
                UIView.makeToast(message: R.string.localizable.notInstall("DukeX"))
            case .armsx2:
                UIView.makeToast(message: R.string.localizable.notInstall("ARMSX2"))
            }
        }
    }
    
    static func processGames(type: EmulatorType, callbackUrl: URL) {
        var delay: Double
        if let _ = ApplicationSceneDelegate.applicationWindow {
            delay = 0.0
        } else {
            delay = 3.0
        }
        DispatchQueue.global().asyncAfter(delay: delay) {
            let fromGames = GameScheme.pullFromURL(callbackUrl)
            var games = [Game]()
            let realm = Database.realm
            for mg in fromGames {
                if let _ = realm.object(ofType: Game.self, forPrimaryKey: mg.titleId) {
                    Log.debug("MeloNX游戏已存在:\(mg.titleId) \(mg.titleName)")
                } else {
                    let game = Game()
                    switch type {
                    case .meloNX:
                        game.fileExtension = "xci"
                        game.gameType = .ns
                    case .xeniOS:
                        game.fileExtension = "iso"
                        game.gameType = .xbox360
                    case .dukeX:
                        game.fileExtension = "xiso"
                        game.gameType = .xbox
                    case .armsx2:
                        let ext = URL(fileURLWithPath: mg.titleId).pathExtension.lowercased()
                        game.fileExtension = ext.isEmpty ? "iso" : ext
                        game.gameType = .ps2
                    }
                    game.id = mg.titleId
                    game.name = mg.titleName
                    game.importDate = Date()
                    if let icon = mg.iconData {
                        game.gameCover = CreamAsset.create(objectID: game.id, propName: "gameCover", data: icon)
                    } else {
                        OnlineCoverManager.shared.addCoverMatch(.init(game: game))
                    }
                    games.append(game)
                }
            }
            if games.count > 0 {
                try? realm.write({
                    realm.add(games)
                })
                DispatchQueue.main.asyncAfter(delay: 1) {
                    switch type {
                    case .meloNX:
                        UIView.makeToast(message: R.string.localizable.biosImportSuccess("MeloNX Games"))
                    case .xeniOS:
                        UIView.makeToast(message: R.string.localizable.biosImportSuccess("Xenios Games"))
                    case .dukeX:
                        UIView.makeToast(message: R.string.localizable.biosImportSuccess("DukeX Games"))
                    case .armsx2:
                        UIView.makeToast(message: R.string.localizable.biosImportSuccess("ARMSX2 Games"))
                    }
                }
            }
        }
    }
}

struct GameScheme: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id = UUID().uuidString
    
    var titleName: String
    var titleId: String
    var developer: String
    var version: String
    var iconData: Data?
    
    static func pullFromURL(_ url: URL) -> [GameScheme] {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            let items = components.queryItems ?? []
            if let text = items.first(where: { $0.name == "games" })?.value,
                let data = GameScheme.base64URLDecode(text),
                let decoded = try? JSONDecoder().decode([GameScheme].self, from: data) {
                return decoded
            }
            // ARMSX2 sends `payload` wrapping `{ games: [{ title, fileName, ... }] }`.
            if let text = items.first(where: { $0.name == "payload" })?.value,
                let data = GameScheme.base64URLDecode(text),
                let library = try? JSONDecoder().decode(ARMSX2Library.self, from: data) {
                return library.gameSchemes
            }
        }
        return []
    }
    
    private static func base64URLDecode(_ text: String) -> Data? {
        var base64 = text
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 = base64.appending("=")
        }
        return Data(base64Encoded: base64)
    }
}

/// ARMSX2 `com.armsx2.library.v1` callback body. Launch key is `fileName`.
private struct ARMSX2Library: Decodable {
    let games: [ARMSX2Game]
    
    var gameSchemes: [GameScheme] {
        games.compactMap(\.gameScheme)
    }
}

private struct ARMSX2Game: Decodable {
    let title: String?
    let fileName: String?
    let serial: String?
    
    var gameScheme: GameScheme? {
        guard let fileName, !fileName.isEmpty else {
            return nil
        }
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let titleName = trimmedTitle.isEmpty
            ? URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
            : trimmedTitle
        return GameScheme(
            id: fileName,
            titleName: titleName,
            titleId: fileName,
            developer: serial ?? "",
            version: "1.0",
            iconData: nil
        )
    }
}



// MARK: - Persistent PS2 launch diagnostics

private enum PS2DiagnosticLog {
    private static let lock = NSLock()
    private static let formatter = ISO8601DateFormatter()
    private static let logFileName = "manic-ps2-crash.log"
    private static let markerFileName = "manic-ps2-active-session.txt"
    private static let maximumLogBytes: UInt64 = 1_500_000
    private static var exceptionHandlerInstalled = false

    private static var logsDirectoryURL: URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documents.appendingPathComponent("ARMSX2/logs", isDirectory: true)
    }

    static var logURL: URL? {
        logsDirectoryURL?.appendingPathComponent(logFileName)
    }

    private static var markerURL: URL? {
        logsDirectoryURL?.appendingPathComponent(markerFileName)
    }

    static func installCrashHooks() {
        lock.lock()
        defer { lock.unlock() }
        guard !exceptionHandlerInstalled else { return }
        exceptionHandlerInstalled = true
        NSSetUncaughtExceptionHandler(manicPS2UncaughtExceptionHandler)
    }

    static func recoverPreviousSessionIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard let markerURL,
              FileManager.default.fileExists(atPath: markerURL.path),
              let data = try? Data(contentsOf: markerURL),
              let marker = String(data: data, encoding: .utf8),
              !marker.isEmpty else { return }

        appendUnlocked("RECOVERY previous PS2 session ended unexpectedly. Last checkpoint: \(marker.trimmingCharacters(in: .whitespacesAndNewlines))")
        try? FileManager.default.removeItem(at: markerURL)
    }

    static func begin(game: Game) {
        installCrashHooks()
        recoverPreviousSessionIfNeeded()

        let fileSize: UInt64 = {
            let attributes = try? FileManager.default.attributesOfItem(atPath: game.romUrl.path)
            return (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
        }()

        log("========== PS2 SESSION BEGIN ==========")
        log("app_version=\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?") build=\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?")")
        log("ios=\(UIDevice.current.systemName) \(UIDevice.current.systemVersion) device=\(UIDevice.current.model)")
        log("game_id=\(game.id)")
        log("game_name=\(game.displayName)")
        log("rom=\(game.romUrl.lastPathComponent) ext=\(game.romUrl.pathExtension.lowercased()) bytes=\(fileSize)")
        log("game_jit_preference=\(game.jit)")
        checkpoint("session-begin")
    }

    static func log(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        appendUnlocked(message)
    }

    static func checkpoint(_ step: String) {
        lock.lock()
        defer { lock.unlock() }

        let stamp = "\(formatter.string(from: Date())) | \(step)\n"
        if let markerURL {
            ensureDirectoryUnlocked()
            try? stamp.data(using: .utf8)?.write(to: markerURL, options: .atomic)
        }
        appendUnlocked("CHECKPOINT \(step)")
    }

    static func end(clean: Bool, reason: String) {
        lock.lock()
        defer { lock.unlock() }
        appendUnlocked("SESSION END clean=\(clean) reason=\(reason)")
        if clean, let markerURL {
            try? FileManager.default.removeItem(at: markerURL)
        }
        appendUnlocked("========== PS2 SESSION END ==========")
    }

    static func recordUncaughtException(_ exception: NSException) {
        lock.lock()
        defer { lock.unlock() }
        appendUnlocked("UNCAUGHT NSException name=\(exception.name.rawValue) reason=\(exception.reason ?? "nil")")
        if !exception.callStackSymbols.isEmpty {
            appendUnlocked("exception_backtrace=\(exception.callStackSymbols.joined(separator: " | "))")
        }
    }

    static func text(maxCharacters: Int = 140_000) -> String {
        recoverPreviousSessionIfNeeded()
        guard let logURL,
              let data = try? Data(contentsOf: logURL),
              let full = String(data: data, encoding: .utf8) else {
            return "No PS2 diagnostic log exists yet. Launch a PS2 game once, then reopen this screen."
        }
        if full.count <= maxCharacters { return full }
        return "…older log content trimmed…\n" + String(full.suffix(maxCharacters))
    }

    static func ensureExportFile() -> URL? {
        recoverPreviousSessionIfNeeded()
        if let logURL, !FileManager.default.fileExists(atPath: logURL.path) {
            log("PS2 diagnostics file created manually.")
        }
        return logURL
    }

    static func clear() {
        lock.lock()
        defer { lock.unlock() }
        if let logURL { try? FileManager.default.removeItem(at: logURL) }
        if let markerURL { try? FileManager.default.removeItem(at: markerURL) }
    }

    private static func ensureDirectoryUnlocked() {
        guard let directory = logsDirectoryURL else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private static func rotateIfNeededUnlocked() {
        guard let logURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: logURL.path),
              let size = (attrs[.size] as? NSNumber)?.uint64Value,
              size > maximumLogBytes else { return }

        let oldURL = logURL.deletingLastPathComponent().appendingPathComponent("manic-ps2-crash.previous.log")
        try? FileManager.default.removeItem(at: oldURL)
        try? FileManager.default.moveItem(at: logURL, to: oldURL)
    }

    private static func appendUnlocked(_ message: String) {
        ensureDirectoryUnlocked()
        rotateIfNeededUnlocked()
        guard let logURL else { return }

        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }

        do {
            let handle = try FileHandle(forWritingTo: logURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            // Diagnostics must never make a launch fail.
        }
    }
}

private func manicPS2UncaughtExceptionHandler(_ exception: NSException) {
    PS2DiagnosticLog.recordUncaughtException(exception)
}

// MARK: - Embedded ARMSX2 bridge

enum ARMSX2EmbeddedCore {
    static var diagnosticLogURL: URL? {
        PS2DiagnosticLog.ensureExportFile()
    }

    static func diagnosticLogText() -> String {
        PS2DiagnosticLog.text()
    }

    static func clearDiagnosticLog() {
        PS2DiagnosticLog.clear()
    }

    private static func prepare() -> Bool {
#if canImport(ARMSX2Core)
        return ARMSX2EmbeddedRuntime.prepare()
#else
        return false
#endif
    }

    static var isAvailable: Bool {
#if canImport(ARMSX2Core)
        return true
#else
        return false
#endif
    }

    static var isJITAvailable: Bool {
#if canImport(ARMSX2Core)
        guard prepare() else { return false }
        return ARMSX2Bridge.isJITAvailable()
#else
        return false
#endif
    }

    static var availableBIOSNames: [String] {
#if canImport(ARMSX2Core)
        guard prepare() else { return [] }
        return ARMSX2Bridge.availableBIOSInfos()
            .filter { $0.valid }
            .map { $0.fileName }
#else
        return []
#endif
    }

    static var defaultBIOSName: String? {
#if canImport(ARMSX2Core)
        guard prepare() else { return nil }
        let name = ARMSX2Bridge.defaultBIOSName()
        return name.isEmpty ? nil : name
#else
        return nil
#endif
    }

    @discardableResult
    static func importBIOS(from sourceURL: URL) -> Bool {
#if canImport(ARMSX2Core)
        guard prepare() else { return false }
        let destinationDirectory = URL(fileURLWithPath: ARMSX2Bridge.biosDirectory(), isDirectory: true)
        let destination = destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)

            let valid = ARMSX2Bridge.availableBIOSInfos()
                .contains { $0.valid && $0.fileName == destination.lastPathComponent }
            if valid {
                ARMSX2Bridge.setDefaultBIOS(destination.lastPathComponent)
            }
            return valid
        } catch {
            Log.error("ARMSX2 BIOS import failed: \(error)")
            return false
        }
#else
        return false
#endif
    }

    static func setDefaultBIOS(_ fileName: String) {
#if canImport(ARMSX2Core)
        guard prepare() else { return }
        ARMSX2Bridge.setDefaultBIOS(fileName)
#endif
    }

    /// Returns true when ManicEMU took ownership of the launch.
    @discardableResult
    static func startGame(_ game: Game) -> Bool {
#if canImport(ARMSX2Core)
        guard game.gameType == .ps2,
              game.isRomExtsts,
              FileManager.default.fileExists(atPath: game.romUrl.path) else {
            return false
        }

        PS2DiagnosticLog.begin(game: game)
        PS2DiagnosticLog.checkpoint("startGame.before-prepare")
        let prepared = prepare()
        PS2DiagnosticLog.log("prepare_result=\(prepared)")
        PS2DiagnosticLog.checkpoint("startGame.after-prepare")
        guard prepared else {
            PS2DiagnosticLog.end(clean: true, reason: "prepare returned false")
            UIView.makeToast(message: "Could not initialize the embedded ARMSX2 core")
            return true
        }

        let biosName = ARMSX2Bridge.defaultBIOSName()
        let biosAvailable = ARMSX2Bridge.hasBIOS()
        let validBIOS = ARMSX2Bridge.availableBIOSInfos().filter { $0.valid }.map { $0.fileName }
        PS2DiagnosticLog.log("bios_available=\(biosAvailable) default_bios=\(biosName) valid_bios_files=\(validBIOS)")
        PS2DiagnosticLog.checkpoint("startGame.after-bios-check")
        guard biosAvailable else {
            PS2DiagnosticLog.end(clean: true, reason: "BIOS missing")
            UIView.makeToast(message: "A PS2 BIOS is required before starting this game")
            return true
        }

        PS2DiagnosticLog.checkpoint("startGame.before-canResolveISO")
        let canResolve = ARMSX2Bridge.canResolveISO(game.romUrl.path)
        PS2DiagnosticLog.log("canResolveISO=\(canResolve)")
        PS2DiagnosticLog.checkpoint("startGame.after-canResolveISO")
        guard canResolve else {
            PS2DiagnosticLog.end(clean: true, reason: "ISO could not be resolved")
            UIView.makeToast(message: "ARMSX2 could not read this PS2 game image")
            return true
        }

        let jitAvailable = ARMSX2Bridge.isJITAvailable()
        PS2DiagnosticLog.log("jit_preference=\(game.jit) jit_available=\(jitAvailable)")
        PS2DiagnosticLog.checkpoint("startGame.after-jit-check")

        // PS2 can boot through ARMSX2's interpreter without a JIT grant.
        // JIT is an opt-in per-game acceleration, not a hard launch requirement.
        if game.jit && !jitAvailable {
#if SIDE_LOAD
            acquireJITAndLaunch(gameID: game.id)
#else
            UIView.makeToast(message: "JIT is enabled for this PS2 game, but this build cannot acquire a JIT grant. Disable JIT for interpreter mode.")
#endif
            return true
        }

        launchPreparedGame(gameID: game.id)
        return true
#else
        return false
#endif
    }

#if canImport(ARMSX2Core)
    private static func acquireJITAndLaunch(gameID: String) {
#if SIDE_LOAD
        PS2DiagnosticLog.checkpoint("jit-acquire.begin")
        if StikJITManager.shared.jitLaunchMode == .externalDebugger {
            if !StikJITHostCoordinator.shared.openExternalDebugger() {
                UIView.makeToast(message: R.string.localizable.notInstall("StikDebug"))
            }
            return
        }

        UIView.makeLoading(timeout: R.Numbers.WebLoadingViewTimeout)
        StikJITHostCoordinator.shared.acquireNow { ok, message in
            DispatchQueue.main.async {
                UIView.hideLoading()
                PS2DiagnosticLog.log("jit-acquire.callback ok=\(ok) message=\(message ?? "nil")")
                PS2DiagnosticLog.checkpoint("jit-acquire.callback")

                guard ok else {
                    UIView.makeAlert(
                        title: R.string.localizable.enableJIT(),
                        detail: message ?? R.string.localizable.errorUnknown(),
                        detailAlignment: .center,
                        cancelTitle: R.string.localizable.gotIt())
                    return
                }

                guard ARMSX2Bridge.isJITAvailable() else {
                    UIView.makeToast(message: "JIT was requested, but ARMSX2 still cannot see an active JIT grant.")
                    return
                }

                launchPreparedGame(gameID: gameID)
            }
        }
#endif
    }

    private static func launchPreparedGame(gameID: String) {
        PS2DiagnosticLog.checkpoint("launchPreparedGame.enter")
        guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameID),
              !game.isInvalidated,
              !game.isDeleted,
              game.gameType == .ps2,
              game.isRomExtsts else { return }

        let useJIT = game.jit && ARMSX2Bridge.isJITAvailable()
        PS2DiagnosticLog.log("launchPreparedGame useJIT=\(useJIT)")
        PS2DiagnosticLog.checkpoint("launchPreparedGame.before-cpu-settings")

        ARMSX2Bridge.setINIInt("EmuCore/CPU", key: "CoreType", value: Int32(useJIT ? 2 : 1))
        ARMSX2Bridge.setINIBool("EmuCore/CPU", key: "UseArm64Dynarec", value: useJIT)
        ARMSX2Bridge.setINIBool("EmuCore/CPU/Recompiler", key: "EnableEE", value: useJIT)
        ARMSX2Bridge.setINIBool("EmuCore/CPU/Recompiler", key: "EnableIOP", value: useJIT)
        ARMSX2Bridge.setINIBool("EmuCore/CPU/Recompiler", key: "EnableVU0", value: useJIT)
        ARMSX2Bridge.setINIBool("EmuCore/CPU/Recompiler", key: "EnableVU1", value: useJIT)
        ARMSX2Bridge.setINIBool("ARMSX2iOS/Speedhacks", key: "ManualFastmem", value: true)
        ARMSX2Bridge.setINIBool("EmuCore/CPU/Recompiler", key: "EnableFastmem", value: useJIT)
        if !useJIT {
            ARMSX2Bridge.setINIBool("EmuCore/Speedhacks", key: "vuThread", value: false)
        }
        ARMSX2Bridge.flushINISettings()
        PS2DiagnosticLog.checkpoint("launchPreparedGame.after-cpu-settings")

        let controller = ARMSX2EmbeddedGameViewController(game: game)
        controller.modalPresentationStyle = .fullScreen
        PS2DiagnosticLog.checkpoint("launchPreparedGame.before-present-controller")
        topViewController(appController: true)?.present(controller, animated: true) {
            PS2DiagnosticLog.checkpoint("launchPreparedGame.controller-presented")
        }
    }
#endif
}

#if canImport(ARMSX2Core)
/// Minimal native host for the ARMSX2 render surface. XMB remains the frontend;
/// ARMSX2's standalone SwiftUI library/menu is not presented.
private final class ARMSX2EmbeddedGameViewController: UIViewController {
    private let gameID: String
    private var hasBooted = false
    private var isClosing = false
    private var vmObservers: [NSObjectProtocol] = []

    init(game: Game) {
        self.gameID = game.id
        super.init(nibName: nil, bundle: nil)
        modalPresentationCapturesStatusBarAppearance = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        PS2DiagnosticLog.checkpoint("gameVC.viewDidLoad.enter")

        PS2DiagnosticLog.checkpoint("gameVC.viewDidLoad.before-runtime-prepare")
        let runtimePrepared = ARMSX2EmbeddedRuntime.prepare()
        PS2DiagnosticLog.log("gameVC runtime_prepare_result=\(runtimePrepared)")
        PS2DiagnosticLog.checkpoint("gameVC.viewDidLoad.after-runtime-prepare")
        guard runtimePrepared else {
            UIView.makeToast(message: "Could not initialize the embedded ARMSX2 core")
            dismiss(animated: true)
            return
        }

        // Do not reparent ARMSX2's CAMetalLayer into Manic's UIWindow.
        // The native render surface stays attached to ARMSX2's SDL-created window.
        let center = NotificationCenter.default
        vmObservers = [
            center.addObserver(forName: Notification.Name("ARMSX2iOSRequestVMBoot"), object: nil, queue: .main) { _ in
                PS2DiagnosticLog.checkpoint("notification.ARMSX2iOSRequestVMBoot")
            },
            center.addObserver(forName: Notification.Name("ARMSX2iOSEnterGameScreen"), object: nil, queue: .main) { _ in
                PS2DiagnosticLog.checkpoint("notification.ARMSX2iOSEnterGameScreen")
            },
            center.addObserver(forName: Notification.Name("ARMSX2iOSVMDidShutdown"), object: nil, queue: .main) { [weak self] _ in
                PS2DiagnosticLog.checkpoint("notification.ARMSX2iOSVMDidShutdown")
                self?.closeAfterVMStops()
            },
            center.addObserver(forName: Notification.Name("ARMSX2iOSReturnToMenu"), object: nil, queue: .main) { [weak self] _ in
                PS2DiagnosticLog.checkpoint("notification.ARMSX2iOSReturnToMenu")
                self?.closeAfterVMStops()
            }
        ]
        PS2DiagnosticLog.checkpoint("gameVC.viewDidLoad.observers-installed")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // ARMSX2 reads connected controllers directly. Do not let the XMB focus
        // engine consume those same D-pad events while a PS2 VM is active.
        FocusSystem.shared.isEnabled = false

        PS2DiagnosticLog.checkpoint("gameVC.viewDidAppear.enter")
        guard !hasBooted,
              let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameID),
              !game.isInvalidated,
              game.isRomExtsts else { return }

        PS2DiagnosticLog.checkpoint("gameVC.before-showGameWindow")
        ARMSX2EmbeddedRuntime.showGameWindow()
        PS2DiagnosticLog.checkpoint("gameVC.after-showGameWindow")

        hasBooted = true
        PS2DiagnosticLog.checkpoint("gameVC.before-bootISO")
        let bootAccepted = ARMSX2EmbeddedRuntime.bootISO(atPath: game.romUrl.path)
        PS2DiagnosticLog.log("bootISO_return=\(bootAccepted)")
        PS2DiagnosticLog.checkpoint("gameVC.after-bootISO")
        if !bootAccepted {
            hasBooted = false
            UIView.makeToast(message: "ARMSX2 could not start this PS2 game")
            closeAfterVMStops()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        PS2DiagnosticLog.log("gameVC.viewWillDisappear isBeingDismissed=\(isBeingDismissed) navDismissed=\(navigationController?.isBeingDismissed == true)")
        FocusSystem.shared.isEnabled = true
        ExternalInputDispatch.sink = .focusKit
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            ARMSX2EmbeddedRuntime.stop()
            ARMSX2EmbeddedRuntime.hideGameWindow()
            ApplicationSceneDelegate.applicationWindow?.makeKeyAndVisible()
        }
    }

    private func closeAfterVMStops() {
        guard !isClosing else { return }
        isClosing = true
        PS2DiagnosticLog.checkpoint("gameVC.closeAfterVMStops")
        FocusSystem.shared.isEnabled = true
        ExternalInputDispatch.sink = .focusKit
        ARMSX2EmbeddedRuntime.hideGameWindow()
        ApplicationSceneDelegate.applicationWindow?.makeKeyAndVisible()
        if presentingViewController != nil {
            dismiss(animated: true) {
                PS2DiagnosticLog.end(clean: true, reason: "VM stopped / returned to menu")
            }
        } else {
            PS2DiagnosticLog.end(clean: true, reason: "VM stopped without presenter")
        }
    }

    deinit {
        PS2DiagnosticLog.log("gameVC.deinit")
        vmObservers.forEach(NotificationCenter.default.removeObserver)
        ARMSX2EmbeddedRuntime.stop()
        ARMSX2EmbeddedRuntime.hideGameWindow()
    }
}
#endif
