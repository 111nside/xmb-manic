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

/// Minimal original console-style startup sequence for the XMB frontend.
/// Deliberately avoids PlayStation logos/assets while keeping the quiet, dark startup pacing.
private final class XMBStartupViewController: UIViewController {
    private let minimumDisplayDuration: TimeInterval = 1.80
    private var appearedAt: CFTimeInterval = CACurrentMediaTime()
    private var didStartEntrance = false
    private var didStartExit = false

    private let backgroundGradient = CAGradientLayer()
    private let centerBloom = CAGradientLayer()
    private let emblemView = UIView()
    private let barOne = UIView()
    private let barTwo = UIView()
    private let flashView = UIView()

    init(preparingResources: Bool) {
        // Keep the argument so the existing startup call does not need special first-launch logic.
        // The visual intentionally stays text-free even while resources are being prepared.
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
        view.backgroundColor = .black
        setupLayers()
        setupViews()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appearedAt = CACurrentMediaTime()
        startEntranceIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        backgroundGradient.frame = view.bounds
        centerBloom.frame = view.bounds
        flashView.frame = view.bounds

        let side = min(max(view.bounds.width * 0.065, 62), 94)
        emblemView.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        emblemView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)

        let barLength = side * 0.72
        let barThickness = max(8, side * 0.105)
        for bar in [barOne, barTwo] {
            bar.bounds = CGRect(x: 0, y: 0, width: barLength, height: barThickness)
            bar.center = CGPoint(x: side / 2, y: side / 2)
            bar.layer.cornerRadius = barThickness / 2
        }
        barOne.transform = CGAffineTransform(rotationAngle: .pi / 4)
        barTwo.transform = CGAffineTransform(rotationAngle: -.pi / 4)
    }

    private func setupLayers() {
        backgroundGradient.colors = [
            UIColor.black.cgColor,
            UIColor(red: 0.002, green: 0.013, blue: 0.040, alpha: 1).cgColor,
            UIColor.black.cgColor
        ]
        backgroundGradient.locations = [0, 0.52, 1]
        backgroundGradient.startPoint = CGPoint(x: 0.5, y: 0)
        backgroundGradient.endPoint = CGPoint(x: 0.5, y: 1)
        backgroundGradient.opacity = 0
        view.layer.addSublayer(backgroundGradient)

        centerBloom.type = .radial
        centerBloom.colors = [
            UIColor(red: 0.28, green: 0.60, blue: 1.0, alpha: 0.16).cgColor,
            UIColor(red: 0.05, green: 0.16, blue: 0.42, alpha: 0.06).cgColor,
            UIColor.clear.cgColor
        ]
        centerBloom.locations = [0, 0.30, 1]
        centerBloom.startPoint = CGPoint(x: 0.5, y: 0.5)
        centerBloom.endPoint = CGPoint(x: 1.0, y: 1.0)
        centerBloom.opacity = 0
        view.layer.addSublayer(centerBloom)
    }

    private func setupViews() {
        emblemView.backgroundColor = .clear
        emblemView.alpha = 0
        emblemView.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)

        let markColor = UIColor(red: 0.86, green: 0.94, blue: 1.0, alpha: 1)
        for bar in [barOne, barTwo] {
            bar.backgroundColor = markColor
            bar.layer.shadowColor = UIColor(red: 0.28, green: 0.62, blue: 1.0, alpha: 1).cgColor
            bar.layer.shadowOpacity = 0.72
            bar.layer.shadowRadius = 12
            bar.layer.shadowOffset = .zero
            emblemView.addSubview(bar)
        }

        flashView.backgroundColor = UIColor(red: 0.68, green: 0.84, blue: 1.0, alpha: 1)
        flashView.alpha = 0
        flashView.isUserInteractionEnabled = false

        view.addSubview(emblemView)
        view.addSubview(flashView)
    }

    private func startEntranceIfNeeded() {
        guard !didStartEntrance else { return }
        didStartEntrance = true

        let backgroundFade = CABasicAnimation(keyPath: "opacity")
        backgroundFade.fromValue = 0
        backgroundFade.toValue = 1
        backgroundFade.duration = 0.70
        backgroundFade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        backgroundGradient.opacity = 1
        backgroundGradient.add(backgroundFade, forKey: "backgroundFade")

        let bloomFade = CABasicAnimation(keyPath: "opacity")
        bloomFade.fromValue = 0
        bloomFade.toValue = 0.72
        bloomFade.duration = 0.85
        bloomFade.beginTime = CACurrentMediaTime() + 0.18
        bloomFade.fillMode = .backwards
        bloomFade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        centerBloom.opacity = 0.72
        centerBloom.add(bloomFade, forKey: "bloomFade")

        UIView.animate(
            withDuration: 0.68,
            delay: 0.24,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: {
                self.emblemView.alpha = 1
                self.emblemView.transform = .identity
            }
        )

        // A single restrained luminance pulse keeps the startup from feeling static
        // without adding rings, text, particles, or other busy animation.
        UIView.animate(
            withDuration: 0.16,
            delay: 0.78,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: {
                self.flashView.alpha = 0.055
            },
            completion: { _ in
                UIView.animate(withDuration: 0.30) {
                    self.flashView.alpha = 0
                }
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
                withDuration: 0.34,
                delay: 0,
                options: [.curveEaseInOut],
                animations: {
                    self.emblemView.alpha = 0
                    self.emblemView.transform = CGAffineTransform(scaleX: 1.025, y: 1.025)
                    self.view.backgroundColor = .black
                },
                completion: { _ in
                    completion()
                }
            )

            let bloomOut = CABasicAnimation(keyPath: "opacity")
            bloomOut.fromValue = self.centerBloom.presentation()?.opacity ?? self.centerBloom.opacity
            bloomOut.toValue = 0
            bloomOut.duration = 0.34
            self.centerBloom.opacity = 0
            self.centerBloom.add(bloomOut, forKey: "bloomOut")
        }
    }
}
