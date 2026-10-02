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
    private enum Category: Int, CaseIterable {
        case recent, games, importGames, settings, classicHome

        var title: String {
            switch self {
            case .recent: return "Recent"
            case .games: return "Games"
            case .importGames: return "Import"
            case .settings: return "Settings"
            case .classicHome: return "Manic"
            }
        }

        var symbol: String {
            switch self {
            case .recent: return "clock.fill"
            case .games: return "gamecontroller.fill"
            case .importGames: return "square.and.arrow.down.fill"
            case .settings: return "gearshape.fill"
            case .classicHome: return "square.grid.2x2.fill"
            }
        }
    }

    private var selectedCategory: Category = .games
    private var games: [Game] = []
    private var gameToken: NotificationToken?

    private let backgroundView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.025, green: 0.10, blue: 0.20, alpha: 1)
        return v
    }()

    private let glowView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.20)
        v.layer.cornerRadius = 240
        v.layer.shadowColor = UIColor.systemCyan.cgColor
        v.layer.shadowOpacity = 0.35
        v.layer.shadowRadius = 100
        return v
    }()

    private let dateLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .medium)
        l.textColor = UIColor.white.withAlphaComponent(0.82)
        l.textAlignment = .right
        return l
    }()

    private let categoryStack = UIStackView()
    private var categoryButtons: [UIButton] = []

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 24, weight: .semibold)
        l.textColor = .white
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .regular)
        l.textColor = UIColor.white.withAlphaComponent(0.62)
        return l
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 4, left: 0, bottom: 24, right: 0)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.dataSource = self
        cv.delegate = self
        cv.register(XMBGameCell.self, forCellWithReuseIdentifier: XMBGameCell.reuseIdentifier)
        return cv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupXMB()
        observeGames()
        updateClock()
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.updateClock() }
    }

    deinit { gameToken = nil }

    private func setupXMB() {
        view.backgroundColor = .black
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        backgroundView.addSubview(glowView)
        glowView.snp.makeConstraints { make in
            make.width.height.equalTo(480)
            make.trailing.equalToSuperview().offset(170)
            make.top.equalToSuperview().offset(-210)
        }

        view.addSubview(dateLabel)
        dateLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(12)
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-22)
        }

        categoryStack.axis = .horizontal
        categoryStack.alignment = .center
        categoryStack.distribution = .equalSpacing
        categoryStack.spacing = 14
        view.addSubview(categoryStack)
        categoryStack.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(42)
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(24)
            make.trailing.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-24)
            make.height.equalTo(72)
        }

        for category in Category.allCases {
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: category.symbol)
            config.imagePlacement = .top
            config.imagePadding = 5
            config.title = category.title
            config.baseForegroundColor = UIColor.white.withAlphaComponent(0.58)
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 11, weight: .medium)
                return outgoing
            }
            let button = UIButton(configuration: config)
            button.tag = category.rawValue
            button.addTarget(self, action: #selector(categoryTapped(_:)), for: .primaryActionTriggered)
            categoryButtons.append(button)
            categoryStack.addArrangedSubview(button)
        }

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(collectionView)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(categoryStack.snp.bottom).offset(18)
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(30)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(3)
            make.leading.equalTo(titleLabel)
        }
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(18)
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(24)
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-24)
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }
        refreshCategoryAppearance()
    }

    private func observeGames() {
        let results = Database.realm.objects(Game.self).where { !$0.isDeleted }
        gameToken = results.observe { [weak self] _ in self?.reloadGames() }
        reloadGames()
    }

    private func reloadGames() {
        let results = Database.realm.objects(Game.self).where { !$0.isDeleted }
        switch selectedCategory {
        case .recent:
            games = Array(results).filter { $0.latestPlayDate != nil }.sorted { ($0.latestPlayDate ?? .distantPast) > ($1.latestPlayDate ?? .distantPast) }
        case .games:
            games = Array(results).sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        default:
            games = []
        }
        titleLabel.text = selectedCategory.title
        subtitleLabel.text = games.isEmpty && (selectedCategory == .games || selectedCategory == .recent) ? "No games to display" : "\(games.count) game\(games.count == 1 ? "" : "s")"
        collectionView.reloadData()
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        guard let category = Category(rawValue: sender.tag) else { return }
        selectedCategory = category
        refreshCategoryAppearance()
        switch category {
        case .recent, .games:
            reloadGames()
        case .importGames:
            present(BaseNavigationController(rootViewController: ImportViewController()), animated: true)
        case .settings:
            present(BaseNavigationController(rootViewController: SettingsViewController()), animated: true)
        case .classicHome:
            let classic = HomeViewController()
            classic.modalPresentationStyle = .fullScreen
            present(classic, animated: true)
        }
    }

    private func refreshCategoryAppearance() {
        for button in categoryButtons {
            guard let category = Category(rawValue: button.tag) else { continue }
            let active = category == selectedCategory
            button.configuration?.baseForegroundColor = active ? .white : UIColor.white.withAlphaComponent(0.55)
            button.transform = active ? CGAffineTransform(scaleX: 1.12, y: 1.12) : .identity
        }
        titleLabel.text = selectedCategory.title
    }

    private func updateClock() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE  MMM d    h:mm a"
        dateLabel.text = formatter.string(from: Date())
    }
}

extension XMBHomeViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { games.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: XMBGameCell.reuseIdentifier, for: indexPath) as! XMBGameCell
        cell.configure(game: games[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard games.indices.contains(indexPath.item) else { return }
        games[indexPath.item].handleTapAction(forceQuick: true)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: UIDevice.isPad ? 92 : 76)
    }
}

private final class XMBGameCell: UICollectionViewCell {
    static let reuseIdentifier = "XMBGameCell"
    private let coverView = UIImageView()
    private let nameLabel = UILabel()
    private let platformLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.white.withAlphaComponent(0.07).cgColor
        contentView.backgroundColor = UIColor.white.withAlphaComponent(0.055)

        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = 7
        coverView.contentMode = .scaleAspectFill
        nameLabel.textColor = .white
        nameLabel.font = .systemFont(ofSize: 17, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        platformLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        platformLabel.font = .systemFont(ofSize: 12, weight: .regular)
        chevron.tintColor = UIColor.white.withAlphaComponent(0.35)

        [coverView, nameLabel, platformLabel, chevron].forEach(contentView.addSubview)
        coverView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.top.bottom.equalToSuperview().inset(7)
            make.width.equalTo(coverView.snp.height)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverView.snp.trailing).offset(13)
            make.trailing.lessThanOrEqualTo(chevron.snp.leading).offset(-10)
            make.centerY.equalToSuperview().offset(-10)
        }
        platformLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(3)
        }
        chevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.width.equalTo(9)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

override func didUpdateFocus(
    in context: UIFocusUpdateContext,
    with coordinator: UIFocusAnimationCoordinator
) {
    super.didUpdateFocus(in: context, with: coordinator)

    coordinator.addCoordinatedAnimations {
        self.contentView.backgroundColor = self.isFocused
            ? UIColor.white.withAlphaComponent(0.20)
            : UIColor.white.withAlphaComponent(0.055)

        self.transform = self.isFocused
            ? CGAffineTransform(scaleX: 1.015, y: 1.015)
            : .identity
    }
}

    override var isHighlighted: Bool {
        didSet { contentView.alpha = isHighlighted ? 0.65 : 1.0 }
    }

    func configure(game: Game) {
        nameLabel.text = game.displayName
        platformLabel.text = game.gameType.localizedShortName
        coverView.setGameCover(game: game, size: CGSize(width: 80, height: 80))
    }
}
