//
//  EmulatorInteractionKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/12/16.
//  Copyright © 2025 Manic EMU. All rights reserved.
//


import IceCream
import GameController

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
#if canImport(ARMSX2Core)
    // Keep the UIKit host alive for the entire native PS2 session. ARMSX2 renders
    // through its own UIWindow, so relying only on the presenting hierarchy can
    // allow the Manic host controller to disappear during window/lifecycle churn.
    private static var activeGameController: ARMSX2EmbeddedGameViewController?
#endif

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

    /// Opens the original PS2 BIOS Browser with no disc inserted. This is the
    /// authentic Memory Card / System Configuration screen from the console.
    @discardableResult
    static func openMemoryCardBrowser() -> Bool {
#if canImport(ARMSX2Core)
        guard prepare() else {
            UIView.makeToast(message: "Could not initialize the embedded ARMSX2 core")
            return false
        }
        guard ARMSX2Bridge.hasBIOS() else {
            UIView.makeToast(message: "A PS2 BIOS is required to open the PS2 Browser")
            return false
        }

        guard activeGameController == nil else {
            UIView.makeToast(message: "A PS2 session is already running")
            return true
        }

        guard let presenter = topViewController(appController: true) else {
            UIView.makeToast(message: "Could not open the PS2 Browser")
            return false
        }

        _ = configureCPUForCurrentJIT()
        let controller = ARMSX2EmbeddedGameViewController(memoryCardBrowser: true)
        controller.modalPresentationStyle = .fullScreen
        controller.onClosed = {
            ARMSX2EmbeddedCore.activeGameController = nil
        }
        activeGameController = controller
        presenter.present(controller, animated: true)
        return true
#else
        UIView.makeToast(message: "PS2 support is not available in this build")
        return false
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

    @discardableResult
    private static func configureCPUForCurrentJIT() -> Bool {
        // If iOS already granted executable memory, always use ARMSX2's ARM64
        // recompilers. The old per-game JIT flag could leave EE/IOP/VU/Fastmem
        // disabled even though JIT was active, producing the startup warnings.
        let useJIT = ARMSX2Bridge.isJITAvailable()
        PS2DiagnosticLog.log("configureCPU useJIT=\(useJIT)")
        PS2DiagnosticLog.checkpoint("cpu-settings.begin")

        ARMSX2Bridge.setINIInt("EmuCore/CPU", key: "CoreType", value: Int32(useJIT ? 2 : 1))
        ARMSX2Bridge.setINIBool("EmuCore/CPU", key: "UseArm64Dynarec", value: useJIT)
        ARMSX2Bridge.setINIBool("EmuCore/CPU/Recompiler", key: "EnableEE", value: useJIT)
        ARMSX2Bridge.setINIBool("EmuCore/CPU/Recompiler", key: "EnableIOP", value: useJIT)
        ARMSX2Bridge.setINIBool("EmuCore/CPU/Recompiler", key: "EnableVU0", value: useJIT)
        ARMSX2Bridge.setINIBool("EmuCore/CPU/Recompiler", key: "EnableVU1", value: useJIT)

        // Use ARMSX2's normal Fastmem path whenever JIT is available. Device testing
        // indicates the intermittent launch failure correlates more strongly with low
        // available memory / background-app pressure than with Fastmem itself.
        let useFastmem = useJIT
        ARMSX2Bridge.setINIBool("EmuCore/CPU/Recompiler", key: "EnableFastmem", value: useFastmem)
        ARMSX2Bridge.setINIBool("ARMSX2iOS/Speedhacks", key: "ManualFastmem", value: useFastmem)
        PS2DiagnosticLog.log("configureCPU fastmem=\(useFastmem) restored=true")
        if !useJIT {
            ARMSX2Bridge.setINIBool("EmuCore/Speedhacks", key: "vuThread", value: false)
        }
        ARMSX2Bridge.flushINISettings()
        PS2DiagnosticLog.checkpoint("cpu-settings.end")
        return useJIT
    }

    private static func launchPreparedGame(gameID: String) {
        PS2DiagnosticLog.checkpoint("launchPreparedGame.enter")
        guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameID),
              !game.isInvalidated,
              !game.isDeleted,
              game.gameType == .ps2,
              game.isRomExtsts else { return }

        guard activeGameController == nil else {
            PS2DiagnosticLog.log("launchPreparedGame ignored because another PS2 host controller is active")
            return
        }

        guard let presenter = topViewController(appController: true) else {
            PS2DiagnosticLog.end(clean: true, reason: "No presenter for PS2 host controller")
            UIView.makeToast(message: "Could not open the PS2 game screen")
            return
        }

        let useJIT = configureCPUForCurrentJIT()
        PS2DiagnosticLog.log("launchPreparedGame useJIT=\(useJIT)")

        let controller = ARMSX2EmbeddedGameViewController(game: game)
        controller.modalPresentationStyle = .fullScreen
        controller.onClosed = {
            ARMSX2EmbeddedCore.activeGameController = nil
        }
        activeGameController = controller
        PS2DiagnosticLog.checkpoint("launchPreparedGame.before-present-controller")
        presenter.present(controller, animated: true) {
            PS2DiagnosticLog.checkpoint("launchPreparedGame.controller-presented")
        }
    }
#endif
}

#if canImport(ARMSX2Core)
/// Minimal native host for the ARMSX2 render surface. XMB remains the frontend;
/// ARMSX2's standalone SwiftUI library/menu is not presented.
private final class ARMSX2EmbeddedGameViewController: UIViewController {
    var onClosed: (() -> Void)?

    private enum BootMode {
        case game(String)
        case memoryCardBrowser
    }

    private let bootMode: BootMode
    private var hasBooted = false
    private var isClosing = false
    private var vmObservers: [NSObjectProtocol] = []
    private var touchControlsView: ARMSX2TouchControlsView?
    private weak var gameplayHostView: UIView?
    private var gameplayTapRecognizer: UITapGestureRecognizer?
    private var externalControllerConnected = false
    private var diagnosticHeartbeatTimer: Timer?
    private var diagnosticHeartbeatSequence = 0

    init(game: Game) {
        self.bootMode = .game(game.id)
        super.init(nibName: nil, bundle: nil)
        modalPresentationCapturesStatusBarAppearance = true
    }

    init(memoryCardBrowser: Bool) {
        self.bootMode = .memoryCardBrowser
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
            let closed = onClosed
            onClosed = nil
            dismiss(animated: true) {
                closed?()
            }
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
            },
            center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
                self?.refreshExternalControllerState()
            },
            center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
                self?.refreshExternalControllerState()
            },
            center.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { _ in
                PS2DiagnosticLog.checkpoint("app.didReceiveMemoryWarning")
            },
            center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
                PS2DiagnosticLog.checkpoint("app.willResignActive")
            },
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
                PS2DiagnosticLog.checkpoint("app.didEnterBackground")
            },
            center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
                PS2DiagnosticLog.checkpoint("app.willEnterForeground")
            },
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                PS2DiagnosticLog.checkpoint("app.didBecomeActive")
            },
            center.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { _ in
                PS2DiagnosticLog.checkpoint("app.willTerminate")
            }
        ]
        refreshExternalControllerState()
        PS2DiagnosticLog.checkpoint("gameVC.viewDidLoad.observers-installed")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // ARMSX2 reads connected controllers directly. Do not let the XMB focus
        // engine consume those same D-pad events while a PS2 VM is active.
        FocusSystem.shared.isEnabled = false

        PS2DiagnosticLog.checkpoint("gameVC.viewDidAppear.enter")
        guard !hasBooted else {
            installTouchControlsIfNeeded()
            startDiagnosticHeartbeatIfNeeded()
            return
        }

        PS2DiagnosticLog.checkpoint("gameVC.before-showGameWindow")
        ARMSX2EmbeddedRuntime.showGameWindow()
        PS2DiagnosticLog.checkpoint("gameVC.after-showGameWindow")
        installTouchControlsIfNeeded()
        startDiagnosticHeartbeatIfNeeded()

        hasBooted = true
        let bootAccepted: Bool
        switch bootMode {
        case .game(let gameID):
            guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameID),
                  !game.isInvalidated,
                  game.isRomExtsts else {
                hasBooted = false
                UIView.makeToast(message: "The PS2 game file is no longer available")
                closeAfterVMStops()
                return
            }
            PS2DiagnosticLog.checkpoint("gameVC.before-bootISO")
            bootAccepted = ARMSX2EmbeddedRuntime.bootISO(atPath: game.romUrl.path)
            PS2DiagnosticLog.log("bootISO_return=\(bootAccepted)")
            PS2DiagnosticLog.checkpoint("gameVC.after-bootISO")

        case .memoryCardBrowser:
            PS2DiagnosticLog.checkpoint("gameVC.before-bootBIOSBrowser")
            bootAccepted = ARMSX2EmbeddedRuntime.bootBIOSBrowser()
            PS2DiagnosticLog.log("bootBIOSBrowser_return=\(bootAccepted)")
            PS2DiagnosticLog.checkpoint("gameVC.after-bootBIOSBrowser")
        }

        if !bootAccepted {
            hasBooted = false
            UIView.makeToast(message: "ARMSX2 could not start the PS2")
            closeAfterVMStops()
        }
    }

    private func installTouchControlsIfNeeded() {
        let renderView = ARMSX2Bridge.gameRenderView()
        guard let hostView = renderView.window?.rootViewController?.view ?? renderView.superview else { return }
        gameplayHostView = hostView

        if gameplayTapRecognizer == nil {
            let tap = UITapGestureRecognizer(target: self, action: #selector(gameplaySurfaceTapped(_:)))
            tap.cancelsTouchesInView = false
            hostView.addGestureRecognizer(tap)
            gameplayTapRecognizer = tap
        }

        if let touchControlsView, touchControlsView.superview === hostView {
            touchControlsView.setExternalControllerConnected(externalControllerConnected)
            hostView.bringSubviewToFront(touchControlsView)
            return
        }

        touchControlsView?.releaseAllInputs()
        touchControlsView?.removeFromSuperview()

        let controls = ARMSX2TouchControlsView()
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.onMenu = { [weak self] in
            self?.presentARMSX2QuickMenu()
        }
        hostView.addSubview(controls)
        NSLayoutConstraint.activate([
            controls.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            controls.topAnchor.constraint(equalTo: hostView.topAnchor),
            controls.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
        ])
        controls.setExternalControllerConnected(externalControllerConnected)
        hostView.bringSubviewToFront(controls)
        touchControlsView = controls
    }

    private func startDiagnosticHeartbeatIfNeeded() {
        guard diagnosticHeartbeatTimer == nil, !isClosing else { return }
        diagnosticHeartbeatSequence = 0
        recordDiagnosticHeartbeat()

        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.recordDiagnosticHeartbeat()
        }
        diagnosticHeartbeatTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopDiagnosticHeartbeat() {
        diagnosticHeartbeatTimer?.invalidate()
        diagnosticHeartbeatTimer = nil
    }

    private func recordDiagnosticHeartbeat() {
        guard !isClosing else { return }
        diagnosticHeartbeatSequence += 1

        let state: String
        switch UIApplication.shared.applicationState {
        case .active:
            state = "active"
        case .inactive:
            state = "inactive"
        case .background:
            state = "background"
        @unknown default:
            state = "unknown"
        }

        let renderView = ARMSX2Bridge.gameRenderView()
        let window = renderView.window
        let size = renderView.bounds.size
        PS2DiagnosticLog.checkpoint(
            "gameVC.heartbeat seq=\(diagnosticHeartbeatSequence) app=\(state) " +
            "window_present=\(window != nil) window_hidden=\(window?.isHidden ?? true) " +
            "render=\(Int(size.width))x\(Int(size.height))"
        )
    }

    private func refreshExternalControllerState() {
        let connected = !GCController.controllers().isEmpty
        guard externalControllerConnected != connected || touchControlsView != nil else {
            externalControllerConnected = connected
            return
        }

        externalControllerConnected = connected
        touchControlsView?.setExternalControllerConnected(connected)
        PS2DiagnosticLog.log("gameVC external_controller_connected=\(connected)")
    }

    @objc private func gameplaySurfaceTapped(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, externalControllerConnected else { return }
        touchControlsView?.revealMenuButtonBriefly()
    }

    private func presentARMSX2QuickMenu() {
        guard !isClosing else { return }
        let renderView = ARMSX2Bridge.gameRenderView()
        guard let hostRoot = renderView.window?.rootViewController,
              hostRoot.presentedViewController == nil else { return }

        let menu = ARMSX2EmbeddedQuickMenuViewController()
        menu.onExitGame = { [weak self] in
            self?.requestExitFromTouchControls()
        }
        menu.onVirtualPadVisibilityChanged = { [weak self] visible in
            self?.touchControlsView?.setUserVirtualPadVisible(visible)
        }
        menu.modalPresentationStyle = .overFullScreen
        hostRoot.present(menu, animated: true)
    }

    private func requestExitFromTouchControls() {
        guard !isClosing else { return }
        PS2DiagnosticLog.checkpoint("gameVC.touch-exit-requested")
        ARMSX2EmbeddedRuntime.stop()

        // Normally ARMSX2 posts VMDidShutdown/ReturnToMenu. Keep a short fallback
        // so the player can always return to XMB even if a title hangs while stopping.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.closeAfterVMStops()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        PS2DiagnosticLog.log("gameVC.viewWillDisappear isBeingDismissed=\(isBeingDismissed) navDismissed=\(navigationController?.isBeingDismissed == true)")
        FocusSystem.shared.isEnabled = true
        ExternalInputDispatch.sink = .focusKit
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            stopDiagnosticHeartbeat()
            ARMSX2EmbeddedRuntime.stop()
            ARMSX2EmbeddedRuntime.hideGameWindow()
            ApplicationSceneDelegate.applicationWindow?.makeKeyAndVisible()
        }
    }

    private func closeAfterVMStops() {
        guard !isClosing else { return }
        isClosing = true
        stopDiagnosticHeartbeat()
        PS2DiagnosticLog.checkpoint("gameVC.closeAfterVMStops")
        FocusSystem.shared.isEnabled = true
        ExternalInputDispatch.sink = .focusKit
        touchControlsView?.releaseAllInputs()
        touchControlsView?.removeFromSuperview()
        touchControlsView = nil
        if let gameplayTapRecognizer, let gameplayHostView {
            gameplayHostView.removeGestureRecognizer(gameplayTapRecognizer)
        }
        gameplayTapRecognizer = nil
        gameplayHostView = nil
        ARMSX2EmbeddedRuntime.hideGameWindow()
        ApplicationSceneDelegate.applicationWindow?.makeKeyAndVisible()
        let closed = onClosed
        onClosed = nil
        if presentingViewController != nil {
            dismiss(animated: true) {
                closed?()
                PS2DiagnosticLog.end(clean: true, reason: "VM stopped / returned to menu")
            }
        } else {
            closed?()
            PS2DiagnosticLog.end(clean: true, reason: "VM stopped without presenter")
        }
    }

    deinit {
        stopDiagnosticHeartbeat()
        PS2DiagnosticLog.log("gameVC.deinit")
        touchControlsView?.releaseAllInputs()
        touchControlsView?.removeFromSuperview()
        if let gameplayTapRecognizer, let gameplayHostView {
            gameplayHostView.removeGestureRecognizer(gameplayTapRecognizer)
        }
        vmObservers.forEach(NotificationCenter.default.removeObserver)
        ARMSX2EmbeddedRuntime.stop()
        ARMSX2EmbeddedRuntime.hideGameWindow()
    }
}

// MARK: - Embedded PS2 touch controller

private final class ARMSX2TouchControlsView: UIView {
    var onMenu: (() -> Void)?

    private var padButtons: [ARMSX2TouchPadButton] = []
    private var gameplayControls: [UIView] = []
    private let leftStick = ARMSX2VirtualStickView(left: true)
    private let rightStick = ARMSX2VirtualStickView(left: false)
    private let menuButton = UIButton(type: .system)
    private var externalControllerConnected = false
    private var userVirtualPadVisible = true
    private var menuHideWorkItem: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Gameplay remains touch-transparent except for visible controls/menu.
        for child in subviews where !child.isHidden && child.alpha > 0.01 {
            let converted = convert(point, to: child)
            if child.point(inside: converted, with: event) {
                return true
            }
        }
        return false
    }

    func setExternalControllerConnected(_ connected: Bool) {
        externalControllerConnected = connected
        updateVirtualPadVisibility(animated: true)

        // Match native ARMSX2: with a physical controller the virtual pad goes away
        // and the pause button is hidden until the game surface is tapped.
        if connected {
            menuHideWorkItem?.cancel()
            menuButton.isHidden = true
            menuButton.alpha = 0
        } else {
            menuHideWorkItem?.cancel()
            menuButton.isHidden = false
            menuButton.alpha = 1
        }
    }

    func setUserVirtualPadVisible(_ visible: Bool) {
        userVirtualPadVisible = visible
        updateVirtualPadVisibility(animated: true)
    }

    func revealMenuButtonBriefly() {
        guard externalControllerConnected else {
            menuButton.isHidden = false
            menuButton.alpha = 1
            return
        }

        menuHideWorkItem?.cancel()
        menuButton.isHidden = false
        UIView.animate(withDuration: 0.12,
                       delay: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.menuButton.alpha = 1
        }

        let item = DispatchWorkItem { [weak self] in
            guard let self, self.externalControllerConnected else { return }
            UIView.animate(withDuration: 0.18,
                           delay: 0,
                           options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.menuButton.alpha = 0
            } completion: { _ in
                if self.externalControllerConnected {
                    self.menuButton.isHidden = true
                }
            }
        }
        menuHideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: item)
    }

    func releaseAllInputs() {
        padButtons.forEach { $0.releaseInput() }
        leftStick.reset()
        rightStick.reset()
    }

    private func updateVirtualPadVisibility(animated: Bool) {
        let visible = userVirtualPadVisible && !externalControllerConnected
        if !visible {
            releaseAllInputs()
        }

        let changes = {
            self.gameplayControls.forEach {
                $0.alpha = visible ? 1 : 0
                $0.isHidden = !visible
            }
        }

        if animated && visible {
            gameplayControls.forEach {
                $0.isHidden = false
                $0.alpha = 0
            }
            UIView.animate(withDuration: 0.16,
                           delay: 0,
                           options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction],
                           animations: changes)
        } else {
            changes()
        }
    }

    private func registerGameplayControl(_ view: UIView) {
        gameplayControls.append(view)
        addSubview(view)
    }

    private func setupControls() {
        let dpad = UIView()
        dpad.translatesAutoresizingMaskIntoConstraints = false
        dpad.backgroundColor = .clear
        registerGameplayControl(dpad)

        let up = makePadButton("▲", .up, style: .dpad)
        let down = makePadButton("▼", .down, style: .dpad)
        let left = makePadButton("◀", .left, style: .dpad)
        let right = makePadButton("▶", .right, style: .dpad)
        [up, down, left, right].forEach(dpad.addSubview)

        let face = UIView()
        face.translatesAutoresizingMaskIntoConstraints = false
        face.backgroundColor = .clear
        registerGameplayControl(face)

        let triangle = makePadButton("△", .triangle, style: .face(.systemGreen))
        let cross = makePadButton("✕", .cross, style: .face(.systemBlue))
        let square = makePadButton("□", .square, style: .face(.systemPink))
        let circle = makePadButton("○", .circle, style: .face(.systemRed))
        [triangle, cross, square, circle].forEach(face.addSubview)

        let l2 = makePadButton("L2", .L2, style: .shoulder)
        let l1 = makePadButton("L1", .L1, style: .shoulder)
        let r1 = makePadButton("R1", .R1, style: .shoulder)
        let r2 = makePadButton("R2", .R2, style: .shoulder)
        [l2, l1, r1, r2].forEach(registerGameplayControl)

        let select = makePadButton("SEL", .select, style: .system)
        let start = makePadButton("START", .start, style: .system)
        [select, start].forEach(registerGameplayControl)

        leftStick.translatesAutoresizingMaskIntoConstraints = false
        rightStick.translatesAutoresizingMaskIntoConstraints = false
        registerGameplayControl(leftStick)
        registerGameplayControl(rightStick)

        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
        menuButton.tintColor = .white
        menuButton.backgroundColor = UIColor.black.withAlphaComponent(0.40)
        menuButton.layer.cornerRadius = 22
        menuButton.accessibilityLabel = "Pause Menu"
        menuButton.addTarget(self, action: #selector(menuPressed), for: .touchUpInside)
        addSubview(menuButton)

        let guide = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            dpad.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 18),
            dpad.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -12),
            dpad.widthAnchor.constraint(equalToConstant: 132),
            dpad.heightAnchor.constraint(equalToConstant: 132),

            up.widthAnchor.constraint(equalToConstant: 48), up.heightAnchor.constraint(equalToConstant: 48),
            up.centerXAnchor.constraint(equalTo: dpad.centerXAnchor), up.topAnchor.constraint(equalTo: dpad.topAnchor),
            down.widthAnchor.constraint(equalTo: up.widthAnchor), down.heightAnchor.constraint(equalTo: up.heightAnchor),
            down.centerXAnchor.constraint(equalTo: dpad.centerXAnchor), down.bottomAnchor.constraint(equalTo: dpad.bottomAnchor),
            left.widthAnchor.constraint(equalTo: up.widthAnchor), left.heightAnchor.constraint(equalTo: up.heightAnchor),
            left.leadingAnchor.constraint(equalTo: dpad.leadingAnchor), left.centerYAnchor.constraint(equalTo: dpad.centerYAnchor),
            right.widthAnchor.constraint(equalTo: up.widthAnchor), right.heightAnchor.constraint(equalTo: up.heightAnchor),
            right.trailingAnchor.constraint(equalTo: dpad.trailingAnchor), right.centerYAnchor.constraint(equalTo: dpad.centerYAnchor),

            face.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -18),
            face.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -12),
            face.widthAnchor.constraint(equalToConstant: 132),
            face.heightAnchor.constraint(equalToConstant: 132),

            triangle.widthAnchor.constraint(equalToConstant: 50), triangle.heightAnchor.constraint(equalToConstant: 50),
            triangle.centerXAnchor.constraint(equalTo: face.centerXAnchor), triangle.topAnchor.constraint(equalTo: face.topAnchor),
            cross.widthAnchor.constraint(equalTo: triangle.widthAnchor), cross.heightAnchor.constraint(equalTo: triangle.heightAnchor),
            cross.centerXAnchor.constraint(equalTo: face.centerXAnchor), cross.bottomAnchor.constraint(equalTo: face.bottomAnchor),
            square.widthAnchor.constraint(equalTo: triangle.widthAnchor), square.heightAnchor.constraint(equalTo: triangle.heightAnchor),
            square.leadingAnchor.constraint(equalTo: face.leadingAnchor), square.centerYAnchor.constraint(equalTo: face.centerYAnchor),
            circle.widthAnchor.constraint(equalTo: triangle.widthAnchor), circle.heightAnchor.constraint(equalTo: triangle.heightAnchor),
            circle.trailingAnchor.constraint(equalTo: face.trailingAnchor), circle.centerYAnchor.constraint(equalTo: face.centerYAnchor),

            leftStick.leadingAnchor.constraint(equalTo: dpad.trailingAnchor, constant: 10),
            leftStick.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -20),
            leftStick.widthAnchor.constraint(equalToConstant: 88),
            leftStick.heightAnchor.constraint(equalToConstant: 88),

            rightStick.trailingAnchor.constraint(equalTo: face.leadingAnchor, constant: -10),
            rightStick.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -20),
            rightStick.widthAnchor.constraint(equalToConstant: 88),
            rightStick.heightAnchor.constraint(equalToConstant: 88),

            l2.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 18),
            l2.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            l2.widthAnchor.constraint(equalToConstant: 66), l2.heightAnchor.constraint(equalToConstant: 38),
            l1.leadingAnchor.constraint(equalTo: l2.trailingAnchor, constant: 8),
            l1.centerYAnchor.constraint(equalTo: l2.centerYAnchor),
            l1.widthAnchor.constraint(equalTo: l2.widthAnchor), l1.heightAnchor.constraint(equalTo: l2.heightAnchor),

            r2.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -18),
            r2.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            r2.widthAnchor.constraint(equalToConstant: 66), r2.heightAnchor.constraint(equalToConstant: 38),
            r1.trailingAnchor.constraint(equalTo: r2.leadingAnchor, constant: -8),
            r1.centerYAnchor.constraint(equalTo: r2.centerYAnchor),
            r1.widthAnchor.constraint(equalTo: r2.widthAnchor), r1.heightAnchor.constraint(equalTo: r2.heightAnchor),

            select.trailingAnchor.constraint(equalTo: centerXAnchor, constant: -8),
            select.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -10),
            select.widthAnchor.constraint(equalToConstant: 54), select.heightAnchor.constraint(equalToConstant: 28),
            start.leadingAnchor.constraint(equalTo: centerXAnchor, constant: 8),
            start.bottomAnchor.constraint(equalTo: select.bottomAnchor),
            start.widthAnchor.constraint(equalToConstant: 62), start.heightAnchor.constraint(equalTo: select.heightAnchor),

            // Keep the pause/quick-menu control clear of the R1/R2 shoulder cluster.
            // Centering it in the top safe area also stays symmetrical with the
            // native-style virtual pad and works across compact landscape widths.
            menuButton.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            menuButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            menuButton.widthAnchor.constraint(equalToConstant: 44),
            menuButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func makePadButton(_ title: String,
                               _ button: ARMSX2PadButton,
                               style: ARMSX2TouchPadButton.Style) -> ARMSX2TouchPadButton {
        let control = ARMSX2TouchPadButton(title: title, padButton: button, style: style)
        control.translatesAutoresizingMaskIntoConstraints = false
        padButtons.append(control)
        return control
    }

    @objc private func menuPressed() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.prepare()
        feedback.impactOccurred(intensity: 0.72)
        onMenu?()
    }
}

private final class ARMSX2TouchPadButton: UIButton {
    enum Style {
        case dpad
        case face(UIColor)
        case shoulder
        case system
    }

    private let padButton: ARMSX2PadButton
    private let style: Style
    private var pressed = false
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    init(title: String, padButton: ARMSX2PadButton, style: Style) {
        self.padButton = padButton
        self.style = style
        super.init(frame: .zero)

        setTitle(title, for: .normal)
        titleLabel?.font = .systemFont(
            ofSize: {
                switch style {
                case .face: return 23
                case .dpad: return 16
                case .shoulder: return 11
                case .system: return 9.5
                }
            }(),
            weight: .semibold
        )

        switch style {
        case .face(let color):
            setTitleColor(color, for: .normal)
            backgroundColor = UIColor.black.withAlphaComponent(0.16)
            layer.borderColor = color.withAlphaComponent(0.60).cgColor
            layer.cornerRadius = 25
        case .dpad:
            setTitleColor(.white, for: .normal)
            backgroundColor = UIColor.black.withAlphaComponent(0.30)
            layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor
            layer.cornerRadius = 13
        case .shoulder:
            setTitleColor(.white, for: .normal)
            backgroundColor = UIColor.black.withAlphaComponent(0.32)
            layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
            layer.cornerRadius = 12
        case .system:
            setTitleColor(UIColor.white.withAlphaComponent(0.92), for: .normal)
            backgroundColor = UIColor.black.withAlphaComponent(0.28)
            layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
            layer.cornerRadius = 10
        }

        layer.borderWidth = 1
        alpha = 0.82
        haptic.prepare()

        addTarget(self, action: #selector(pressInput), for: .touchDown)
        addTarget(self, action: #selector(releaseInputAction), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func pressInput() {
        guard !pressed else { return }
        pressed = true
        haptic.impactOccurred(intensity: hapticIntensity)
        haptic.prepare()
        ARMSX2Bridge.setPadButton(padButton, pressed: true)
        UIView.animate(withDuration: 0.06,
                       delay: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.alpha = 1
            self.transform = CGAffineTransform(scaleX: 0.91, y: 0.91)
            switch self.style {
            case .face(let color):
                self.backgroundColor = color.withAlphaComponent(0.24)
            default:
                self.backgroundColor = UIColor.white.withAlphaComponent(0.24)
            }
        }
    }

    private var hapticIntensity: CGFloat {
        switch style {
        case .face: return 0.72
        case .dpad: return 0.58
        case .shoulder: return 0.82
        case .system: return 0.48
        }
    }

    @objc private func releaseInputAction() {
        releaseInput()
    }

    func releaseInput() {
        if pressed {
            ARMSX2Bridge.setPadButton(padButton, pressed: false)
            pressed = false
        }

        UIView.animate(withDuration: 0.08,
                       delay: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.alpha = 0.82
            self.transform = .identity
            switch self.style {
            case .face:
                self.backgroundColor = UIColor.black.withAlphaComponent(0.16)
            case .dpad:
                self.backgroundColor = UIColor.black.withAlphaComponent(0.30)
            case .shoulder:
                self.backgroundColor = UIColor.black.withAlphaComponent(0.32)
            case .system:
                self.backgroundColor = UIColor.black.withAlphaComponent(0.28)
            }
        }
    }
}

private final class ARMSX2VirtualStickView: UIView {
    private let isLeft: Bool
    private let knob = UIView()
    private let haptic = UISelectionFeedbackGenerator()

    init(left: Bool) {
        self.isLeft = left
        super.init(frame: .zero)

        backgroundColor = UIColor.black.withAlphaComponent(0.24)
        layer.cornerRadius = 43
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor

        knob.translatesAutoresizingMaskIntoConstraints = false
        knob.backgroundColor = UIColor.white.withAlphaComponent(0.30)
        knob.layer.cornerRadius = 18
        knob.layer.borderWidth = 1
        knob.layer.borderColor = UIColor.white.withAlphaComponent(0.30).cgColor
        addSubview(knob)
        NSLayoutConstraint.activate([
            knob.centerXAnchor.constraint(equalTo: centerXAnchor),
            knob.centerYAnchor.constraint(equalTo: centerYAnchor),
            knob.widthAnchor.constraint(equalToConstant: 36),
            knob.heightAnchor.constraint(equalToConstant: 36)
        ])

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
        haptic.prepare()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let location = recognizer.location(in: self)
        let radius = max(1, min(bounds.width, bounds.height) * 0.5 - 12)
        var x = (location.x - bounds.midX) / radius
        var y = (location.y - bounds.midY) / radius
        let magnitude = hypot(x, y)
        if magnitude > 1 {
            x /= magnitude
            y /= magnitude
        }

        switch recognizer.state {
        case .began, .changed:
            if recognizer.state == .began {
                haptic.selectionChanged()
                haptic.prepare()
            }
            let knobTravel = min(bounds.width, bounds.height) * 0.24
            knob.transform = CGAffineTransform(translationX: x * knobTravel, y: y * knobTravel)
            if isLeft {
                ARMSX2Bridge.setLeftStickX(Float(x), y: Float(y))
            } else {
                ARMSX2Bridge.setRightStickX(Float(x), y: Float(y))
            }
        default:
            reset()
        }
    }

    func reset() {
        if isLeft {
            ARMSX2Bridge.setLeftStickX(0, y: 0)
        } else {
            ARMSX2Bridge.setRightStickX(0, y: 0)
        }
        UIView.animate(withDuration: 0.10,
                       delay: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.knob.transform = .identity
        }
    }
}

// MARK: - ARMSX2-style embedded quick menu

private final class ARMSX2EmbeddedQuickMenuViewController: UIViewController {
    var onExitGame: (() -> Void)?
    var onVirtualPadVisibilityChanged: ((Bool) -> Void)?

    private static var osdPreset = 0
    private static var virtualPadVisible = true
    private static var fullScreenEnabled = false

    private let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let stack = UIStackView()
    private var resumed = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.42)

        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(backdropTapped(_:)))
        dismissTap.cancelsTouchesInView = false
        view.addGestureRecognizer(dismissTap)

        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 22
        card.clipsToBounds = true
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        view.addSubview(card)

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false
        card.contentView.addSubview(scroll)

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 640),
            card.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.82),

            // UIScrollView content does not give its container an intrinsic height.
            // Give the quick-menu card a real frame instead of only a max-height;
            // otherwise Auto Layout can collapse it to 0pt while the VM still pauses.
            card.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.82),

            scroll.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: card.contentView.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -18),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -36)
        ])

        buildMenu()
        ARMSX2Bridge.setVMPaused(true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if (isBeingDismissed || navigationController?.isBeingDismissed == true), !resumed {
            ARMSX2Bridge.setVMPaused(false)
        }
    }

    private func buildMenu() {
        stack.addArrangedSubview(makeHeader())

        stack.addArrangedSubview(makeSectionTitle("Quick Actions"))
        stack.addArrangedSubview(makeRow(
            title: "OSD",
            subtitle: "Cycle ARMSX2 performance overlay",
            symbol: "speedometer"
        ) { [weak self] in self?.cycleOSD() })

        stack.addArrangedSubview(makeRow(
            title: "Virtual Pad",
            subtitle: Self.virtualPadVisible ? "On" : "Off",
            symbol: "gamecontroller"
        ) { [weak self] in self?.toggleVirtualPad() })

        stack.addArrangedSubview(makeRow(
            title: "Full Screen",
            subtitle: Self.fullScreenEnabled ? "On" : "Off",
            symbol: "arrow.up.left.and.arrow.down.right"
        ) { [weak self] in self?.toggleFullScreen() })

        stack.addArrangedSubview(makeRow(
            title: "Speed / Fast Forward",
            subtitle: "100% to 500%",
            symbol: "forward.fill"
        ) { [weak self] in self?.showSpeedMenu() })

        stack.addArrangedSubview(makeSectionTitle("This Game"))
        stack.addArrangedSubview(makeRow(
            title: "ARMSX2 Game Settings",
            subtitle: "View the current settings ARMSX2 is using",
            symbol: "slider.horizontal.3"
        ) { [weak self] in self?.showCurrentGameSettings() })

        stack.addArrangedSubview(makeRow(
            title: "Save / Load States",
            subtitle: "Manage PCSX2 state slots",
            symbol: "square.stack.3d.up.fill"
        ) { [weak self] in self?.showSaveStateSlots() })

        stack.addArrangedSubview(makeRow(
            title: "Change Disc",
            subtitle: "Insert another PS2 image without leaving the game",
            symbol: "opticaldisc"
        ) { [weak self] in self?.showDiscPicker() })

        stack.addArrangedSubview(makeRow(
            title: "Eject Disc",
            subtitle: ARMSX2Bridge.discInDriveName() ?? "No disc",
            symbol: "eject.fill"
        ) { [weak self] in self?.ejectDisc() })

        stack.addArrangedSubview(makeSectionTitle("Reset & Exit"))

        let exit = makeRow(
            title: "Stop Game",
            subtitle: "Exit back to the Manic XMB",
            symbol: "stop.fill",
            destructive: true
        ) { [weak self] in self?.confirmExit() }
        stack.addArrangedSubview(exit)

        let resume = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "Resume"
        config.image = UIImage(systemName: "play.fill")
        config.imagePadding = 8
        config.baseForegroundColor = .white
        config.background.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.92)
        config.cornerStyle = .capsule
        resume.configuration = config
        resume.heightAnchor.constraint(equalToConstant: 48).isActive = true
        resume.addTarget(self, action: #selector(resumePressed), for: .touchUpInside)
        stack.addArrangedSubview(resume)
    }

    private func makeHeader() -> UIView {
        let container = UIView()
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Paused"
        title.textColor = .white
        title.font = .systemFont(ofSize: 26, weight: .semibold)

        let subtitle = UILabel()
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.text = "ARMSX2 Quick Menu"
        subtitle.textColor = UIColor.white.withAlphaComponent(0.58)
        subtitle.font = .systemFont(ofSize: 12.5, weight: .medium)

        container.addSubview(title)
        container.addSubview(subtitle)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            title.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            subtitle.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        return container
    }

    private func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = UIColor.white.withAlphaComponent(0.62)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
        return label
    }

    private func makeRow(title: String,
                         subtitle: String,
                         symbol: String,
                         destructive: Bool = false,
                         action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = title
        config.subtitle = subtitle
        config.image = UIImage(systemName: symbol)
        config.imagePlacement = .leading
        config.imagePadding = 12
        config.titleAlignment = .leading
        config.baseForegroundColor = destructive ? UIColor.systemRed : .white
        config.background.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 13, bottom: 10, trailing: 13)

        let button = UIButton(configuration: config)
        button.contentHorizontalAlignment = .leading
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    @objc private func backdropTapped(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: view)
        if !card.frame.contains(point) {
            resumePressed()
        }
    }

    @objc private func resumePressed() {
        guard !resumed else { return }
        resumed = true
        ARMSX2Bridge.setVMPaused(false)
        dismiss(animated: true)
    }

    private func cycleOSD() {
        Self.osdPreset = (Self.osdPreset + 1) % 4
        ARMSX2Bridge.applyOsdPreset(Int32(Self.osdPreset))
        UIView.makeToast(message: "ARMSX2 OSD: \(["Off", "Simple", "Detail", "Full"][Self.osdPreset])")
    }

    private func toggleVirtualPad() {
        Self.virtualPadVisible.toggle()
        onVirtualPadVisibilityChanged?(Self.virtualPadVisible)
        rebuildMenu()
    }

    private func toggleFullScreen() {
        Self.fullScreenEnabled.toggle()
        ARMSX2Bridge.setFullScreen(Self.fullScreenEnabled)
        rebuildMenu()
    }

    private func rebuildMenu() {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        buildMenu()
    }

    private func showSpeedMenu() {
        let alert = UIAlertController(title: "Speed / Fast Forward", message: nil, preferredStyle: .actionSheet)
        for percent in [100, 150, 200, 300, 500] {
            alert.addAction(UIAlertAction(title: "\(percent)%", style: .default) { _ in
                if percent == 100 {
                    ARMSX2Bridge.setRuntimeFastForward(enabled: false, speedPercent: Int32(percent))
                    ARMSX2Bridge.setRuntimeEmulationSpeedPercent(Int32(percent))
                } else {
                    ARMSX2Bridge.setRuntimeFastForward(enabled: true, speedPercent: Int32(percent))
                }
                UIView.makeToast(message: "Emulation speed: \(percent)%")
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presentActionSheet(alert)
    }

    private func showCurrentGameSettings() {
        guard let settings = ARMSX2Bridge.gameSettingsForCurrentGame(), !settings.isEmpty else {
            UIView.makeToast(message: "ARMSX2 game settings are not ready yet")
            return
        }

        let text = settings.keys.sorted().map { key in
            let value = settings[key].map { String(describing: $0) } ?? "—"
            return "\(key): \(value)"
        }.joined(separator: "\n")

        let controller = ARMSX2SettingsSnapshotViewController(text: text)
        controller.modalPresentationStyle = .formSheet
        present(controller, animated: true)
    }

    private func showSaveStateSlots() {
        let slots = ARMSX2Bridge.saveStateSlots()
            .filter { $0.slot >= 0 }
            .sorted { $0.slot < $1.slot }

        guard !slots.isEmpty else {
            UIView.makeToast(message: "Save states are not ready yet")
            return
        }

        let alert = UIAlertController(title: "Save / Load States", message: "Choose a slot", preferredStyle: .actionSheet)
        for info in slots.prefix(10) {
            let state = info.occupied ? "Saved" : "Empty"
            alert.addAction(UIAlertAction(title: "Slot \(info.slot + 1) — \(state)", style: .default) { [weak self] _ in
                self?.showSaveStateActions(info)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presentActionSheet(alert)
    }

    private func showSaveStateActions(_ info: ARMSX2SaveStateSlotInfo) {
        let alert = UIAlertController(title: "Slot \(info.slot + 1)", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            ARMSX2Bridge.saveState(toSlot: info.slot) { saved, _ in
                DispatchQueue.main.async {
                    UIView.makeToast(message: saved ? "State saved" : "Could not save state")
                }
            }
        })

        if info.occupied {
            alert.addAction(UIAlertAction(title: "Load", style: .default) { _ in
                ARMSX2Bridge.loadState(
                    fromSlot: info.slot,
                    expectedModified: info.modifiedDate,
                    keepingUndo: false
                ) { loaded, _ in
                    DispatchQueue.main.async {
                        UIView.makeToast(message: loaded ? "State loaded" : "Could not load state")
                    }
                }
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presentActionSheet(alert)
    }

    private func showDiscPicker() {
        let games = Array(Database.realm.objects(Game.self))
            .filter { !$0.isDeleted && $0.effectiveGameType == .ps2 && $0.isRomExtsts }
            .map { game -> (name: String, path: String) in
                let display = game.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                return (display.isEmpty ? game.name : display, game.romUrl.path)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        guard !games.isEmpty else {
            UIView.makeToast(message: "No PS2 disc images are available")
            return
        }

        let alert = UIAlertController(title: "Change Disc", message: "Insert Disc (No Reboot)", preferredStyle: .actionSheet)
        for game in games {
            alert.addAction(UIAlertAction(title: game.name, style: .default) { _ in
                ARMSX2Bridge.changeDisc(toISO: game.path) { success in
                    DispatchQueue.main.async {
                        UIView.makeToast(message: success ? "\(game.name) inserted" : "Could not change discs")
                    }
                }
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presentActionSheet(alert)
    }

    private func ejectDisc() {
        ARMSX2Bridge.ejectDisc { success in
            DispatchQueue.main.async {
                UIView.makeToast(message: success ? "Disc ejected" : "Could not eject the disc")
            }
        }
    }

    private func confirmExit() {
        let alert = UIAlertController(
            title: "Stop Game?",
            message: "This stops the PS2 VM and returns to the Manic XMB.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Stop", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.resumed = true
            self.dismiss(animated: true) {
                self.onExitGame?()
            }
        })
        present(alert, animated: true)
    }

    private func presentActionSheet(_ alert: UIAlertController) {
        if let popover = alert.popoverPresentationController {
            popover.sourceView = card
            popover.sourceRect = CGRect(x: card.bounds.midX, y: card.bounds.midY, width: 1, height: 1)
        }
        present(alert, animated: true)
    }
}

private final class ARMSX2SettingsSnapshotViewController: UIViewController {
    private let text: String

    init(text: String) {
        self.text = text
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "ARMSX2 Game Settings"
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)

        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = text
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isEditable = false
        textView.backgroundColor = .clear

        let done = UIButton(type: .system)
        done.translatesAutoresizingMaskIntoConstraints = false
        done.setTitle("Done", for: .normal)
        done.addTarget(self, action: #selector(donePressed), for: .touchUpInside)

        view.addSubview(titleLabel)
        view.addSubview(textView)
        view.addSubview(done)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            done.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            done.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 14),
            textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -14),
            textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    @objc private func donePressed() {
        dismiss(animated: true)
    }
}

#endif
