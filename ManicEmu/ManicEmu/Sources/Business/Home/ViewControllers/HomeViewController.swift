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

    private var sections: [XMBSection] = []
    private var selectedSectionIndex = 0
    private var games: [Game] = []
    private var rememberedGameIndex: [String: Int] = [:]
    private var gameToken: NotificationToken?
    private var clockTimer: Timer?
    private var sectionCenterConstraint: Constraint?

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
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.80)
        label.textAlignment = .right
        return label
    }()

    private let sectionScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.clipsToBounds = false
        scrollView.decelerationRate = .fast
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
    private let positionRail = XMBPositionRailView()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 3
        layout.sectionInset = UIEdgeInsets(top: 7, left: 0, bottom: 30, right: 0)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
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
            UIView.animate(withDuration: 0.12) {
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

        clockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateClock()
        }
    }

    deinit {
        gameToken = nil
        clockTimer?.invalidate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        ExternalInputDispatch.sink = .focusKit

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
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if hasFocusContext {
            popFocusContext()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // The XMB rail sits near the visual center on every aspect ratio.
        sectionCenterConstraint?.update(offset: -view.bounds.height * 0.10)

        let sideInset = max(0, (sectionScrollView.bounds.width - 86) / 2)
        sectionScrollView.contentInset.left = sideInset
        sectionScrollView.contentInset.right = sideInset

        if sections.indices.contains(selectedSectionIndex) {
            scrollSelectedSectionIntoView(animated: false)
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

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(sectionScrollView.snp.bottom).offset(2)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualTo(view.safeAreaLayoutGuide).multipliedBy(0.8)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(1)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualTo(view.safeAreaLayoutGuide).multipliedBy(0.84)
        }

        view.addSubview(gamesContentView)
        gamesContentView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualTo(460)
            make.leading.greaterThanOrEqualTo(view.safeAreaLayoutGuide).offset(12)
            make.trailing.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-12)
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        gamesContentView.addSubview(listContainerView)
        listContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        listContainerView.addSubview(collectionView)
        listContainerView.addSubview(positionRail)

        positionRail.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(8)
            make.width.equalTo(24)
        }

        collectionView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.equalTo(positionRail.snp.leading).offset(-8)
        }

        view.addSubview(profileContainerView)
        profileContainerView.isHidden = true
        profileContainerView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualTo(620)
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

        view.addSubview(actionContainerView)
        actionContainerView.isHidden = true
        actionContainerView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualTo(420)
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
        actionSymbolView.tintColor = UIColor.white.withAlphaComponent(0.92)
        actionSymbolView.contentMode = .scaleAspectFit

        actionTitleLabel.textColor = .white
        actionTitleLabel.font = .systemFont(ofSize: 21, weight: .semibold)
        actionTitleLabel.textAlignment = .center

        actionSubtitleLabel.textColor = UIColor.white.withAlphaComponent(0.60)
        actionSubtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        actionSubtitleLabel.textAlignment = .center
        actionSubtitleLabel.numberOfLines = 2

        actionContainerView.addSubview(actionSymbolView)
        actionContainerView.addSubview(actionTitleLabel)
        actionContainerView.addSubview(actionSubtitleLabel)
        actionContainerView.addSubview(actionButton)

        actionSymbolView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(56)
        }
        actionTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(actionSymbolView.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
        }
        actionSubtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(actionTitleLabel.snp.bottom).offset(5)
            make.leading.trailing.equalToSuperview().inset(14)
        }
        actionButton.snp.makeConstraints { make in
            make.top.equalTo(actionSubtitleLabel.snp.bottom).offset(14)
            make.centerX.equalToSuperview()
            make.width.equalTo(190)
            make.height.equalTo(44)
            make.bottom.equalToSuperview()
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
        let results = Database.realm.objects(Game.self).where { !$0.isDeleted }
        gameToken = results.observe { [weak self] _ in
            self?.rebuildSectionsAndContent()
        }
        rebuildSectionsAndContent()
    }

    private func rebuildSectionsAndContent() {
        let allGames = Array(Database.realm.objects(Game.self).where { !$0.isDeleted })
        let existingIdentifier = sections.indices.contains(selectedSectionIndex)
            ? sections[selectedSectionIndex].identifier
            : UserDefaults.standard.string(forKey: Self.selectedSectionDefaultsKey)

        let availableTypes = Set(allGames.map(\.gameType))
        var orderedTypes = System.allGameTypes.filter { availableTypes.contains($0) }
        let extraTypes = availableTypes
            .filter { !orderedTypes.contains($0) }
            .sorted { $0.localizedShortName.localizedCaseInsensitiveCompare($1.localizedShortName) == .orderedAscending }
        orderedTypes.append(contentsOf: extraTypes)

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
    }

    private func rebuildSectionButtons() {
        sectionButtons.forEach { $0.removeFromSuperview() }
        sectionButtons.removeAll()

        for (index, section) in sections.enumerated() {
            var configuration = UIButton.Configuration.plain()
            configuration.image = safeSystemImage(section.symbol)
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
        selectedSectionIndex = sender.tag
        updateSelectedSection(animated: true, restoreFocus: false)
    }

    private func moveSection(by offset: Int) {
        guard !sections.isEmpty else { return }

        rememberCurrentGameIndex()

        let newIndex = min(max(selectedSectionIndex + offset, 0), sections.count - 1)
        guard newIndex != selectedSectionIndex else { return }

        selectedSectionIndex = newIndex
        updateSelectedSection(animated: true, restoreFocus: true)
    }

    private func updateSelectedSection(animated: Bool, restoreFocus: Bool) {
        guard sections.indices.contains(selectedSectionIndex) else { return }
        let section = sections[selectedSectionIndex]

        UserDefaults.standard.set(section.identifier, forKey: Self.selectedSectionDefaultsKey)

        for (index, button) in sectionButtons.enumerated() {
            let selected = index == selectedSectionIndex
            button.configuration?.baseForegroundColor = selected ? .white : UIColor.white.withAlphaComponent(0.54)
            button.alpha = selected ? 1.0 : 0.62
            button.transform = selected ? CGAffineTransform(scaleX: 1.14, y: 1.14) : .identity
            button.layer.shadowColor = selected ? UIColor.systemCyan.cgColor : UIColor.clear.cgColor
            button.layer.shadowOpacity = selected ? 0.55 : 0
            button.layer.shadowRadius = selected ? 12 : 0
        }

        scrollSelectedSectionIntoView(animated: animated)
        titleLabel.text = section.title

        let showGames: Bool
        let showProfile: Bool
        let showAction: Bool

        switch section.kind {
        case .console(let gameType):
            games = Array(Database.realm.objects(Game.self).where { !$0.isDeleted })
                .filter { $0.gameType == gameType }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            showGames = true
            showProfile = false
            showAction = false
            subtitleLabel.text = games.isEmpty ? "No games in this system" : "\(games.count) game\(games.count == 1 ? "" : "s")"

        case .profile:
            games = []
            showGames = false
            showProfile = true
            showAction = false
            subtitleLabel.text = "Custom XMB profile"
            refreshProfile()

        case .importGames:
            games = []
            showGames = false
            showProfile = false
            showAction = true
            subtitleLabel.text = "Add games to your library"
            configureActionView(title: "Import games",
                                subtitle: "Open ManicEMU's import screen",
                                symbol: "square.and.arrow.down.fill")

        case .settings:
            games = []
            showGames = false
            showProfile = false
            showAction = true
            subtitleLabel.text = "Controllers, cores, networking and more"
            configureActionView(title: "Settings",
                                subtitle: "Open ManicEMU settings",
                                symbol: "gearshape.fill")

        case .classicHome:
            games = []
            showGames = false
            showProfile = false
            showAction = true
            subtitleLabel.text = "Original ManicEMU interface"
            configureActionView(title: "Classic ManicEMU",
                                subtitle: "Open the original frontend",
                                symbol: "square.grid.2x2.fill")
        }

        gamesContentView.isHidden = !showGames
        profileContainerView.isHidden = !showProfile
        actionContainerView.isHidden = !showAction

        collectionView.reloadData()
        let initialIndex = games.isEmpty ? nil : rememberedIndexForCurrentSection()
        positionRail.update(index: initialIndex, count: games.count)

        let updates = {
            self.titleLabel.alpha = 1
            self.subtitleLabel.alpha = 1
            self.gamesContentView.alpha = showGames ? 1 : 0
            self.profileContainerView.alpha = showProfile ? 1 : 0
            self.actionContainerView.alpha = showAction ? 1 : 0
        }

        if animated {
            titleLabel.alpha = 0.40
            subtitleLabel.alpha = 0.40
            UIView.animate(withDuration: 0.18, animations: updates)
        } else {
            updates()
        }

        if restoreFocus, FocusSystem.shared.hasExternalInput {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if showGames {
                    self.focusGame(at: self.rememberedIndexForCurrentSection())
                } else if showProfile {
                    FocusSystem.shared.focus(self.avatarButton)
                } else if showAction {
                    FocusSystem.shared.focus(self.actionButton)
                }
            }
        }
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
            return avatarButton
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
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        collectionView.layoutIfNeeded()

        if let cell = collectionView.cellForItem(at: indexPath) {
            FocusSystem.shared.focus(cell)
        } else {
            FocusSystem.shared.updateFocusIfNeeded()
        }
    }

    private func scrollSelectedSectionIntoView(animated: Bool = true) {
        guard sectionButtons.indices.contains(selectedSectionIndex), sectionScrollView.bounds.width > 0 else { return }

        sectionScrollView.layoutIfNeeded()
        let button = sectionButtons[selectedSectionIndex]
        let visibleRect = button.convert(button.bounds, to: sectionScrollView)
        let delta = visibleRect.midX - sectionScrollView.bounds.midX
        var target = sectionScrollView.contentOffset
        target.x += delta

        let minX = -sectionScrollView.adjustedContentInset.left
        let maxX = max(minX,
                       sectionScrollView.contentSize.width - sectionScrollView.bounds.width + sectionScrollView.adjustedContentInset.right)
        target.x = min(max(target.x, minX), maxX)

        sectionScrollView.setContentOffset(target, animated: animated)
    }

    private func updateFocusedGame(index: Int) {
        guard games.indices.contains(index) else { return }

        if sections.indices.contains(selectedSectionIndex) {
            rememberedGameIndex[sections[selectedSectionIndex].identifier] = index
        }

        positionRail.update(index: index, count: games.count)
    }

    private func activateGame(at index: Int) {
        guard games.indices.contains(index) else { return }
        games[index].handleTapAction(forceQuick: true)
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

        let game = games[indexPath.item]
        cell.configure(game: game, coverMode: coverMode)
        cell.isFocusable = true
        cell.enableFocusEffects = false
        cell.onFocusChange = { [weak self, weak cell] focused in
            cell?.setXMBFocused(focused)
            if focused {
                self?.updateFocusedGame(index: indexPath.item)
            }
        }
        cell.onFocusConfirm = { [weak self] in
            self?.activateGame(at: indexPath.item)
            return true
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        updateFocusedGame(index: indexPath.item)
        activateGame(at: indexPath.item)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let rowHeight: CGFloat = coverMode == .square ? 60 : 70
        return CGSize(width: collectionView.bounds.width, height: rowHeight)
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

// MARK: - XMB game row

private final class XMBGameRowCell: UICollectionViewCell {
    static let reuseIdentifier = "XMBGameRowCell"

    private let highlightView = UIView()
    private let coverView = UIImageView()
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
        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail

        detailLabel.textColor = UIColor.white.withAlphaComponent(0.52)
        detailLabel.font = .systemFont(ofSize: 10, weight: .regular)
        detailLabel.lineBreakMode = .byTruncatingTail

        contentView.addSubview(highlightView)
        contentView.addSubview(coverView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(detailLabel)

        highlightView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverView.snp.trailing).offset(11)
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview().offset(-8)
        }

        detailLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(nameLabel)
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
        setXMBFocused(false)
        coverView.image = nil
    }

    func setXMBFocused(_ focused: Bool) {
        UIView.animate(withDuration: 0.12) {
            self.highlightView.backgroundColor = focused
                ? UIColor.white.withAlphaComponent(0.13)
                : .clear
            self.nameLabel.textColor = focused ? .white : UIColor.white.withAlphaComponent(0.90)
            self.coverView.layer.borderWidth = focused ? 1.5 : 0
            self.coverView.layer.borderColor = UIColor.white.withAlphaComponent(0.80).cgColor
            self.transform = focused
                ? CGAffineTransform(scaleX: 1.035, y: 1.035)
                : .identity
        }
    }

    func configure(game: Game, coverMode: XMBCoverMode) {
        nameLabel.text = game.displayName

        var detailParts = [game.gameType.localizedShortName]
        if game.totalPlayDuration > 0 {
            detailParts.append(Date.timeDuration(milliseconds: Int(game.totalPlayDuration)))
        }
        detailLabel.text = detailParts.joined(separator: "  •  ")

        switch coverMode {
        case .original:
            coverView.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(4)
                make.centerY.equalToSuperview()
                make.width.equalTo(50)
                make.height.equalTo(64)
            }
            coverView.layer.cornerRadius = 4
            coverView.contentMode = .scaleAspectFit
            coverView.setGameCover(game: game, size: CGSize(width: 100, height: 128)) { [weak coverView] _ in
                coverView?.contentMode = .scaleAspectFit
            }

        case .square:
            coverView.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(6)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(50)
            }
            coverView.layer.cornerRadius = 6
            coverView.contentMode = .scaleAspectFill
            coverView.setGameCover(game: game, size: CGSize(width: 100, height: 100)) { [weak coverView] _ in
                coverView?.contentMode = .scaleAspectFill
            }
        }
    }
}

// MARK: - Vertical position bar

private final class XMBPositionRailView: UIView {
    private let trackView = UIView()
    private let thumbView = UIView()
    private let countLabel = UILabel()

    private var currentIndex: Int?
    private var itemCount = 0

    override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = false

        trackView.backgroundColor = UIColor.white.withAlphaComponent(0.13)
        trackView.layer.cornerRadius = 1

        thumbView.backgroundColor = UIColor.white.withAlphaComponent(0.80)
        thumbView.layer.cornerRadius = 2

        countLabel.textColor = UIColor.white.withAlphaComponent(0.42)
        countLabel.font = .monospacedDigitSystemFont(ofSize: 8, weight: .medium)
        countLabel.textAlignment = .center
        countLabel.numberOfLines = 2

        addSubview(trackView)
        addSubview(thumbView)
        addSubview(countLabel)

        trackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(14)
            make.bottom.equalTo(countLabel.snp.top).offset(-6)
            make.width.equalTo(2)
        }

        countLabel.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(25)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard itemCount > 0,
              let currentIndex,
              trackView.bounds.height > 1 else {
            thumbView.isHidden = true
            return
        }

        thumbView.isHidden = false

        let thumbHeight = max(16, min(42, trackView.bounds.height / CGFloat(max(itemCount, 1))))
        let progress = itemCount <= 1 ? 0 : CGFloat(currentIndex) / CGFloat(itemCount - 1)
        let travel = max(0, trackView.bounds.height - thumbHeight)
        let originY = trackView.frame.minY + travel * progress

        thumbView.frame = CGRect(x: (bounds.width - 4) / 2,
                                 y: originY,
                                 width: 4,
                                 height: thumbHeight)
    }

    func update(index: Int?, count: Int) {
        itemCount = count
        if let index, count > 0 {
            currentIndex = min(max(index, 0), count - 1)
            countLabel.text = "\(currentIndex! + 1)\n\(count)"
        } else {
            currentIndex = nil
            countLabel.text = count > 0 ? "—\n\(count)" : "—"
        }
        setNeedsLayout()
    }
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
    private let glowLayer = CAGradientLayer()
    private let waveLayers: [CAShapeLayer] = (0..<4).map { _ in CAShapeLayer() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        gradientLayer.colors = [
            UIColor(red: 0.005, green: 0.035, blue: 0.12, alpha: 1).cgColor,
            UIColor(red: 0.008, green: 0.12, blue: 0.31, alpha: 1).cgColor,
            UIColor(red: 0.005, green: 0.045, blue: 0.16, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.05, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.95, y: 1)
        layer.addSublayer(gradientLayer)

        glowLayer.colors = [
            UIColor.systemCyan.withAlphaComponent(0.0).cgColor,
            UIColor.systemCyan.withAlphaComponent(0.18).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.0).cgColor
        ]
        glowLayer.startPoint = CGPoint(x: 0, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(glowLayer)

        for (index, wave) in waveLayers.enumerated() {
            let alpha = max(0.035, 0.105 - CGFloat(index) * 0.018)
            wave.fillColor = UIColor.systemBlue.withAlphaComponent(alpha).cgColor
            wave.strokeColor = UIColor.white.withAlphaComponent(alpha * 1.35).cgColor
            wave.lineWidth = CGFloat(0.7 + Double(index) * 0.35)
            wave.lineJoin = .round
            layer.addSublayer(wave)
        }
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

        glowLayer.frame = CGRect(x: -bounds.width * 0.15,
                                 y: bounds.height * 0.24,
                                 width: bounds.width * 1.30,
                                 height: bounds.height * 0.52)

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
