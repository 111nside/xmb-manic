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

                        let homeController = HomeViewController()
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

/// Original console-style startup sequence for the XMB frontend.
/// It intentionally uses its own abstract mark/animation rather than PlayStation branding or assets.
private final class XMBStartupViewController: UIViewController {
    private let preparingResources: Bool
    private let minimumDisplayDuration: TimeInterval = 2.35
    private var appearedAt: CFTimeInterval = CACurrentMediaTime()
    private var didStartEntrance = false
    private var didStartExit = false

    private let backgroundGradient = CAGradientLayer()
    private let radialGlow = CAGradientLayer()
    private let horizonGlow = CAGradientLayer()
    private let starLayer = CAReplicatorLayer()
    private let starDot = CALayer()
    private let ringLayer = CAShapeLayer()
    private let secondaryRingLayer = CAShapeLayer()
    private let sweepLayer = CAShapeLayer()

    private let emblemView = UIView()
    private let emblemGlowView = UIView()
    private let barOne = UIView()
    private let barTwo = UIView()
    private let centerCore = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let prepareLabel = UILabel()

    init(preparingResources: Bool) {
        self.preparingResources = preparingResources
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersStatusBarHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.005, green: 0.012, blue: 0.032, alpha: 1)
        setupLayers()
        setupViews()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appearedAt = CACurrentMediaTime()
        startEntranceIfNeeded()

        if preparingResources {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) { [weak self] in
                guard let self, !self.didStartExit else { return }
                UIView.animate(withDuration: 0.45) {
                    self.prepareLabel.alpha = 0.62
                }
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bounds = view.bounds
        backgroundGradient.frame = bounds
        radialGlow.frame = bounds
        horizonGlow.frame = bounds
        starLayer.frame = bounds

        let center = CGPoint(x: bounds.midX, y: bounds.midY - min(18, bounds.height * 0.025))
        let emblemSize = min(max(bounds.width * 0.074, 72), 112)
        emblemView.bounds = CGRect(x: 0, y: 0, width: emblemSize, height: emblemSize)
        emblemView.center = center
        emblemGlowView.bounds = emblemView.bounds
        emblemGlowView.center = center
        emblemGlowView.layer.cornerRadius = emblemSize / 2

        let ringRadius = emblemSize * 0.86
        ringLayer.path = UIBezierPath(
            ovalIn: CGRect(
                x: center.x - ringRadius,
                y: center.y - ringRadius,
                width: ringRadius * 2,
                height: ringRadius * 2
            )
        ).cgPath

        let secondRadius = ringRadius * 1.46
        secondaryRingLayer.path = UIBezierPath(
            ovalIn: CGRect(
                x: center.x - secondRadius,
                y: center.y - secondRadius,
                width: secondRadius * 2,
                height: secondRadius * 2
            )
        ).cgPath

        let sweep = UIBezierPath()
        let sweepY = center.y + emblemSize * 1.35
        sweep.move(to: CGPoint(x: bounds.width * 0.12, y: sweepY))
        sweep.addCurve(
            to: CGPoint(x: bounds.width * 0.88, y: sweepY),
            controlPoint1: CGPoint(x: bounds.width * 0.33, y: sweepY - 54),
            controlPoint2: CGPoint(x: bounds.width * 0.67, y: sweepY + 54)
        )
        sweepLayer.path = sweep.cgPath

        let barLength = emblemSize * 0.68
        let barThickness = max(9, emblemSize * 0.12)
        [barOne, barTwo].forEach {
            $0.bounds = CGRect(x: 0, y: 0, width: barLength, height: barThickness)
            $0.center = CGPoint(x: emblemSize / 2, y: emblemSize / 2)
            $0.layer.cornerRadius = barThickness / 2
        }
        barOne.transform = CGAffineTransform(rotationAngle: .pi / 4)
        barTwo.transform = CGAffineTransform(rotationAngle: -.pi / 4)

        let coreSize = max(10, emblemSize * 0.13)
        centerCore.bounds = CGRect(x: 0, y: 0, width: coreSize, height: coreSize)
        centerCore.center = CGPoint(x: emblemSize / 2, y: emblemSize / 2)
        centerCore.layer.cornerRadius = coreSize / 2

        titleLabel.sizeToFit()
        titleLabel.center = CGPoint(x: bounds.midX, y: center.y + emblemSize * 0.91)
        subtitleLabel.sizeToFit()
        subtitleLabel.center = CGPoint(x: bounds.midX, y: titleLabel.frame.maxY + 21)
        prepareLabel.sizeToFit()
        prepareLabel.center = CGPoint(x: bounds.midX, y: bounds.height - max(45, view.safeAreaInsets.bottom + 24))
    }

    private func setupLayers() {
        backgroundGradient.colors = [
            UIColor(red: 0.002, green: 0.008, blue: 0.025, alpha: 1).cgColor,
            UIColor(red: 0.008, green: 0.028, blue: 0.075, alpha: 1).cgColor,
            UIColor(red: 0.002, green: 0.008, blue: 0.025, alpha: 1).cgColor
        ]
        backgroundGradient.locations = [0, 0.53, 1]
        backgroundGradient.startPoint = CGPoint(x: 0.5, y: 0)
        backgroundGradient.endPoint = CGPoint(x: 0.5, y: 1)
        view.layer.addSublayer(backgroundGradient)

        radialGlow.type = .radial
        radialGlow.colors = [
            UIColor(red: 0.20, green: 0.58, blue: 1.0, alpha: 0.36).cgColor,
            UIColor(red: 0.05, green: 0.20, blue: 0.55, alpha: 0.12).cgColor,
            UIColor.clear.cgColor
        ]
        radialGlow.locations = [0, 0.28, 1]
        radialGlow.startPoint = CGPoint(x: 0.5, y: 0.46)
        radialGlow.endPoint = CGPoint(x: 1.0, y: 0.98)
        radialGlow.opacity = 0
        view.layer.addSublayer(radialGlow)

        horizonGlow.colors = [
            UIColor.clear.cgColor,
            UIColor(red: 0.10, green: 0.52, blue: 1.0, alpha: 0.08).cgColor,
            UIColor(red: 0.38, green: 0.78, blue: 1.0, alpha: 0.15).cgColor,
            UIColor(red: 0.10, green: 0.52, blue: 1.0, alpha: 0.08).cgColor,
            UIColor.clear.cgColor
        ]
        horizonGlow.locations = [0, 0.38, 0.5, 0.62, 1]
        horizonGlow.startPoint = CGPoint(x: 0, y: 0.5)
        horizonGlow.endPoint = CGPoint(x: 1, y: 0.5)
        horizonGlow.opacity = 0
        view.layer.addSublayer(horizonGlow)

        starDot.backgroundColor = UIColor.white.withAlphaComponent(0.85).cgColor
        starDot.bounds = CGRect(x: 0, y: 0, width: 1.6, height: 1.6)
        starDot.cornerRadius = 0.8
        starDot.position = CGPoint(x: 22, y: 30)
        starLayer.instanceCount = 34
        starLayer.instanceTransform = CATransform3DMakeTranslation(47, 23, 0)
        starLayer.instanceAlphaOffset = -0.018
        starLayer.opacity = 0
        starLayer.addSublayer(starDot)
        view.layer.addSublayer(starLayer)

        [ringLayer, secondaryRingLayer].forEach { ring in
            ring.fillColor = UIColor.clear.cgColor
            ring.strokeColor = UIColor(red: 0.44, green: 0.78, blue: 1.0, alpha: 0.75).cgColor
            ring.lineWidth = 1
            ring.opacity = 0
            view.layer.addSublayer(ring)
        }
        secondaryRingLayer.strokeColor = UIColor(red: 0.22, green: 0.48, blue: 1.0, alpha: 0.30).cgColor

        sweepLayer.fillColor = UIColor.clear.cgColor
        sweepLayer.strokeColor = UIColor(red: 0.34, green: 0.72, blue: 1.0, alpha: 0.40).cgColor
        sweepLayer.lineWidth = 1.2
        sweepLayer.lineCap = .round
        sweepLayer.strokeEnd = 0
        sweepLayer.opacity = 0
        view.layer.addSublayer(sweepLayer)
    }

    private func setupViews() {
        emblemGlowView.backgroundColor = UIColor(red: 0.20, green: 0.60, blue: 1.0, alpha: 0.12)
        emblemGlowView.layer.shadowColor = UIColor(red: 0.20, green: 0.65, blue: 1.0, alpha: 1).cgColor
        emblemGlowView.layer.shadowOpacity = 0.8
        emblemGlowView.layer.shadowRadius = 30
        emblemGlowView.alpha = 0

        emblemView.backgroundColor = .clear
        emblemView.alpha = 0
        emblemView.transform = CGAffineTransform(scaleX: 0.48, y: 0.48)

        let barColor = UIColor(red: 0.78, green: 0.91, blue: 1.0, alpha: 1)
        [barOne, barTwo].forEach {
            $0.backgroundColor = barColor
            $0.layer.shadowColor = UIColor(red: 0.20, green: 0.65, blue: 1.0, alpha: 1).cgColor
            $0.layer.shadowOpacity = 0.9
            $0.layer.shadowRadius = 11
            $0.layer.shadowOffset = .zero
            emblemView.addSubview($0)
        }

        centerCore.backgroundColor = .white
        centerCore.layer.shadowColor = UIColor.white.cgColor
        centerCore.layer.shadowOpacity = 1
        centerCore.layer.shadowRadius = 7
        centerCore.layer.shadowOffset = .zero
        emblemView.addSubview(centerCore)

        titleLabel.text = "XMB"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .light)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.96)
        titleLabel.alpha = 0
        titleLabel.attributedText = NSAttributedString(
            string: "XMB",
            attributes: [
                .font: UIFont.systemFont(ofSize: 24, weight: .light),
                .foregroundColor: UIColor.white.withAlphaComponent(0.96),
                .kern: 8.0
            ]
        )

        subtitleLabel.attributedText = NSAttributedString(
            string: "SYSTEM START",
            attributes: [
                .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.44),
                .kern: 4.2
            ]
        )
        subtitleLabel.alpha = 0

        prepareLabel.attributedText = NSAttributedString(
            string: "PREPARING SYSTEM",
            attributes: [
                .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.68),
                .kern: 2.6
            ]
        )
        prepareLabel.alpha = 0

        view.addSubview(emblemGlowView)
        view.addSubview(emblemView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(prepareLabel)
    }

    private func startEntranceIfNeeded() {
        guard !didStartEntrance else { return }
        didStartEntrance = true

        let glowAnimation = CABasicAnimation(keyPath: "opacity")
        glowAnimation.fromValue = 0
        glowAnimation.toValue = 0.95
        glowAnimation.duration = 1.15
        glowAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        radialGlow.opacity = 0.95
        radialGlow.add(glowAnimation, forKey: "bootGlow")

        let horizonAnimation = CABasicAnimation(keyPath: "opacity")
        horizonAnimation.fromValue = 0
        horizonAnimation.toValue = 1
        horizonAnimation.duration = 1.35
        horizonAnimation.beginTime = CACurrentMediaTime() + 0.15
        horizonAnimation.fillMode = .backwards
        horizonAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        horizonGlow.opacity = 1
        horizonGlow.add(horizonAnimation, forKey: "horizonGlow")

        let stars = CABasicAnimation(keyPath: "opacity")
        stars.fromValue = 0
        stars.toValue = 0.50
        stars.duration = 1.4
        stars.beginTime = CACurrentMediaTime() + 0.35
        stars.fillMode = .backwards
        starLayer.opacity = 0.50
        starLayer.add(stars, forKey: "stars")

        UIView.animate(
            withDuration: 1.05,
            delay: 0.28,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.12,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: {
                self.emblemGlowView.alpha = 1
                self.emblemView.alpha = 1
                self.emblemView.transform = .identity
            }
        )

        animateRing(ringLayer, delay: 0.35, scale: 1.18, duration: 1.25)
        animateRing(secondaryRingLayer, delay: 0.60, scale: 1.12, duration: 1.55)

        let stroke = CABasicAnimation(keyPath: "strokeEnd")
        stroke.fromValue = 0
        stroke.toValue = 1
        stroke.duration = 1.15
        stroke.beginTime = CACurrentMediaTime() + 0.82
        stroke.fillMode = .backwards
        stroke.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        sweepLayer.strokeEnd = 1
        sweepLayer.opacity = 1
        sweepLayer.add(stroke, forKey: "sweep")

        UIView.animate(withDuration: 0.72, delay: 1.05, options: [.curveEaseOut]) {
            self.titleLabel.alpha = 1
        }
        UIView.animate(withDuration: 0.65, delay: 1.28, options: [.curveEaseOut]) {
            self.subtitleLabel.alpha = 1
        }

        let breathe = CABasicAnimation(keyPath: "transform.scale")
        breathe.fromValue = 0.985
        breathe.toValue = 1.025
        breathe.duration = 1.55
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        emblemView.layer.add(breathe, forKey: "breathe")
    }

    private func animateRing(_ layer: CAShapeLayer, delay: TimeInterval, scale: CGFloat, duration: TimeInterval) {
        let group = CAAnimationGroup()
        group.beginTime = CACurrentMediaTime() + delay
        group.duration = duration
        group.fillMode = .backwards

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 0.72, 0]
        opacity.keyTimes = [0, 0.28, 1]

        let transform = CABasicAnimation(keyPath: "transform.scale")
        transform.fromValue = 0.62
        transform.toValue = scale

        group.animations = [opacity, transform]
        layer.add(group, forKey: "pulse")
    }

    func finish(completion: @escaping () -> Void) {
        let elapsed = CACurrentMediaTime() - appearedAt
        let delay = max(0, minimumDisplayDuration - elapsed)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.didStartExit else { return }
            self.didStartExit = true

            self.prepareLabel.layer.removeAllAnimations()
            UIView.animate(withDuration: 0.20) {
                self.prepareLabel.alpha = 0
            }

            UIView.animate(
                withDuration: 0.48,
                delay: 0,
                options: [.curveEaseIn],
                animations: {
                    self.titleLabel.alpha = 0
                    self.subtitleLabel.alpha = 0
                    self.emblemView.alpha = 0
                    self.emblemGlowView.alpha = 0
                    self.view.backgroundColor = UIColor(red: 0.005, green: 0.020, blue: 0.060, alpha: 1)
                },
                completion: { _ in
                    completion()
                }
            )
        }
    }
}

