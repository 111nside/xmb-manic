//
//  ApplicationSceneDelegate.swift
//  testScene
//
//  Created by Aoshuang Lee on 2024/12/26.
//

import UIKit
import GameController
import OAuthSwift
import UniformTypeIdentifiers

class ApplicationSceneDelegate: UIResponder, UIWindowSceneDelegate {
    static weak var applicationScene: UIWindowScene?
    static weak var applicationWindow: UIWindow?
    var window: UIWindow?
    static var launchGameID: String? = nil
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            ApplicationSceneDelegate.applicationScene = windowScene
            window = UIWindow(windowScene: windowScene)
            ApplicationSceneDelegate.applicationWindow = window
            window?.tintColor = R.Color.Main
            installGamepadEventInteraction(on: window)
            let bootController = XMBStartupViewController(preparingResources: Self.needsResourceExtract())
            window?.rootViewController = bootController
            window?.makeKeyAndVisible()

            let loadThenPresentHome = {
                ResourcesKit.loadResources { isSuccess in
                    Database.setup {
                        ThemeManager.shared.setup()

                        let homeController = XMBHomeViewController()
                        bootController.finish {
                            guard let window = self.window else { return }

                            UIView.transition(
                                with: window,
                                duration: 0.65,
                                options: [.transitionCrossDissolve, .curveEaseInOut, .allowAnimatedContent],
                                animations: {
                                    window.rootViewController = homeController
                                },
                                completion: nil
                            )

                            BackgroundMusicKit.shared.startMonitoring()
                            FocusSoundEffects.shared.startMonitoring()
                            if Settings.defalut.iCloudSyncEnable {
                                SyncManager.shared.startSync()
                            }

                            if !isSuccess {
                                UIView.makeAlert(title: R.string.localizable.fatalErrorTitle(), detail: R.string.localizable.fatalErrorDesc(), cancelTitle: R.string.localizable.confirmTitle())
                            }
                            if connectionOptions.urlContexts.count > 0 {
                                self.scene(scene, openURLContexts: connectionOptions.urlContexts)
                            }

                            CheevosBridge.setup(with: R.Config.AppVersion, requireCredentials: {
                                if let user = AchievementsUser.getUser() {
                                    let cheevosUser = CheevosUser()
                                    cheevosUser.userName = user.username
                                    cheevosUser.password = user.password
                                    cheevosUser.token = user.token
                                    return cheevosUser
                                }
                                return nil
                            }, updateCredentials: { cheevosUser in
                                if let u = cheevosUser?.userName,
                                   let p = cheevosUser?.password,
                                   let t = cheevosUser?.token {
                                    AchievementsUser.updateUser(username: u, password: p, token: t)
                                }
                            })

#if SIDE_LOAD
                            StikJITHostCoordinator.shared.enableOnLaunchIfNeeded()
#endif
                        }
                    }
                }
            }

            // Always show the custom startup sequence first. Resource extraction still begins on
            // the next main-loop turn, preserving ManicEMU's original first-launch behavior.
            DispatchQueue.main.async(execute: loadThenPresentHome)
            let dropInteraction = UIDropInteraction(delegate: self)
            window?.addInteraction(dropInteraction)
        }
    }
    
    /// Route gamepad HID through Game Controller instead of UIKit (iPad system focus hitch).
    /// iOS 18+; older versions fall back to swallowing gamepad UIPress in ManicApplication.
    private func installGamepadEventInteraction(on window: UIWindow?) {
        guard let window else { return }
        if #available(iOS 18.0, *) {
            let interaction = GCEventInteraction()
            interaction.handledEventTypes = .gamepad
            if #available(iOS 26.0, *) {
                interaction.receivesEventsInView = false
            }
            window.addInteraction(interaction)
        }
    }
    
    /// Mirrors ResourcesKit's unzip gate without performing any file work.
    private static func needsResourceExtract() -> Bool {
        if let systemCoreVersion = UserDefaults.standard.string(forKey: R.DefaultKey.SystemCoreVersion) {
            let appVersionNumber = UInt64(R.Config.AppVersion.replacingOccurrences(ofPattern: "\\.", withTemplate: ""))!
            let systemCoreVersionNumber = UInt64(systemCoreVersion.replacingOccurrences(ofPattern: "\\.", withTemplate: ""))!
            if systemCoreVersionNumber < appVersionNumber {
                return true
            }
            let systemCoreBuildVersion = UserDefaults.standard.integer(forKey: R.DefaultKey.SystemCoreBuildVersion)
            let appBuildVersion = Int(R.Config.AppBuildVersion)!
            if appBuildVersion > systemCoreBuildVersion {
                return true
            }
        } else {
            return true
        }
        return !FileManager.default.fileExists(atPath: R.Path.Resource)
            || !FileManager.default.fileExists(atPath: R.Path.ExtrasDB)
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        OrientationLockPin.handleSceneWillResignActive()
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        FilesSyncManager.shared.handleDidBecomeActive()
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for URLContext in URLContexts {
            let url = URLContext.url
            Log.debug("openURLContexts 回调URL:\(url)")
            if let scheme = url.scheme {
                if scheme == R.Strings.OAuthGoogleDriveCallbackHost ||
                    scheme == R.Strings.OAuthCallbackHost ||
                    scheme == R.Strings.OAuthOneDriveCallbackHost {
                    Log.debug("OAuth鉴权回调")
                    OAuthSwift.handle(url: url)
                } else if scheme == R.Strings.ManicScheme {
                    if let host = url.host, host == R.Strings.MeloNXScheme {
                        EmulatorInteractionKit.processGames(type: .meloNX, callbackUrl: url)
                    } else if let host = url.host, host == R.Strings.XeniOSScheme {
                        EmulatorInteractionKit.processGames(type: .xeniOS, callbackUrl: url)
                    } else if let host = url.host, host == R.Strings.DukeXScheme {
                        EmulatorInteractionKit.processGames(type: .dukeX, callbackUrl: url)
                    } else if let host = url.host, host == R.Strings.ARMSX2Scheme {
                        EmulatorInteractionKit.processGames(type: .armsx2, callbackUrl: url)
                    } else {
                        Self.launchGameID = url.lastPathComponent
                    }
                }
            }
        }
        
        if let launchGameID = Self.launchGameID, let window, let _ = window.rootViewController {
            //页面已经初始化好了，在这里处理, 如果没有初始化好，则交给GamesViewController处理
            Self.launchGameID = nil
            let realm = Database.realm
            if let game = realm.object(ofType: Game.self, forPrimaryKey: launchGameID) {
                game.handleTapAction(forceQuick: true)
            }
        }
        
        DispatchQueue.global().async {
            let allSupportExtentions = FileType.allSupportFileExtension()
            let fileUrls = URLContexts.map({ $0.url }).filter { $0.scheme == "file" && allSupportExtentions.contains([$0.pathExtension]) }
            if fileUrls.count > 0 {
                //先复制到本地 确保后续操作有足够权限
                var newFileUrls = [URL]()
                for fileUrl in fileUrls {
                    if #available(iOS 17.0, *) {
                        guard fileUrl.startAccessingSecurityScopedResource() else {
                            DispatchQueue.main.async {
                                UIView.makeToast(message: R.string.localizable.openFilePermissionsLimit(fileUrl.lastPathComponent))
                            }
                            continue
                        }
                    } else {
                        let _ = fileUrl.startAccessingSecurityScopedResource()
                    }
                    let newFileUrl = URL(fileURLWithPath: R.Path.Temp.appendingPathComponent(fileUrl.lastPathComponent))
                    do {
                        try FileManager.safeCopyItem(at: fileUrl, to: newFileUrl, shouldReplace: true)
                        newFileUrls.append(newFileUrl)
                    } catch {
                        DispatchQueue.main.async {
                            UIView.makeToast(message: R.string.localizable.openFilePermissionsLimit(fileUrl.lastPathComponent))
                        }
                    }
                }
                DispatchQueue.main.asyncAfter(delay: 1.5) {
                    if newFileUrls.count > 0 {
                        FilesImporter.importFiles(urls: newFileUrls)
                    }
                }
            }
        }
    }
}

extension ApplicationSceneDelegate: UIDropInteractionDelegate {
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: any UIDropSession) {
        window?.showDropView()
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: any UIDropSession) -> Bool {
        if let _ = session.localDragSession {
            return false
        }
        return true
    }
    
    // 处理拖放操作
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        let allowedTypes = UTType.allTypes
        if session.hasItemsConforming(toTypeIdentifiers: allowedTypes.map({ $0.identifier })) {
            UIView.makeLoading()
            let dispatchGroup = DispatchGroup()
            var urls: [URL] = []
            var errors: [ImportError] = []
            let supportIdentifiers = allowedTypes.reduce("") { $0 + " " + $1.identifier }
            for item in session.items {
                let itemProvider = item.itemProvider
                var supportIdentifier: String? = nil
                //找出item支持的UTType的identifier
                for itemProviderIdentifier in itemProvider.registeredTypeIdentifiers {
                    if supportIdentifiers.contains(itemProviderIdentifier, caseSensitive: false) {
                        supportIdentifier = itemProviderIdentifier
                        break
                    }
                }
                
                if let supportIdentifier = supportIdentifier {
                    //找到了支持的类型
                    if let utType = UTType(supportIdentifier),
                       let extens = utType.tags[.filenameExtension]?.first,
                       let suggestedName = itemProvider.suggestedName {
                        //获取到文件名
                        let fileName = suggestedName + "." + extens
                        //将内容先复制到缓存目录中
                        let dstUrl = URL(fileURLWithPath: R.Path.DropWorkSpace.appendingPathComponent(fileName))
                        dispatchGroup.enter()
                        itemProvider.loadFileRepresentation(forTypeIdentifier: supportIdentifier) { url, error in
                            defer { dispatchGroup.leave() }
                            if let url = url {
                                do {
                                    try FileManager.safeCopyItem(at: url, to: dstUrl, shouldReplace: true)
                                    //复制成功
                                    urls.append(dstUrl)
                                } catch {
                                    //复制失败
                                    errors.append(.badCopy(fileName: fileName))
                                }
                            }
                        }
                    }
                }
            }
            
            // 所有操作完成后刷新UI
            dispatchGroup.notify(queue: .main) {
                if urls.count > 0 {
                    FilesImporter.importFiles(urls: urls, preErrors: errors)
                } else {
                    UIView.hideLoading()
                    UIView.makeToast(message: R.string.localizable.dropErrorLoadFailed())
                }
            }
        } else {
            UIView.makeToast(message: R.string.localizable.dropErrorNotSupportFile())
        }
    }
    
    // 设置拖放操作类型为复制
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: any UIDropSession) {
        window?.hideDropView()
    }
}

/// Quiet console-style startup for the custom XMB frontend.
/// Uses original ManicEMU branding and a restrained wave reveal rather than copying
/// PlayStation logos, boot artwork, or audio.
private final class XMBStartupViewController: UIViewController {
    private let minimumDisplayDuration: TimeInterval = 2.05
    private var appearedAt: CFTimeInterval = CACurrentMediaTime()
    private var didStartEntrance = false
    private var didStartExit = false

    private let backgroundGradient = CAGradientLayer()
    private let waveLayers: [CAShapeLayer] = (0..<4).map { _ in CAShapeLayer() }

    private let brandLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor.white.withAlphaComponent(0.92)
        label.textAlignment = .right
        label.alpha = 0
        label.numberOfLines = 1
        label.attributedText = NSAttributedString(
            string: "MANIC EMU",
            attributes: [
                .font: UIFont.systemFont(ofSize: 22, weight: .light),
                .kern: 2.1,
                .foregroundColor: UIColor.white.withAlphaComponent(0.92)
            ]
        )
        return label
    }()

    init(preparingResources: Bool) {
        // Keep first-launch resource work independent from the visual presentation.
        _ = preparingResources
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersStatusBarHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = XMBBackgroundTheme.current.gradientColors.first ?? .black
        setupBackground()
        setupBrand()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appearedAt = CACurrentMediaTime()
        startEntranceIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradient.frame = view.bounds
        layoutWaves()
    }

    private func setupBackground() {
        let theme = XMBBackgroundTheme.current
        backgroundGradient.colors = theme.gradientColors.map(\.cgColor)
        backgroundGradient.locations = [0, 0.48, 1]
        backgroundGradient.startPoint = CGPoint(x: 0.05, y: 0)
        backgroundGradient.endPoint = CGPoint(x: 0.95, y: 1)
        backgroundGradient.opacity = 0
        view.layer.addSublayer(backgroundGradient)

        for (index, wave) in waveLayers.enumerated() {
            wave.fillColor = UIColor.clear.cgColor
            wave.strokeColor = theme.waveColor.withAlphaComponent(0.19 - CGFloat(index) * 0.025).cgColor
            wave.lineWidth = 1.0 + CGFloat(index) * 0.32
            wave.lineCap = .round
            wave.lineJoin = .round
            wave.opacity = 0
            view.layer.addSublayer(wave)
        }
    }

    private func setupBrand() {
        view.addSubview(brandLabel)

        NSLayoutConstraint.activate([
            brandLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -42),
            brandLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -2),
            brandLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.centerXAnchor, constant: 24)
        ])
    }

    private func layoutWaves() {
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }

        let width = view.bounds.width + 180
        let baseY = view.bounds.height * 0.62

        for (index, wave) in waveLayers.enumerated() {
            wave.frame = CGRect(x: -90, y: 0, width: width, height: view.bounds.height)

            let offset = CGFloat(index) * 12
            let amplitude = CGFloat(18 + index * 7)
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: baseY + offset))
            path.addCurve(
                to: CGPoint(x: width * 0.48, y: baseY - amplitude + offset),
                controlPoint1: CGPoint(x: width * 0.16, y: baseY - amplitude * 1.15 + offset),
                controlPoint2: CGPoint(x: width * 0.31, y: baseY + amplitude * 0.72 + offset)
            )
            path.addCurve(
                to: CGPoint(x: width, y: baseY + amplitude * 0.22 + offset),
                controlPoint1: CGPoint(x: width * 0.66, y: baseY - amplitude * 1.05 + offset),
                controlPoint2: CGPoint(x: width * 0.84, y: baseY + amplitude * 0.95 + offset)
            )
            wave.path = path.cgPath
        }
    }

    private func startEntranceIfNeeded() {
        guard !didStartEntrance else { return }
        didStartEntrance = true

        let backgroundFade = CABasicAnimation(keyPath: "opacity")
        backgroundFade.fromValue = 0
        backgroundFade.toValue = 1
        backgroundFade.duration = 1.05
        backgroundFade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        backgroundGradient.opacity = 1
        backgroundGradient.add(backgroundFade, forKey: "backgroundFade")

        let gradientBreath = CABasicAnimation(keyPath: "locations")
        gradientBreath.fromValue = [0.0, 0.40, 1.0]
        gradientBreath.toValue = [0.0, 0.60, 1.0]
        gradientBreath.duration = 6.8
        gradientBreath.autoreverses = true
        gradientBreath.repeatCount = .infinity
        gradientBreath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        backgroundGradient.add(gradientBreath, forKey: "bootGradientBreath")

        for (index, wave) in waveLayers.enumerated() {
            let reveal = CABasicAnimation(keyPath: "opacity")
            reveal.fromValue = 0
            reveal.toValue = 1
            reveal.duration = 1.15
            reveal.beginTime = CACurrentMediaTime() + 0.34 + Double(index) * 0.10
            reveal.fillMode = .backwards
            reveal.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            wave.opacity = 1
            wave.add(reveal, forKey: "waveReveal")

            let drift = CABasicAnimation(keyPath: "transform.translation.x")
            drift.fromValue = CGFloat(-22 - index * 7)
            drift.toValue = CGFloat(22 + index * 8)
            drift.duration = 7.5 + Double(index) * 1.1
            drift.autoreverses = true
            drift.repeatCount = .infinity
            drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            wave.add(drift, forKey: "waveDrift")
        }

        UIView.animate(
            withDuration: 0.90,
            delay: 0.72,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: {
                self.brandLabel.alpha = 1
            }
        )
    }

    func finish(completion: @escaping () -> Void) {
        let elapsed = CACurrentMediaTime() - appearedAt
        let delay = max(0, minimumDisplayDuration - elapsed)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.didStartExit else { return }
            self.didStartExit = true

            UIView.animate(
                withDuration: 0.42,
                delay: 0,
                options: [.curveEaseInOut],
                animations: {
                    self.brandLabel.alpha = 0
                    self.view.alpha = 0
                },
                completion: { _ in
                    completion()
                }
            )
        }
    }
}
