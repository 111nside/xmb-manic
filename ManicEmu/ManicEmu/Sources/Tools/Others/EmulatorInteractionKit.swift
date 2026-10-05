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


// MARK: - Embedded ARMSX2 bridge

enum ARMSX2EmbeddedCore {
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

        guard prepare() else {
            UIView.makeToast(message: "Could not initialize the embedded ARMSX2 core")
            return true
        }

        guard ARMSX2Bridge.hasBIOS() else {
            UIView.makeToast(message: "A PS2 BIOS is required before starting this game")
            return true
        }

        guard ARMSX2Bridge.canResolveISO(game.romUrl.path) else {
            UIView.makeToast(message: "ARMSX2 could not read this PS2 game image")
            return true
        }

        // PS2 can boot through ARMSX2's interpreter without a JIT grant.
        // JIT is an opt-in per-game acceleration, not a hard launch requirement.
        if game.jit && !ARMSX2Bridge.isJITAvailable() {
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
        guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameID),
              !game.isInvalidated,
              !game.isDeleted,
              game.gameType == .ps2,
              game.isRomExtsts else { return }

        let useJIT = game.jit && ARMSX2Bridge.isJITAvailable()

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

        let controller = ARMSX2EmbeddedGameViewController(game: game)
        controller.modalPresentationStyle = .fullScreen
        topViewController(appController: true)?.present(controller, animated: true)
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
    private weak var renderView: UIView?
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

        guard ARMSX2EmbeddedRuntime.prepare() else {
            UIView.makeToast(message: "Could not initialize the embedded ARMSX2 core")
            dismiss(animated: true)
            return
        }

        let renderView = ARMSX2Bridge.gameRenderView()
        renderView.removeFromSuperview()
        renderView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(renderView)
        self.renderView = renderView

        NSLayoutConstraint.activate([
            renderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            renderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            renderView.topAnchor.constraint(equalTo: view.topAnchor),
            renderView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let center = NotificationCenter.default
        vmObservers = [
            center.addObserver(forName: Notification.Name("ARMSX2iOSVMDidShutdown"), object: nil, queue: .main) { [weak self] _ in
                self?.closeAfterVMStops()
            },
            center.addObserver(forName: Notification.Name("ARMSX2iOSReturnToMenu"), object: nil, queue: .main) { [weak self] _ in
                self?.closeAfterVMStops()
            }
        ]
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // ARMSX2 reads connected controllers directly. Do not let the XMB focus
        // engine consume those same D-pad events while a PS2 VM is active.
        FocusSystem.shared.isEnabled = false

        guard !hasBooted,
              let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameID),
              !game.isInvalidated,
              game.isRomExtsts else { return }

        renderView?.setNeedsLayout()
        renderView?.layoutIfNeeded()
        ARMSX2Bridge.prepareGameRenderViewForCurrentRenderer()

        hasBooted = true
        if !ARMSX2EmbeddedRuntime.bootISO(atPath: game.romUrl.path) {
            hasBooted = false
            UIView.makeToast(message: "ARMSX2 could not start this PS2 game")
            closeAfterVMStops()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        FocusSystem.shared.isEnabled = true
        ExternalInputDispatch.sink = .focusKit
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            ARMSX2EmbeddedRuntime.stop()
        }
    }

    private func closeAfterVMStops() {
        guard !isClosing else { return }
        isClosing = true
        FocusSystem.shared.isEnabled = true
        ExternalInputDispatch.sink = .focusKit
        if presentingViewController != nil {
            dismiss(animated: true)
        }
    }

    deinit {
        vmObservers.forEach(NotificationCenter.default.removeObserver)
        ARMSX2EmbeddedRuntime.stop()
    }
}
#endif
