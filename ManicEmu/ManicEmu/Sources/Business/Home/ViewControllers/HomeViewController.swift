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

final class XMBHomeViewController: BaseViewController {
    private enum SectionKind: Equatable {
        case profile
        case recent
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
            case .recent:
                return "recent"
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

    private enum XMBItem {
        case game(Game)
        case action(title: String, subtitle: String, symbol: String, handler: () -> Void)
    }

    private static let selectedSectionDefaultsKey = "ManicXMB.selectedSection"

    private var sections: [XMBSection] = []
    private var selectedSectionIndex = 0
    private var items: [XMBItem] = []
    private var rememberedItemIndex: [String: Int] = [:]
    private var gameToken: NotificationToken?
    private var clockTimer: Timer?

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
        return scrollView
    }()

    private let sectionStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 18
        return stack
    }()

    private var sectionButtons: [UIButton] = []

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 26, weight: .semibold)
        label.textColor = .white
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.62)
        return label
    }()

    private let gamesContentView = UIView()
    private let listContainerView = UIView()
    private let gameHorizontalStack = UIStackView()
    private let positionRail = XMBPositionRailView()
    private let detailView = XMBGameDetailView()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 4
        layout.sectionInset = UIEdgeInsets(top: 12, left: 0, bottom: 28, right: 0)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
        collectionView.register(XMBRowCell.self, forCellWithReuseIdentifier: XMBRowCell.reuseIdentifier)

        // Manic's FocusKit does not use UIKit's default focus engine. Marking the
        // collection as a FocusKit container is what makes DualSense D-pad/stick
        // navigation reach its cells.
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
    private let adventureCardView = SettingsAdventureCardView()

    private let profileHeadingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .white
        label.text = "Player profile"
        return label
    }()

    private let profileStatsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.70)
        label.numberOfLines = 0
        return label
    }()

    private let retroStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.78)
        label.numberOfLines = 2
        return label
    }()

    private lazy var retroButton: UIButton = {
        let button = makeProfileButton(title: "RetroAchievements", symbol: "trophy.fill")
        button.addTarget(self, action: #selector(openRetroAchievements), for: .touchUpInside)
        return button
    }()

    private lazy var historyButton: UIButton = {
        let button = makeProfileButton(title: "Play history", symbol: "clock.arrow.circlepath")
        button.addTarget(self, action: #selector(openPlayHistory), for: .touchUpInside)
        return button
    }()

    private let controlsHintLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.50)
        label.text = "Left / Right: systems   •   Up / Down: games   •   Cross: open   •   Circle: back"
        label.numberOfLines = 2
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupXMB()
        observeGames()
        updateClock()

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

        // Games switch this sink to gameplay. Always restore system navigation
        // when the user returns to the XMB.
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
        // Keep a large game-information panel on iPad / landscape-sized layouts,
        // but let the vertical list use the whole width on phones.
        detailView.isHidden = view.bounds.width < 760
    }

    private func setupXMB() {
        view.backgroundColor = UIColor(red: 0.01, green: 0.055, blue: 0.15, alpha: 1)

        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        view.addSubview(dateLabel)
        dateLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(10)
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-20)
        }

        view.addSubview(sectionScrollView)
        sectionScrollView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(32)
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(86)
        }

        sectionScrollView.addSubview(sectionStack)
        sectionStack.snp.makeConstraints { make in
            make.edges.equalTo(sectionScrollView.contentLayoutGuide)
            make.height.equalTo(sectionScrollView.frameLayoutGuide)
        }

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(sectionScrollView.snp.bottom).offset(8)
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(34)
            make.trailing.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-24)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(3)
            make.leading.equalTo(titleLabel)
            make.trailing.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-24)
        }

        view.addSubview(controlsHintLabel)
        controlsHintLabel.snp.makeConstraints { make in
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(28)
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-28)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-8)
            make.height.greaterThanOrEqualTo(20)
        }

        view.addSubview(gamesContentView)
        gamesContentView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(controlsHintLabel.snp.top).offset(-6)
        }

        gameHorizontalStack.axis = .horizontal
        gameHorizontalStack.alignment = .fill
        gameHorizontalStack.distribution = .fill
        gameHorizontalStack.spacing = 18
        gameHorizontalStack.addArrangedSubview(listContainerView)
        gameHorizontalStack.addArrangedSubview(detailView)

        gamesContentView.addSubview(gameHorizontalStack)
        gameHorizontalStack.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-22)
        }

        detailView.snp.makeConstraints { make in
            make.width.equalTo(300).priority(.high)
        }

        listContainerView.addSubview(positionRail)
        listContainerView.addSubview(collectionView)

        positionRail.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(10)
            make.width.equalTo(26)
        }

        collectionView.snp.makeConstraints { make in
            make.leading.equalTo(positionRail.snp.trailing).offset(12)
            make.top.trailing.bottom.equalToSuperview()
        }

        view.addSubview(profileContainerView)
        profileContainerView.isHidden = true
        profileContainerView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(14)
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(28)
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-28)
            make.bottom.equalTo(controlsHintLabel.snp.top).offset(-8)
        }

        profileContainerView.addSubview(profileContentView)
        profileContentView.snp.makeConstraints { make in
            make.edges.equalTo(profileContainerView.contentLayoutGuide)
            make.width.equalTo(profileContainerView.frameLayoutGuide)
        }

        setupProfileView()
    }

    private func setupProfileView() {
        adventureCardView.overrideUserInterfaceStyle = .dark

        let actionStack = UIStackView(arrangedSubviews: [retroButton, historyButton])
        actionStack.axis = .vertical
        actionStack.alignment = .fill
        actionStack.distribution = .fillEqually
        actionStack.spacing = 10

        profileContentView.addSubview(profileHeadingLabel)
        profileContentView.addSubview(adventureCardView)
        profileContentView.addSubview(profileStatsLabel)
        profileContentView.addSubview(retroStatusLabel)
        profileContentView.addSubview(actionStack)

        profileHeadingLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }

        adventureCardView.snp.makeConstraints { make in
            make.top.equalTo(profileHeadingLabel.snp.bottom).offset(12)
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.height.equalTo(190)
        }

        profileStatsLabel.snp.makeConstraints { make in
            make.top.equalTo(adventureCardView.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview()
        }

        retroStatusLabel.snp.makeConstraints { make in
            make.top.equalTo(profileStatsLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
        }

        actionStack.snp.makeConstraints { make in
            make.top.equalTo(retroStatusLabel.snp.bottom).offset(12)
            make.leading.equalToSuperview()
            make.width.lessThanOrEqualTo(360)
            make.trailing.lessThanOrEqualToSuperview()
            make.bottom.equalToSuperview().offset(-18)
            make.height.equalTo(108)
        }
    }

    private func makeProfileButton(title: String, symbol: String) -> UIButton {
        var configuration = UIButton.Configuration.gray()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = 10
        configuration.baseForegroundColor = .white
        configuration.background.backgroundColor = UIColor.white.withAlphaComponent(0.10)

        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.isFocusable = true
        button.enableFocusEffects = false
        button.onFocusChange = { [weak button] focused in
            UIView.animate(withDuration: 0.12) {
                if var configuration = button?.configuration {
                    configuration.background.backgroundColor = focused
                        ? UIColor.white.withAlphaComponent(0.24)
                        : UIColor.white.withAlphaComponent(0.10)
                    button?.configuration = configuration
                }
                button?.transform = focused ? CGAffineTransform(scaleX: 1.015, y: 1.015) : .identity
            }
        }
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

        var rebuilt: [XMBSection] = [
            XMBSection(kind: .profile, title: "Profile", symbol: "person.crop.circle.fill"),
            XMBSection(kind: .recent, title: "Recent", symbol: "clock.fill")
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
            selectedSectionIndex = min(1, max(0, sections.count - 1))
        }

        updateSelectedSection(animated: false, restoreFocus: false)
        refreshProfile()
    }

    private func rebuildSectionButtons() {
        sectionButtons.forEach { $0.removeFromSuperview() }
        sectionButtons.removeAll()

        for (index, section) in sections.enumerated() {
            var configuration = UIButton.Configuration.plain()
            configuration.image = UIImage(systemName: section.symbol)
            configuration.imagePlacement = .top
            configuration.imagePadding = 5
            configuration.title = section.title
            configuration.baseForegroundColor = UIColor.white.withAlphaComponent(0.55)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 11, weight: .medium)
                return outgoing
            }

            let button = UIButton(configuration: configuration)
            button.tag = index
            button.alpha = 0.70
            button.addTarget(self, action: #selector(sectionTapped(_:)), for: .touchUpInside)
            button.snp.makeConstraints { make in
                make.width.equalTo(74)
            }

            sectionButtons.append(button)
            sectionStack.addArrangedSubview(button)
        }
    }

    @objc private func sectionTapped(_ sender: UIButton) {
        guard sections.indices.contains(sender.tag) else { return }
        selectedSectionIndex = sender.tag
        updateSelectedSection(animated: true, restoreFocus: false)
    }

    private func moveSection(by offset: Int) {
        guard !sections.isEmpty else { return }

        rememberCurrentItemIndex()

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
            button.configuration?.baseForegroundColor = selected ? .white : UIColor.white.withAlphaComponent(0.55)
            button.alpha = selected ? 1.0 : 0.66
            button.transform = selected ? CGAffineTransform(scaleX: 1.13, y: 1.13) : .identity
        }

        scrollSelectedSectionIntoView()

        titleLabel.text = section.title
        rebuildItems(for: section)

        let showProfile = section.kind == .profile
        profileContainerView.isHidden = !showProfile
        gamesContentView.isHidden = showProfile

        if showProfile {
            subtitleLabel.text = "Your playtime, avatar, profile and RetroAchievements"
            refreshProfile()
        } else {
            switch section.kind {
            case .recent:
                subtitleLabel.text = items.isEmpty ? "No recently played games" : "\(items.count) recently played"
            case .console:
                subtitleLabel.text = items.isEmpty ? "No games in this system" : "\(items.count) game\(items.count == 1 ? "" : "s")"
            case .importGames:
                subtitleLabel.text = "Add games to your library"
            case .settings:
                subtitleLabel.text = "Open ManicEMU settings"
            case .classicHome:
                subtitleLabel.text = "Open the original ManicEMU interface"
            case .profile:
                break
            }
        }

        collectionView.reloadData()
        positionRail.update(index: items.isEmpty ? nil : 0, count: items.count)
        updateDetailForCurrentSection()

        let updates = {
            self.titleLabel.alpha = 1
            self.subtitleLabel.alpha = 1
            self.gamesContentView.alpha = showProfile ? 0 : 1
            self.profileContainerView.alpha = showProfile ? 1 : 0
        }

        if animated {
            titleLabel.alpha = 0.35
            subtitleLabel.alpha = 0.35
            UIView.animate(withDuration: 0.18, animations: updates)
        } else {
            updates()
        }

        if restoreFocus, FocusSystem.shared.hasExternalInput {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if showProfile {
                    FocusSystem.shared.focus(self.retroButton)
                } else {
                    let preferredIndex = self.rememberedIndexForCurrentSection()
                    self.focusItem(at: preferredIndex)
                }
            }
        }
    }

    private func rebuildItems(for section: XMBSection) {
        let results = Array(Database.realm.objects(Game.self).where { !$0.isDeleted })

        switch section.kind {
        case .profile:
            items = []

        case .recent:
            items = results
                .filter { $0.latestPlayDate != nil }
                .sorted { ($0.latestPlayDate ?? .distantPast) > ($1.latestPlayDate ?? .distantPast) }
                .map { .game($0) }

        case .console(let gameType):
            items = results
                .filter { $0.gameType == gameType }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                .map { .game($0) }

        case .importGames:
            items = [
                .action(title: "Import games",
                        subtitle: "Open ManicEMU's import screen",
                        symbol: "square.and.arrow.down.fill",
                        handler: { [weak self] in
                            self?.presentManicScreen(BaseNavigationController(rootViewController: ImportViewController()))
                        })
            ]

        case .settings:
            items = [
                .action(title: "Settings",
                        subtitle: "Controllers, cores, skins, networking and more",
                        symbol: "gearshape.fill",
                        handler: { [weak self] in
                            self?.presentManicScreen(BaseNavigationController(rootViewController: SettingsViewController()))
                        })
            ]

        case .classicHome:
            items = [
                .action(title: "Classic ManicEMU",
                        subtitle: "Open the original ManicEMU home screen",
                        symbol: "square.grid.2x2.fill",
                        handler: { [weak self] in
                            self?.presentManicScreen(HomeViewController())
                        })
            ]
        }
    }

    private func rememberCurrentItemIndex() {
        guard sections.indices.contains(selectedSectionIndex),
              !items.isEmpty else { return }

        let sectionID = sections[selectedSectionIndex].identifier
        if let focused = FocusSystem.shared.currentFocusedView,
           let cell = focused as? UICollectionViewCell,
           let indexPath = collectionView.indexPath(for: cell) {
            rememberedItemIndex[sectionID] = indexPath.item
        } else if let selected = collectionView.indexPathsForSelectedItems?.first {
            rememberedItemIndex[sectionID] = selected.item
        }
    }

    private func rememberedIndexForCurrentSection() -> Int {
        guard sections.indices.contains(selectedSectionIndex), !items.isEmpty else { return 0 }
        let remembered = rememberedItemIndex[sections[selectedSectionIndex].identifier] ?? 0
        return min(max(remembered, 0), items.count - 1)
    }

    private func preferredXMBFocusView() -> UIView? {
        guard sections.indices.contains(selectedSectionIndex) else { return collectionView }
        if sections[selectedSectionIndex].kind == .profile {
            return retroButton
        }
        return collectionView
    }

    private func focusItem(at index: Int) {
        guard !items.isEmpty else {
            FocusSystem.shared.updateFocusIfNeeded()
            return
        }

        let clamped = min(max(index, 0), items.count - 1)
        let indexPath = IndexPath(item: clamped, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        collectionView.layoutIfNeeded()

        if let cell = collectionView.cellForItem(at: indexPath) {
            FocusSystem.shared.focus(cell)
        } else {
            FocusSystem.shared.updateFocusIfNeeded()
        }
    }

    private func scrollSelectedSectionIntoView() {
        guard sectionButtons.indices.contains(selectedSectionIndex) else { return }
        sectionScrollView.layoutIfNeeded()

        let button = sectionButtons[selectedSectionIndex]
        var rect = button.convert(button.bounds, to: sectionScrollView)
        rect = rect.insetBy(dx: -34, dy: 0)
        sectionScrollView.scrollRectToVisible(rect, animated: true)
    }

    private func updateFocusedItem(index: Int) {
        guard items.indices.contains(index) else { return }

        if sections.indices.contains(selectedSectionIndex) {
            rememberedItemIndex[sections[selectedSectionIndex].identifier] = index
        }

        positionRail.update(index: index, count: items.count)

        switch items[index] {
        case .game(let game):
            detailView.configure(game: game)
        case .action(let title, let subtitle, let symbol, _):
            detailView.configureAction(title: title, subtitle: subtitle, symbol: symbol)
        }
    }

    private func updateDetailForCurrentSection() {
        guard !items.isEmpty else {
            detailView.configureEmpty(title: titleLabel.text ?? "")
            return
        }

        let index = rememberedIndexForCurrentSection()
        updateFocusedItem(index: index)
    }

    private func activateItem(at index: Int) {
        guard items.indices.contains(index) else { return }

        switch items[index] {
        case .game(let game):
            game.handleTapAction(forceQuick: true)

        case .action(_, _, _, let handler):
            handler()
        }
    }

    private func presentManicScreen(_ contentViewController: UIViewController) {
        let host = XMBModalHostViewController(contentViewController: contentViewController)
        host.modalPresentationStyle = .fullScreen
        present(host, animated: true)
    }

    private func refreshProfile() {
        let games = Array(Database.realm.objects(Game.self).where { !$0.isDeleted })
        let totalDuration = games.reduce(0.0) { $0 + $1.totalPlayDuration }
        let totalText = totalDuration > 0
            ? Date.timeDuration(milliseconds: Int(totalDuration))
            : R.string.localizable.readyGameInfoNeverPlayed()

        let mostPlayed = games
            .filter { $0.totalPlayDuration > 0 }
            .max(by: { $0.totalPlayDuration < $1.totalPlayDuration })

        if let mostPlayed {
            let mostPlayedTime = Date.timeDuration(milliseconds: Int(mostPlayed.totalPlayDuration))
            profileStatsLabel.text = "Total playtime: \(totalText)\nMost played: \(mostPlayed.displayName) • \(mostPlayedTime)"
        } else {
            profileStatsLabel.text = "Total playtime: \(totalText)\nMost played: —"
        }

        if let user = AchievementsUser.getUser() {
            retroStatusLabel.text = "RetroAchievements connected as \(user.username)"
        } else {
            retroStatusLabel.text = "RetroAchievements not connected"
        }
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

    private func symbol(for gameType: GameType) -> String {
        let shortName = gameType.localizedShortName.uppercased()

        if ["GB", "GBC", "GBA", "NDS", "3DS", "PSP", "LYNX", "NGP", "WSC"].contains(shortName) {
            return "rectangle.portrait.fill"
        }
        if ["ARCADE", "2600", "5200", "7800"].contains(shortName) {
            return "arcade.stick.console.fill"
        }
        if ["DOS", "C64", "AMIGA", "FLASH"].contains(shortName) {
            return "desktopcomputer"
        }
        return "gamecontroller.fill"
    }
}

extension XMBHomeViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: XMBRowCell.reuseIdentifier,
                                                       for: indexPath) as! XMBRowCell

        switch items[indexPath.item] {
        case .game(let game):
            cell.configure(game: game)
        case .action(let title, let subtitle, let symbol, _):
            cell.configureAction(title: title, subtitle: subtitle, symbol: symbol)
        }

        cell.isFocusable = true
        cell.enableFocusEffects = false
        cell.onFocusChange = { [weak self, weak cell] focused in
            cell?.setXMBFocused(focused)
            if focused {
                self?.updateFocusedItem(index: indexPath.item)
            }
        }
        cell.onFocusConfirm = { [weak self] in
            self?.activateItem(at: indexPath.item)
            return true
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        updateFocusedItem(index: indexPath.item)
        activateItem(at: indexPath.item)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: UIDevice.isPad ? 72 : 64)
    }
}

// MARK: - XMB row

private final class XMBRowCell: UICollectionViewCell {
    static let reuseIdentifier = "XMBRowCell"

    private let highlightView = UIView()
    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let accessoryView = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.clipsToBounds = false

        highlightView.backgroundColor = UIColor.white.withAlphaComponent(0.0)
        highlightView.layer.cornerRadius = 8

        iconView.clipsToBounds = true
        iconView.layer.cornerRadius = 6
        iconView.contentMode = .scaleAspectFill
        iconView.tintColor = UIColor.white.withAlphaComponent(0.90)

        nameLabel.textColor = .white
        nameLabel.font = .systemFont(ofSize: 17, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail

        detailLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        detailLabel.font = .systemFont(ofSize: 11, weight: .regular)
        detailLabel.lineBreakMode = .byTruncatingTail

        accessoryView.tintColor = UIColor.white.withAlphaComponent(0.28)
        accessoryView.contentMode = .scaleAspectFit

        contentView.addSubview(highlightView)
        contentView.addSubview(iconView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(detailLabel)
        contentView.addSubview(accessoryView)

        highlightView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.top.bottom.equalToSuperview().inset(7)
            make.width.equalTo(iconView.snp.height)
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(13)
            make.trailing.lessThanOrEqualTo(accessoryView.snp.leading).offset(-12)
            make.centerY.equalToSuperview().offset(-9)
        }

        detailLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.lessThanOrEqualTo(accessoryView.snp.leading).offset(-12)
            make.top.equalTo(nameLabel.snp.bottom).offset(3)
        }

        accessoryView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(12)
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
        iconView.image = nil
    }

    func setXMBFocused(_ focused: Bool) {
        UIView.animate(withDuration: 0.12) {
            self.highlightView.backgroundColor = focused
                ? UIColor.white.withAlphaComponent(0.18)
                : UIColor.white.withAlphaComponent(0.0)
            self.nameLabel.textColor = focused ? .white : UIColor.white.withAlphaComponent(0.88)
            self.accessoryView.alpha = focused ? 1.0 : 0.40
            self.transform = focused
                ? CGAffineTransform(scaleX: 1.018, y: 1.018)
                : .identity
        }
    }

    func configure(game: Game) {
        nameLabel.text = game.displayName

        var detailParts = [game.gameType.localizedShortName]
        if game.totalPlayDuration > 0 {
            detailParts.append(Date.timeDuration(milliseconds: Int(game.totalPlayDuration)))
        }
        detailLabel.text = detailParts.joined(separator: "  •  ")

        iconView.contentMode = .scaleAspectFill
        iconView.setGameCover(game: game, size: CGSize(width: 80, height: 80))
        accessoryView.image = UIImage(systemName: "chevron.right")
    }

    func configureAction(title: String, subtitle: String, symbol: String) {
        nameLabel.text = title
        detailLabel.text = subtitle

        iconView.contentMode = .scaleAspectFit
        iconView.image = UIImage(systemName: symbol)
        iconView.tintColor = .white
        accessoryView.image = UIImage(systemName: "chevron.right")
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

        trackView.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        trackView.layer.cornerRadius = 1

        thumbView.backgroundColor = UIColor.white.withAlphaComponent(0.82)
        thumbView.layer.cornerRadius = 2

        countLabel.textColor = UIColor.white.withAlphaComponent(0.52)
        countLabel.font = .monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        countLabel.textAlignment = .center
        countLabel.numberOfLines = 2

        addSubview(trackView)
        addSubview(thumbView)
        addSubview(countLabel)

        trackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(18)
            make.bottom.equalTo(countLabel.snp.top).offset(-8)
            make.width.equalTo(2)
        }

        countLabel.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(28)
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

        let thumbHeight = max(18, min(44, trackView.bounds.height / CGFloat(max(itemCount, 1))))
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

// MARK: - Selected-game detail

private final class XMBGameDetailView: UIView {
    private let coverView = UIImageView()
    private let titleLabel = UILabel()
    private let platformLabel = UILabel()
    private let playtimeLabel = UILabel()
    private let lastPlayedLabel = UILabel()
    private let actionIconView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor.black.withAlphaComponent(0.10)
        layer.cornerRadius = 18

        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = 12
        coverView.backgroundColor = UIColor.white.withAlphaComponent(0.06)

        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.numberOfLines = 2

        platformLabel.textColor = UIColor.white.withAlphaComponent(0.62)
        platformLabel.font = .systemFont(ofSize: 13, weight: .medium)

        playtimeLabel.textColor = UIColor.white.withAlphaComponent(0.74)
        playtimeLabel.font = .systemFont(ofSize: 13, weight: .regular)

        lastPlayedLabel.textColor = UIColor.white.withAlphaComponent(0.52)
        lastPlayedLabel.font = .systemFont(ofSize: 12, weight: .regular)
        lastPlayedLabel.numberOfLines = 2

        actionIconView.tintColor = UIColor.white.withAlphaComponent(0.88)
        actionIconView.contentMode = .scaleAspectFit
        actionIconView.isHidden = true

        addSubview(coverView)
        addSubview(actionIconView)
        addSubview(titleLabel)
        addSubview(platformLabel)
        addSubview(playtimeLabel)
        addSubview(lastPlayedLabel)

        coverView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(18)
            make.height.equalTo(coverView.snp.width).multipliedBy(0.72)
        }

        actionIconView.snp.makeConstraints { make in
            make.center.equalTo(coverView)
            make.width.height.equalTo(72)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(coverView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(18)
        }

        platformLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(7)
            make.leading.trailing.equalTo(titleLabel)
        }

        playtimeLabel.snp.makeConstraints { make in
            make.top.equalTo(platformLabel.snp.bottom).offset(12)
            make.leading.trailing.equalTo(titleLabel)
        }

        lastPlayedLabel.snp.makeConstraints { make in
            make.top.equalTo(playtimeLabel.snp.bottom).offset(5)
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.lessThanOrEqualToSuperview().offset(-18)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(game: Game) {
        actionIconView.isHidden = true
        coverView.image = nil
        coverView.setGameCover(game: game, size: CGSize(width: 320, height: 230))

        titleLabel.text = game.displayName
        platformLabel.text = game.gameType.localizedShortName

        if game.totalPlayDuration > 0 {
            playtimeLabel.text = "Playtime  \(Date.timeDuration(milliseconds: Int(game.totalPlayDuration)))"
        } else {
            playtimeLabel.text = "Not played yet"
        }

        if let latestPlayDate = game.latestPlayDate {
            lastPlayedLabel.text = "Last played \(latestPlayDate.timeAgo())"
        } else {
            lastPlayedLabel.text = nil
        }
    }

    func configureAction(title: String, subtitle: String, symbol: String) {
        coverView.image = nil
        coverView.backgroundColor = UIColor.white.withAlphaComponent(0.055)
        actionIconView.image = UIImage(systemName: symbol)
        actionIconView.isHidden = false

        titleLabel.text = title
        platformLabel.text = subtitle
        playtimeLabel.text = "Press Cross to open"
        lastPlayedLabel.text = nil
    }

    func configureEmpty(title: String) {
        coverView.image = nil
        coverView.backgroundColor = UIColor.white.withAlphaComponent(0.035)
        actionIconView.image = UIImage(systemName: "gamecontroller")
        actionIconView.isHidden = false

        titleLabel.text = title
        platformLabel.text = "Nothing to display"
        playtimeLabel.text = nil
        lastPlayedLabel.text = nil
    }
}

// MARK: - XMB profile / Manic screen host

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

        // Push after child controllers have appeared so this host is the focus
        // root. It still sees every focusable control inside the embedded Manic
        // screen, while Circle always has a reliable way back to the XMB.
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
    private let waveLayers: [CAShapeLayer] = (0..<3).map { _ in CAShapeLayer() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        gradientLayer.colors = [
            UIColor(red: 0.01, green: 0.055, blue: 0.16, alpha: 1).cgColor,
            UIColor(red: 0.015, green: 0.17, blue: 0.38, alpha: 1).cgColor,
            UIColor(red: 0.02, green: 0.08, blue: 0.22, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.05, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.95, y: 1)
        layer.addSublayer(gradientLayer)

        glowLayer.colors = [
            UIColor.systemCyan.withAlphaComponent(0.0).cgColor,
            UIColor.systemCyan.withAlphaComponent(0.14).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.0).cgColor
        ]
        glowLayer.startPoint = CGPoint(x: 0, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(glowLayer)

        for (index, wave) in waveLayers.enumerated() {
            wave.fillColor = UIColor.clear.cgColor
            wave.strokeColor = UIColor.white.withAlphaComponent(0.11 - CGFloat(index) * 0.02).cgColor
            wave.lineWidth = CGFloat(1.2 + Double(index) * 0.7)
            wave.lineCap = .round
            layer.addSublayer(wave)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds

        glowLayer.frame = CGRect(x: -bounds.width * 0.10,
                                 y: bounds.height * 0.28,
                                 width: bounds.width * 1.20,
                                 height: bounds.height * 0.38)

        let centerY = bounds.height * 0.48

        for (index, wave) in waveLayers.enumerated() {
            wave.frame = bounds
            let offset = CGFloat(index) * 16
            let path = UIBezierPath()
            path.move(to: CGPoint(x: -80, y: centerY + 26 - offset))
            path.addCurve(to: CGPoint(x: bounds.width * 0.55, y: centerY - 16 + offset * 0.25),
                          controlPoint1: CGPoint(x: bounds.width * 0.14, y: centerY - 45 - offset),
                          controlPoint2: CGPoint(x: bounds.width * 0.34, y: centerY + 32 + offset))
            path.addCurve(to: CGPoint(x: bounds.width + 80, y: centerY + 10 - offset * 0.30),
                          controlPoint1: CGPoint(x: bounds.width * 0.70, y: centerY - 58 + offset),
                          controlPoint2: CGPoint(x: bounds.width * 0.88, y: centerY + 42 - offset))
            wave.path = path.cgPath

            if wave.animation(forKey: "xmbWaveDrift") == nil {
                let animation = CABasicAnimation(keyPath: "transform.translation.x")
                animation.fromValue = -16 - index * 8
                animation.toValue = 16 + index * 8
                animation.duration = 7.5 + Double(index) * 2.2
                animation.autoreverses = true
                animation.repeatCount = .infinity
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                wave.add(animation, forKey: "xmbWaveDrift")
            }
        }
    }
}
