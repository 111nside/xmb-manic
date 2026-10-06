//
//  HomeViewController.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/25.
//  Copyright © 2024 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import SideMenu
import DNSPageView
import ColorfulX
import UniformTypeIdentifiers
import BlurUIKit
import RealmSwift
import PhotosUI
import SnapKit
import SceneKit
#if canImport(ARMSX2Core)
import ARMSX2Core
#endif

class HomeViewController: BaseViewController {
    
    private let gamesViewController = GamesViewController()
    
    private let importViewController = ImportViewController()
    
    private let settingsViewController = SettingsViewController()
    
    private lazy var childControllers: [BaseViewController] = {
        if Locale.isRTLLanguage {
            [settingsViewController, importViewController, gamesViewController]
        } else {
            [gamesViewController, importViewController, settingsViewController]
        }
        
    }()
    
    private lazy var pageViewManager: PageViewManager = {
        let style = PageStyle()
        style.contentViewBackgroundColor = UIDevice.isPad ? UIColor(.dm, light: .white, dark: .black) : .clear
        let manager = PageViewManager(style: style, titles: HomeTabBar.BarSelection.allCases.map { String($0.rawValue) }, childViewControllers: childControllers)
        if UIDevice.isPhone {
            manager.contentView.backgroundColor = R.Color.BackgroundPrimary
            let backgroundMask = PageBackgroundMaskView()
            manager.contentView.insertSubview(backgroundMask, at: 0)
            backgroundMask.snp.makeConstraints { make in
                make.leading.top.trailing.equalToSuperview()
                make.height.equalTo(R.Size.PageBackgroundMaskHeight)
            }
        }
        childControllers.forEach {
            addChild($0)
            $0.didMove(toParent: self)
        }
        return manager
    }()
    
    lazy var homeTabBar: HomeTabBar = {
        let view = HomeTabBar()
        view.selectionChange = { [weak self] selection in
            var selection = selection
            if Locale.isRTLLanguage {
                if selection == .games {
                    selection = .settings
                } else if selection == .settings {
                    selection = .games
                }
            }
            self?.pageViewManager.setCurrentPage(selection.rawValue)
            switch selection {
            case .games:
                Log.debug("切换到游戏")
                if UIDevice.isPhone, UIDevice.isLandscape {
                    self?.gamesViewController.view.masksToBounds = false
                }
                
            case .imports:
                Log.debug("切换到导入")
                if UIDevice.isPhone, UIDevice.isLandscape {
                    self?.gamesViewController.view.masksToBounds = true
                }
                
            case .settings:
                Log.debug("切换到设置")
            }
            self?.updateLandscapeBackgroundVisible()
            self?.activateCurrentTabFocusContext()
        }
        view.isHidden = UIDevice.isPhone && UIDevice.isLandscape
        return view
    }()
    
    private var homeTabBarBlurView: UIView = {
        let view = BlurUIKit.VariableBlurView()
        view.direction = .up
        view.maximumBlurRadius = 1
        view.dimmingAlpha = .interfaceStyle(lightModeAlpha: 0.05, darkModeAlpha: 0.05)
        view.dimmingTintColor = R.Color.BackgroundPrimary
        view.isHidden = UIDevice.isLandscape
        return view
    }()
    
    ///横屏动态背景 所有tab横屏时可见 层级高于BaseViewController的PageBackgroundMaskView
    private lazy var landscapeBackgroundView: LandscapeBackgroundView = {
        let view = LandscapeBackgroundView()
        view.isHidden = true
        view.pauseRendering()
        return view
    }()
    
    private var homeSelectionChangeNotification: Any? = nil
    
    private var landscapeBackgroundNotification: Any? = nil
    
    /// D-pad ran off a tab edge; the following selection change should restore focus in the new tab.
    private var shouldHandoffTabFocus = false
    
    private var currentChildViewController: BaseViewController {
        switch homeTabBar.currentSelection {
        case .games:
            return gamesViewController
        case .imports:
            return importViewController
        case .settings:
            return settingsViewController
        }
    }
    
    deinit {
        if let homeSelectionChangeNotification = homeSelectionChangeNotification {
            NotificationCenter.default.removeObserver(homeSelectionChangeNotification)
        }
        if let landscapeBackgroundNotification = landscapeBackgroundNotification {
            NotificationCenter.default.removeObserver(landscapeBackgroundNotification)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(.dm, light: .white, dark: .black)
        
        self.setupViews()
        
        //GameListLandscapeView上报的背景变更 只有横屏可见时才实时应用 否则先记录待横屏时应用
        landscapeBackgroundNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.LandscapeBackgroundChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            if let background = notification.object as? LandscapeBackgroundView.Background {
                self.landscapeBackgroundView.setBackground(background)
            }
        }
        
        updateLandscapeBackgroundVisible()
        
        homeSelectionChangeNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.HomeSelectionChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            if let selection = notification.object as? HomeTabBar.BarSelection {
                if self.presentedViewController == nil {
                    if self.homeTabBar.currentSelection != selection {
                        self.homeTabBar.currentSelection = selection
                    }
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        landscapeBackgroundView.setHomeVisible(true)
        if let coordinator = transitionCoordinator {
            let size = R.Size.WindowSize
            viewWillTransition(to: size, with: coordinator)
            childControllers.forEach { $0.viewWillTransition(to: size, with: coordinator) }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        activateCurrentTabFocusContext()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if currentChildViewController.hasFocusContext {
            currentChildViewController.popFocusContext()
        }
        landscapeBackgroundView.setHomeVisible(false)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.resignFirstResponder()
    }
    
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        super.present(viewControllerToPresent, animated: flag, completion: completion)
        self.resignFirstResponder()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if !UIDevice.isIOS15 {
            NotificationCenter.default.post(name: R.NotificationName.ViewWillTransition, object: nil)
        }
        homeTabBarBlurView.isHidden = UIDevice.isLandscape
        if currentChildViewController is GamesViewController {
            updateGamesFocusCommands(focusContext: currentChildViewController.focusContext)
        }
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            if UIDevice.isPhone {
                if let pageBackgroundMaskView = self.pageViewManager.contentView.subviews.first(where: { $0.isKind(of: PageBackgroundMaskView.self) }) {
                    pageBackgroundMaskView.snp.updateConstraints { make in
                        make.height.equalTo(R.Size.PageBackgroundMaskHeight)
                    }
                }
            }
            self.updateLandscapeBackgroundVisible()
            if UIDevice.isIOS15 {
                NotificationCenter.default.post(name: R.NotificationName.ViewWillTransition, object: nil)
            }
            NotificationCenter.default.post(name: R.NotificationName.ViewAlongsideTransition, object: nil)
            self.homeTabBar.isHidden = UIDevice.isPhone && UIDevice.isLandscape
        }, completion: { _ in
            NotificationCenter.default.post(name: R.NotificationName.ViewDidTransition, object: nil)
        })
    }
    
    override func handleScreenPanGesture(edges: UIRectEdge, gesture: UIScreenEdgePanGestureRecognizer) {
        childControllers[self.pageViewManager.currentIndex].handleScreenPanGesture(edges: edges, gesture: gesture)
    }
    
    private func setupViews() {
        //横屏动态背景 插在自身PageBackgroundMaskView之上 分页内容之下
        if let backgroundMaskView {
            view.insertSubview(landscapeBackgroundView, aboveSubview: backgroundMaskView)
        } else {
            view.insertSubview(landscapeBackgroundView, at: 0)
        }
        landscapeBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        view.addSubview(pageViewManager.contentView)
        pageViewManager.contentView.delegate = self
        pageViewManager.contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        if Locale.isRTLLanguage {
            DispatchQueue.main.asyncAfter(delay: 0.35) { [weak self] in
                self?.pageViewManager.setCurrentPage(HomeTabBar.BarSelection.settings.rawValue)
            }
        }
        
        view.addSubview(homeTabBarBlurView)
        view.addSubview(homeTabBar)
        homeTabBarBlurView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(homeTabBar).offset(-R.Size.ContentSpaceLarge)
        }
        
        homeTabBar.snp.makeConstraints { make in
            make.size.equalTo(R.Size.HomeTabBarSize)
            make.centerX.equalTo(self.view)
            if R.Size.SafeArea.top == 0 {
                make.bottom.equalToSuperview().inset(R.Size.ContentInsetBottom)
            } else {
                make.bottom.equalTo(view.safeAreaLayoutGuide)
            }
        }
    }
    
    ///根据横竖屏更新动态背景显隐 横屏时透明化分页容器与子页面使背景透出
    private func updateLandscapeBackgroundVisible() {
        let landscape = UIDevice.isLandscape
        if landscape {
            if UIDevice.isPhone {
                if landscapeBackgroundView.isHidden {
                    landscapeBackgroundView.isHidden = false
                }
                
                if getSelection() == .games {
                    gamesViewController.updateLandscapeBackgroundIfNeed()
                } else if !landscapeBackgroundView.isShaderMode {
                    landscapeBackgroundView.setBackground(LandscapeBackgroundView.Background.shader(reload: false), animated: false)
                }
                
                landscapeBackgroundView.resumeRendering()
            } else if UIDevice.isPad {
                if getSelection() == .games, landscapeBackgroundView.isHidden {
                    landscapeBackgroundView.isHidden = false
                    landscapeBackgroundView.resumeRendering()
                } else if getSelection() != .games, !landscapeBackgroundView.isHidden {
                    landscapeBackgroundView.isHidden = true
                    landscapeBackgroundView.pauseRendering()
                }
            }
        } else {
            landscapeBackgroundView.isHidden = true
            landscapeBackgroundView.pauseRendering()
        }
        
        //横屏时分页容器与已加载的子页面透明化 并隐藏各自的PageBackgroundMaskView 使动态背景透出
        if UIDevice.isPad {
            pageViewManager.contentView.collectionView.backgroundColor = landscape ? .clear : UIColor(.dm, light: .white, dark: .black)
        } else {
            pageViewManager.contentView.backgroundColor = landscape ? .clear : R.Color.BackgroundPrimary
            if let pageMaskView = pageViewManager.contentView.subviews.first(where: { $0.isKind(of: PageBackgroundMaskView.self) }) {
                pageMaskView.isHidden = landscape
            }
        }
        childControllers.filter { $0.isViewLoaded }.forEach {
            if UIDevice.isPad {
                if $0 is GamesViewController {
                    $0.view.backgroundColor = landscape ? .clear : R.Color.BackgroundPrimary
                }
            } else {
                $0.view.backgroundColor = landscape ? .clear : R.Color.BackgroundPrimary
                $0.backgroundMaskView?.isHidden = landscape ? true : !$0.enableBackgroundMask
            }
        }
    }
    
    // MARK: - Tab FocusKit
    
    /// Make the selected child VC the focus root so search stays inside that tab.
    private func activateCurrentTabFocusContext() {
        let viewController = currentChildViewController
        let handoff = shouldHandoffTabFocus
        shouldHandoffTabFocus = false
        viewController.activateFocusRoot { [weak self] context in
            guard let self else { return }
            // Tab bar lives on HomeViewController; include it in this tab's page-level search.
            context.addAdditionalSearchRoot(self.homeTabBar)
            context.addCommands([
                FocusCommand(key: FocusKey("control+1"), title: R.string.localizable.tabbarTitleGames(), action: { [weak self] in
                    self?.homeTabBar.currentSelection = .games
                }),
                FocusCommand(key: FocusKey("control+2"), title: R.string.localizable.tabbarTitleImport(), action: { [weak self] in
                    self?.homeTabBar.currentSelection = .imports
                }),
                FocusCommand(key: FocusKey("control+3"), title: R.string.localizable.tabbarTitleSettings(), action: { [weak self] in
                    self?.homeTabBar.currentSelection = .settings
                }),
                FocusCommand(key: FocusKey("l2"), title: R.string.localizable.nextTap(), action: { [weak self] in
                    self?.homeTabBar.previousSelection()
                }),
                FocusCommand(key: FocusKey("r2"), title: R.string.localizable.previousTap(), action: { [weak self] in
                    self?.homeTabBar.nextSelection()
                })
            ])
            
            if self.homeTabBar.currentSelection == .games {
                var commands = [FocusCommand(key: FocusKey("l1"), title: R.string.localizable.scrollToFirstGame(), action: { [weak self] in
                    self?.gamesViewController.scrollToFirstGame()
                }),
                 FocusCommand(key: FocusKey("r1"), title: R.string.localizable.scrollToLastGame(), action: { [weak self] in
                    self?.gamesViewController.scrollToLastGame()
                })]
                self.updateGamesFocusCommands(focusContext: context)
                context.addCommands(commands)
            }
            
            context.onFocusChange = { [weak self] focusView, attemptedDirection in
                guard let self, focusView == nil, let attemptedDirection else { return }
                self.handleTabFocusExit(attemptedDirection)
            }
        }
        if handoff, FocusSystem.shared.hasExternalInput {
            let context = viewController.focusContext
            DispatchQueue.main.async {
                guard FocusSystem.shared.currentContext === context else { return }
                FocusSystem.shared.updateFocusIfNeeded()
            }
        }
    }
    
    /// Horizontal search found no target in this tab: move to the adjacent sibling tab.
    private func handleTabFocusExit(_ direction: FocusDirection) {
        guard direction.isHorizontal else { return }
        var offset = direction == .right ? 1 : -1
        if Locale.isRTLLanguage {
            offset = -offset
        }
        guard let newSelection = HomeTabBar.BarSelection(rawValue: homeTabBar.currentSelection.rawValue + offset) else {
            return
        }
        shouldHandoffTabFocus = true
        homeTabBar.currentSelection = newSelection
    }
    
    private func updateGamesFocusCommands(focusContext: FocusContext) {
        guard currentChildViewController is GamesViewController else { return }
        if UIDevice.isLandscape {
            focusContext.addCommand(FocusCommand(key: FocusKey("l3"), title: R.string.localizable.filterTitle(), action: {
                NotificationCenter.default.post(name: R.NotificationName.ShowFilterForLandscapeMode, object: nil)
            }))
        } else {
            focusContext.removeCommands(for: FocusKey("l3"))
        }
    }
}

extension HomeViewController: UIGestureRecognizerDelegate {
    // 让 UICollectionView 的手势在 EdgePan 失败后才识别
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIScreenEdgePanGestureRecognizer,
           let scrollView = otherGestureRecognizer.view as? UIScrollView,
           otherGestureRecognizer == scrollView.panGestureRecognizer {
            return true // 先执行 EdgePan，失败后才允许 UICollectionView 滚动
        }
        return false
    }
}

extension HomeViewController: PageContentViewDelegate {
    func contentView(_ contentView: DNSPageView.PageContentView, didEndScrollAt index: Int) {
        if let selection = getSelection(for: index) {
            homeTabBar.currentSelection = selection
        }
    }
    
    func contentView(_ contentView: DNSPageView.PageContentView, scrollingWith sourceIndex: Int, targetIndex: Int, progress: CGFloat) {
        guard UIDevice.isPad else { return }
        if let sourceSelection = getSelection(for: sourceIndex), let targetSelection = getSelection(for: targetIndex) {
            if sourceSelection == .imports,
               targetSelection == .games,
               landscapeBackgroundView.isHidden {
                landscapeBackgroundView.isHidden = false
                landscapeBackgroundView.resumeRendering()
            }
        }
    }
    
    private func getSelection(for index: Int? = nil) -> HomeTabBar.BarSelection? {
        if let index {
            var realIndex = index
            if Locale.isRTLLanguage {
                if index == HomeTabBar.BarSelection.games.rawValue {
                    realIndex = HomeTabBar.BarSelection.settings.rawValue
                } else if index == HomeTabBar.BarSelection.settings.rawValue {
                    realIndex = HomeTabBar.BarSelection.games.rawValue
                }
            }
            return HomeTabBar.BarSelection(rawValue: realIndex)
        } else {
            return homeTabBar.currentSelection
        }
    }
}

// MARK: - XMB-inspired home (Manic XMB fork)
// Original HomeViewController is intentionally retained above as a fallback.

private enum XMBBackgroundTheme: Int, CaseIterable {
    case blue = 0
    case purple
    case green
    case red
    case silver
    case black

    static let defaultsKey = "ManicXMB.backgroundTheme"

    static var current: XMBBackgroundTheme {
        get { XMBBackgroundTheme(rawValue: UserDefaults.standard.integer(forKey: defaultsKey)) ?? .blue }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
            NotificationCenter.default.post(name: .xmbBackgroundThemeDidChange, object: newValue)
        }
    }

    var title: String {
        switch self {
        case .blue: return "Classic Blue"
        case .purple: return "Purple"
        case .green: return "Green"
        case .red: return "Red"
        case .silver: return "Silver"
        case .black: return "Black"
        }
    }

    var gradientColors: [UIColor] {
        switch self {
        case .blue:
            return [
                UIColor(red: 0.005, green: 0.035, blue: 0.12, alpha: 1),
                UIColor(red: 0.008, green: 0.12, blue: 0.31, alpha: 1),
                UIColor(red: 0.005, green: 0.045, blue: 0.16, alpha: 1)
            ]
        case .purple:
            return [
                UIColor(red: 0.06, green: 0.015, blue: 0.12, alpha: 1),
                UIColor(red: 0.22, green: 0.035, blue: 0.34, alpha: 1),
                UIColor(red: 0.08, green: 0.018, blue: 0.15, alpha: 1)
            ]
        case .green:
            return [
                UIColor(red: 0.01, green: 0.08, blue: 0.055, alpha: 1),
                UIColor(red: 0.03, green: 0.24, blue: 0.14, alpha: 1),
                UIColor(red: 0.01, green: 0.10, blue: 0.07, alpha: 1)
            ]
        case .red:
            return [
                UIColor(red: 0.11, green: 0.015, blue: 0.02, alpha: 1),
                UIColor(red: 0.31, green: 0.035, blue: 0.045, alpha: 1),
                UIColor(red: 0.13, green: 0.018, blue: 0.025, alpha: 1)
            ]
        case .silver:
            return [
                UIColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1),
                UIColor(red: 0.28, green: 0.30, blue: 0.34, alpha: 1),
                UIColor(red: 0.12, green: 0.13, blue: 0.15, alpha: 1)
            ]
        case .black:
            return [
                UIColor(red: 0.008, green: 0.008, blue: 0.012, alpha: 1),
                UIColor(red: 0.035, green: 0.035, blue: 0.05, alpha: 1),
                UIColor(red: 0.012, green: 0.012, blue: 0.018, alpha: 1)
            ]
        }
    }

    var waveColor: UIColor {
        switch self {
        case .blue: return .systemBlue
        case .purple: return .systemPurple
        case .green: return .systemGreen
        case .red: return .systemRed
        case .silver: return .white
        case .black: return UIColor(white: 0.72, alpha: 1)
        }
    }
}

private extension Notification.Name {
    static let xmbBackgroundThemeDidChange = Notification.Name("ManicXMB.BackgroundThemeDidChange")
    static let xmbConsoleIconsDidChange = Notification.Name("ManicXMB.ConsoleIconsDidChange")
    static let xmbLibraryViewSettingsDidChange = Notification.Name("ManicXMB.LibraryViewSettingsDidChange")
}

private enum XMBCoverMode: Int {
    case original = 0
    case square = 1

    var title: String {
        switch self {
        case .original: return "Original"
        case .square: return "Square"
        }
    }
}

/// Adds a deliberate empty band around the horizontal XMB rail.
/// Games already passed by the focused item are shifted above the rail instead
/// of visually travelling through/behind the selected console icon.
private final class XMBGameColumnLayout: UICollectionViewFlowLayout {
    var focusPosition: CGFloat = 0 {
        didSet {
            if abs(oldValue - focusPosition) > 0.002 { invalidateLayout() }
        }
    }

    var railGap: CGFloat = 100 {
        didSet {
            if abs(oldValue - railGap) > 0.5 { invalidateLayout() }
        }
    }

    private func adjustedCopy(_ attributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        guard let copy = attributes.copy() as? UICollectionViewLayoutAttributes else {
            return attributes
        }
        if copy.representedElementCategory == .cell {
            let clampedPosition = max(0, focusPosition)
            let completedIndex = floor(clampedPosition)
            let fraction = clampedPosition - completedIndex
            let item = CGFloat(copy.indexPath.item)

            if item < completedIndex {
                // Rows which have fully crossed the XMB rail stay above it.
                copy.frame.origin.y -= railGap
                copy.zIndex = -20
            } else if abs(item - completedIndex) < 0.001, fraction > 0 {
                // Move the crossing row progressively instead of jumping the entire
                // rail gap when the selected index changes.
                copy.frame.origin.y -= railGap * fraction
                copy.zIndex = -10
            } else {
                copy.zIndex = 0
            }
            copy.alpha = 1
        }
        return copy
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let expandedRect = rect.insetBy(dx: 0, dy: -railGap)
        return super.layoutAttributesForElements(in: expandedRect)?
            .map(adjustedCopy)
            .filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = super.layoutAttributesForItem(at: indexPath) else { return nil }
        return adjustedCopy(attributes)
    }
}

private enum XMBGameSort: Int, CaseIterable {
    case nameAZ = 0
    case nameZA
    case recentlyPlayed
    case mostPlayed
    case recentlyAdded

    var title: String {
        switch self {
        case .nameAZ: return "Name A–Z"
        case .nameZA: return "Name Z–A"
        case .recentlyPlayed: return "Recently Played"
        case .mostPlayed: return "Most Played"
        case .recentlyAdded: return "Recently Added"
        }
    }
}

private enum XMBGameFilter: Int, CaseIterable {
    case all = 0
    case played
    case unplayed
    case hasSave

    var title: String {
        switch self {
        case .all: return "All Games"
        case .played: return "Played"
        case .unplayed: return "Unplayed"
        case .hasSave: return "Has Save Data"
        }
    }
}

private enum XMBConsoleSort: Int, CaseIterable {
    case systemDefault = 0
    case nameAZ
    case nameZA
    case recentlyPlayed
    case mostPlayed
    case manufacturer

    var title: String {
        switch self {
        case .systemDefault: return "System Default"
        case .nameAZ: return "Name A–Z"
        case .nameZA: return "Name Z–A"
        case .recentlyPlayed: return "Recently Played"
        case .mostPlayed: return "Most Played"
        case .manufacturer: return "Manufacturer"
        }
    }
}

private enum XMBConsoleFilter: Int, CaseIterable {
    case libraryOnly = 0
    case allSystems
    case playedSystems

    var title: String {
        switch self {
        case .libraryOnly: return "Library Systems"
        case .allSystems: return "All Systems"
        case .playedSystems: return "Played Systems"
        }
    }
}

private struct XMBGameItem {
    let id: String
    let displayName: String
    let gameType: GameType
    let totalPlayDuration: Double
    let latestPlayDate: Date?
    let importDate: Date
    let hasSaveData: Bool

    init?(game: Game) {
        guard !game.isInvalidated else { return nil }
        id = game.id
        let resolvedName = game.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        displayName = resolvedName.isEmpty ? game.name : resolvedName
        gameType = game.effectiveGameType
        totalPlayDuration = game.totalPlayDuration.isFinite ? max(0, game.totalPlayDuration) : 0
        latestPlayDate = game.latestPlayDate
        importDate = game.importDate
        hasSaveData = game.isSaveExtsts
    }
}

private final class XMBProfileMenuButton: UIButton {
    private let symbolView = UIImageView()
    private let primaryLabel = UILabel()
    private let secondaryLabel = UILabel()
    private let symbolPlate = UIView()

    init(title: String, subtitle: String, image: UIImage?) {
        super.init(frame: .zero)

        backgroundColor = .clear
        layer.cornerRadius = 11
        clipsToBounds = false

        symbolPlate.translatesAutoresizingMaskIntoConstraints = false
        symbolPlate.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        symbolPlate.layer.cornerRadius = 17
        symbolPlate.layer.borderWidth = 1
        symbolPlate.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        symbolPlate.isUserInteractionEnabled = false
        addSubview(symbolPlate)

        symbolView.translatesAutoresizingMaskIntoConstraints = false
        symbolView.image = image
        symbolView.tintColor = UIColor.white.withAlphaComponent(0.92)
        symbolView.contentMode = .scaleAspectFit
        symbolView.isUserInteractionEnabled = false
        addSubview(symbolView)

        primaryLabel.translatesAutoresizingMaskIntoConstraints = false
        primaryLabel.text = title
        primaryLabel.font = .systemFont(ofSize: 15.5, weight: .semibold)
        primaryLabel.textColor = .white
        primaryLabel.lineBreakMode = .byTruncatingTail
        primaryLabel.isUserInteractionEnabled = false
        addSubview(primaryLabel)

        secondaryLabel.translatesAutoresizingMaskIntoConstraints = false
        secondaryLabel.text = subtitle
        secondaryLabel.font = .systemFont(ofSize: 11.25, weight: .regular)
        secondaryLabel.textColor = UIColor.white.withAlphaComponent(0.56)
        secondaryLabel.lineBreakMode = .byTruncatingTail
        secondaryLabel.isUserInteractionEnabled = false
        addSubview(secondaryLabel)

        NSLayoutConstraint.activate([
            // Keep every submenu icon directly on the same vertical axis as the
            // selected Profile icon in the horizontal XMB rail.
            symbolPlate.centerXAnchor.constraint(equalTo: centerXAnchor),
            symbolPlate.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolPlate.widthAnchor.constraint(equalToConstant: 34),
            symbolPlate.heightAnchor.constraint(equalToConstant: 34),

            symbolView.centerXAnchor.constraint(equalTo: symbolPlate.centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: symbolPlate.centerYAnchor),
            symbolView.widthAnchor.constraint(equalToConstant: 19),
            symbolView.heightAnchor.constraint(equalToConstant: 19),

            primaryLabel.leadingAnchor.constraint(equalTo: symbolPlate.trailingAnchor, constant: 15),
            primaryLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            primaryLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -7),

            secondaryLabel.leadingAnchor.constraint(equalTo: primaryLabel.leadingAnchor),
            secondaryLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            secondaryLabel.topAnchor.constraint(equalTo: primaryLabel.bottomAnchor, constant: 2)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSubtitle(_ text: String) {
        secondaryLabel.text = text
    }

    func setXMBFocused(_ focused: Bool) {
        UIView.animate(withDuration: 0.14,
                       delay: 0,
                       options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]) {
            self.backgroundColor = focused ? UIColor.white.withAlphaComponent(0.085) : .clear
            self.symbolPlate.backgroundColor = focused
                ? UIColor.white.withAlphaComponent(0.15)
                : UIColor.white.withAlphaComponent(0.07)
            self.symbolPlate.transform = focused
                ? CGAffineTransform(scaleX: 1.08, y: 1.08)
                : .identity
            self.primaryLabel.alpha = focused ? 1.0 : 0.88
            self.secondaryLabel.alpha = focused ? 0.90 : 0.72
        }
    }
}

final class XMBHomeViewController: BaseViewController {
    private enum SectionKind: Equatable {
        case profile
        case console(GameType)
        case importGames
        case settings
        case classicHome
    }

    private struct XMBSection: Equatable {
        let kind: SectionKind
        let title: String
        let symbol: String

        var identifier: String {
            switch kind {
            case .profile:
                return "profile"
            case .console(let gameType):
                return "console:\(gameType.localizedShortName)"
            case .importGames:
                return "import"
            case .settings:
                return "settings"
            case .classicHome:
                return "manic"
            }
        }
    }

    private static let selectedSectionDefaultsKey = "ManicXMB.selectedSection"
    private static let coverModeDefaultsKey = "ManicXMB.coverMode"
    private static let showHintsDefaultsKey = "ManicXMB.showControllerHints"
    private static let profileNameDefaultsKey = "ManicXMB.profileName"
    private static let profileStatusDefaultsKey = "ManicXMB.profileStatus"
    private static let gameSortDefaultsKey = "ManicXMB.gameSort"
    private static let gameFilterDefaultsKey = "ManicXMB.gameFilter"
    private static let consoleSortDefaultsKey = "ManicXMB.consoleSort"
    private static let consoleFilterDefaultsKey = "ManicXMB.consoleFilter"

    private var sections: [XMBSection] = []
    private var selectedSectionIndex = 0
    // Never keep Realm-managed Game objects in the XMB collection. Importing can
    // replace/invalidate Realm rows while UIKit is still holding cells/focus callbacks.
    // A value snapshot keeps the home screen stable across imports and app relaunches.
    private var libraryGames: [XMBGameItem] = []
    private var games: [XMBGameItem] = []
    private var rememberedGameIndex: [String: Int] = [:]
    private var gameToken: NotificationToken?
    private var clockTimer: Timer?
    private var sectionCenterConstraint: Constraint?
    private var pendingLibraryRefresh = false
    private var isRefreshingLibrary = false
    private var libraryRefreshWorkItem: DispatchWorkItem?
    private var pendingSectionTransitionDirection: CGFloat = 0
    private var consoleIconObserver: NSObjectProtocol?
    private var librarySettingsObserver: NSObjectProtocol?
    private var isTouchScrollingSections = false
    private var isTouchScrollingGames = false
    private var isProgrammaticGameScroll = false

    private var gameSort: XMBGameSort {
        get { XMBGameSort(rawValue: UserDefaults.standard.integer(forKey: Self.gameSortDefaultsKey)) ?? .nameAZ }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.gameSortDefaultsKey) }
    }

    private var gameFilter: XMBGameFilter {
        get { XMBGameFilter(rawValue: UserDefaults.standard.integer(forKey: Self.gameFilterDefaultsKey)) ?? .all }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.gameFilterDefaultsKey) }
    }

    private var consoleSort: XMBConsoleSort {
        get { XMBConsoleSort(rawValue: UserDefaults.standard.integer(forKey: Self.consoleSortDefaultsKey)) ?? .systemDefault }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.consoleSortDefaultsKey) }
    }

    private var consoleFilter: XMBConsoleFilter {
        get { XMBConsoleFilter(rawValue: UserDefaults.standard.integer(forKey: Self.consoleFilterDefaultsKey)) ?? .libraryOnly }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.consoleFilterDefaultsKey) }
    }

    private var coverMode: XMBCoverMode {
        get {
            XMBCoverMode(rawValue: UserDefaults.standard.integer(forKey: Self.coverModeDefaultsKey)) ?? .original
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.coverModeDefaultsKey)
        }
    }

    private var showControllerHints: Bool {
        get { UserDefaults.standard.bool(forKey: Self.showHintsDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.showHintsDefaultsKey) }
    }

    private let backgroundView = XMBWaveBackgroundView()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.78)
        label.textAlignment = .right
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.85
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.28
        label.layer.shadowRadius = 2
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        return label
    }()

    private lazy var gameOptionsButton: UIButton = makeXMBOptionsButton(symbol: "line.3.horizontal.decrease.circle", title: "Games") { [weak self] in
        self?.refreshViewOptionMenus()
    }

    private lazy var consoleOptionsButton: UIButton = makeXMBOptionsButton(symbol: "arrow.up.arrow.down.circle", title: "Systems") { [weak self] in
        self?.refreshViewOptionMenus()
    }

    private let sectionScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.isScrollEnabled = true
        scrollView.clipsToBounds = false
        scrollView.decelerationRate = UIScrollView.DecelerationRate(rawValue: 0.994)
        return scrollView
    }()

    private let sectionStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 20
        return stack
    }()

    private var sectionButtons: [UIButton] = []

    private let selectedSectionGlow: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        view.layer.cornerRadius = 34
        view.layer.shadowColor = UIColor.systemCyan.cgColor
        view.layer.shadowOpacity = 0.55
        view.layer.shadowRadius = 24
        view.isUserInteractionEnabled = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 19, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.58)
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()

    private let gamesContentView = UIView()
    private let listContainerView = UIView()

    private lazy var gameColumnLayout: XMBGameColumnLayout = {
        let layout = XMBGameColumnLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 5
        layout.sectionInset = .zero
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = gameColumnLayout
        // The collection spans the screen. The custom layout reserves a visual gap
        // for the horizontal console rail as the focused game moves down the column.

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
        collectionView.isScrollEnabled = true
        collectionView.decelerationRate = UIScrollView.DecelerationRate(rawValue: 0.994)
        collectionView.clipsToBounds = true
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.register(XMBGameRowCell.self, forCellWithReuseIdentifier: XMBGameRowCell.reuseIdentifier)
        collectionView.isFocusable = true
        collectionView.enableFocusEffects = false
        return collectionView
    }()

    private let profileContainerView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        return scrollView
    }()

    private let profileContentView = UIView()

    private let profileMenuContainerView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.decelerationRate = .normal
        return scrollView
    }()

    private lazy var profileDetailsButton = makeProfileMenuButton(title: "Profile Details",
                                                                  subtitle: "Account, avatar, XMB colors and preferences",
                                                                  symbol: "person.crop.circle.fill") { [weak self] in
        self?.openProfileDetails()
    }

    private lazy var ps2MemoryCardsButton = makeProfileMenuButton(title: "PS2 Memory Cards",
                                                                  subtitle: "Open the original PS2 Browser / Memory Card screen",
                                                                  symbol: "memorychip.fill") { [weak self] in
        self?.openPS2MemoryCards()
    }

    private lazy var gameLibrarySettingsButton = makeProfileMenuButton(title: "Game Library View",
                                                                        subtitle: "Sort and filter games",
                                                                        symbol: "line.3.horizontal.decrease.circle") { [weak self] in
        self?.openLibraryViewSettings(.games)
    }

    private lazy var consoleLibrarySettingsButton = makeProfileMenuButton(title: "Console Library View",
                                                                           subtitle: "Sort and filter consoles",
                                                                           symbol: "arrow.up.arrow.down.circle") { [weak self] in
        self?.openLibraryViewSettings(.consoles)
    }

    private lazy var avatarButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        button.layer.cornerRadius = 48
        button.clipsToBounds = true
        button.imageView?.contentMode = .scaleAspectFill
        button.tintColor = .white
        button.isFocusable = true
        button.enableFocusEffects = false
        button.addTarget(self, action: #selector(changeAvatarPressed), for: .touchUpInside)
        button.onFocusChange = { [weak button] focused in
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]) {
                button?.transform = focused ? CGAffineTransform(scaleX: 1.07, y: 1.07) : .identity
                button?.layer.borderWidth = focused ? 2 : 0
                button?.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
            }
        }
        button.onFocusConfirm = { [weak self] in
            self?.changeAvatarPressed()
            return true
        }
        return button
    }()

    private let profileNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 1
        return label
    }()

    private let profileStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.62)
        label.numberOfLines = 2
        return label
    }()

    private let profileStatsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.82)
        label.numberOfLines = 0
        return label
    }()

    private let retroStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.76)
        label.numberOfLines = 2
        return label
    }()

    private lazy var editNameButton = makeProfileButton(title: "Edit display name", symbol: "pencil") { [weak self] in
        self?.editProfileName()
    }

    private lazy var editStatusButton = makeProfileButton(title: "Edit profile status", symbol: "text.bubble") { [weak self] in
        self?.editProfileStatus()
    }

    private lazy var changeAvatarButton = makeProfileButton(title: "Change avatar", symbol: "photo") { [weak self] in
        self?.changeAvatarPressed()
    }

    private lazy var retroButton = makeProfileButton(title: "RetroAchievements", symbol: "trophy.fill") { [weak self] in
        self?.openRetroAchievements()
    }

    private lazy var historyButton = makeProfileButton(title: "Play history", symbol: "clock.arrow.circlepath") { [weak self] in
        self?.openPlayHistory()
    }

    private lazy var coverModeControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [XMBCoverMode.original.title, XMBCoverMode.square.title])
        control.selectedSegmentIndex = coverMode.rawValue
        control.selectedSegmentTintColor = UIColor.white.withAlphaComponent(0.22)
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        control.setTitleTextAttributes([.foregroundColor: UIColor.white.withAlphaComponent(0.60)], for: .normal)
        control.addTarget(self, action: #selector(coverModeChanged(_:)), for: .valueChanged)
        control.isFocusable = true
        control.enableFocusEffects = false
        control.onFocusConfirm = { [weak self, weak control] in
            guard let self, let control else { return true }
            let next = control.selectedSegmentIndex == 0 ? 1 : 0
            control.selectedSegmentIndex = next
            self.coverModeChanged(control)
            return true
        }
        return control
    }()

    private lazy var hintsSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.isOn = showControllerHints
        toggle.addTarget(self, action: #selector(hintsChanged(_:)), for: .valueChanged)
        toggle.isFocusable = true
        toggle.enableFocusEffects = false
        toggle.onFocusConfirm = { [weak self, weak toggle] in
            guard let self, let toggle else { return true }
            toggle.setOn(!toggle.isOn, animated: true)
            self.hintsChanged(toggle)
            return true
        }
        return toggle
    }()

    private let actionContainerView = UIView()
    private let actionSymbolView = UIImageView()
    private let actionTitleLabel = UILabel()
    private let actionSubtitleLabel = UILabel()
    private lazy var actionButton = makeActionButton()

    private let controlsHintLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.48)
        label.textAlignment = .center
        label.text = "◀ ▶  systems     ▲ ▼  games     ✕  open     ○  back     L1 / R1  systems"
        label.numberOfLines = 1
        label.isHidden = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupXMB()
        observeGames()
        updateClock()
        applyControllerHintVisibility()

        consoleIconObserver = NotificationCenter.default.addObserver(forName: .xmbConsoleIconsDidChange,
                                                                     object: nil,
                                                                     queue: .main) { [weak self] _ in
            self?.refreshSectionButtonImages()
        }
        librarySettingsObserver = NotificationCenter.default.addObserver(forName: .xmbLibraryViewSettingsDidChange,
                                                                          object: nil,
                                                                          queue: .main) { [weak self] _ in
            guard let self else { return }
            self.refreshProfileMenuSettingsLabels()
            self.rebuildSectionsAndContent()
        }

        clockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateClock()
        }
    }

    deinit {
        libraryRefreshWorkItem?.cancel()
        gameToken = nil
        clockTimer?.invalidate()
        if let consoleIconObserver {
            NotificationCenter.default.removeObserver(consoleIconObserver)
        }
        if let librarySettingsObserver {
            NotificationCenter.default.removeObserver(librarySettingsObserver)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        ExternalInputDispatch.sink = .focusKit
        FocusSystem.shared.isEnabled = true

        activateFocusRoot { [weak self] context in
            guard let self else { return }
            context.autoFocusOnActivate = true
            context.preferredFocusView = { [weak self] in
                self?.preferredXMBFocusView()
            }
            context.addCommands([
                FocusCommand(key: .left, title: "Previous system", action: { [weak self] in
                    self?.moveSection(by: -1)
                }),
                FocusCommand(key: .right, title: "Next system", action: { [weak self] in
                    self?.moveSection(by: 1)
                }),
                FocusCommand(key: .up, title: "Previous game", handler: { [weak self] in
                    self?.moveGame(by: -1) ?? false
                }),
                FocusCommand(key: .down, title: "Next game", handler: { [weak self] in
                    self?.moveGame(by: 1) ?? false
                }),
                FocusCommand(key: FocusKey("l1"), title: "Previous system", action: { [weak self] in
                    self?.moveSection(by: -1)
                }),
                FocusCommand(key: FocusKey("r1"), title: "Next system", action: { [weak self] in
                    self?.moveSection(by: 1)
                })
            ])
        }

        if FocusSystem.shared.hasExternalInput {
            DispatchQueue.main.async {
                FocusSystem.shared.updateFocusIfNeeded()
            }
        }

        refreshProfile()

        // A full-screen Import/Settings/Manic screen can change the Realm library.
        // Reload from a fresh detached snapshot only after returning to the XMB.
        scheduleLibraryRefresh()

        if pendingLibraryRefresh {
            pendingLibraryRefresh = false
            scheduleLibraryRefresh()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if hasFocusContext {
            popFocusContext()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Keep the XMB rail slightly above center so the selected system can reveal
        // a useful vertical game column beneath it, matching the classic XMB layout.
        sectionCenterConstraint?.update(offset: -view.bounds.height * 0.12)

        let sideInset = max(0, (sectionScrollView.bounds.width - 86) / 2)
        sectionScrollView.contentInset.left = sideInset
        sectionScrollView.contentInset.right = sideInset

        if sections.indices.contains(selectedSectionIndex) {
            scrollSelectedSectionIntoView(animated: false)
        }

        updateGameColumnInsets()

        if sections.indices.contains(selectedSectionIndex),
           case .console = sections[selectedSectionIndex].kind,
           !games.isEmpty,
           !isTouchScrollingGames,
           !isProgrammaticGameScroll,
           !collectionView.isDragging,
           !collectionView.isDecelerating {
            scrollGameToAnchor(index: rememberedIndexForCurrentSection(), animated: false)
        }
    }

    private func setupXMB() {
        view.backgroundColor = UIColor(red: 0.008, green: 0.045, blue: 0.13, alpha: 1)

        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        view.addSubview(dateLabel)
        dateLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(10)
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-20)
        }

        view.addSubview(selectedSectionGlow)
        selectedSectionGlow.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.height.equalTo(68)
        }

        view.addSubview(sectionScrollView)
        sectionScrollView.delegate = self
        sectionScrollView.snp.makeConstraints { make in
            sectionCenterConstraint = make.centerY.equalToSuperview().offset(-40).constraint
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(92)
        }

        selectedSectionGlow.snp.makeConstraints { make in
            make.centerY.equalTo(sectionScrollView).offset(-8)
        }

        sectionScrollView.addSubview(sectionStack)
        sectionStack.snp.makeConstraints { make in
            make.edges.equalTo(sectionScrollView.contentLayoutGuide)
            make.height.equalTo(sectionScrollView.frameLayoutGuide)
        }

        // The selected system is already labelled in the horizontal rail, so avoid a
        // duplicate title/subtitle between the rail and its games. Keeping these labels
        // hidden also leaves substantially more vertical room on iPhone landscape.
        titleLabel.isHidden = true
        subtitleLabel.isHidden = true

        // The game column intentionally spans the entire safe area instead of living in a
        // cropped panel below the console rail. The first game begins beneath the selected
        // console, but when the user moves down, previous games remain visible above the
        // console row instead of disappearing at a panel boundary.
        view.addSubview(gamesContentView)
        gamesContentView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        gamesContentView.addSubview(listContainerView)
        listContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        listContainerView.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // Keep the horizontal console rail visually above games that scroll through it.
        view.bringSubviewToFront(selectedSectionGlow)
        view.bringSubviewToFront(sectionScrollView)
        view.bringSubviewToFront(dateLabel)

        view.addSubview(profileContainerView)
        profileContainerView.isHidden = true
        profileContainerView.snp.makeConstraints { make in
            make.top.equalTo(sectionScrollView.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
            make.width.equalTo(560).priority(.high)
            make.leading.greaterThanOrEqualTo(view.safeAreaLayoutGuide).offset(18)
            make.trailing.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-18)
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        profileContainerView.addSubview(profileContentView)
        profileContentView.snp.makeConstraints { make in
            make.edges.equalTo(profileContainerView.contentLayoutGuide)
            make.width.equalTo(profileContainerView.frameLayoutGuide)
        }

        setupProfileManager()

        view.addSubview(profileMenuContainerView)
        profileMenuContainerView.isHidden = true
        profileMenuContainerView.snp.makeConstraints { make in
            make.top.equalTo(sectionScrollView.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
            make.width.equalTo(440).priority(.high)
            make.leading.greaterThanOrEqualTo(view.safeAreaLayoutGuide).offset(24)
            make.trailing.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-24)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-10)
        }

        let profileMenuStack = UIStackView(arrangedSubviews: [
            profileDetailsButton,
            ps2MemoryCardsButton,
            gameLibrarySettingsButton,
            consoleLibrarySettingsButton
        ])
        profileMenuStack.axis = .vertical
        profileMenuStack.alignment = .fill
        profileMenuStack.distribution = .fill
        profileMenuStack.spacing = 5
        profileMenuContainerView.addSubview(profileMenuStack)
        profileMenuStack.snp.makeConstraints { make in
            make.edges.equalTo(profileMenuContainerView.contentLayoutGuide)
            make.width.equalTo(profileMenuContainerView.frameLayoutGuide)
        }
        [profileDetailsButton, ps2MemoryCardsButton, gameLibrarySettingsButton, consoleLibrarySettingsButton].forEach {
            $0.snp.makeConstraints { $0.height.equalTo(58) }
        }

        view.addSubview(actionContainerView)
        actionContainerView.isHidden = true
        actionContainerView.snp.makeConstraints { make in
            make.top.equalTo(sectionScrollView.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.width.equalTo(400).priority(.high)
            make.leading.greaterThanOrEqualTo(view.safeAreaLayoutGuide).offset(24)
            make.trailing.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-24)
            make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-18)
        }
        setupActionView()

        view.addSubview(controlsHintLabel)
        controlsHintLabel.snp.makeConstraints { make in
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-6)
            make.height.equalTo(20)
        }
    }

    private func setupProfileManager() {
        let header = UIView()
        let preferenceCard = makeProfileCard()
        let achievementsCard = makeProfileCard()

        profileContentView.addSubview(header)
        profileContentView.addSubview(preferenceCard)
        profileContentView.addSubview(achievementsCard)

        header.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.greaterThanOrEqualTo(122)
        }

        header.addSubview(avatarButton)
        header.addSubview(profileNameLabel)
        header.addSubview(profileStatusLabel)

        avatarButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(6)
            make.top.equalToSuperview().offset(8)
            make.width.height.equalTo(96)
        }

        profileNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarButton.snp.trailing).offset(18)
            make.trailing.equalToSuperview().offset(-8)
            make.top.equalTo(avatarButton).offset(10)
        }

        profileStatusLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(profileNameLabel)
            make.top.equalTo(profileNameLabel.snp.bottom).offset(5)
        }

        let editStack = UIStackView(arrangedSubviews: [editNameButton, editStatusButton, changeAvatarButton])
        editStack.axis = .horizontal
        editStack.alignment = .fill
        editStack.distribution = .fillEqually
        editStack.spacing = 8
        header.addSubview(editStack)
        editStack.snp.makeConstraints { make in
            make.leading.equalTo(profileNameLabel)
            make.trailing.equalToSuperview().offset(-8)
            make.top.greaterThanOrEqualTo(profileStatusLabel.snp.bottom).offset(8)
            make.bottom.equalToSuperview().offset(-4)
            make.height.equalTo(38)
        }

        preferenceCard.addSubview(profileStatsLabel)
        profileStatsLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(14)
        }

        let coverTitle = makeSmallProfileLabel("Game cover shape")
        preferenceCard.addSubview(coverTitle)
        preferenceCard.addSubview(coverModeControl)
        coverTitle.snp.makeConstraints { make in
            make.top.equalTo(profileStatsLabel.snp.bottom).offset(18)
            make.leading.equalToSuperview().offset(14)
        }
        coverModeControl.snp.makeConstraints { make in
            make.centerY.equalTo(coverTitle)
            make.trailing.equalToSuperview().offset(-14)
            make.width.equalTo(190)
        }

        let hintsTitle = makeSmallProfileLabel("Show controller instructions")
        preferenceCard.addSubview(hintsTitle)
        preferenceCard.addSubview(hintsSwitch)
        hintsTitle.snp.makeConstraints { make in
            make.top.equalTo(coverTitle.snp.bottom).offset(22)
            make.leading.equalTo(coverTitle)
            make.bottom.equalToSuperview().offset(-16)
        }
        hintsSwitch.snp.makeConstraints { make in
            make.centerY.equalTo(hintsTitle)
            make.trailing.equalToSuperview().offset(-14)
        }

        achievementsCard.addSubview(retroStatusLabel)
        retroStatusLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(14)
        }

        let raActions = UIStackView(arrangedSubviews: [retroButton, historyButton])
        raActions.axis = .horizontal
        raActions.alignment = .fill
        raActions.distribution = .fillEqually
        raActions.spacing = 8
        achievementsCard.addSubview(raActions)
        raActions.snp.makeConstraints { make in
            make.top.equalTo(retroStatusLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(14)
            make.bottom.equalToSuperview().offset(-14)
            make.height.equalTo(42)
        }

        preferenceCard.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
        }

        achievementsCard.snp.makeConstraints { make in
            make.top.equalTo(preferenceCard.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
        }
    }

    private func setupActionView() {
        actionContainerView.clipsToBounds = false
        actionContainerView.backgroundColor = .clear

        actionTitleLabel.textColor = .white
        actionTitleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        actionTitleLabel.textAlignment = .center
        actionTitleLabel.numberOfLines = 1
        actionTitleLabel.adjustsFontSizeToFitWidth = true
        actionTitleLabel.minimumScaleFactor = 0.82
        actionTitleLabel.lineBreakMode = .byTruncatingTail
        actionTitleLabel.layer.shadowColor = UIColor.black.cgColor
        actionTitleLabel.layer.shadowOpacity = 0.38
        actionTitleLabel.layer.shadowRadius = 2
        actionTitleLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        actionTitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        actionTitleLabel.setContentHuggingPriority(.required, for: .vertical)

        actionSubtitleLabel.textColor = UIColor.white.withAlphaComponent(0.68)
        actionSubtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        actionSubtitleLabel.textAlignment = .center
        actionSubtitleLabel.numberOfLines = 1
        actionSubtitleLabel.lineBreakMode = .byTruncatingTail
        actionSubtitleLabel.adjustsFontSizeToFitWidth = true
        actionSubtitleLabel.minimumScaleFactor = 0.86
        actionSubtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        actionSymbolView.tintColor = UIColor.white.withAlphaComponent(0.94)
        actionSymbolView.contentMode = .scaleAspectFit

        actionContainerView.addSubview(actionTitleLabel)
        actionContainerView.addSubview(actionSubtitleLabel)
        actionContainerView.addSubview(actionSymbolView)
        actionContainerView.addSubview(actionButton)

        // Put the bold white heading first and give it a real height. This avoids the
        // compressed/cropped title that could occur on landscape phones.
        actionTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(2)
            make.leading.trailing.equalToSuperview().inset(10)
            make.height.equalTo(30)
        }
        actionSubtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(actionTitleLabel.snp.bottom).offset(2)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(18)
        }
        actionSymbolView.snp.makeConstraints { make in
            make.top.equalTo(actionSubtitleLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(38)
        }
        actionButton.snp.makeConstraints { make in
            make.top.equalTo(actionSymbolView.snp.bottom).offset(9)
            make.centerX.equalToSuperview()
            make.width.equalTo(176)
            make.height.equalTo(40)
            make.bottom.equalToSuperview().offset(-2)
        }
    }

    private func makeProfileCard() -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.14)
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        return view
    }

    private func makeSmallProfileLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.76)
        return label
    }

    private func makeXMBOptionsButton(symbol: String,
                                      title: String,
                                      menuWillOpen: @escaping () -> Void) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = safeSystemImage(symbol)
        configuration.title = title
        configuration.imagePadding = 5
        configuration.baseForegroundColor = UIColor.white.withAlphaComponent(0.76)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 7, bottom: 5, trailing: 7)

        let button = UIButton(configuration: configuration)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.10)
        button.layer.cornerRadius = 10
        button.showsMenuAsPrimaryAction = true
        button.isFocusable = true
        button.enableFocusEffects = false
        button.addAction(UIAction { _ in menuWillOpen() }, for: .menuActionTriggered)
        button.onFocusChange = { [weak button] focused in
            UIView.animate(withDuration: 0.14) {
                button?.backgroundColor = focused
                    ? UIColor.white.withAlphaComponent(0.14)
                    : UIColor.black.withAlphaComponent(0.10)
                button?.transform = focused ? CGAffineTransform(scaleX: 1.04, y: 1.04) : .identity
            }
        }
        return button
    }

    private func refreshViewOptionMenus() {
        let selectedGameSort = gameSort
        let selectedGameFilter = gameFilter
        let gameSortActions = XMBGameSort.allCases.map { value in
            UIAction(title: value.title,
                     state: value == selectedGameSort ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.gameSort = value
                self.refreshViewOptionMenus()
                self.updateSelectedSection(animated: true, restoreFocus: false)
            }
        }
        let gameFilterActions = XMBGameFilter.allCases.map { value in
            UIAction(title: value.title,
                     state: value == selectedGameFilter ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.gameFilter = value
                self.refreshViewOptionMenus()
                self.updateSelectedSection(animated: true, restoreFocus: false)
            }
        }
        gameOptionsButton.menu = UIMenu(title: "Game View",
                                        children: [
                                            UIMenu(title: "Sort", options: .displayInline, children: gameSortActions),
                                            UIMenu(title: "Filter", options: .displayInline, children: gameFilterActions)
                                        ])

        let selectedConsoleSort = consoleSort
        let selectedConsoleFilter = consoleFilter
        let consoleSortActions = XMBConsoleSort.allCases.map { value in
            UIAction(title: value.title,
                     state: value == selectedConsoleSort ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.consoleSort = value
                self.refreshViewOptionMenus()
                self.rebuildSectionsAndContent()
            }
        }
        let consoleFilterActions = XMBConsoleFilter.allCases.map { value in
            UIAction(title: value.title,
                     state: value == selectedConsoleFilter ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.consoleFilter = value
                self.refreshViewOptionMenus()
                self.rebuildSectionsAndContent()
            }
        }
        consoleOptionsButton.menu = UIMenu(title: "System View",
                                           children: [
                                               UIMenu(title: "Sort", options: .displayInline, children: consoleSortActions),
                                               UIMenu(title: "Filter", options: .displayInline, children: consoleFilterActions)
                                           ])
    }

    private func makeProfileMenuButton(title: String,
                                       subtitle: String,
                                       symbol: String,
                                       action: @escaping () -> Void) -> XMBProfileMenuButton {
        let button = XMBProfileMenuButton(title: title,
                                          subtitle: subtitle,
                                          image: safeSystemImage(symbol))
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusChange = { [weak button] focused in
            button?.setXMBFocused(focused)
        }
        button.onFocusConfirm = {
            action()
            return true
        }
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func makeProfileButton(title: String, symbol: String, action: @escaping () -> Void) -> UIButton {
        var configuration = UIButton.Configuration.gray()
        configuration.title = title
        configuration.image = safeSystemImage(symbol)
        configuration.imagePadding = 7
        configuration.baseForegroundColor = .white
        configuration.background.backgroundColor = UIColor.white.withAlphaComponent(0.09)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 9, bottom: 6, trailing: 9)

        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusChange = { [weak button] focused in
            UIView.animate(withDuration: 0.12) {
                if var configuration = button?.configuration {
                    configuration.background.backgroundColor = focused
                        ? UIColor.white.withAlphaComponent(0.22)
                        : UIColor.white.withAlphaComponent(0.09)
                    button?.configuration = configuration
                }
                button?.transform = focused ? CGAffineTransform(scaleX: 1.02, y: 1.02) : .identity
            }
        }
        button.onFocusConfirm = {
            action()
            return true
        }
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func makeActionButton() -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Open"
        configuration.baseForegroundColor = .white
        configuration.baseBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.78)
        configuration.cornerStyle = .capsule

        let button = UIButton(configuration: configuration)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusChange = { [weak button] focused in
            UIView.animate(withDuration: 0.12) {
                button?.transform = focused ? CGAffineTransform(scaleX: 1.06, y: 1.06) : .identity
            }
        }
        button.onFocusConfirm = { [weak self] in
            self?.activateActionSection()
            return true
        }
        button.addTarget(self, action: #selector(actionButtonPressed), for: .touchUpInside)
        return button
    }

    private func observeGames() {
        // Do not hold a live Results notification here. The import pipeline performs
        // multiple Realm writes/replacements in quick succession, which can invalidate
        // objects that collection-view cells are still rendering. Instead, refresh a
        // detached value snapshot when the XMB appears/returns from a modal screen.
        gameToken = nil
        scheduleLibraryRefresh()
    }

    /// Coalesce library refreshes and apply them only while the XMB itself is visible.
    private func scheduleLibraryRefresh() {
        libraryRefreshWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.presentedViewController == nil, self.viewIfLoaded?.window != nil else {
                self.pendingLibraryRefresh = true
                return
            }
            self.performLibraryRefresh()
        }

        libraryRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: workItem)
    }

    private func performLibraryRefresh() {
        guard !isRefreshingLibrary else {
            pendingLibraryRefresh = true
            return
        }

        isRefreshingLibrary = true
        pendingLibraryRefresh = false
        rebuildSectionsAndContent()
        isRefreshingLibrary = false

        if pendingLibraryRefresh {
            pendingLibraryRefresh = false
            scheduleLibraryRefresh()
        }
    }

    private func rebuildSectionsAndContent() {
        // Copy only primitive/value data out of Realm. UIKit must never retain live Game
        // rows because imports can invalidate or replace those rows underneath the XMB.
        let realmResults = Database.realm.objects(Game.self).where { !$0.isDeleted }
        let snapshot = Array(realmResults.compactMap { XMBGameItem(game: $0) })
        libraryGames = snapshot

        let existingIdentifier = sections.indices.contains(selectedSectionIndex)
            ? sections[selectedSectionIndex].identifier
            : UserDefaults.standard.string(forKey: Self.selectedSectionDefaultsKey)

        let availableTypes = Set(snapshot.map(\.gameType))
        var orderedTypes: [GameType]

        switch consoleFilter {
        case .libraryOnly:
            orderedTypes = System.allGameTypes.filter { availableTypes.contains($0) }
            let extras = availableTypes
                .filter { !orderedTypes.contains($0) }
                .sorted { $0.localizedShortName.localizedCaseInsensitiveCompare($1.localizedShortName) == .orderedAscending }
            orderedTypes.append(contentsOf: extras)

        case .allSystems:
            orderedTypes = System.allGameTypes
            let extras = availableTypes
                .filter { !orderedTypes.contains($0) }
                .sorted { $0.localizedShortName.localizedCaseInsensitiveCompare($1.localizedShortName) == .orderedAscending }
            orderedTypes.append(contentsOf: extras)

        case .playedSystems:
            orderedTypes = System.allGameTypes.filter { gameType in
                snapshot.contains { $0.gameType == gameType && $0.totalPlayDuration > 0 }
            }
            let extras = availableTypes
                .filter { type in
                    !orderedTypes.contains(type) &&
                    snapshot.contains { $0.gameType == type && $0.totalPlayDuration > 0 }
                }
                .sorted { $0.localizedShortName.localizedCaseInsensitiveCompare($1.localizedShortName) == .orderedAscending }
            orderedTypes.append(contentsOf: extras)
        }

        switch consoleSort {
        case .systemDefault:
            break
        case .nameAZ:
            orderedTypes.sort {
                $0.localizedShortName.localizedCaseInsensitiveCompare($1.localizedShortName) == .orderedAscending
            }
        case .nameZA:
            orderedTypes.sort {
                $0.localizedShortName.localizedCaseInsensitiveCompare($1.localizedShortName) == .orderedDescending
            }
        case .recentlyPlayed:
            orderedTypes.sort {
                latestPlayDate(for: $0, in: snapshot) > latestPlayDate(for: $1, in: snapshot)
            }
        case .mostPlayed:
            orderedTypes.sort {
                totalPlayTime(for: $0, in: snapshot) > totalPlayTime(for: $1, in: snapshot)
            }
        case .manufacturer:
            let order = Dictionary(uniqueKeysWithValues: Manufacturer.allCases.enumerated().map { ($1, $0) })
            orderedTypes.sort {
                let leftRank = order[$0.manufacturer] ?? Int.max
                let rightRank = order[$1.manufacturer] ?? Int.max
                if leftRank != rightRank { return leftRank < rightRank }
                return $0.localizedShortName.localizedCaseInsensitiveCompare($1.localizedShortName) == .orderedAscending
            }
        }

        var rebuilt = [
            XMBSection(kind: .profile, title: "Profile", symbol: "person.crop.circle.fill")
        ]

        rebuilt.append(contentsOf: orderedTypes.map { gameType in
            XMBSection(kind: .console(gameType),
                       title: gameType.localizedShortName,
                       symbol: symbol(for: gameType))
        })

        rebuilt.append(contentsOf: [
            XMBSection(kind: .importGames, title: "Import", symbol: "square.and.arrow.down.fill"),
            XMBSection(kind: .settings, title: "Settings", symbol: "gearshape.fill"),
            XMBSection(kind: .classicHome, title: "Manic", symbol: "square.grid.2x2.fill")
        ])

        sections = rebuilt
        rebuildSectionButtons()

        if let existingIdentifier,
           let restored = sections.firstIndex(where: { $0.identifier == existingIdentifier }) {
            selectedSectionIndex = restored
        } else if let firstConsole = sections.firstIndex(where: {
            if case .console = $0.kind { return true }
            return false
        }) {
            selectedSectionIndex = firstConsole
        } else {
            selectedSectionIndex = 0
        }

        updateSelectedSection(animated: false, restoreFocus: false)
        refreshProfile()
        refreshProfileMenuSettingsLabels()
    }

    private func rebuildSectionButtons() {
        sectionButtons.forEach { $0.removeFromSuperview() }
        sectionButtons.removeAll()

        for (index, section) in sections.enumerated() {
            var configuration = UIButton.Configuration.plain()
            configuration.image = sectionImage(for: section)
            configuration.imagePlacement = .top
            configuration.imagePadding = 6
            configuration.title = section.title
            configuration.baseForegroundColor = UIColor.white.withAlphaComponent(0.54)
            configuration.contentInsets = .zero
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 11, weight: .medium)
                return outgoing
            }

            let button = UIButton(configuration: configuration)
            button.tag = index
            button.alpha = 0.64
            button.addTarget(self, action: #selector(sectionTapped(_:)), for: .touchUpInside)
            button.imageView?.contentMode = .scaleAspectFit
            button.titleLabel?.shadowColor = UIColor.black.withAlphaComponent(0.40)
            button.titleLabel?.shadowOffset = CGSize(width: 0, height: 1)
            button.snp.makeConstraints { make in
                make.width.equalTo(86)
                make.height.equalTo(80)
            }

            sectionButtons.append(button)
            sectionStack.addArrangedSubview(button)
        }
    }

    @objc private func sectionTapped(_ sender: UIButton) {
        guard sections.indices.contains(sender.tag) else { return }
        rememberCurrentGameIndex()
        pendingSectionTransitionDirection = sender.tag == selectedSectionIndex ? 0 : (sender.tag > selectedSectionIndex ? 1 : -1)
        selectedSectionIndex = sender.tag
        updateSelectedSection(animated: true, restoreFocus: false)
    }

    private func moveSection(by offset: Int) {
        guard !sections.isEmpty else { return }

        rememberCurrentGameIndex()

        let newIndex = min(max(selectedSectionIndex + offset, 0), sections.count - 1)
        guard newIndex != selectedSectionIndex else { return }

        pendingSectionTransitionDirection = newIndex > selectedSectionIndex ? 1 : -1
        selectedSectionIndex = newIndex
        updateSelectedSection(animated: true, restoreFocus: true)
    }

    private func updateSelectedSection(animated: Bool, restoreFocus: Bool) {
        guard sections.indices.contains(selectedSectionIndex) else { return }
        let section = sections[selectedSectionIndex]

        UserDefaults.standard.set(section.identifier, forKey: Self.selectedSectionDefaultsKey)

        for (index, button) in sectionButtons.enumerated() {
            let selected = index == selectedSectionIndex
            if var configuration = button.configuration {
                configuration.baseForegroundColor = selected ? .white : UIColor.white.withAlphaComponent(0.50)
                configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var outgoing = incoming
                    outgoing.font = .systemFont(ofSize: selected ? 12 : 11,
                                                weight: selected ? .semibold : .medium)
                    return outgoing
                }
                button.configuration = configuration
            }
            let visualChanges = {
                button.alpha = selected ? 1.0 : 0.60
                button.transform = selected ? CGAffineTransform(scaleX: 1.14, y: 1.14) : .identity
                button.layer.shadowColor = selected ? UIColor.systemCyan.cgColor : UIColor.clear.cgColor
                button.layer.shadowOpacity = selected ? 0.55 : 0
                button.layer.shadowRadius = selected ? 12 : 0
            }
            if animated {
                UIView.animate(withDuration: 0.19,
                               delay: 0,
                               usingSpringWithDamping: 0.90,
                               initialSpringVelocity: 0.15,
                               options: [.beginFromCurrentState, .allowUserInteraction],
                               animations: visualChanges)
            } else {
                visualChanges()
            }
        }

        if !isTouchScrollingSections {
            scrollSelectedSectionIntoView(animated: animated)
        }
        titleLabel.text = section.title

        let showGames: Bool
        let showProfileMenu: Bool
        let showAction: Bool

        switch section.kind {
        case .console(let gameType):
            games = filteredAndSortedGames(for: gameType)
            showGames = true
            showProfileMenu = false
            showAction = false
            subtitleLabel.text = games.isEmpty ? "No games in this system" : "\(games.count) game\(games.count == 1 ? "" : "s")"

        case .profile:
            games = []
            showGames = false
            showProfileMenu = true
            showAction = false
            subtitleLabel.text = "Custom XMB profile"
            refreshProfile()
            refreshProfileMenuSettingsLabels()

        case .importGames:
            games = []
            showGames = false
            showProfileMenu = false
            showAction = true
            subtitleLabel.text = "Add games to your library"
            configureActionView(title: "Import Games",
                                subtitle: "Add games to your library",
                                symbol: "square.and.arrow.down.fill")

        case .settings:
            games = []
            showGames = false
            showProfileMenu = false
            showAction = true
            subtitleLabel.text = "Controllers, cores, networking and more"
            configureActionView(title: "Settings",
                                subtitle: "Controllers  •  Video  •  Audio  •  Cores",
                                symbol: "gearshape.fill")

        case .classicHome:
            games = []
            showGames = false
            showProfileMenu = false
            showAction = true
            subtitleLabel.text = "Original ManicEMU interface"
            configureActionView(title: "ManicEMU",
                                subtitle: "Open the original interface",
                                symbol: "square.grid.2x2.fill")
        }

        gamesContentView.isHidden = !showGames
        // Account details now live on their own XMB-styled screen.
        profileContainerView.isHidden = true
        profileMenuContainerView.isHidden = !showProfileMenu
        actionContainerView.isHidden = !showAction

        if showAction {
            view.bringSubviewToFront(actionContainerView)
        } else if showProfileMenu {
            view.bringSubviewToFront(profileMenuContainerView)
        }
        view.bringSubviewToFront(selectedSectionGlow)
        view.bringSubviewToFront(sectionScrollView)
        view.bringSubviewToFront(dateLabel)

        let initialIndex = games.isEmpty ? 0 : rememberedIndexForCurrentSection()
        UIView.performWithoutAnimation {
            gameColumnLayout.focusPosition = CGFloat(initialIndex)
            collectionView.reloadData()
            updateGameColumnInsets()
            collectionView.layoutIfNeeded()
            if games.indices.contains(initialIndex) {
                scrollGameToAnchor(index: initialIndex, animated: false)
            } else {
                let top = -collectionView.contentInset.top
                collectionView.setContentOffset(CGPoint(x: 0, y: top), animated: false)
            }
            collectionView.layoutIfNeeded()
        }

        let shownView: UIView? = showGames ? gamesContentView : (showProfileMenu ? profileMenuContainerView : (showAction ? actionContainerView : nil))
        let direction = pendingSectionTransitionDirection
        pendingSectionTransitionDirection = 0

        let updates = {
            self.gamesContentView.alpha = showGames ? 1 : 0
            self.profileMenuContainerView.alpha = showProfileMenu ? 1 : 0
            self.actionContainerView.alpha = showAction ? 1 : 0
            shownView?.transform = .identity
        }

        if animated {
            if direction != 0 {
                shownView?.alpha = 0.25
                shownView?.transform = CGAffineTransform(translationX: direction * 24, y: 0)
            }
            UIView.animate(withDuration: 0.24,
                           delay: 0,
                           options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction],
                           animations: updates)
        } else {
            updates()
        }

        if restoreFocus, FocusSystem.shared.hasExternalInput {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if showGames {
                    self.focusGame(at: self.rememberedIndexForCurrentSection())
                } else if showProfileMenu {
                    FocusSystem.shared.focus(self.profileDetailsButton)
                } else if showAction {
                    FocusSystem.shared.focus(self.actionButton)
                }
            }
        }
    }

    private func filteredAndSortedGames(for gameType: GameType) -> [XMBGameItem] {
        var result = libraryGames.filter { $0.gameType == gameType }

        switch gameFilter {
        case .all:
            break
        case .played:
            result = result.filter { $0.totalPlayDuration > 0 }
        case .unplayed:
            result = result.filter { $0.totalPlayDuration <= 0 }
        case .hasSave:
            result = result.filter(\.hasSaveData)
        }

        switch gameSort {
        case .nameAZ:
            result.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .nameZA:
            result.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedDescending }
        case .recentlyPlayed:
            result.sort { ($0.latestPlayDate ?? .distantPast) > ($1.latestPlayDate ?? .distantPast) }
        case .mostPlayed:
            result.sort { $0.totalPlayDuration > $1.totalPlayDuration }
        case .recentlyAdded:
            result.sort { $0.importDate > $1.importDate }
        }
        return result
    }

    private func totalPlayTime(for gameType: GameType, in snapshot: [XMBGameItem]) -> Double {
        snapshot.lazy
            .filter { $0.gameType == gameType }
            .reduce(0) { $0 + $1.totalPlayDuration }
    }

    private func latestPlayDate(for gameType: GameType, in snapshot: [XMBGameItem]) -> Date {
        snapshot.lazy
            .filter { $0.gameType == gameType }
            .compactMap(\.latestPlayDate)
            .max() ?? .distantPast
    }

    private var gameRowHeight: CGFloat {
        coverMode == .square ? 52 : 58
    }

    private var gameRowStride: CGFloat {
        gameRowHeight + gameColumnLayout.minimumLineSpacing
    }

    @discardableResult
    private func moveGame(by offset: Int) -> Bool {
        guard sections.indices.contains(selectedSectionIndex),
              case .console = sections[selectedSectionIndex].kind,
              !games.isEmpty else { return false }

        let current = rememberedIndexForCurrentSection()
        let next = min(max(current + offset, 0), games.count - 1)
        guard next != current else { return true }
        focusGame(at: next)
        return true
    }

    private func refreshProfileMenuSettingsLabels() {
        func update(_ button: XMBProfileMenuButton, subtitle: String) {
            button.setSubtitle(subtitle)
        }
        update(gameLibrarySettingsButton,
               subtitle: "Sort: \(gameSort.title)  •  Filter: \(gameFilter.title)")
        update(consoleLibrarySettingsButton,
               subtitle: "Sort: \(consoleSort.title)  •  Filter: \(consoleFilter.title)")
    }

    private func openLibraryViewSettings(_ kind: XMBLibraryViewSettingsKind) {
        let controller = XMBLibraryViewSettingsViewController(kind: kind)
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true)
    }

    private func rememberCurrentGameIndex() {
        guard sections.indices.contains(selectedSectionIndex), !games.isEmpty else { return }
        let sectionID = sections[selectedSectionIndex].identifier

        if let focused = FocusSystem.shared.currentFocusedView,
           let cell = focused as? UICollectionViewCell,
           let indexPath = collectionView.indexPath(for: cell) {
            rememberedGameIndex[sectionID] = indexPath.item
        } else if let selected = collectionView.indexPathsForSelectedItems?.first {
            rememberedGameIndex[sectionID] = selected.item
        }
    }

    private func rememberedIndexForCurrentSection() -> Int {
        guard sections.indices.contains(selectedSectionIndex), !games.isEmpty else { return 0 }
        let remembered = rememberedGameIndex[sections[selectedSectionIndex].identifier] ?? 0
        return min(max(remembered, 0), games.count - 1)
    }

    private func preferredXMBFocusView() -> UIView? {
        guard sections.indices.contains(selectedSectionIndex) else { return collectionView }

        switch sections[selectedSectionIndex].kind {
        case .console:
            return collectionView
        case .profile:
            return profileDetailsButton
        case .importGames, .settings, .classicHome:
            return actionButton
        }
    }

    private func focusGame(at index: Int) {
        guard !games.isEmpty else {
            FocusSystem.shared.updateFocusIfNeeded()
            return
        }

        let clamped = min(max(index, 0), games.count - 1)
        let indexPath = IndexPath(item: clamped, section: 0)

        updateFocusedGame(index: clamped)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { [weak self] in
            guard let self else { return }
            self.collectionView.layoutIfNeeded()
            if let cell = self.collectionView.cellForItem(at: indexPath) {
                FocusSystem.shared.focus(cell)
            } else {
                FocusSystem.shared.updateFocusIfNeeded()
            }
        }
    }

    private func updateGameColumnInsets() {
        guard collectionView.bounds.height > 0 else { return }

        // sectionScrollView and gamesContentView are both ultimately laid out against the
        // root view. Use that stable screen-space geometry instead of converting directly
        // into UICollectionView coordinates: a UIScrollView's bounds origin changes while
        // it scrolls, which previously made this anchor drift into the selected console.
        view.layoutIfNeeded()
        let safeTop = view.safeAreaInsets.top
        let railTop = max(0, sectionScrollView.frame.minY - safeTop)
        let railBottom = max(railTop, sectionScrollView.frame.maxY - safeTop)
        let railHeight = max(0, railBottom - railTop)

        // Keep the focused cover unmistakably below the console label/icon. The extra
        // clearance also accounts for the 1.08x focus scale on the cover artwork.
        let anchorY = railBottom + 30

        let rowHeight = gameRowHeight

        // Put the previous row immediately above the console rail instead of making it
        // disappear. With the focused row anchored at `anchorY`, the unmodified previous
        // row would overlap the rail. Translate every passed row by exactly the distance
        // required for that previous row's bottom edge to stop just above `railTop`.
        let rowStride = rowHeight + gameColumnLayout.minimumLineSpacing
        let normalPreviousBottom = anchorY - rowStride + rowHeight
        let desiredPreviousBottom = max(0, railTop - 5)
        gameColumnLayout.railGap = max(0, normalPreviousBottom - desiredPreviousBottom)

        let bottomInset = max(18, collectionView.bounds.height - anchorY - rowHeight)

        let newInsets = UIEdgeInsets(top: anchorY, left: 0, bottom: bottomInset, right: 0)
        if collectionView.contentInset != newInsets {
            collectionView.contentInset = newInsets
        }
    }

    private func scrollGameToAnchor(index: Int, animated: Bool) {
        guard games.indices.contains(index) else { return }
        updateGameColumnInsets()
        collectionView.layoutIfNeeded()

        let minY = -collectionView.contentInset.top
        let maxY = max(minY, collectionView.contentSize.height - collectionView.bounds.height + collectionView.contentInset.bottom)
        let nominalY = CGFloat(index) * gameRowStride - collectionView.contentInset.top
        let clampedY = min(max(nominalY, minY), maxY)

        if !animated {
            isProgrammaticGameScroll = false
            gameColumnLayout.focusPosition = CGFloat(index)
        } else {
            isProgrammaticGameScroll = true
        }
        collectionView.setContentOffset(CGPoint(x: 0, y: clampedY), animated: animated)
        if !animated {
            updateGameFocusFromScroll()
        }
    }

    private func settleGameAfterTouch() {
        guard !games.isEmpty, gameRowStride > 0 else { return }
        let raw = (collectionView.contentOffset.y + collectionView.contentInset.top) / gameRowStride
        let index = min(max(Int(raw.rounded()), 0), games.count - 1)
        let minY = -collectionView.contentInset.top
        let maxY = max(minY, collectionView.contentSize.height - collectionView.bounds.height + collectionView.contentInset.bottom)
        let targetY = min(max(CGFloat(index) * gameRowStride - collectionView.contentInset.top, minY), maxY)

        UIView.animate(withDuration: 0.17,
                       delay: 0,
                       options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]) {
            self.collectionView.contentOffset = CGPoint(x: 0, y: targetY)
        } completion: { _ in
            self.gameColumnLayout.focusPosition = CGFloat(index)
            self.updateGameFocusFromScroll()
        }
    }

    private func settleSelectedSectionAfterTouch() {
        guard sectionButtons.indices.contains(selectedSectionIndex),
              sectionScrollView.bounds.width > 0 else { return }
        sectionScrollView.layoutIfNeeded()
        let button = sectionButtons[selectedSectionIndex]
        let minX = -sectionScrollView.adjustedContentInset.left
        let maxX = max(minX,
                       sectionScrollView.contentSize.width - sectionScrollView.bounds.width + sectionScrollView.adjustedContentInset.right)
        let targetX = min(max(button.frame.midX - sectionScrollView.bounds.width * 0.5, minX), maxX)

        UIView.animate(withDuration: 0.17,
                       delay: 0,
                       options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]) {
            self.sectionScrollView.contentOffset = CGPoint(x: targetX, y: self.sectionScrollView.contentOffset.y)
        }
    }

    private func scrollSelectedSectionIntoView(animated: Bool = true) {
        guard sectionButtons.indices.contains(selectedSectionIndex), sectionScrollView.bounds.width > 0 else { return }

        sectionScrollView.layoutIfNeeded()
        let button = sectionButtons[selectedSectionIndex]
        let minX = -sectionScrollView.adjustedContentInset.left
        let maxX = max(minX,
                       sectionScrollView.contentSize.width - sectionScrollView.bounds.width + sectionScrollView.adjustedContentInset.right)
        let centeredX = button.frame.midX - sectionScrollView.bounds.width * 0.5
        let targetX = min(max(centeredX, minX), maxX)
        sectionScrollView.setContentOffset(CGPoint(x: targetX, y: sectionScrollView.contentOffset.y), animated: animated)
    }

    private func updateFocusedGame(index: Int) {
        guard games.indices.contains(index) else { return }

        if sections.indices.contains(selectedSectionIndex) {
            rememberedGameIndex[sections[selectedSectionIndex].identifier] = index
        }

        scrollGameToAnchor(index: index, animated: true)
    }

    private func updateGameFocusFromScroll() {
        guard !games.isEmpty,
              sections.indices.contains(selectedSectionIndex),
              case .console = sections[selectedSectionIndex].kind,
              gameRowStride > 0 else { return }

        let raw = (collectionView.contentOffset.y + collectionView.contentInset.top) / gameRowStride
        let position = min(max(raw, 0), CGFloat(games.count - 1))
        gameColumnLayout.focusPosition = position

        let nearest = min(max(Int(position.rounded()), 0), games.count - 1)
        rememberedGameIndex[sections[selectedSectionIndex].identifier] = nearest

        collectionView.indexPathsForVisibleItems.forEach { path in
            (collectionView.cellForItem(at: path) as? XMBGameRowCell)?
                .setXMBFocused(path.item == nearest)
        }
    }

    private func updateFocusedGame(gameID: String) {
        guard let index = games.firstIndex(where: { $0.id == gameID }) else { return }
        updateFocusedGame(index: index)
    }

    private func openGameDetails(gameID: String) {
        let controller = XMBGameDetailViewController(gameID: gameID)
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true)
    }

    private func activateGame(at index: Int) {
        guard games.indices.contains(index) else { return }
        activateGame(gameID: games[index].id)
    }

    private func activateGame(gameID: String) {
        guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameID),
              !game.isInvalidated,
              !game.isDeleted else { return }
        game.handleTapAction(forceQuick: true)
    }

    private func configureActionView(title: String, subtitle: String, symbol: String) {
        actionTitleLabel.text = title
        actionSubtitleLabel.text = subtitle
        actionSymbolView.image = safeSystemImage(symbol)
    }

    private func activateActionSection() {
        guard sections.indices.contains(selectedSectionIndex) else { return }

        switch sections[selectedSectionIndex].kind {
        case .importGames:
            presentManicScreen(BaseNavigationController(rootViewController: ImportViewController()))
        case .settings:
            presentManicScreen(BaseNavigationController(rootViewController: SettingsViewController()))
        case .classicHome:
            presentManicScreen(HomeViewController())
        case .profile, .console:
            break
        }
    }

    @objc private func actionButtonPressed() {
        activateActionSection()
    }

    private func presentManicScreen(_ contentViewController: UIViewController) {
        let host = XMBModalHostViewController(contentViewController: contentViewController)
        host.modalPresentationStyle = .fullScreen
        present(host, animated: true)
    }

    private func refreshProfile() {
        let defaults = UserDefaults.standard
        let displayName = defaults.string(forKey: Self.profileNameDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let status = defaults.string(forKey: Self.profileStatusDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines)

        profileNameLabel.text = (displayName?.isEmpty == false) ? displayName : "Player"
        profileStatusLabel.text = (status?.isEmpty == false) ? status : "Ready to play"
        loadProfileAvatar()

        let allGames = Array(Database.realm.objects(Game.self).where { !$0.isDeleted })
        let totalDuration = allGames.reduce(0.0) { $0 + $1.totalPlayDuration }
        let playedGames = allGames.filter { $0.totalPlayDuration > 0 }.count
        let totalText = totalDuration > 0
            ? Date.timeDuration(milliseconds: Int(totalDuration))
            : R.string.localizable.readyGameInfoNeverPlayed()

        let mostPlayed = allGames
            .filter { $0.totalPlayDuration > 0 }
            .max(by: { $0.totalPlayDuration < $1.totalPlayDuration })

        if let mostPlayed {
            let mostPlayedTime = Date.timeDuration(milliseconds: Int(mostPlayed.totalPlayDuration))
            profileStatsLabel.text = "Total playtime  \(totalText)\nGames played  \(playedGames) / \(allGames.count)\nMost played  \(mostPlayed.displayName) • \(mostPlayedTime)"
        } else {
            profileStatsLabel.text = "Total playtime  \(totalText)\nGames played  \(playedGames) / \(allGames.count)\nMost played  —"
        }

        if let user = AchievementsUser.getUser() {
            retroStatusLabel.text = "RetroAchievements connected as \(user.username)"
        } else {
            retroStatusLabel.text = "RetroAchievements not connected"
        }

        coverModeControl.selectedSegmentIndex = coverMode.rawValue
        hintsSwitch.isOn = showControllerHints
    }

    private func profileAvatarURL() -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let directory = documents.appendingPathComponent("XMBProfile", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("avatar.png")
    }

    private func loadProfileAvatar() {
        if let url = profileAvatarURL(),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            avatarButton.setImage(image, for: .normal)
            avatarButton.imageView?.contentMode = .scaleAspectFill
        } else {
            avatarButton.setImage(safeSystemImage("person.crop.circle.fill"), for: .normal)
            avatarButton.imageView?.contentMode = .scaleAspectFit
        }
        updateProfileRailAvatar()
    }

    private func profileRailAvatarImage() -> UIImage? {
        guard let url = profileAvatarURL(),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data),
              image.size.width > 0,
              image.size.height > 0 else { return nil }

        let targetSize = CGSize(width: 44, height: 44)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            let clipPath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: targetSize))
            clipPath.addClip()

            let scale = max(targetSize.width / image.size.width,
                            targetSize.height / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale,
                                  height: image.size.height * scale)
            let drawRect = CGRect(x: (targetSize.width - drawSize.width) / 2,
                                  y: (targetSize.height - drawSize.height) / 2,
                                  width: drawSize.width,
                                  height: drawSize.height)
            image.draw(in: drawRect)
        }
        return rendered.withRenderingMode(.alwaysOriginal)
    }

    private func updateProfileRailAvatar() {
        guard let profileIndex = sections.firstIndex(where: {
            if case .profile = $0.kind { return true }
            return false
        }), sectionButtons.indices.contains(profileIndex) else { return }

        let button = sectionButtons[profileIndex]
        if var configuration = button.configuration {
            configuration.image = profileRailAvatarImage() ?? safeSystemImage("person.crop.circle.fill")
            button.configuration = configuration
        }
    }

    @objc private func changeAvatarPressed() {
        let alert = UIAlertController(title: "Profile avatar", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Choose Photo", style: .default) { [weak self] _ in
            self?.presentAvatarPicker()
        })
        alert.addAction(UIAlertAction(title: "Reset Avatar", style: .destructive) { [weak self] _ in
            guard let self else { return }
            if let url = self.profileAvatarURL() {
                try? FileManager.default.removeItem(at: url)
            }
            self.loadProfileAvatar()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = avatarButton
            popover.sourceRect = avatarButton.bounds
        }
        present(alert, animated: true)
    }

    private func presentAvatarPicker() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func editProfileName() {
        let alert = UIAlertController(title: "Display name", message: "This name is only used by the XMB profile.", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = UserDefaults.standard.string(forKey: Self.profileNameDefaultsKey) ?? "Player"
            textField.placeholder = "Player"
            textField.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            let value = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            UserDefaults.standard.set(value.isEmpty ? "Player" : String(value.prefix(32)), forKey: Self.profileNameDefaultsKey)
            self?.refreshProfile()
        })
        present(alert, animated: true)
    }

    private func editProfileStatus() {
        let alert = UIAlertController(title: "Profile status", message: "Add a short line to your XMB profile.", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = UserDefaults.standard.string(forKey: Self.profileStatusDefaultsKey) ?? "Ready to play"
            textField.placeholder = "Ready to play"
            textField.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            let value = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            UserDefaults.standard.set(value.isEmpty ? "Ready to play" : String(value.prefix(70)), forKey: Self.profileStatusDefaultsKey)
            self?.refreshProfile()
        })
        present(alert, animated: true)
    }

    private func openConsoleIconSettings() {
        let controller = XMBConsoleIconSettingsViewController()
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true)
    }

    @objc private func coverModeChanged(_ sender: UISegmentedControl) {
        coverMode = XMBCoverMode(rawValue: sender.selectedSegmentIndex) ?? .original
        collectionView.reloadData()
    }

    @objc private func hintsChanged(_ sender: UISwitch) {
        showControllerHints = sender.isOn
        applyControllerHintVisibility()
    }

    private func applyControllerHintVisibility() {
        controlsHintLabel.isHidden = !showControllerHints
        collectionView.contentInset.bottom = showControllerHints ? 30 : 0
        profileContainerView.contentInset.bottom = showControllerHints ? 26 : 0
    }

    @objc private func openRetroAchievements() {
        RetroAchievementsLaunchView.show(loginedAction: .jumpProfile)
    }

    @objc private func openPlayHistory() {
        _ = PlayHistoryView.show()
    }

    private func openProfileDetails() {
        let controller = XMBProfileDetailsViewController()
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true)
    }

    private func openPS2MemoryCards() {
        _ = ARMSX2EmbeddedCore.openMemoryCardBrowser()
    }

    private func updateClock() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE  MMM d    h:mm a"
        dateLabel.text = formatter.string(from: Date())
    }

    private func safeSystemImage(_ preferredName: String) -> UIImage? {
        UIImage(systemName: preferredName)
            ?? UIImage(systemName: "gamecontroller.fill")
            ?? UIImage(systemName: "circle.fill")
    }

    private func sectionImage(for section: XMBSection) -> UIImage? {
        switch section.kind {
        case .profile:
            return profileRailAvatarImage() ?? safeSystemImage(section.symbol)
        case .console(let gameType):
            return XMBConsoleIconStore.image(for: gameType)
        default:
            return safeSystemImage(section.symbol)
        }
    }

    private func refreshSectionButtonImages() {
        for (index, section) in sections.enumerated() where sectionButtons.indices.contains(index) {
            guard var configuration = sectionButtons[index].configuration else { continue }
            configuration.image = sectionImage(for: section)
            sectionButtons[index].configuration = configuration
        }
    }

    private func symbol(for gameType: GameType) -> String {
        let shortName = gameType.localizedShortName.uppercased()

        if ["GB", "GBC", "GBA", "NDS", "DS", "3DS", "PSP", "LYNX", "NGP", "WSC", "J2ME", "SYMBIAN"].contains(shortName) {
            return "rectangle.portrait.fill"
        }
        if ["PS1", "DC", "SS", "SATURN", "MCD", "NGC", "WII"].contains(shortName) {
            return "opticaldisc.fill"
        }
        if ["DOS", "C64", "AMIGA", "FLASH"].contains(shortName) {
            return "desktopcomputer"
        }
        if ["ARCADE"].contains(shortName) {
            return "circle.grid.cross.fill"
        }
        if ["2600", "5200", "7800", "NES", "SNES", "N64", "MD", "MS", "SG-1000", "PCE", "JAGUAR", "VB", "PM"].contains(shortName) {
            return "gamecontroller.fill"
        }
        return "gamecontroller.fill"
    }
}

extension XMBHomeViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        games.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: XMBGameRowCell.reuseIdentifier,
                                                       for: indexPath) as! XMBGameRowCell

        guard games.indices.contains(indexPath.item) else {
            cell.configurePlaceholder()
            return cell
        }

        let game = games[indexPath.item]
        let gameID = game.id
        cell.configure(game: game, coverMode: coverMode)
        cell.isFocusable = true
        cell.enableFocusEffects = false
        cell.onFocusChange = { [weak self, weak cell] focused in
            cell?.setXMBFocused(focused)
            if focused {
                self?.updateFocusedGame(gameID: gameID)
            }
        }
        // Explicit vertical focus commands make game navigation deterministic even
        // when the previous row is mostly clipped above the console rail. Spatial focus
        // alone can lose that target once it is nearly off-screen.
        let itemIndex = indexPath.item
        cell.focusCommands = [
            FocusCommand(key: .up, title: "Previous Game", handler: { [weak self] in
                guard let self else { return true }
                if itemIndex > 0 {
                    self.focusGame(at: itemIndex - 1)
                }
                return true
            }),
            FocusCommand(key: .down, title: "Next Game", handler: { [weak self] in
                guard let self else { return true }
                if itemIndex + 1 < self.games.count {
                    self.focusGame(at: itemIndex + 1)
                }
                return true
            })
        ]
        cell.onFocusConfirm = { [weak self] in
            self?.openGameDetails(gameID: gameID)
            return true
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard games.indices.contains(indexPath.item) else { return }
        let highlightedIndex = rememberedIndexForCurrentSection()
        collectionView.deselectItem(at: indexPath, animated: false)

        if indexPath.item != highlightedIndex {
            // Touch mirrors controller focus: the first tap only moves the XMB
            // highlight. A second tap on the highlighted title opens its menu.
            updateFocusedGame(index: indexPath.item)
            return
        }

        openGameDetails(gameID: games[indexPath.item].id)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if scrollView === sectionScrollView {
            isTouchScrollingSections = true
        } else if scrollView === collectionView {
            isTouchScrollingGames = true
            isProgrammaticGameScroll = false
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === sectionScrollView {
            guard isTouchScrollingSections || scrollView.isDragging || scrollView.isDecelerating,
                  !sections.isEmpty,
                  !sectionButtons.isEmpty else { return }

            let centerX = sectionScrollView.contentOffset.x + sectionScrollView.bounds.width * 0.5
            guard let nearest = sectionButtons.enumerated().min(by: {
                abs($0.element.frame.midX - centerX) < abs($1.element.frame.midX - centerX)
            }) else { return }

            if nearest.offset != selectedSectionIndex {
                rememberCurrentGameIndex()
                let direction = nearest.offset > selectedSectionIndex ? 1 : -1
                let next = min(max(selectedSectionIndex + direction, 0), sections.count - 1)
                pendingSectionTransitionDirection = CGFloat(direction)
                selectedSectionIndex = next
                updateSelectedSection(animated: false, restoreFocus: false)
            }
            return
        }

        if scrollView === collectionView {
            updateGameFocusFromScroll()
        }
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        // Do not replace UIKit's predicted destination. Fast finger flicks should
        // keep their momentum and visibly travel through systems/games instead of
        // jumping directly to a forced nearest item. We only perform a short settle
        // after deceleration has naturally finished.
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        finishTouchScroll(on: scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            finishTouchScroll(on: scrollView)
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if scrollView === collectionView {
            isProgrammaticGameScroll = false
            updateGameFocusFromScroll()
        }
    }

    private func finishTouchScroll(on scrollView: UIScrollView) {
        if scrollView === sectionScrollView {
            isTouchScrollingSections = false
            settleSelectedSectionAfterTouch()
            return
        }

        if scrollView === collectionView {
            isTouchScrollingGames = false
            isProgrammaticGameScroll = false
            updateGameFocusFromScroll()
            settleGameAfterTouch()
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: gameRowHeight)
    }
}

extension XMBHomeViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self, let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                if let url = self.profileAvatarURL(), let data = image.pngData() {
                    try? data.write(to: url, options: .atomic)
                }
                self.loadProfileAvatar()
            }
        }
    }
}

// MARK: - Consistent console icons

private enum XMBSystemIconFactory {
    private enum Family {
        case verticalHandheld
        case horizontalHandheld
        case dualScreen
        case homeConsole
        case cartridgeConsole
        case arcade
        case computer
    }

    static func image(for gameType: GameType) -> UIImage {
        let name = gameType.localizedShortName.uppercased()
        let family = family(for: name)
        let size = CGSize(width: 46, height: 34)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            let cg = context.cgContext
            cg.setStrokeColor(UIColor.white.cgColor)
            cg.setFillColor(UIColor.white.cgColor)
            cg.setLineWidth(1.8)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)

            switch family {
            case .verticalHandheld:
                let body = UIBezierPath(roundedRect: CGRect(x: 14, y: 1, width: 18, height: 31), cornerRadius: 4)
                body.stroke()
                UIBezierPath(roundedRect: CGRect(x: 17, y: 5, width: 12, height: 10), cornerRadius: 1.5).stroke()
                drawDPad(in: cg, center: CGPoint(x: 19, y: 22), scale: 0.75)
                cg.fillEllipse(in: CGRect(x: 26, y: 20, width: 3.2, height: 3.2))
                cg.fillEllipse(in: CGRect(x: 29, y: 23, width: 3.2, height: 3.2))

            case .horizontalHandheld:
                let body = UIBezierPath(roundedRect: CGRect(x: 2, y: 7, width: 42, height: 22), cornerRadius: 7)
                body.stroke()
                UIBezierPath(roundedRect: CGRect(x: 13, y: 10, width: 20, height: 16), cornerRadius: 2).stroke()
                drawDPad(in: cg, center: CGPoint(x: 8.5, y: 18), scale: 0.85)
                cg.fillEllipse(in: CGRect(x: 36, y: 15, width: 3.2, height: 3.2))
                cg.fillEllipse(in: CGRect(x: 39.2, y: 19, width: 3.2, height: 3.2))

            case .dualScreen:
                let top = UIBezierPath(roundedRect: CGRect(x: 10, y: 2, width: 26, height: 13), cornerRadius: 2.5)
                let bottom = UIBezierPath(roundedRect: CGRect(x: 10, y: 18, width: 26, height: 13), cornerRadius: 2.5)
                top.stroke()
                bottom.stroke()
                cg.move(to: CGPoint(x: 18, y: 16.5))
                cg.addLine(to: CGPoint(x: 28, y: 16.5))
                cg.strokePath()
                drawDPad(in: cg, center: CGPoint(x: 15, y: 24.5), scale: 0.65)
                cg.fillEllipse(in: CGRect(x: 30, y: 23, width: 2.8, height: 2.8))

            case .homeConsole:
                let console = UIBezierPath(roundedRect: CGRect(x: 4, y: 8, width: 30, height: 18), cornerRadius: 4)
                console.stroke()
                cg.strokeEllipse(in: CGRect(x: 9, y: 12, width: 10, height: 10))
                cg.move(to: CGPoint(x: 24, y: 13))
                cg.addLine(to: CGPoint(x: 30, y: 13))
                cg.strokePath()
                cg.fillEllipse(in: CGRect(x: 27, y: 19, width: 3, height: 3))
                let controller = UIBezierPath(roundedRect: CGRect(x: 34, y: 17, width: 10, height: 8), cornerRadius: 4)
                controller.stroke()

            case .cartridgeConsole:
                let base = UIBezierPath(roundedRect: CGRect(x: 3, y: 11, width: 40, height: 18), cornerRadius: 5)
                base.stroke()
                let cart = UIBezierPath(roundedRect: CGRect(x: 15, y: 2, width: 16, height: 14), cornerRadius: 2)
                cart.stroke()
                cg.move(to: CGPoint(x: 19, y: 6))
                cg.addLine(to: CGPoint(x: 27, y: 6))
                cg.strokePath()
                cg.fillEllipse(in: CGRect(x: 35, y: 18, width: 3, height: 3))

            case .arcade:
                let cabinet = UIBezierPath(roundedRect: CGRect(x: 10, y: 2, width: 26, height: 31), cornerRadius: 3)
                cabinet.stroke()
                UIBezierPath(roundedRect: CGRect(x: 14, y: 6, width: 18, height: 11), cornerRadius: 2).stroke()
                cg.move(to: CGPoint(x: 18, y: 23))
                cg.addLine(to: CGPoint(x: 18, y: 19))
                cg.strokePath()
                cg.fillEllipse(in: CGRect(x: 16.5, y: 18, width: 3, height: 3))
                cg.fillEllipse(in: CGRect(x: 25, y: 21, width: 3, height: 3))

            case .computer:
                UIBezierPath(roundedRect: CGRect(x: 5, y: 4, width: 36, height: 23), cornerRadius: 3).stroke()
                cg.move(to: CGPoint(x: 23, y: 27))
                cg.addLine(to: CGPoint(x: 23, y: 31))
                cg.strokePath()
                cg.move(to: CGPoint(x: 15, y: 31))
                cg.addLine(to: CGPoint(x: 31, y: 31))
                cg.strokePath()
            }
        }

        let labeled = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
            let label = String(name.prefix(5))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .right
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 5.5, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.88),
                .paragraphStyle: paragraph
            ]
            label.draw(in: CGRect(x: 18, y: 27, width: 26, height: 7), withAttributes: attributes)
        }
        return labeled.withRenderingMode(.alwaysOriginal)
    }

    private static func family(for name: String) -> Family {
        if ["GB", "GBC"].contains(name) {
            return .verticalHandheld
        }
        if ["NDS", "DS", "3DS"].contains(name) {
            return .dualScreen
        }
        if ["GBA", "PSP", "LYNX", "NGP", "NGPC", "WSC", "WS", "J2ME", "SYMBIAN"].contains(name) {
            return .horizontalHandheld
        }
        if ["PS1", "PS2", "DC", "SS", "SATURN", "MCD", "NGC", "WII"].contains(name) {
            return .homeConsole
        }
        if ["ARCADE", "MAME"].contains(name) {
            return .arcade
        }
        if ["DOS", "WIN95", "WIN98", "C64", "AMIGA", "FLASH"].contains(name) {
            return .computer
        }
        return .cartridgeConsole
    }

    private static func drawDPad(in context: CGContext, center: CGPoint, scale: CGFloat) {
        let thickness = 2.2 * scale
        let length = 7.0 * scale
        let horizontal = CGRect(x: center.x - length / 2, y: center.y - thickness / 2, width: length, height: thickness)
        let vertical = CGRect(x: center.x - thickness / 2, y: center.y - length / 2, width: thickness, height: length)
        context.fill(horizontal)
        context.fill(vertical)
    }
}

// MARK: - XMB game row

private final class XMBGameRowCell: UICollectionViewCell {
    static let reuseIdentifier = "XMBGameRowCell"

    private let highlightView = UIView()
    private let coverView = UIImageView()
    private var configuredCoverMode: XMBCoverMode = .original
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.clipsToBounds = false

        highlightView.backgroundColor = .clear
        highlightView.layer.cornerRadius = 8

        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = 5
        coverView.backgroundColor = UIColor.white.withAlphaComponent(0.04)

        nameLabel.textColor = UIColor.white.withAlphaComponent(0.90)
        nameLabel.font = .systemFont(ofSize: 15.5, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.textAlignment = .left
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.78
        nameLabel.layer.shadowColor = UIColor.black.cgColor
        nameLabel.layer.shadowOpacity = 0.28
        nameLabel.layer.shadowRadius = 1.5
        nameLabel.layer.shadowOffset = CGSize(width: 0, height: 1)

        detailLabel.textColor = UIColor.white.withAlphaComponent(0.54)
        detailLabel.font = .systemFont(ofSize: 10.5, weight: .regular)
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.textAlignment = .left

        contentView.addSubview(highlightView)
        contentView.addSubview(coverView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(detailLabel)

        highlightView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // Classic-XMB placement: the cover stays on the exact center line of the
        // selected console above it, while the game name/details sit to its RIGHT.
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverView.snp.trailing).offset(15)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
            make.centerY.equalToSuperview().offset(-7)
        }

        detailLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
            make.top.equalTo(nameLabel.snp.bottom).offset(2)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onFocusChange = nil
        onFocusConfirm = nil
        focusCommands = []
        setXMBFocused(false)
        coverView.image = nil
    }

    func setXMBFocused(_ focused: Bool) {
        UIView.animate(withDuration: 0.12) {
            self.highlightView.backgroundColor = .clear
            self.nameLabel.textColor = focused ? .white : UIColor.white.withAlphaComponent(0.88)
            self.detailLabel.textColor = focused
                ? UIColor.white.withAlphaComponent(0.68)
                : UIColor.white.withAlphaComponent(0.50)
            self.coverView.layer.borderWidth = focused ? 1.0 : 0
            self.coverView.layer.borderColor = UIColor.white.withAlphaComponent(0.78).cgColor
            self.coverView.layer.shadowColor = UIColor.systemCyan.cgColor
            self.coverView.layer.shadowOpacity = focused ? 0.30 : 0
            self.coverView.layer.shadowRadius = focused ? 4 : 0
            self.coverView.transform = focused
                ? CGAffineTransform(scaleX: 1.035, y: 1.035)
                : .identity
            self.transform = .identity
        }
    }

    func configurePlaceholder() {
        onFocusChange = nil
        onFocusConfirm = nil
        focusCommands = []
        coverView.image = nil
        nameLabel.text = nil
        detailLabel.text = nil
        setXMBFocused(false)
    }

    func configure(game: XMBGameItem, coverMode: XMBCoverMode) {
        configuredCoverMode = coverMode
        nameLabel.text = game.displayName

        var detailParts = [game.gameType.localizedShortName]
        if game.totalPlayDuration > 0, game.totalPlayDuration <= Double(Int.max) {
            detailParts.append(Date.timeDuration(milliseconds: Int(game.totalPlayDuration)))
        }
        detailLabel.text = detailParts.joined(separator: "  •  ")

        // Resolve the Realm row only for the synchronous cover request. The collection
        // itself keeps only XMBGameItem values, so later import writes cannot invalidate
        // the objects retained by cells/focus callbacks.
        let liveGame = Database.realm.object(ofType: Game.self, forPrimaryKey: game.id)

        switch coverMode {
        case .original:
            applyOriginalCoverGeometry(image: nil)
            coverView.layer.cornerRadius = 4
            coverView.contentMode = .scaleAspectFit
            if let liveGame, !liveGame.isInvalidated {
                coverView.setGameCover(game: liveGame, size: CGSize(width: 100, height: 100)) { [weak self] image in
                    guard let self, self.configuredCoverMode == .original else { return }
                    self.coverView.contentMode = .scaleAspectFit
                    self.applyOriginalCoverGeometry(image: image)
                }
            } else {
                let placeholder = UIImage.placeHolder(preferenceSize: CGSize(width: 76, height: 100))
                coverView.image = placeholder
                applyOriginalCoverGeometry(image: placeholder)
            }

        case .square:
            coverView.snp.remakeConstraints { make in
                make.centerX.equalToSuperview()
                make.centerY.equalToSuperview()
                make.width.height.equalTo(46)
            }
            coverView.layer.cornerRadius = 6
            coverView.contentMode = .scaleAspectFill
            if let liveGame, !liveGame.isInvalidated {
                coverView.setGameCover(game: liveGame, size: CGSize(width: 92, height: 92)) { [weak coverView] _ in
                    coverView?.contentMode = .scaleAspectFill
                }
            } else {
                coverView.image = UIImage.placeHolder(preferenceSize: CGSize(width: 92, height: 92))
            }
        }
    }

    private func applyOriginalCoverGeometry(image: UIImage?) {
        let fallbackRatio: CGFloat = 38.0 / 50.0
        let imageSize = image?.size ?? .zero
        let ratio = (imageSize.width > 0 && imageSize.height > 0)
            ? imageSize.width / imageSize.height
            : fallbackRatio

        let maxWidth: CGFloat = 50
        let maxHeight: CGFloat = 50
        var width = maxHeight * ratio
        var height = maxHeight

        if width > maxWidth {
            width = maxWidth
            height = maxWidth / max(ratio, 0.01)
        }

        width = max(20, width)
        height = max(20, height)

        coverView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(width)
            make.height.equalTo(height)
        }
        setNeedsLayout()
    }
}

private enum XMBLibraryViewSettingsKind {
    case games
    case consoles

    var title: String {
        switch self {
        case .games: return "Game Library View"
        case .consoles: return "Console Library View"
        }
    }
}

private final class XMBLibraryViewSettingsViewController: UIViewController {
    private let kind: XMBLibraryViewSettingsKind
    private let backgroundView = XMBWaveBackgroundView()
    private let titleLabel = UILabel()
    private let sortButton = UIButton(type: .system)
    private let filterButton = UIButton(type: .system)

    private lazy var closeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "chevron.left")
        configuration.title = "Back"
        configuration.imagePadding = 6
        configuration.baseForegroundColor = .white
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(closePressed), for: .touchUpInside)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusConfirm = { [weak self] in
            self?.closePressed()
            return true
        }
        return button
    }()

    init(kind: XMBLibraryViewSettingsKind) {
        self.kind = kind
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(14)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
        }

        titleLabel.text = kind.title
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 26, weight: .semibold)
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }

        configureSettingButton(sortButton, action: #selector(sortPressed))
        configureSettingButton(filterButton, action: #selector(filterPressed))

        let stack = UIStackView(arrangedSubviews: [sortButton, filterButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.distribution = .fillEqually
        view.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalTo(closeButton.snp.bottom).offset(44)
            make.centerX.equalToSuperview()
            make.width.equalTo(520).priority(.high)
            make.leading.greaterThanOrEqualTo(view.safeAreaLayoutGuide).offset(24)
            make.trailing.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-24)
            make.height.equalTo(132)
        }

        refreshLabels()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ExternalInputDispatch.sink = .focusKit
        FocusSystem.shared.isEnabled = true
        pushOverlayFocusContext { [weak self] context in
            context.autoFocusOnActivate = true
            context.preferredFocusView = { [weak self] in self?.sortButton }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if hasFocusContext { popFocusContext() }
    }

    private func configureSettingButton(_ button: UIButton, action: Selector) {
        var configuration = UIButton.Configuration.gray()
        configuration.baseForegroundColor = .white
        configuration.background.backgroundColor = UIColor.black.withAlphaComponent(0.24)
        configuration.cornerStyle = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)
        button.configuration = configuration
        button.contentHorizontalAlignment = .leading
        button.addTarget(self, action: action, for: .touchUpInside)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusChange = { [weak button] focused in
            UIView.animate(withDuration: 0.16,
                           delay: 0,
                           options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]) {
                button?.transform = focused ? CGAffineTransform(scaleX: 1.025, y: 1.025) : .identity
                button?.backgroundColor = focused ? UIColor.white.withAlphaComponent(0.10) : .clear
            }
        }
        button.onFocusConfirm = { [weak button] in
            button?.sendActions(for: .touchUpInside)
            return true
        }
    }

    @objc private func closePressed() {
        dismiss(animated: true)
    }

    @objc private func sortPressed() {
        let defaults = UserDefaults.standard
        switch kind {
        case .games:
            let current = XMBGameSort(rawValue: defaults.integer(forKey: "ManicXMB.gameSort")) ?? .nameAZ
            let cases = XMBGameSort.allCases
            let index = cases.firstIndex(of: current) ?? 0
            defaults.set(cases[(index + 1) % cases.count].rawValue, forKey: "ManicXMB.gameSort")
        case .consoles:
            let current = XMBConsoleSort(rawValue: defaults.integer(forKey: "ManicXMB.consoleSort")) ?? .systemDefault
            let cases = XMBConsoleSort.allCases
            let index = cases.firstIndex(of: current) ?? 0
            defaults.set(cases[(index + 1) % cases.count].rawValue, forKey: "ManicXMB.consoleSort")
        }
        refreshLabels()
        NotificationCenter.default.post(name: .xmbLibraryViewSettingsDidChange, object: nil)
    }

    @objc private func filterPressed() {
        let defaults = UserDefaults.standard
        switch kind {
        case .games:
            let current = XMBGameFilter(rawValue: defaults.integer(forKey: "ManicXMB.gameFilter")) ?? .all
            let cases = XMBGameFilter.allCases
            let index = cases.firstIndex(of: current) ?? 0
            defaults.set(cases[(index + 1) % cases.count].rawValue, forKey: "ManicXMB.gameFilter")
        case .consoles:
            let current = XMBConsoleFilter(rawValue: defaults.integer(forKey: "ManicXMB.consoleFilter")) ?? .libraryOnly
            let cases = XMBConsoleFilter.allCases
            let index = cases.firstIndex(of: current) ?? 0
            defaults.set(cases[(index + 1) % cases.count].rawValue, forKey: "ManicXMB.consoleFilter")
        }
        refreshLabels()
        NotificationCenter.default.post(name: .xmbLibraryViewSettingsDidChange, object: nil)
    }

    private func refreshLabels() {
        let defaults = UserDefaults.standard
        var sortTitle = ""
        var filterTitle = ""

        switch kind {
        case .games:
            sortTitle = (XMBGameSort(rawValue: defaults.integer(forKey: "ManicXMB.gameSort")) ?? .nameAZ).title
            filterTitle = (XMBGameFilter(rawValue: defaults.integer(forKey: "ManicXMB.gameFilter")) ?? .all).title
        case .consoles:
            sortTitle = (XMBConsoleSort(rawValue: defaults.integer(forKey: "ManicXMB.consoleSort")) ?? .systemDefault).title
            filterTitle = (XMBConsoleFilter(rawValue: defaults.integer(forKey: "ManicXMB.consoleFilter")) ?? .libraryOnly).title
        }

        if var configuration = sortButton.configuration {
            configuration.title = "Sort"
            configuration.subtitle = sortTitle
            sortButton.configuration = configuration
        }
        if var configuration = filterButton.configuration {
            configuration.title = "Filter"
            configuration.subtitle = filterTitle
            filterButton.configuration = configuration
        }
    }
}

// MARK: - Console icon customization

private enum XMBConsoleIconStore {
    private static var directoryURL: URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let directory = documents.appendingPathComponent("XMBProfile/ConsoleIcons", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func safeName(for gameType: GameType) -> String {
        let raw = gameType.rawValue
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return raw.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
    }

    static func customURL(for gameType: GameType) -> URL? {
        directoryURL?.appendingPathComponent(safeName(for: gameType)).appendingPathExtension("png")
    }

    static func image(for gameType: GameType) -> UIImage {
        if let url = customURL(for: gameType),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image.withRenderingMode(.alwaysOriginal)
        }
        if let brand = gameType.brandImage {
            return brand.withRenderingMode(.alwaysOriginal)
        }
        return XMBSystemIconFactory.image(for: gameType)
    }

    static func save(_ image: UIImage, for gameType: GameType) -> Bool {
        guard let url = customURL(for: gameType),
              let data = image.pngData() else { return false }
        do {
            try data.write(to: url, options: .atomic)
            NotificationCenter.default.post(name: .xmbConsoleIconsDidChange, object: gameType)
            return true
        } catch {
            return false
        }
    }

    static func reset(_ gameType: GameType) {
        if let url = customURL(for: gameType) {
            try? FileManager.default.removeItem(at: url)
        }
        NotificationCenter.default.post(name: .xmbConsoleIconsDidChange, object: gameType)
    }
}

private final class XMBConsoleIconSettingsViewController: UIViewController {
    private let backgroundView = XMBWaveBackgroundView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let gameTypes = System.allGameTypes
    private var pendingGameType: GameType?

    private lazy var closeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "chevron.left")
        configuration.title = "Back"
        configuration.imagePadding = 6
        configuration.baseForegroundColor = .white
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(closePressed), for: .touchUpInside)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusConfirm = { [weak self] in
            self?.closePressed()
            return true
        }
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(14)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
        }

        let title = UILabel()
        title.text = "Console Icons"
        title.textColor = .white
        title.font = .systemFont(ofSize: 25, weight: .semibold)
        view.addSubview(title)
        title.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }

        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.08)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 68
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "iconCell")
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(closeButton.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ExternalInputDispatch.sink = .focusKit
        FocusSystem.shared.isEnabled = true
        pushOverlayFocusContext { [weak self] context in
            context.autoFocusOnActivate = true
            context.preferredFocusView = { [weak self] in self?.closeButton }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if hasFocusContext { popFocusContext() }
    }

    @objc private func closePressed() {
        dismiss(animated: true)
    }

    private func chooseIcon(for gameType: GameType, sourceView: UIView) {
        let sheet = UIAlertController(title: gameType.localizedName,
                                      message: "Choose a custom XMB icon or restore the console's default icon.",
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Choose Image", style: .default) { [weak self] _ in
            self?.pendingGameType = gameType
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            self?.present(picker, animated: true)
        })
        sheet.addAction(UIAlertAction(title: "Restore Default", style: .destructive) { [weak self] _ in
            XMBConsoleIconStore.reset(gameType)
            self?.tableView.reloadData()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(sheet, animated: true)
    }
}

extension XMBConsoleIconSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        gameTypes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "iconCell", for: indexPath)
        let gameType = gameTypes[indexPath.row]
        var configuration = cell.defaultContentConfiguration()
        configuration.image = XMBConsoleIconStore.image(for: gameType)
        configuration.imageProperties.maximumSize = CGSize(width: 42, height: 34)
        configuration.text = gameType.localizedName
        configuration.secondaryText = "Tap to customize"
        configuration.textProperties.color = .white
        configuration.secondaryTextProperties.color = UIColor.white.withAlphaComponent(0.54)
        cell.contentConfiguration = configuration
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard gameTypes.indices.contains(indexPath.row),
              let cell = tableView.cellForRow(at: indexPath) else { return }
        chooseIcon(for: gameTypes[indexPath.row], sourceView: cell)
    }
}

extension XMBConsoleIconSettingsViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let gameType = pendingGameType,
              let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            pendingGameType = nil
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self, let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                _ = XMBConsoleIconStore.save(image, for: gameType)
                self.pendingGameType = nil
                self.tableView.reloadData()
            }
        }
    }
}

// MARK: - XMB game details

private final class XMBGameDetailViewController: UIViewController {
    private let gameID: String
    private let backgroundView = XMBWaveBackgroundView()
    private let bannerView = UIImageView()
    private let bannerDimView = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let coverView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let synopsisLabel = UILabel()
    private let metadataLabel = UILabel()
    private let statsLabel = UILabel()

    private lazy var closeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "chevron.left")
        configuration.title = "Back"
        configuration.imagePadding = 6
        configuration.baseForegroundColor = .white
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(closePressed), for: .touchUpInside)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusConfirm = { [weak self] in
            self?.closePressed()
            return true
        }
        return button
    }()

    private lazy var playButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Play"
        configuration.image = UIImage(systemName: "play.fill")
        configuration.imagePadding = 8
        configuration.baseForegroundColor = .white
        configuration.baseBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.84)
        configuration.cornerStyle = .capsule
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(playPressed), for: .touchUpInside)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusConfirm = { [weak self] in
            self?.playPressed()
            return true
        }
        return button
    }()

    private lazy var moreButton: UIButton = {
        var configuration = UIButton.Configuration.gray()
        configuration.title = "More Options"
        configuration.image = UIImage(systemName: "ellipsis.circle")
        configuration.imagePadding = 7
        configuration.baseForegroundColor = .white
        configuration.background.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(morePressed), for: .touchUpInside)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusConfirm = { [weak self] in
            self?.morePressed()
            return true
        }
        return button
    }()

    init(gameID: String) {
        self.gameID = gameID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        bannerView.contentMode = .scaleAspectFill
        bannerView.clipsToBounds = true
        bannerView.alpha = 0.78
        view.addSubview(bannerView)
        bannerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        bannerDimView.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        view.addSubview(bannerDimView)
        bannerDimView.snp.makeConstraints { $0.edges.equalTo(bannerView) }

        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(14)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
        }

        view.addSubview(scrollView)
        scrollView.showsVerticalScrollIndicator = false
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(closeButton.snp.bottom).offset(10)
            make.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        setupContent()
        loadGame()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ExternalInputDispatch.sink = .focusKit
        FocusSystem.shared.isEnabled = true
        pushOverlayFocusContext { [weak self] context in
            context.autoFocusOnActivate = true
            context.preferredFocusView = { [weak self] in self?.playButton }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if hasFocusContext { popFocusContext() }
    }

    private func setupContent() {
        coverView.contentMode = .scaleAspectFit
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = 8
        coverView.backgroundColor = UIColor.white.withAlphaComponent(0.05)

        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 29, weight: .bold)
        titleLabel.numberOfLines = 2
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOpacity = 0.50
        titleLabel.layer.shadowRadius = 4

        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.70)
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        subtitleLabel.numberOfLines = 2

        synopsisLabel.textColor = UIColor.white.withAlphaComponent(0.86)
        synopsisLabel.font = .systemFont(ofSize: 14, weight: .regular)
        synopsisLabel.numberOfLines = 0

        metadataLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        metadataLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        metadataLabel.numberOfLines = 0

        statsLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        statsLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        statsLabel.numberOfLines = 0

        contentView.addSubview(coverView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(playButton)
        contentView.addSubview(moreButton)

        coverView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalToSuperview().offset(18)
            make.width.equalTo(118)
            make.height.equalTo(166)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverView.snp.trailing).offset(20)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(coverView).offset(10)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
        }

        let actionStack = UIStackView(arrangedSubviews: [playButton, moreButton])
        actionStack.axis = .horizontal
        actionStack.spacing = 10
        actionStack.distribution = .fillEqually
        contentView.addSubview(actionStack)
        actionStack.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(subtitleLabel.snp.bottom).offset(18)
            make.width.equalTo(320).priority(.high)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
            make.height.equalTo(44)
        }

        let synopsisCard = makeCard()
        let metadataCard = makeCard()
        contentView.addSubview(synopsisCard)
        contentView.addSubview(metadataCard)

        synopsisCard.snp.makeConstraints { make in
            make.top.equalTo(coverView.snp.bottom).offset(22)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        let synopsisTitle = sectionTitle("Overview")
        synopsisCard.addSubview(synopsisTitle)
        synopsisCard.addSubview(synopsisLabel)
        synopsisTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        synopsisLabel.snp.makeConstraints { make in
            make.top.equalTo(synopsisTitle.snp.bottom).offset(9)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
        }

        metadataCard.snp.makeConstraints { make in
            make.top.equalTo(synopsisCard.snp.bottom).offset(12)
            make.leading.trailing.equalTo(synopsisCard)
            make.bottom.equalToSuperview().offset(-28)
        }

        let detailsTitle = sectionTitle("Game Details")
        metadataCard.addSubview(detailsTitle)
        metadataCard.addSubview(metadataLabel)
        metadataCard.addSubview(statsLabel)
        detailsTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        metadataLabel.snp.makeConstraints { make in
            make.top.equalTo(detailsTitle.snp.bottom).offset(9)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        statsLabel.snp.makeConstraints { make in
            make.top.equalTo(metadataLabel.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
        }
    }

    private func makeCard() -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        view.layer.cornerRadius = 15
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        return view
    }

    private func sectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        return label
    }

    private func loadGame() {
        guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameID),
              !game.isInvalidated,
              !game.isDeleted else {
            dismiss(animated: true)
            return
        }

        let displayName = game.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        titleLabel.text = displayName.isEmpty ? game.name : displayName
        subtitleLabel.text = game.gameType.localizedName

        bannerView.image = game.bannerImage
        if bannerView.image == nil {
            bannerView.alpha = 0
        }

        coverView.setGameCover(game: game, size: CGSize(width: 236, height: 332)) { [weak coverView] _ in
            coverView?.contentMode = .scaleAspectFit
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let total = game.totalPlayDuration > 0
            ? Date.timeDuration(milliseconds: Int(game.totalPlayDuration))
            : "Never played"
        let latestSession = game.latestPlayDuration > 0
            ? Date.timeDuration(milliseconds: Int(game.latestPlayDuration))
            : "—"
        let lastPlayed = game.latestPlayDate.map { formatter.string(from: $0) } ?? "Never"
        let imported = formatter.string(from: game.importDate)

        statsLabel.text = """
        Total playtime  \(total)
        Last played  \(lastPlayed)
        Last session  \(latestSession)
        Added to library  \(imported)
        """

        if let stored = GameMetadata.getGameMetadata(game: game) {
            applyMetadata(stored)
        } else {
            synopsisLabel.text = "Loading overview…"
            metadataLabel.text = "Metadata is being matched from ManicEMU's local game database."

            // ROM names often contain region/revision tags which make a single fuzzy
            // search miss an otherwise present overview. Try the display name, the
            // library name and a cleaned filename, then prefer a result with overview text.
            let displayed = titleLabel.text ?? game.name
            let libraryName = game.name
            let romName = game.romUrl.deletingPathExtension().lastPathComponent
            let cleanedROMName = romName
                .replacingOccurrences(of: #"\s*[\(\[].*?[\)\]]"#,
                                      with: "",
                                      options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let queries = Array(Set([displayed, libraryName, cleanedROMName]))
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                var best: GameMetadata?
                for query in queries {
                    let matches = GameMetadataKit.searchGameInfo(displayName: query)
                    if let withOverview = matches.first(where: {
                        !$0.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }) {
                        best = withOverview
                        break
                    }
                    if best == nil {
                        best = matches.first
                    }
                }

                DispatchQueue.main.async {
                    guard let self else { return }
                    self.applyMetadata(best)
                }
            }
        }
    }

    private func applyMetadata(_ metadata: GameMetadata?) {
        guard let metadata else {
            synopsisLabel.text = "No overview is available in the local ManicEMU metadata database for this game."
            metadataLabel.text = "Developer  —\nPublisher  —\nGenre  —\nRelease  —\nRegion  —\nRating  —"
            return
        }

        synopsisLabel.text = metadata.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No overview is available for this title."
            : metadata.overview

        func value(_ text: String) -> String {
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : text
        }

        metadataLabel.text = """
        Developer  \(value(metadata.developer))
        Publisher  \(value(metadata.publisher))
        Genre  \(value(metadata.genre))
        Release  \(metadata.releaseDateDisplay)
        Region  \(value(metadata.region))
        Rating  \(metadata.esrpDisplay)
        """
    }

    @objc private func closePressed() {
        dismiss(animated: true)
    }

    @objc private func playPressed() {
        let id = gameID
        dismiss(animated: true) {
            guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: id),
                  !game.isInvalidated,
                  !game.isDeleted else { return }
            game.handleTapAction(forceQuick: true)
        }
    }

    @objc private func morePressed() {
        guard let game = Database.realm.object(ofType: Game.self, forPrimaryKey: gameID),
              !game.isInvalidated,
              !game.isDeleted else { return }
        GameInfoView.show(game: game)
    }
}

// MARK: - XMB profile details

private final class XMBProfileDetailsViewController: UIViewController {
    private let backgroundView = XMBWaveBackgroundView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Profile"
        label.textColor = .white
        label.font = .systemFont(ofSize: 27, weight: .semibold)
        return label
    }()

    private lazy var closeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "chevron.left")
        configuration.title = "Back"
        configuration.imagePadding = 6
        configuration.baseForegroundColor = .white
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(closePressed), for: .touchUpInside)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusConfirm = { [weak self] in
            self?.closePressed()
            return true
        }
        return button
    }()

    private lazy var avatarButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        button.layer.cornerRadius = 48
        button.clipsToBounds = true
        button.tintColor = .white
        button.imageView?.contentMode = .scaleAspectFill
        button.addTarget(self, action: #selector(changeAvatarPressed), for: .touchUpInside)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusConfirm = { [weak self] in
            self?.changeAvatarPressed()
            return true
        }
        return button
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 25, weight: .semibold)
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white.withAlphaComponent(0.66)
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.numberOfLines = 2
        return label
    }()

    private let statsLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white.withAlphaComponent(0.84)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.numberOfLines = 0
        return label
    }()

    private let accountStatusLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white.withAlphaComponent(0.76)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.numberOfLines = 2
        return label
    }()

    private lazy var editNameButton = makeButton(title: "Display Name", symbol: "pencil") { [weak self] in
        self?.editName()
    }

    private lazy var editStatusButton = makeButton(title: "Status", symbol: "text.bubble") { [weak self] in
        self?.editStatus()
    }

    private lazy var changeAvatarButton = makeButton(title: "Avatar", symbol: "photo") { [weak self] in
        self?.changeAvatarPressed()
    }

    private lazy var retroButton = makeButton(title: "RetroAchievements", symbol: "trophy.fill") {
        RetroAchievementsLaunchView.show(loginedAction: .jumpProfile)
    }

    private lazy var historyButton = makeButton(title: "Play History", symbol: "clock.arrow.circlepath") {
        _ = PlayHistoryView.show()
    }

    private lazy var consoleIconsButton = makeButton(title: "Console Icons", symbol: "square.grid.3x3.fill") { [weak self] in
        self?.openConsoleIconSettings()
    }

    private lazy var coverModeControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [XMBCoverMode.original.title, XMBCoverMode.square.title])
        control.selectedSegmentTintColor = UIColor.white.withAlphaComponent(0.22)
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        control.setTitleTextAttributes([.foregroundColor: UIColor.white.withAlphaComponent(0.60)], for: .normal)
        control.addTarget(self, action: #selector(coverModeChanged(_:)), for: .valueChanged)
        control.isFocusable = true
        control.enableFocusEffects = false
        control.onFocusConfirm = { [weak self, weak control] in
            guard let self, let control else { return true }
            control.selectedSegmentIndex = control.selectedSegmentIndex == 0 ? 1 : 0
            self.coverModeChanged(control)
            return true
        }
        return control
    }()

    private lazy var hintsSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.addTarget(self, action: #selector(hintsChanged(_:)), for: .valueChanged)
        toggle.isFocusable = true
        toggle.enableFocusEffects = false
        toggle.onFocusConfirm = { [weak self, weak toggle] in
            guard let self, let toggle else { return true }
            toggle.setOn(!toggle.isOn, animated: true)
            self.hintsChanged(toggle)
            return true
        }
        return toggle
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(14)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
        }

        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }

        view.addSubview(scrollView)
        scrollView.showsVerticalScrollIndicator = false
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(closeButton.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        buildContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ExternalInputDispatch.sink = .focusKit
        FocusSystem.shared.isEnabled = true
        pushOverlayFocusContext { [weak self] context in
            context.autoFocusOnActivate = true
            context.preferredFocusView = { [weak self] in self?.avatarButton }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if hasFocusContext { popFocusContext() }
    }

    private func buildContent() {
        let headerCard = makeCard()
        let preferencesCard = makeCard()
        let themeCard = makeCard()
        let accountCard = makeCard()

        contentView.addSubview(headerCard)
        contentView.addSubview(preferencesCard)
        contentView.addSubview(themeCard)
        contentView.addSubview(accountCard)

        headerCard.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.centerX.equalToSuperview()
            make.width.equalTo(620).priority(.high)
            make.leading.greaterThanOrEqualToSuperview().offset(18)
            make.trailing.lessThanOrEqualToSuperview().offset(-18)
        }

        headerCard.addSubview(avatarButton)
        headerCard.addSubview(nameLabel)
        headerCard.addSubview(statusLabel)

        avatarButton.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(18)
            make.width.height.equalTo(96)
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarButton.snp.trailing).offset(18)
            make.trailing.equalToSuperview().offset(-18)
            make.top.equalTo(avatarButton).offset(8)
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(5)
        }

        let editStack = UIStackView(arrangedSubviews: [editNameButton, editStatusButton, changeAvatarButton])
        editStack.axis = .horizontal
        editStack.distribution = .fillEqually
        editStack.spacing = 8
        headerCard.addSubview(editStack)
        editStack.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.equalToSuperview().offset(-18)
            make.top.greaterThanOrEqualTo(statusLabel.snp.bottom).offset(12)
            make.height.equalTo(42)
            make.bottom.equalToSuperview().offset(-18)
        }

        preferencesCard.snp.makeConstraints { make in
            make.top.equalTo(headerCard.snp.bottom).offset(12)
            make.leading.trailing.equalTo(headerCard)
        }

        let preferencesTitle = makeSectionTitle("Profile & XMB")
        preferencesCard.addSubview(preferencesTitle)
        preferencesCard.addSubview(statsLabel)
        preferencesCard.addSubview(coverModeControl)
        preferencesCard.addSubview(hintsSwitch)

        let coverLabel = makeSmallLabel("Game cover shape")
        let hintsLabel = makeSmallLabel("Show controller instructions")
        preferencesCard.addSubview(coverLabel)
        preferencesCard.addSubview(hintsLabel)
        preferencesCard.addSubview(consoleIconsButton)

        preferencesTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        statsLabel.snp.makeConstraints { make in
            make.top.equalTo(preferencesTitle.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        coverLabel.snp.makeConstraints { make in
            make.top.equalTo(statsLabel.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(16)
        }
        coverModeControl.snp.makeConstraints { make in
            make.centerY.equalTo(coverLabel)
            make.trailing.equalToSuperview().offset(-16)
            make.width.equalTo(200)
        }
        hintsLabel.snp.makeConstraints { make in
            make.top.equalTo(coverLabel.snp.bottom).offset(24)
            make.leading.equalTo(coverLabel)
        }
        hintsSwitch.snp.makeConstraints { make in
            make.centerY.equalTo(hintsLabel)
            make.trailing.equalToSuperview().offset(-16)
        }
        consoleIconsButton.snp.makeConstraints { make in
            make.top.equalTo(hintsLabel.snp.bottom).offset(18)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().offset(-16)
        }

        themeCard.snp.makeConstraints { make in
            make.top.equalTo(preferencesCard.snp.bottom).offset(12)
            make.leading.trailing.equalTo(headerCard)
        }

        let themeTitle = makeSectionTitle("Classic PS3 Background")
        let themeSubtitle = makeSmallLabel("Choose an XMB colorway.")
        themeCard.addSubview(themeTitle)
        themeCard.addSubview(themeSubtitle)
        themeTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        themeSubtitle.snp.makeConstraints { make in
            make.top.equalTo(themeTitle.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 8
        rows.distribution = .fillEqually
        themeCard.addSubview(rows)
        rows.snp.makeConstraints { make in
            make.top.equalTo(themeSubtitle.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-16)
        }

        let themes = XMBBackgroundTheme.allCases
        for start in stride(from: 0, to: themes.count, by: 3) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8
            row.distribution = .fillEqually
            for index in start..<min(start + 3, themes.count) {
                row.addArrangedSubview(makeThemeButton(themes[index]))
            }
            while row.arrangedSubviews.count < 3 {
                let spacer = UIView()
                spacer.isUserInteractionEnabled = false
                row.addArrangedSubview(spacer)
            }
            rows.addArrangedSubview(row)
            row.snp.makeConstraints { $0.height.equalTo(42) }
        }

        accountCard.snp.makeConstraints { make in
            make.top.equalTo(themeCard.snp.bottom).offset(12)
            make.leading.trailing.equalTo(headerCard)
            make.bottom.equalToSuperview().offset(-24)
        }

        let accountTitle = makeSectionTitle("Account")
        accountCard.addSubview(accountTitle)
        accountCard.addSubview(accountStatusLabel)

        let accountActions = UIStackView(arrangedSubviews: [retroButton, historyButton])
        accountActions.axis = .horizontal
        accountActions.spacing = 8
        accountActions.distribution = .fillEqually
        accountCard.addSubview(accountActions)

        accountTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        accountStatusLabel.snp.makeConstraints { make in
            make.top.equalTo(accountTitle.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        accountActions.snp.makeConstraints { make in
            make.top.equalTo(accountStatusLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().offset(-16)
        }
    }

    private func makeCard() -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.09).cgColor
        return view
    }

    private func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        return label
    }

    private func makeSmallLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = UIColor.white.withAlphaComponent(0.70)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        return label
    }

    private func makeButton(title: String, symbol: String, action: @escaping () -> Void) -> UIButton {
        var configuration = UIButton.Configuration.gray()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = 7
        configuration.baseForegroundColor = .white
        configuration.background.backgroundColor = UIColor.white.withAlphaComponent(0.09)
        let button = UIButton(configuration: configuration)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        button.onFocusConfirm = {
            action()
            return true
        }
        button.onFocusChange = { [weak button] focused in
            UIView.animate(withDuration: 0.14) {
                button?.transform = focused ? CGAffineTransform(scaleX: 1.025, y: 1.025) : .identity
            }
        }
        return button
    }

    private func makeThemeButton(_ theme: XMBBackgroundTheme) -> UIButton {
        var configuration = UIButton.Configuration.gray()
        configuration.title = theme.title
        configuration.baseForegroundColor = .white
        configuration.background.backgroundColor = theme.gradientColors[1].withAlphaComponent(0.55)
        configuration.cornerStyle = .medium
        let button = UIButton(configuration: configuration)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.addAction(UIAction { [weak button] _ in
            XMBBackgroundTheme.current = theme
            button?.superview?.superview?.setNeedsLayout()
        }, for: .touchUpInside)
        button.onFocusConfirm = {
            XMBBackgroundTheme.current = theme
            return true
        }
        return button
    }

    private func refresh() {
        let defaults = UserDefaults.standard
        let name = defaults.string(forKey: "ManicXMB.profileName")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let status = defaults.string(forKey: "ManicXMB.profileStatus")?.trimmingCharacters(in: .whitespacesAndNewlines)
        nameLabel.text = name?.isEmpty == false ? name : "Player"
        statusLabel.text = status?.isEmpty == false ? status : "Ready to play"

        let allGames = Array(Database.realm.objects(Game.self).where { !$0.isDeleted })
        let totalDuration = allGames.reduce(0.0) { $0 + $1.totalPlayDuration }
        let playedGames = allGames.filter { $0.totalPlayDuration > 0 }.count
        let totalText = totalDuration > 0
            ? Date.timeDuration(milliseconds: Int(totalDuration))
            : R.string.localizable.readyGameInfoNeverPlayed()
        let mostPlayed = allGames
            .filter { $0.totalPlayDuration > 0 }
            .max(by: { $0.totalPlayDuration < $1.totalPlayDuration })

        if let mostPlayed {
            statsLabel.text = "Total playtime  \(totalText)\nGames played  \(playedGames) / \(allGames.count)\nMost played  \(mostPlayed.displayName) • \(Date.timeDuration(milliseconds: Int(mostPlayed.totalPlayDuration)))"
        } else {
            statsLabel.text = "Total playtime  \(totalText)\nGames played  \(playedGames) / \(allGames.count)\nMost played  —"
        }

        accountStatusLabel.text = AchievementsUser.getUser().map {
            "RetroAchievements connected as \($0.username)"
        } ?? "RetroAchievements not connected"

        coverModeControl.selectedSegmentIndex = XMBCoverMode(rawValue: defaults.integer(forKey: "ManicXMB.coverMode"))?.rawValue ?? 0
        hintsSwitch.isOn = defaults.bool(forKey: "ManicXMB.showControllerHints")
        loadAvatar()
        backgroundView.applyTheme(.current)
    }

    private func avatarURL() -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let directory = documents.appendingPathComponent("XMBProfile", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("avatar.png")
    }

    private func loadAvatar() {
        if let url = avatarURL(),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            avatarButton.setImage(image, for: .normal)
            avatarButton.imageView?.contentMode = .scaleAspectFill
        } else {
            avatarButton.setImage(UIImage(systemName: "person.crop.circle.fill"), for: .normal)
            avatarButton.imageView?.contentMode = .scaleAspectFit
        }
    }

    @objc private func closePressed() {
        dismiss(animated: true)
    }

    @objc private func changeAvatarPressed() {
        let alert = UIAlertController(title: "Profile avatar", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Choose Photo", style: .default) { [weak self] _ in
            self?.presentAvatarPicker()
        })
        alert.addAction(UIAlertAction(title: "Reset Avatar", style: .destructive) { [weak self] _ in
            guard let self else { return }
            if let url = avatarURL() {
                try? FileManager.default.removeItem(at: url)
            }
            loadAvatar()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = avatarButton
            popover.sourceRect = avatarButton.bounds
        }
        present(alert, animated: true)
    }

    private func presentAvatarPicker() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func editName() {
        let alert = UIAlertController(title: "Display name", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = UserDefaults.standard.string(forKey: "ManicXMB.profileName") ?? "Player"
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            let value = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            UserDefaults.standard.set(value.isEmpty ? "Player" : String(value.prefix(32)), forKey: "ManicXMB.profileName")
            self?.refresh()
        })
        present(alert, animated: true)
    }

    private func editStatus() {
        let alert = UIAlertController(title: "Profile status", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = UserDefaults.standard.string(forKey: "ManicXMB.profileStatus") ?? "Ready to play"
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            let value = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            UserDefaults.standard.set(value.isEmpty ? "Ready to play" : String(value.prefix(70)), forKey: "ManicXMB.profileStatus")
            self?.refresh()
        })
        present(alert, animated: true)
    }

    private func openConsoleIconSettings() {
        let controller = XMBConsoleIconSettingsViewController()
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true)
    }

    @objc private func coverModeChanged(_ sender: UISegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegmentIndex, forKey: "ManicXMB.coverMode")
    }

    @objc private func hintsChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "ManicXMB.showControllerHints")
    }
}

extension XMBProfileDetailsViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self, let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                if let url = self.avatarURL(), let data = image.pngData() {
                    try? data.write(to: url, options: .atomic)
                }
                self.loadAvatar()
            }
        }
    }
}

// MARK: - PS2 crash diagnostics

private final class XMBPS2DiagnosticsViewController: UIViewController {
    private let backgroundView = XMBWaveBackgroundView()
    private let textView = UITextView()

    private lazy var closeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "chevron.left")
        configuration.title = "Back"
        configuration.imagePadding = 6
        configuration.baseForegroundColor = .white
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(closePressed), for: .touchUpInside)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusConfirm = { [weak self] in
            self?.closePressed()
            return true
        }
        return button
    }()

    private lazy var shareButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Share Log"
        configuration.image = UIImage(systemName: "square.and.arrow.up")
        configuration.imagePadding = 7
        configuration.baseForegroundColor = .white
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(sharePressed), for: .touchUpInside)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusConfirm = { [weak self] in
            self?.sharePressed()
            return true
        }
        return button
    }()

    private lazy var clearButton: UIButton = {
        var configuration = UIButton.Configuration.gray()
        configuration.title = "Clear"
        configuration.image = UIImage(systemName: "trash")
        configuration.imagePadding = 7
        configuration.baseForegroundColor = .white
        configuration.background.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(clearPressed), for: .touchUpInside)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusConfirm = { [weak self] in
            self?.clearPressed()
            return true
        }
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(14)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
        }

        let titleLabel = UILabel()
        titleLabel.text = "PS2 Crash Log"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 25, weight: .semibold)
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Persistent launch checkpoints survive a native crash. After a crash, reopen ManicEMU and share this file."
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.64)
        subtitleLabel.font = .systemFont(ofSize: 12.5, weight: .regular)
        subtitleLabel.numberOfLines = 2
        subtitleLabel.textAlignment = .center
        view.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(28)
        }

        let actions = UIStackView(arrangedSubviews: [shareButton, clearButton])
        actions.axis = .horizontal
        actions.spacing = 10
        actions.distribution = .fillEqually
        view.addSubview(actions)
        actions.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(12)
            make.centerX.equalToSuperview()
            make.width.equalTo(360).priority(.high)
            make.leading.greaterThanOrEqualTo(view.safeAreaLayoutGuide).offset(24)
            make.trailing.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-24)
            make.height.equalTo(42)
        }

        textView.backgroundColor = UIColor.black.withAlphaComponent(0.30)
        textView.textColor = UIColor.white.withAlphaComponent(0.86)
        textView.font = UIFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = true
        textView.layer.cornerRadius = 14
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        view.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.top.equalTo(actions.snp.bottom).offset(12)
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-12)
        }

        backgroundView.applyTheme(.current)
        reloadLog()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ExternalInputDispatch.sink = .focusKit
        FocusSystem.shared.isEnabled = true
        pushOverlayFocusContext { [weak self] context in
            context.autoFocusOnActivate = true
            context.preferredFocusView = { [weak self] in self?.shareButton }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if hasFocusContext { popFocusContext() }
    }

    private func reloadLog() {
        textView.text = ARMSX2EmbeddedCore.diagnosticLogText()
        let bottom = NSRange(location: max(0, textView.text.utf16.count - 1), length: 0)
        textView.scrollRangeToVisible(bottom)
    }

    @objc private func closePressed() {
        dismiss(animated: true)
    }

    @objc private func sharePressed() {
        guard let url = ARMSX2EmbeddedCore.diagnosticLogURL else {
            UIView.makeToast(message: "Could not create the PS2 diagnostic file")
            return
        }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        present(controller, animated: true)
    }

    @objc private func clearPressed() {
        ARMSX2EmbeddedCore.clearDiagnosticLog()
        reloadLog()
    }
}

// MARK: - PS2 memory card browser

private struct XMBPS2SaveItem {
    let cardName: String
    let folderName: String
    let title: String
    let serial: String?
    let modified: Date?
    let icon: XMBPS2IconModel?
}

private struct XMBPS2CardSection {
    let name: String
    let saves: [XMBPS2SaveItem]
}

private final class XMBPS2MemoryCardViewController: UIViewController {
    private let backgroundView = XMBWaveBackgroundView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "No PS2 save data found."
        label.textColor = UIColor.white.withAlphaComponent(0.68)
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private var sections: [XMBPS2CardSection] = []

    private lazy var closeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "chevron.left")
        configuration.title = "Back"
        configuration.imagePadding = 6
        configuration.baseForegroundColor = .white
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(closePressed), for: .touchUpInside)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusConfirm = { [weak self] in
            self?.closePressed()
            return true
        }
        return button
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "PS2 Memory Card Data"
        label.textColor = .white
        label.font = .systemFont(ofSize: 25, weight: .semibold)
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Save folders and their original PlayStation 2 browser icons"
        label.textColor = UIColor.white.withAlphaComponent(0.58)
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .center
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(14)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
        }

        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
        }

        view.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
        }

        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.08)
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = 108
        tableView.estimatedRowHeight = 108
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(XMBPS2SaveCell.self, forCellReuseIdentifier: XMBPS2SaveCell.reuseIdentifier)
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        view.addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(30)
        }

        view.addSubview(loadingIndicator)
        loadingIndicator.color = .white
        loadingIndicator.snp.makeConstraints { $0.center.equalToSuperview() }

        backgroundView.applyTheme(.current)
        loadMemoryCards()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ExternalInputDispatch.sink = .focusKit
        FocusSystem.shared.isEnabled = true
        pushOverlayFocusContext { [weak self] context in
            context.autoFocusOnActivate = true
            context.preferredFocusView = { [weak self] in self?.closeButton }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if hasFocusContext { popFocusContext() }
    }

    @objc private func closePressed() {
        dismiss(animated: true)
    }

    private func memoryCardDirectoryURL() -> URL? {
#if canImport(ARMSX2Core)
        guard ARMSX2EmbeddedRuntime.prepare() else { return nil }
        return URL(fileURLWithPath: ARMSX2Bridge.memoryCardDirectory(), isDirectory: true)
#else
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return documents.appendingPathComponent("ARMSX2/memcards", isDirectory: true)
#endif
    }

    private func loadMemoryCards() {
        guard let directory = memoryCardDirectoryURL() else {
            emptyLabel.text = "ARMSX2 could not initialize its memory-card directory."
            emptyLabel.isHidden = false
            return
        }

        loadingIndicator.startAnimating()
        emptyLabel.isHidden = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let loaded = XMBPS2MemoryCardReader.readSections(in: directory)
            DispatchQueue.main.async {
                guard let self else { return }
                self.loadingIndicator.stopAnimating()
                self.sections = loaded
                self.tableView.reloadData()
                let count = loaded.reduce(0) { $0 + $1.saves.count }
                self.emptyLabel.text = loaded.isEmpty
                    ? "No PS2 memory cards were found."
                    : (count == 0 ? "The PS2 memory cards are present, but they do not contain readable save folders yet." : "")
                self.emptyLabel.isHidden = !loaded.isEmpty && count > 0
            }
        }
    }
}

extension XMBPS2MemoryCardViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].saves.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].name
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.textColor = UIColor.white.withAlphaComponent(0.72)
        header.textLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        header.contentView.backgroundColor = UIColor.black.withAlphaComponent(0.10)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: XMBPS2SaveCell.reuseIdentifier,
                                                 for: indexPath) as! XMBPS2SaveCell
        cell.configure(with: sections[indexPath.section].saves[indexPath.row])
        return cell
    }
}

private final class XMBPS2SaveCell: UITableViewCell {
    static let reuseIdentifier = "XMBPS2SaveCell"

    private let iconView = XMBPS2IconSceneView(frame: .zero)
    private let fallbackIconView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "memorychip.fill"))
        view.tintColor = UIColor.white.withAlphaComponent(0.70)
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.numberOfLines = 2
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white.withAlphaComponent(0.55)
        label.font = .systemFont(ofSize: 11.5, weight: .regular)
        label.numberOfLines = 2
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = UIColor.black.withAlphaComponent(0.08)
        selectionStyle = .none

        contentView.addSubview(iconView)
        contentView.addSubview(fallbackIconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(18)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(86)
        }
        fallbackIconView.snp.makeConstraints { make in
            make.center.equalTo(iconView)
            make.width.height.equalTo(42)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(14)
            make.trailing.equalToSuperview().offset(-18)
            make.centerY.equalToSuperview().offset(-13)
        }
        detailLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(5)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.setModel(Optional<XMBPS2IconModel>.none)
        fallbackIconView.isHidden = false
        titleLabel.text = nil
        detailLabel.text = nil
    }

    func configure(with item: XMBPS2SaveItem) {
        titleLabel.text = item.title.isEmpty ? (item.serial ?? item.folderName) : item.title
        var detail = [item.serial ?? item.folderName, item.cardName]
        if let modified = item.modified {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            detail.append(formatter.string(from: modified))
        }
        detailLabel.text = detail.joined(separator: "  •  ")

        iconView.setModel(item.icon)
        fallbackIconView.isHidden = item.icon != nil
    }
}

private final class XMBPS2IconSceneView: SCNView {
    override init(frame: CGRect, options: [String : Any]? = nil) {
        super.init(frame: frame, options: options)
        backgroundColor = .clear
        isOpaque = false
        antialiasingMode = .multisampling4X
        allowsCameraControl = false
        autoenablesDefaultLighting = false
        isPlaying = true
        rendersContinuously = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setModel(_ model: XMBPS2IconModel?) {
        scene = nil
        guard let model else { return }

        let scene = SCNScene()
        let root = SCNNode()
        scene.rootNode.addChildNode(root)

        let geometry = model.makeGeometry()
        let modelNode = SCNNode(geometry: geometry)
        root.addChildNode(modelNode)

        let (minimum, maximum) = modelNode.boundingBox
        let center = SCNVector3((minimum.x + maximum.x) * 0.5,
                                (minimum.y + maximum.y) * 0.5,
                                (minimum.z + maximum.z) * 0.5)
        modelNode.pivot = SCNMatrix4MakeTranslation(center.x, center.y, center.z)
        let width = max(0.001, maximum.x - minimum.x)
        let height = max(0.001, maximum.y - minimum.y)
        let depth = max(0.001, maximum.z - minimum.z)
        let scale = 1.65 / max(width, max(height, depth))
        modelNode.scale = SCNVector3(scale, -scale, scale)

        modelNode.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 6.0)))

        let camera = SCNCamera()
        camera.fieldOfView = 38
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 4.2)
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 520
        ambient.color = UIColor(white: 0.92, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .omni
        key.intensity = 900
        key.color = UIColor.white
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(2.4, 2.2, 3.6)
        scene.rootNode.addChildNode(keyNode)

        self.scene = scene
    }
}

private struct XMBPS2IconModel {
    let positions: [SCNVector3]
    let normals: [SCNVector3]
    let textureCoordinates: [CGPoint]
    let texture: UIImage?

    func makeGeometry() -> SCNGeometry {
        let vertexSource = SCNGeometrySource(vertices: positions)
        var sources = [vertexSource]

        if normals.count == positions.count {
            sources.append(SCNGeometrySource(normals: normals))
        }
        if textureCoordinates.count == positions.count {
            sources.append(SCNGeometrySource(textureCoordinates: textureCoordinates))
        }

        let indices = (0..<positions.count).map { UInt32($0) }
        let indexData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(data: indexData,
                                         primitiveType: .triangles,
                                         primitiveCount: positions.count / 3,
                                         bytesPerIndex: MemoryLayout<UInt32>.size)

        let geometry = SCNGeometry(sources: sources, elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .phong
        material.isDoubleSided = true
        material.diffuse.contents = texture ?? UIColor(white: 0.90, alpha: 1)
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.specular.contents = UIColor.white.withAlphaComponent(0.18)
        material.shininess = 0.15
        geometry.materials = [material]
        return geometry
    }

    static func parse(_ data: Data?) -> XMBPS2IconModel? {
        guard let data, data.count >= 20, ps2U32(data, 0) == 0x00010000 else { return nil }
        let shapeCount = Int(ps2U32(data, 4))
        let textureType = Int(ps2U32(data, 8))
        let vertexCountRaw = Int(ps2U32(data, 16))
        guard (1...64).contains(shapeCount), (3...60_000).contains(vertexCountRaw) else { return nil }

        let bytesPerVertex = shapeCount * 8 + 16
        guard 20 + vertexCountRaw * bytesPerVertex <= data.count else { return nil }

        var positions: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var texcoords: [CGPoint] = []
        positions.reserveCapacity(vertexCountRaw)
        normals.reserveCapacity(vertexCountRaw)
        texcoords.reserveCapacity(vertexCountRaw)

        var offset = 20
        for _ in 0..<vertexCountRaw {
            var firstPosition = SCNVector3Zero
            for shape in 0..<shapeCount {
                let x = Float(ps2I16(data, offset)) / 4096.0
                let y = Float(ps2I16(data, offset + 2)) / 4096.0
                let z = Float(ps2I16(data, offset + 4)) / 4096.0
                if shape == 0 {
                    firstPosition = SCNVector3(x, y, z)
                }
                offset += 8
            }
            positions.append(firstPosition)

            normals.append(SCNVector3(Float(ps2I16(data, offset)) / 4096.0,
                                      Float(ps2I16(data, offset + 2)) / 4096.0,
                                      Float(ps2I16(data, offset + 4)) / 4096.0))
            offset += 8

            texcoords.append(CGPoint(x: CGFloat(Float(ps2I16(data, offset)) / 4096.0),
                                     y: CGFloat(Float(ps2I16(data, offset + 2)) / 4096.0)))
            offset += 4

            // Vertex RGBA, currently left to SceneKit's material/texture.
            offset += 4
        }

        // Skip animation records to reach the texture payload.
        if offset + 20 <= data.count, ps2U32(data, offset) == 1 {
            let frameCount = min(1024, max(0, Int(ps2U32(data, offset + 16))))
            offset += 20
            for _ in 0..<frameCount {
                guard offset + 8 <= data.count else { break }
                let keyCount = Int(ps2U32(data, offset + 4))
                offset += 8
                guard keyCount >= 0, keyCount <= 4096, offset + keyCount * 8 <= data.count else { break }
                offset += keyCount * 8
            }
        }

        let safeCount = vertexCountRaw - vertexCountRaw % 3
        guard safeCount >= 3 else { return nil }

        return XMBPS2IconModel(
            positions: Array(positions.prefix(safeCount)),
            normals: Array(normals.prefix(safeCount)),
            textureCoordinates: Array(texcoords.prefix(safeCount)),
            texture: decodePS2IconTexture(data, start: offset, type: textureType)
        )
    }
}

private struct XMBPS2IconSystem {
    let title: String
    let iconNormal: String

    static func parse(_ data: Data?) -> XMBPS2IconSystem? {
        guard let data, data.count >= 964,
              String(data: data.subdata(in: 0..<4), encoding: .ascii) == "PS2D" else { return nil }

        let iconName = ps2CString(data, offset: 0x104, maxLength: 64, encoding: .ascii)
        let titleStart = 0xC0
        var titleEnd = titleStart
        let titleLimit = min(data.count, titleStart + 68)
        while titleEnd < titleLimit, data[titleEnd] != 0 {
            titleEnd += 1
        }

        let raw = data.subdata(in: titleStart..<titleEnd)
        let split = min(max(Int(ps2U16(data, 0x06)), 0), raw.count)
        let firstData = raw.subdata(in: 0..<split)
        let secondData = raw.subdata(in: split..<raw.count)
        let first = String(data: firstData, encoding: .shiftJIS) ?? ""
        let second = String(data: secondData, encoding: .shiftJIS) ?? ""
        let joined: String
        if first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            second.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            joined = first + second
        } else {
            joined = first + " " + second
        }
        let normalized = joined
            .precomposedStringWithCompatibilityMapping
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return XMBPS2IconSystem(title: normalized, iconNormal: iconName)
    }
}

private enum XMBPS2MemoryCardReader {
    static func readSections(in directory: URL) -> [XMBPS2CardSection] {
        let fileManager = FileManager.default
        guard let cards = try? fileManager.contentsOfDirectory(at: directory,
                                                               includingPropertiesForKeys: [.isDirectoryKey],
                                                               options: [.skipsHiddenFiles]) else {
            return []
        }

        return cards.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .compactMap { cardURL in
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: cardURL.path, isDirectory: &isDirectory) else { return nil }

                let saves: [XMBPS2SaveItem]
                if isDirectory.boolValue {
                    saves = readFolderCard(at: cardURL)
                } else {
                    saves = XMBPS2ImageCardReader(url: cardURL)?.readSaves(cardName: cardURL.lastPathComponent) ?? []
                }
                return XMBPS2CardSection(name: cardURL.lastPathComponent,
                                         saves: saves.sorted {
                                             ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast)
                                         })
            }
    }

    private static func readFolderCard(at url: URL) -> [XMBPS2SaveItem] {
        let fileManager = FileManager.default
        guard let folders = try? fileManager.contentsOfDirectory(at: url,
                                                                 includingPropertiesForKeys: [.isDirectoryKey],
                                                                 options: [.skipsHiddenFiles]) else {
            return []
        }

        return folders.compactMap { saveURL in
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: saveURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  !saveURL.lastPathComponent.hasPrefix("_pcsx2") else { return nil }

            let files = (try? fileManager.contentsOfDirectory(at: saveURL,
                                                              includingPropertiesForKeys: [.contentModificationDateKey],
                                                              options: [.skipsHiddenFiles])) ?? []
            let byName = Dictionary(uniqueKeysWithValues: files.map { ($0.lastPathComponent.lowercased(), $0) })
            let sysURL = byName["icon.sys"]
            let sysData = sysURL.flatMap { try? Data(contentsOf: $0) }
            let sys = XMBPS2IconSystem.parse(sysData)
            let iconURL = sys.flatMap { byName[$0.iconNormal.lowercased()] }
            let iconData = iconURL.flatMap { try? Data(contentsOf: $0) }
            let modified = files.compactMap {
                try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            }.compactMap { $0 }.max()

            let folderName = saveURL.lastPathComponent
            let serial = ps2Serial(from: folderName)
            let title = (sys?.title.isEmpty == false) ? sys!.title : (serial ?? folderName)
            return XMBPS2SaveItem(cardName: url.lastPathComponent,
                                  folderName: folderName,
                                  title: title,
                                  serial: serial,
                                  modified: modified,
                                  icon: XMBPS2IconModel.parse(iconData))
        }
    }
}

private final class XMBPS2ImageCardReader {
    private struct Entry {
        let mode: Int
        let length: Int
        let cluster: Int
        let name: String
        let modified: Date?
    }

    private let data: Data
    private let stride: Int
    private let pagesPerCluster: Int
    private let clustersPerCard: Int
    private let allocationOffset: Int
    private let rootCluster: Int
    private let indirectFATClusters: [Int]
    private let clusterSize: Int
    private let entriesPerCluster: Int
    private var fatCache: [Int: Data] = [:]

    init?(url: URL) {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]), !data.isEmpty else { return nil }

        let stride: Int
        if data.count % 528 == 0, data.count / 528 >= 1024 {
            stride = 528
        } else if data.count % 512 == 0, data.count >= 512 {
            stride = 512
        } else {
            return nil
        }

        guard data.count >= 512 else { return nil }
        let superblock = data.subdata(in: 0..<512)
        let magic = "Sony PS2 Memory Card Format "
        guard let magicData = magic.data(using: .ascii),
              superblock.prefix(magicData.count) == magicData,
              ps2U16(superblock, 0x28) == 512 else { return nil }

        let ppc = Int(ps2U16(superblock, 0x2A))
        let clusters = Int(ps2U32(superblock, 0x30))
        guard (1...16).contains(ppc), (1...(1 << 22)).contains(clusters) else { return nil }

        self.data = data
        self.stride = stride
        self.pagesPerCluster = ppc
        self.clustersPerCard = clusters
        self.allocationOffset = Int(ps2U32(superblock, 0x34))
        self.rootCluster = Int(ps2U32(superblock, 0x3C))
        self.indirectFATClusters = (0..<32).map { Int(ps2U32(superblock, 0x50 + $0 * 4)) }
        self.clusterSize = 512 * ppc
        self.entriesPerCluster = (512 * ppc) / 4
    }

    func readSaves(cardName: String) -> [XMBPS2SaveItem] {
        guard let rootCount = entries(relativeCluster: rootCluster, count: 1).first?.length else { return [] }

        return entries(relativeCluster: rootCluster, count: rootCount)
            .dropFirst(2)
            .filter { ($0.mode & 0x8000) != 0 && ($0.mode & 0x0020) != 0 }
            .compactMap { directory in
                let fileEntries = entries(relativeCluster: directory.cluster, count: directory.length)
                    .dropFirst(2)
                    .filter { ($0.mode & 0x8000) != 0 && ($0.mode & 0x0010) != 0 }

                let byName = Dictionary(uniqueKeysWithValues: fileEntries.map { ($0.name.lowercased(), $0) })
                let sysEntry = byName["icon.sys"]
                let sysData = sysEntry.flatMap { read(relativeCluster: $0.cluster, length: $0.length) }
                let sys = XMBPS2IconSystem.parse(sysData)
                let iconEntry = sys.flatMap { byName[$0.iconNormal.lowercased()] }
                let iconData = iconEntry.flatMap { read(relativeCluster: $0.cluster, length: $0.length) }
                let serial = ps2Serial(from: directory.name)
                let title = (sys?.title.isEmpty == false) ? sys!.title : (serial ?? directory.name)

                return XMBPS2SaveItem(cardName: cardName,
                                      folderName: directory.name,
                                      title: title,
                                      serial: serial,
                                      modified: directory.modified,
                                      icon: XMBPS2IconModel.parse(iconData))
            }
    }

    private func cluster(_ absolute: Int) -> Data? {
        guard absolute >= 0, absolute < clustersPerCard else { return nil }
        var output = Data(capacity: clusterSize)
        let totalPages = data.count / stride

        for index in 0..<pagesPerCluster {
            let page = absolute * pagesPerCluster + index
            guard page < totalPages else { return nil }
            let start = page * stride
            guard start + 512 <= data.count else { return nil }
            output.append(data.subdata(in: start..<(start + 512)))
        }
        return output
    }

    private func cachedCluster(_ absolute: Int) -> Data? {
        if let cached = fatCache[absolute] { return cached }
        guard let loaded = cluster(absolute) else { return nil }
        if fatCache.count < 4096 {
            fatCache[absolute] = loaded
        }
        return loaded
    }

    private func fat(_ relative: Int) -> UInt32? {
        guard relative >= 0 else { return nil }
        let fatIndex = relative / entriesPerCluster
        guard fatIndex / entriesPerCluster < indirectFATClusters.count else { return nil }

        let indirect = indirectFATClusters[fatIndex / entriesPerCluster]
        guard let indirectData = cachedCluster(indirect) else { return nil }
        let fatClusterOffset = (fatIndex % entriesPerCluster) * 4
        guard fatClusterOffset + 4 <= indirectData.count else { return nil }

        let fatCluster = Int(ps2U32(indirectData, fatClusterOffset))
        guard let fatData = cachedCluster(fatCluster) else { return nil }
        let entryOffset = (relative % entriesPerCluster) * 4
        guard entryOffset + 4 <= fatData.count else { return nil }
        return ps2U32(fatData, entryOffset)
    }

    private func read(relativeCluster: Int, length: Int) -> Data? {
        guard length >= 0, length <= clustersPerCard * clusterSize else { return nil }

        var output = Data(capacity: length)
        var current = relativeCluster
        var steps = 0

        while output.count < length {
            guard steps <= clustersPerCard,
                  let bytes = cluster(current + allocationOffset) else { return nil }
            steps += 1
            output.append(bytes.prefix(min(clusterSize, length - output.count)))
            if output.count >= length { break }

            guard let fatEntry = fat(current),
                  fatEntry != 0xFFFFFFFF,
                  (fatEntry & 0x80000000) != 0 else { return nil }
            current = Int(fatEntry & 0x7FFFFFFF)
        }

        return output
    }

    private func entries(relativeCluster: Int, count: Int) -> [Entry] {
        guard count > 0, count <= 4096,
              let raw = read(relativeCluster: relativeCluster, length: count * 512) else { return [] }

        return (0..<count).compactMap { index in
            let offset = index * 512
            guard offset + 0x60 <= raw.count else { return nil }

            var nameEnd = offset + 0x40
            while nameEnd < offset + 0x60, raw[nameEnd] != 0 {
                nameEnd += 1
            }
            let name = String(data: raw.subdata(in: (offset + 0x40)..<nameEnd), encoding: .ascii) ?? ""
            return Entry(mode: Int(ps2U16(raw, offset)),
                         length: Int(ps2U32(raw, offset + 4)),
                         cluster: Int(ps2U32(raw, offset + 0x10)),
                         name: name,
                         modified: ps2Timestamp(raw, offset: offset + 0x18))
        }
    }
}

private func ps2Serial(from folder: String) -> String? {
    let upper = folder.uppercased()
    let pattern = #"^B[A-Z]([A-Z]{4})[-_]?(\d{3})\.?(\d{2})"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: upper, range: NSRange(upper.startIndex..., in: upper)),
          match.numberOfRanges >= 4,
          let codeRange = Range(match.range(at: 1), in: upper),
          let firstRange = Range(match.range(at: 2), in: upper),
          let secondRange = Range(match.range(at: 3), in: upper) else { return nil }
    return "\(upper[codeRange])-\(upper[firstRange])\(upper[secondRange])"
}

private func ps2Timestamp(_ data: Data, offset: Int) -> Date? {
    guard offset >= 0, offset + 8 <= data.count else { return nil }
    var components = DateComponents()
    components.timeZone = TimeZone(identifier: "Asia/Tokyo")
    components.second = Int(data[offset + 1])
    components.minute = Int(data[offset + 2])
    components.hour = Int(data[offset + 3])
    components.day = Int(data[offset + 4])
    components.month = Int(data[offset + 5])
    components.year = Int(ps2U16(data, offset + 6))
    return Calendar(identifier: .gregorian).date(from: components)
}

private func ps2CString(_ data: Data,
                        offset: Int,
                        maxLength: Int,
                        encoding: String.Encoding) -> String {
    guard offset >= 0, offset < data.count else { return "" }
    let limit = min(data.count, offset + maxLength)
    var end = offset
    while end < limit, data[end] != 0 {
        end += 1
    }
    return String(data: data.subdata(in: offset..<end), encoding: encoding) ?? ""
}

private func ps2U16(_ data: Data, _ offset: Int) -> UInt16 {
    guard offset >= 0, offset + 2 <= data.count else { return 0 }
    return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
}

private func ps2I16(_ data: Data, _ offset: Int) -> Int16 {
    Int16(bitPattern: ps2U16(data, offset))
}

private func ps2U32(_ data: Data, _ offset: Int) -> UInt32 {
    guard offset >= 0, offset + 4 <= data.count else { return 0 }
    return UInt32(data[offset])
        | (UInt32(data[offset + 1]) << 8)
        | (UInt32(data[offset + 2]) << 16)
        | (UInt32(data[offset + 3]) << 24)
}

private func decodePS2IconTexture(_ data: Data, start: Int, type: Int) -> UIImage? {
    let textureSize = 128
    let pixelCount = textureSize * textureSize
    var pixels = [UInt16]()
    pixels.reserveCapacity(pixelCount)
    var offset = start

    func appendPixel(_ value: UInt16) {
        if pixels.count < pixelCount {
            pixels.append(value)
        }
    }

    if (type & 8) != 0 {
        guard offset + 4 <= data.count else { return nil }
        let encodedSize = Int(ps2U32(data, offset))
        offset += 4
        let end = min(data.count, offset + max(0, encodedSize))

        while pixels.count < pixelCount, offset + 2 <= end {
            let code = ps2U16(data, offset)
            offset += 2
            if code == 0 { continue }

            if (code & 0x8000) != 0 {
                var count = 0x10000 - Int(code)
                while count > 0, pixels.count < pixelCount, offset + 2 <= end {
                    appendPixel(ps2U16(data, offset))
                    offset += 2
                    count -= 1
                }
            } else {
                guard offset + 2 <= end else { break }
                let color = ps2U16(data, offset)
                offset += 2
                var count = Int(code)
                while count > 0, pixels.count < pixelCount {
                    appendPixel(color)
                    count -= 1
                }
            }
        }
    } else {
        guard offset + pixelCount * 2 <= data.count else { return nil }
        for index in 0..<pixelCount {
            appendPixel(ps2U16(data, offset + index * 2))
        }
    }

    guard !pixels.isEmpty else { return nil }
    if pixels.count < pixelCount {
        pixels.append(contentsOf: repeatElement(0, count: pixelCount - pixels.count))
    }

    var rgba = [UInt8](repeating: 0, count: pixelCount * 4)
    for index in 0..<pixelCount {
        let pixel = Int(pixels[index])
        rgba[index * 4] = UInt8((pixel & 31) * 255 / 31)
        rgba[index * 4 + 1] = UInt8(((pixel >> 5) & 31) * 255 / 31)
        rgba[index * 4 + 2] = UInt8(((pixel >> 10) & 31) * 255 / 31)
        rgba[index * 4 + 3] = 255
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let image: CGImage? = rgba.withUnsafeMutableBytes { bytes in
        guard let base = bytes.baseAddress,
              let context = CGContext(data: base,
                                      width: textureSize,
                                      height: textureSize,
                                      bitsPerComponent: 8,
                                      bytesPerRow: textureSize * 4,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        return context.makeImage()
    }
    return image.map { UIImage(cgImage: $0) }
}

// MARK: - Easier exit from original Manic screens

private final class XMBModalHostViewController: UIViewController {
    private let contentViewController: UIViewController

    private lazy var closeButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "xmark")
        configuration.title = "Close"
        configuration.imagePadding = 7
        configuration.baseBackgroundColor = UIColor.black.withAlphaComponent(0.58)
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .capsule

        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(closePressed), for: .touchUpInside)
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusChange = { [weak button] focused in
            UIView.animate(withDuration: 0.12) {
                button?.transform = focused ? CGAffineTransform(scaleX: 1.07, y: 1.07) : .identity
                button?.alpha = focused ? 1.0 : 0.84
            }
        }
        return button
    }()

    init(contentViewController: UIViewController) {
        self.contentViewController = contentViewController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        addChild(contentViewController)
        view.addSubview(contentViewController.view)
        contentViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        contentViewController.didMove(toParent: self)

        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(10)
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(12)
            make.height.greaterThanOrEqualTo(42)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ExternalInputDispatch.sink = .focusKit

        DispatchQueue.main.async { [weak self] in
            guard let self, self.view.window != nil else { return }
            self.pushOverlayFocusContext { [weak self] context in
                guard let self else { return }
                context.autoFocusOnActivate = true
                context.preferredFocusView = { [weak self] in self?.closeButton }
                context.addCommand(FocusCommand(key: .b, title: "Close", action: { [weak self] in
                    self?.dismiss(animated: true)
                }))
            }
            if FocusSystem.shared.hasExternalInput {
                FocusSystem.shared.updateFocusIfNeeded()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if hasFocusContext {
            popFocusContext()
        }
    }

    @objc private func closePressed() {
        dismiss(animated: true)
    }
}

// MARK: - Animated XMB-style blue background

private final class XMBWaveBackgroundView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let waveLayers: [CAShapeLayer] = (0..<4).map { _ in CAShapeLayer() }
    private var themeObserver: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        gradientLayer.colors = XMBBackgroundTheme.current.gradientColors.map(\.cgColor)
        gradientLayer.startPoint = CGPoint(x: 0.05, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.95, y: 1)
        layer.addSublayer(gradientLayer)

        for (index, wave) in waveLayers.enumerated() {
            let alpha = max(0.045, 0.125 - CGFloat(index) * 0.020)
            wave.fillColor = XMBBackgroundTheme.current.waveColor.withAlphaComponent(alpha).cgColor
            wave.strokeColor = UIColor.white.withAlphaComponent(alpha * 1.35).cgColor
            wave.lineWidth = CGFloat(0.7 + Double(index) * 0.35)
            wave.lineJoin = .round
            layer.addSublayer(wave)
        }

        themeObserver = NotificationCenter.default.addObserver(forName: .xmbBackgroundThemeDidChange,
                                                               object: nil,
                                                               queue: .main) { [weak self] note in
            let theme = (note.object as? XMBBackgroundTheme) ?? .current
            self?.applyTheme(theme)
        }
        applyTheme(.current)
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    func applyTheme(_ theme: XMBBackgroundTheme) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.28)
        gradientLayer.colors = theme.gradientColors.map(\.cgColor)
        for (index, wave) in waveLayers.enumerated() {
            let alpha = max(0.045, 0.125 - CGFloat(index) * 0.020)
            wave.fillColor = theme.waveColor.withAlphaComponent(alpha).cgColor
            wave.strokeColor = UIColor.white.withAlphaComponent(alpha * 1.35).cgColor
        }
        CATransaction.commit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            waveLayers.forEach { $0.removeAllAnimations() }
        } else {
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds

        let centerY = bounds.height * 0.50
        let waveWidth = bounds.width + 260

        for (index, wave) in waveLayers.enumerated() {
            wave.frame = CGRect(x: -130, y: 0, width: waveWidth, height: bounds.height)

            let verticalOffset = CGFloat(index) * 14
            let amplitude = CGFloat(30 + index * 12)
            let bandHeight = CGFloat(22 + index * 7)

            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: centerY + verticalOffset))
            path.addCurve(to: CGPoint(x: waveWidth * 0.52, y: centerY - amplitude + verticalOffset),
                          controlPoint1: CGPoint(x: waveWidth * 0.15, y: centerY - amplitude * 1.3 + verticalOffset),
                          controlPoint2: CGPoint(x: waveWidth * 0.34, y: centerY + amplitude * 0.75 + verticalOffset))
            path.addCurve(to: CGPoint(x: waveWidth, y: centerY + amplitude * 0.25 + verticalOffset),
                          controlPoint1: CGPoint(x: waveWidth * 0.70, y: centerY - amplitude * 1.15 + verticalOffset),
                          controlPoint2: CGPoint(x: waveWidth * 0.88, y: centerY + amplitude * 1.10 + verticalOffset))
            path.addLine(to: CGPoint(x: waveWidth, y: centerY + amplitude * 0.25 + verticalOffset + bandHeight))
            path.addCurve(to: CGPoint(x: waveWidth * 0.52, y: centerY - amplitude + verticalOffset + bandHeight),
                          controlPoint1: CGPoint(x: waveWidth * 0.88, y: centerY + amplitude * 1.10 + verticalOffset + bandHeight),
                          controlPoint2: CGPoint(x: waveWidth * 0.70, y: centerY - amplitude * 1.15 + verticalOffset + bandHeight))
            path.addCurve(to: CGPoint(x: 0, y: centerY + verticalOffset + bandHeight),
                          controlPoint1: CGPoint(x: waveWidth * 0.34, y: centerY + amplitude * 0.75 + verticalOffset + bandHeight),
                          controlPoint2: CGPoint(x: waveWidth * 0.15, y: centerY - amplitude * 1.3 + verticalOffset + bandHeight))
            path.close()
            wave.path = path.cgPath

            if wave.animation(forKey: "xmbWaveDrift") == nil {
                let drift = CABasicAnimation(keyPath: "transform.translation.x")
                drift.fromValue = CGFloat(-55 - index * 12)
                drift.toValue = CGFloat(55 + index * 15)
                drift.duration = 6.5 + Double(index) * 1.8
                drift.autoreverses = true
                drift.repeatCount = .infinity
                drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                wave.add(drift, forKey: "xmbWaveDrift")

                let pulse = CABasicAnimation(keyPath: "opacity")
                pulse.fromValue = 0.62
                pulse.toValue = 1.0
                pulse.duration = 3.4 + Double(index) * 0.8
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                wave.add(pulse, forKey: "xmbWavePulse")
            }
        }
    }
}
