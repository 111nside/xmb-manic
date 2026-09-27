//
//  LibretroCoreConfigsView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit
import RealmSwift

///通用的Libretro核心配置界面 适用于任意Libretro核心
///选项元数据来自LibretroCore.getOptions(corePath) 用户改动通过Prefference(.coreOptions)按Game/GameType两级存储
class LibretroCoreConfigsView: BaseView {
    ///可选值数量超过该阈值时使用picker编辑 否则使用单选列表
    private static let pickerThreshold = 10
    
    ///配置变更回调 游戏运行中调用方可借此调用updateRunningCoreConfigs即时生效
    var didConfigChange: (([String: String])->Void)? = nil
    private var changeConfigs = [String: String]()
    
    ///当前正在编辑的游戏 单游戏时同时作为game级存储的读写对象
    private let games: [Game]
    private let gameType: GameType
    private let corePath: String
    ///当前使用的核心索引 作为Prefference存储的extra
    private let defaultCore: Int
    ///前端已提供快捷入口的选项 不再出现在本页
    private let hiddenOptionKeys: Set<String>
    ///最佳实践默认值 用户未编辑时优先于核心默认值展示
    private let bestSetupConfigs: [String: String]
    ///核心选项分类 已过滤不可见项
    private var coreOptionCategories: [CoreOptionCategory] = []
    ///核心默认值 覆盖存储配置前快照 用于重置后重新叠加
    private var coreDefaultValues: [String: String] = [:]
    private var coreDefaultLabels: [String: String] = [:]
    ///游戏维度的用户配置 单游戏时来自持久化 多游戏时仅累积本次改动点
    private var gameConfigs: [String: String] = [:]
    ///平台维度的用户配置
    private var gameTypeConfigs: [String: String] = [:]
    ///是否已经加载过核心选项
    private var didLoadOptions = false
    
    private var hideCompletion: (([String: String]) -> Void)? = nil
    
    private lazy var listView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            self?.handleAction(action)
        }
        return view
    }()
    
    required init?(parameters: Any...) {
        //参数可能被ShowableView.show以数组形式嵌套传入 先展平
        let games = Self.extractGames(from: parameters)
        guard let firstGame = games.first,
              let corePath = firstGame.libretroCorePath else { return nil }
        let filteredGames = games.filter({ $0.gameType == firstGame.gameType && $0.defaultCore == firstGame.defaultCore })
        guard filteredGames.count > 0 else { return nil }
        self.games = filteredGames
        self.gameType = firstGame.gameType
        self.corePath = corePath
        self.defaultCore = firstGame.defaultCore
        self.hiddenOptionKeys = Set(SpecialCoreOption.getOptimizationCoreOptions(game: firstGame).map(\.rawValue))
        self.bestSetupConfigs = SpecialCoreOption.getBestSetupCoreConfigs(game: firstGame)
        super.init(frame: .zero)
        
        loadStoreConfigs()
        
        addSubview(listView)
        listView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !didLoadOptions else { return }
        didLoadOptions = true
        UIView.makeLoading()
        // Probing a core is slow; delay so the sheet animation can finish first.
        DispatchQueue.main.asyncAfter(delay: 0.35) { [weak self] in
            guard let self else { return }
            LibretroCore.sharedInstance().workspace = R.Path.Libretro
            self.loadCoreOptions()
            self.listView.updatePage(self.getListPage())
            UIView.hideLoading()
        }
    }
    
    //MARK: - 参数解析
    private static func extractGames(from parameters: [Any]) -> [Game] {
        var result = [Game]()
        for parameter in parameters {
            if let game = parameter as? Game {
                result.append(game)
            } else if let games = parameter as? [Game] {
                result.append(contentsOf: games)
            } else if let nested = parameter as? [Any] {
                result.append(contentsOf: extractGames(from: nested))
            }
        }
        return result
    }
    
    //MARK: - 数据加载
    private func loadStoreConfigs() {
        gameConfigs = [:]
        if games.count == 1, let game = games.first {
            gameConfigs = storedConfigs(forGameId: game.id)
        }
        gameTypeConfigs = Prefference.defalut.getPrefference(kind: .coreOptions,
                                                             storeKey: .coreOptionsKey(gameType: gameType, defaultCore: defaultCore))?.coreOptionsValue ?? [:]
    }
    
    private func loadCoreOptions(resetOptFile: Bool = false) {
        let categories = LibretroCore.sharedInstance().getOptions(corePath, resetOptFile: resetOptFile) ?? []
        coreOptionCategories = categories.compactMap({ category in
            guard category.visible else { return nil }
            let visibleOptions = category.options.filter({
                $0.visible && $0.options.count > 0 && !hiddenOptionKeys.contains($0.key)
            })
            guard visibleOptions.count > 0 else { return nil }
            category.options = visibleOptions
            return category
        })
        snapshotCoreDefaults()
        overlayStoreConfigs()
    }
    
    /// Snapshot built-in core defaults. Overlay/reset always start from this, not from .opt values.
    private func snapshotCoreDefaults() {
        coreDefaultValues.removeAll()
        coreDefaultLabels.removeAll()
        for category in coreOptionCategories {
            for option in category.options {
                coreDefaultValues[option.key] = option.defaultValue.isEmpty ? option.value : option.defaultValue
                coreDefaultLabels[option.key] = option.defaultLabel.isEmpty ? option.label : option.defaultLabel
            }
        }
    }
    
    ///将持久化配置覆盖到核心选项上
    ///优先级: 游戏级 > 平台级 > 最佳实践 > 核心默认 同一key覆盖成功则忽略更低级别
    private func overlayStoreConfigs() {
        for category in coreOptionCategories {
            for option in category.options {
                if let defaultValue = coreDefaultValues[option.key] {
                    option.value = defaultValue
                }
                if let defaultLabel = coreDefaultLabels[option.key] {
                    option.label = defaultLabel
                }
                if let gameValue = gameConfigs[option.key], applyStoredValue(gameValue, to: option) {
                    continue
                }
                if let typeValue = gameTypeConfigs[option.key], applyStoredValue(typeValue, to: option) {
                    continue
                }
                if let bestValue = bestSetupConfigs[option.key] {
                    applyStoredValue(bestValue, to: option)
                }
            }
        }
    }
    
    @discardableResult
    private func applyStoredValue(_ storedValue: String, to option: CoreOption) -> Bool {
        guard let match = option.options.first(where: { $0.value == storedValue }) else { return false }
        option.value = match.value
        option.label = match.label
        return true
    }
    
    private func reloadList() {
        overlayStoreConfigs()
        listView.updatePage(getListPage())
    }
    
    //MARK: - 取值
    ///显示值优先级: 游戏级配置 > 平台级配置 > 最佳实践 > 核心当前值
    private func currentValue(for coreOption: CoreOption) -> String {
        gameConfigs[coreOption.key]
            ?? gameTypeConfigs[coreOption.key]
            ?? bestSetupConfigs[coreOption.key]
            ?? coreOption.value
    }
    
    private func currentLabel(for coreOption: CoreOption) -> String {
        let value = currentValue(for: coreOption)
        if let option = coreOption.options.first(where: { $0.value == value }) {
            return option.label.isEmpty ? option.value : option.label
        }
        return value
    }
    
    ///当前页面向外同步的覆盖快照: 平台级为基础 游戏级覆盖其上
    private var workingConfigs: [String: String] {
        gameTypeConfigs.merging(gameConfigs, uniquingKeysWith: { _, new in new })
    }
    
    ///为更多游戏设定时写入/比对的游戏级快照
    private var referenceGameConfigs: [String: String] {
        games.count == 1 ? gameConfigs : workingConfigs
    }
    
    private func isGameTypeDefaultConfig() -> Bool {
        guard !gameTypeConfigs.isEmpty else { return false }
        return gameTypeConfigs == workingConfigs
    }
    
    //MARK: - 页面构建
    private func getListPage() -> ASListPage {
        var navigation = ASListPage.Navigation.defaultNavigation(title: gameType.coreConfigTitle,
                                                                 titleIcon: gameType.coreConfigIcon,
                                                                 tools: [.symbolImage(R.image.ellipsis_iconSymbols())])
        navigation.enableClose = true
        
        let sections = coreOptionCategories.enumerated().map({ index, category in
            var section = ASListPage.Section(cells: category.options.map({ option in
                let detail = currentLabel(for: option)
                if detail.count > 20 {
                    return .iconTitleDetailChevronCell(title: option.desc.isEmpty ? option.key : option.desc,
                                                       detail: detail)
                } else {
                    return .iconTitleDetailChevronCell(title: option.desc.isEmpty ? option.key : option.desc,
                                                       chevronTitle: detail)
                }
            }))
            
            var headerTexts = [ASText]()
            
            if index == 0 {
                headerTexts.append(.init(attributes: .init(text: R.string.localizable.coreConfigsAlert(),
                                                           color: R.Color.LabelSecondary,
                                                           font: R.Font.Footnote(),
                                                           numberOfLines: 0)))
            }
            
            if !category.title.isEmpty {
                headerTexts.append(.init(attributes: .init(text: category.title,
                                                           color: R.Color.LabelSecondary,
                                                           font: R.Font.Subheadline(emphasis: true))))
            }
            if !category.info.isEmpty {
                headerTexts.append(.init(attributes: .init(text: category.info,
                                                           color: R.Color.LabelSecondary,
                                                           font: R.Font.Footnote(),
                                                           numberOfLines: 0)))
            }
            if headerTexts.count > 0 {
                section.header = .texts(headerTexts, pin: false)
            }
            return section
        })
        
        return ASListPage(navigation: navigation,
                          sections: sections,
                          blankSlate: .init(detail: R.string.localizable.coreConfigsEmpty()),
                          backgroundColor: .clear,
                          pageInsets: .insets(top: R.Size.SheetGrabberTopInset))
    }
    
    //MARK: - 事件处理
    private func handleAction(_ action: ASListPage.Action) {
        if let (indexPath, cellData, _) = action.normalItemValue {
            guard indexPath.section < coreOptionCategories.count else { return }
            let options = coreOptionCategories[indexPath.section].options
            guard indexPath.row < options.count else { return }
            showEditor(for: options[indexPath.row], cellData: cellData, indexPath: indexPath)
        } else if let navigationValue = action.navigationValue {
            if navigationValue.isTapClose {
                hide()
            } else if navigationValue.tapToolsValue != nil {
                showMoreMenu()
            }
        }
    }
    
    //MARK: - 条目编辑
    private func showEditor(for coreOption: CoreOption, cellData: ASListPage.Cell, indexPath: IndexPath) {
        let valueOptions = coreOption.options
        let labels = valueOptions.map({ $0.label.isEmpty ? $0.value : $0.label })
        let value = currentValue(for: coreOption)
        let selectedIndex = valueOptions.firstIndex(where: { $0.value == value })
        let title = coreOption.desc.isEmpty ? coreOption.key : coreOption.desc
        let detail = coreOption.info.isEmpty ? nil : coreOption.info
        
        if valueOptions.count <= Self.pickerThreshold {
            OptionsSheetView.show(icon: gameType.coreConfigIcon,
                                  title: title,
                                  detail: detail,
                                  options: labels,
                                  selectedIndex: selectedIndex) { [weak self] index in
                guard let self, let index, index != selectedIndex else { return }
                self.commitChange(coreOption: coreOption,
                                  valueOption: valueOptions[index],
                                  cellData: cellData,
                                  indexPath: indexPath)
            }
        } else {
            var pickedIndex: Int? = nil
            ASSheetView.show(.init(style: .picker(title: title,
                                                  detail: detail,
                                                  datas: labels,
                                                  selectedIndex: selectedIndex ?? 0)),
                             action: { action, _ in
                if let pickerValue = action.pickerValue {
                    pickedIndex = pickerValue.index
                }
                return .none
            }, dismiss: { [weak self] in
                guard let self, let pickedIndex, pickedIndex != selectedIndex else { return }
                self.commitChange(coreOption: coreOption,
                                  valueOption: valueOptions[pickedIndex],
                                  cellData: cellData,
                                  indexPath: indexPath)
            })
        }
    }
    
    private func commitChange(coreOption: CoreOption, valueOption: Options, cellData: ASListPage.Cell, indexPath: IndexPath) {
        persistChange(key: coreOption.key, value: valueOption.value)
        applyStoredValue(valueOption.value, to: coreOption)
        listView.updateCellData(cellData.updateNormalChevron(title: valueOption.label.isEmpty ? valueOption.value : valueOption.label),
                                indexPath: indexPath)
        didConfigChange?([coreOption.key: valueOption.value])
        changeConfigs[coreOption.key] = valueOption.value
        UIDevice.generateHaptic()
    }
    
    ///单游戏: 整份gameConfigs写入该游戏
    ///多游戏: 只把本次改动点合并进每个游戏已有的game级存储
    private func persistChange(key: String, value: String) {
        gameConfigs[key] = value
        if games.count == 1, let game = games.first {
            storeConfigs(gameConfigs, forGameId: game.id)
        } else {
            for game in games {
                var stored = storedConfigs(forGameId: game.id)
                stored[key] = value
                storeConfigs(stored, forGameId: game.id)
            }
        }
    }
    
    //MARK: - 存储
    private func storedConfigs(forGameId gameId: String) -> [String: String] {
        Prefference.defalut.getPrefference(kind: .coreOptions,
                                           storeKey: .coreOptionsKey(gameId: gameId, defaultCore: defaultCore))?.coreOptionsValue ?? [:]
    }
    
    private func decodeConfigs(_ json: String?) -> [String: String] {
        guard let json,
              let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return dict
    }
    
    private func storeConfigs(_ configs: [String: String], forGameId gameId: String) {
        let storeKey = Prefference.StoreKey.coreOptionsKey(gameId: gameId, defaultCore: defaultCore)
        if configs.isEmpty {
            Prefference.defalut.deletePrefference(kind: .coreOptions, storeKey: storeKey)
        } else if let jsonString = configs.jsonString() {
            Prefference.defalut.storePrefference(kind: .coreOptions,
                                                 storeKey: storeKey,
                                                 storeValue: jsonString)
        }
    }
    
    private func deleteGameConfigs(forGameId gameId: String) {
        Prefference.defalut.deletePrefference(kind: .coreOptions,
                                              storeKey: .coreOptionsKey(gameId: gameId, defaultCore: defaultCore))
    }
    
    private func deleteGameTypeConfigs() {
        Prefference.defalut.deletePrefference(kind: .coreOptions,
                                              storeKey: .coreOptionsKey(gameType: gameType, defaultCore: defaultCore))
    }
    
    //MARK: - 更多菜单
    private func showMoreMenu() {
        ChevronSheetView.show(icon: gameType.coreConfigIcon,
                              title: gameType.coreConfigTitle,
                              cellOptions: [
                                .iconTitleChevronCell(icon: .symbolImage(R.image.controller_iconSymbols()),
                                                      title: R.string.localizable.moreGamesSetting()),
                                .iconTitleDetailCheckCell(icon: .symbolImage(R.image.category_iconSymbols()),
                                                          title: R.string.localizable.platformDefaultSkin(gameType.localizedShortName),
                                                          isSelected: isGameTypeDefaultConfig()),
                                .iconTitleChevronCell(icon: .symbolImage(R.image.refresh_iconSymbols()),
                                                      title: R.string.localizable.resetGameCoreSettings()),
                                .iconTitleChevronCell(icon: .symbolImage(R.image.refresh_iconSymbols()),
                                                      title: R.string.localizable.resetGameTypeCoreSettings(gameType.localizedShortName))
                              ]) { [weak self] index in
            guard let self, let index else { return }
            if index == 0 {
                self.showMoreGamesSetting()
            } else if index == 1 {
                self.toggleGameTypeDefaultConfig()
            } else if index == 2 {
                self.resetCurrentGamesConfigs()
            } else if index == 3 {
                self.resetGameTypeConfigs()
            }
        }
    }
    
    private func showMoreGamesSetting() {
        let realm = Database.realm
        let games = Array(realm.objects(Game.self).where({ $0.gameType == self.gameType && $0.defaultCore == self.defaultCore }))
        guard games.count > 0 else {
            UIView.makeToast(message: R.string.localizable.transferPakNoGames())
            return
        }
        
        let prefference = Prefference.defalut.getGamePrefference(kind: .coreOptions)
        let reference = referenceGameConfigs
        
        var cells = [[ASListPage.Cell]]()
        for game in games {
            var isSelected = false
            if let key = Prefference.StoreKey.coreOptionsKey(gameId: game.id, defaultCore: defaultCore).key {
                let stored = decodeConfigs(prefference?[key])
                isSelected = stored == reference
            } else if reference.isEmpty {
                isSelected = true
            }
            cells.append([.iconTitleDetailRadioCell(icon: game.gameCoverIcon,
                                                    iconSize: R.Size.ButtonMedium,
                                                    title: game.displayName,
                                                    isSelected: isSelected)])
        }
        
        var sheetStyle: ASSheet.Style = .simpleList(icon: .symbolImage(R.image.controller_iconSymbols()),
                                                    title: R.string.localizable.moreGamesSetting(),
                                                    detail: .smallText(R.string.localizable.moreGamesSettingDesc(gameType.coreConfigTitle),
                                                                       numberOfLines: 0),
                                                    options: cells)
        
        ASSheetView.show(.init(style: sheetStyle), action: { [weak self] action, updation in
            guard let self else { return .dismiss() }
            if let normalItemValue = action.listPageValue?.normalItemValue {
                let index = normalItemValue.indexPath.section
                let game = games[index]
                let stored = self.storedConfigs(forGameId: game.id)
                let reference = self.referenceGameConfigs
                let isSelected: Bool
                if stored == reference && !reference.isEmpty {
                    self.deleteGameConfigs(forGameId: game.id)
                    isSelected = false
                } else {
                    self.storeConfigs(reference, forGameId: game.id)
                    isSelected = true
                }
                if case let .simpleList(icon, title, detail, options, cancelEnable) = sheetStyle {
                    var cells = options
                    cells[index][0] = normalItemValue.cellData.updateNormalRadio(isSelected: isSelected)
                    sheetStyle = .simpleList(icon: icon, title: title, detail: detail, options: cells, cancelEnable: cancelEnable)
                    updation?(sheetStyle)
                }
                return .none
            }
            return .dismiss(completion: { [weak self] in
                guard let self else { return }
                //单游戏可能在列表里取消了当前游戏 需要重新读取game级
                if self.games.count == 1 {
                    self.loadStoreConfigs()
                }
                self.reloadList()
            })
        })
    }
    
    private func toggleGameTypeDefaultConfig() {
        let storeKey = Prefference.StoreKey.coreOptionsKey(gameType: gameType, defaultCore: defaultCore)
        if isGameTypeDefaultConfig() {
            Prefference.defalut.deletePrefference(kind: .coreOptions, storeKey: storeKey)
            gameTypeConfigs = [:]
        } else {
            let merged = workingConfigs
            guard !merged.isEmpty, let jsonString = merged.jsonString() else {
                UIView.makeToast(message: "No modified settings to apply")
                return
            }
            //storePrefference在gameType级会清除该平台所有游戏的同extra存储
            Prefference.defalut.storePrefference(kind: .coreOptions,
                                                 storeKey: storeKey,
                                                 storeValue: jsonString)
            gameConfigs = [:]
            gameTypeConfigs = merged
        }
        reloadList()
    }
    
    private func resetCurrentGamesConfigs() {
        games.forEach({ deleteGameConfigs(forGameId: $0.id) })
        gameConfigs = [:]
        reloadCoreOptionsAfterReset()
    }
    
    private func resetGameTypeConfigs() {
        deleteGameTypeConfigs()
        let realm = Database.realm
        let allGames = realm.objects(Game.self).where({ $0.gameType == gameType && $0.defaultCore == defaultCore })
        allGames.forEach({ deleteGameConfigs(forGameId: $0.id) })
        gameConfigs = [:]
        gameTypeConfigs = [:]
        reloadCoreOptionsAfterReset()
    }
    
    /// Delete the per-core .opt, then re-probe so the list shows built-in defaults instead of last-run values.
    private func reloadCoreOptionsAfterReset() {
        changeConfigs.removeAll()
        LibretroCore.sharedInstance().workspace = R.Path.Libretro
        UIView.makeLoading()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.loadCoreOptions(resetOptFile: true)
            if PlayViewController.isGaming {
                self.applyDisplayedConfigsToRunningCore()
            }
            self.listView.updatePage(self.getListPage())
            UIView.hideLoading()
        }
    }
    
    private func applyDisplayedConfigsToRunningCore() {
        var configs = [String: String]()
        for category in coreOptionCategories {
            for option in category.options {
                configs[option.key] = option.value
            }
        }
        guard !configs.isEmpty else { return }
        LibretroCore.sharedInstance().updateRunningCoreConfigs(configs, flush: false)
    }
}

extension LibretroCoreConfigsView: ShowableView {
    static func show(game: Game) {
        show(games: [game])
    }
    
    static func show(games: [Game], hideCompletion: (([String: String]) -> Void)? = nil) {
        guard games.count > 0 else { return }
        Self.show(parameters: games)?.hideCompletion = hideCompletion
    }
    
    func didHide() {
        hideCompletion?(changeConfigs)
    }
}
