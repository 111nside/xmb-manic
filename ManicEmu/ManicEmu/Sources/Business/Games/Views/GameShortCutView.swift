//
//  GameShortcutView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/2.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import RealmSwift

class GameShortcutView: BaseView {
    private var optionGroups: [[GameOption]]
    private lazy var shortcuts: [GameOption] = {
        getShortcuts()
    }()
    private var shortcutsStoreValue: String {
        guard shortcuts.count > 0 else { return "" }
        return shortcuts.reduce("", { $0 + ($0.isEmpty ? "" : ",") + "\($1.rawValue)" })
    }
    private var games: [Game]
    
    private var hideCompletion: (() -> Void)? = nil
    
    private lazy var shortcutView: ASSymbolsButtonView = {
        let view = ASSymbolsButtonView()
        view.didTapButton = { [weak self] index in
            guard let self else { return }
            guard self.shortcuts.count > index else { return }
            self.shortcuts.remove(at: index)
            self.saveShortcuts()
            self.updateTop()
        }
        return view
    }()
    
    private lazy var shortcutContainerView: UIView = {
        let view = UIView()
        view.addSubview(shortcutView)
        shortcutView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalTo(R.Size.ButtonSmall)
        }
        return view
    }()
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            if let navigationValue = action.navigationValue {
                if let index = navigationValue.tapToolsValue {
                    if index == 0 {
                        //reload
                        games.forEach({
                            Prefference.defalut.deletePrefference(kind: .gameShortcut, storeKey: .game(gameId: $0.id))
                        })
                        
                        if let firstGame = games.first,
                           Prefference.defalut.getPrefference(kind: .gameShortcut,
                                                              storeKey: .gameType(gameType: firstGame.gameType),
                                                              bestEfforts: true)?.gameShortcutValue != nil {
                            UIView.makeAlert(detail: R.string.localizable.resetAlert(),
                                             confirmTitle: R.string.localizable.confirmTitle(),
                                             cancelAction: { [weak self] in
                                guard let self else { return }
                                self.shortcuts = self.getShortcuts()
                                self.updateTop()
                            }, confirmAction: { [weak self] in
                                guard let self else { return }
                                Prefference.defalut.deletePrefference(kind: .gameShortcut,
                                                                      storeKey: .gameType(gameType: firstGame.gameType))
                                Prefference.defalut.deletePrefference(kind: .gameShortcut,
                                                                      storeKey: .global())
                                self.shortcuts = self.getShortcuts()
                                self.updateTop()
                                
                            })
                        } else {
                            self.shortcuts = self.getShortcuts()
                            self.updateTop()
                        }
                    } else {
                        //more
                        var options = [[ASListPage.Cell]]()
                        let gameType = games.first!.gameType
                        options.append([
                            .iconTitleChevronCell(icon: .symbolImage(R.image.delete_iconSymbols()),
                                                  title: R.string.localizable.removePlatformSettings(gameType.localizedShortName)),
                            .iconTitleChevronCell(icon: .symbolImage(R.image.category_iconSymbols()),
                                                  title: R.string.localizable.setForPlatfrom(gameType.localizedShortName))
                        ])
                        
                        options.append([
                            .iconTitleChevronCell(icon: .symbolImage(R.image.delete_iconSymbols()),
                                                  title: R.string.localizable.removeGlobalSettings()),
                            .iconTitleChevronCell(icon: .symbolImage(R.image.language_iconSymbols()),
                                                  title: R.string.localizable.setForGlobal())
                        ])
                        
                        ASSheetView.show(.init(style: .simpleList(icon: .symbolImage(R.image.ellipsis_iconSymbols()),
                                                                  title: R.string.localizable.moreSettingTitle(),
                                                                  options: options)),
                                         action: { [weak self] action, _ in
                            guard let self else { return .dismiss() }
                            if let indexPath = action.listPageValue?.normalItemValue?.indexPath {
                                if indexPath.section == 0 {
                                    if indexPath.row == 0 {
                                        //remove platform settings
                                        Prefference.defalut.deletePrefference(kind: .gameShortcut, storeKey: .gameType(gameType: gameType))
                                    } else if indexPath.row == 1 {
                                        Prefference.defalut.storePrefference(kind: .gameShortcut,
                                                                             storeKey: .gameType(gameType: gameType),
                                                                             storeValue: self.shortcutsStoreValue)
                                    }
                                } else if indexPath.section == 1 {
                                    if indexPath.row == 0 {
                                        //remove global settings
                                        Prefference.defalut.deletePrefference(kind: .gameShortcut, storeKey: .global())
                                    } else if indexPath.row == 1 {
                                        Prefference.defalut.storePrefference(kind: .gameShortcut,
                                                                             storeKey: .global(),
                                                                             storeValue: self.shortcutsStoreValue)
                                    }
                                }
                            }
                            
                            return .dismiss()
                        })
                    }
                } else if navigationValue.isTapClose {
                    self.hide()
                }
            } else if let indexPath = action.normalItemValue?.indexPath {
                let option = self.optionGroups[indexPath.section][indexPath.row]
                if self.shortcuts.count >= R.Numbers.GameFunctionButtonCount {
                    self.shortcuts.removeLast()
                }
                self.shortcuts.append(option)
                self.saveShortcuts()
                self.updateTop()
            }
        }
        return view
    }()
    
    required init?(parameters: Any...) {
        guard let games = parameters.compactMap({ $0 as? [Game] }).first else { return nil }
        self.games = games
        self.optionGroups = GameOption.groupAndSortOptions(GameOption.availableOptions(games: games, scene: .gaming))
        super.init(frame: .zero)
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func getTop() -> (view: UIView, layout: ASViewLayout, pin: Bool) {
        var icons = shortcuts.map({ $0.icon })
        let fillIconsCount = R.Numbers.GameFunctionButtonCount - shortcuts.count
        if fillIconsCount > 0 {
            for _ in 0..<fillIconsCount {
                icons.append(.symbol(.xmark, colors: [.clear]))
            }
        }
        shortcutView.icons = icons
        return (shortcutContainerView, .fixedHeight(R.Size.NavigationHeight), true)
    }
    
    private func getShortcuts() -> [GameOption] {
        return getPrefferenceShortcuts() ?? GameOption.defaultShortcutOptions(for: games.first)
    }
    
    private func getPrefferenceShortcuts() -> [GameOption]? {
        var prefferences: [GameOption]? = nil
        if games.count == 1 {
            prefferences = Prefference.defalut.getPrefference(kind: .gameShortcut,
                                                              storeKey: .game(gameId: games.first!.id),
                                                              bestEfforts: true)?.gameShortcutValue

        } else if games.count > 1 {
            let firstGameShortcuts = Prefference.defalut.getPrefference(kind: .gameShortcut, storeKey: .game(gameId: games.first!.id))?.gameShortcutValue
            if games.allSatisfy({
                Prefference.defalut.getPrefference(kind: .gameShortcut, storeKey: .game(gameId: $0.id))?.gameShortcutValue == firstGameShortcuts
            }), let firstGameShortcuts {
                prefferences = firstGameShortcuts
            } else {
                prefferences = Prefference.defalut.getPrefference(kind: .gameShortcut, storeKey: .gameType(gameType: games.first!.gameType), bestEfforts: true)?.gameShortcutValue
            }
        }
        
        if let prefferences {
            var result = [GameOption]()
            let availableOptions = Set(GameOption.availableOptions(game: games.first!, scene: .gaming))
            prefferences.forEach({
                if availableOptions.contains($0) {
                    result.append($0)
                }
            })
            return result
        }
        return nil
    }
    
    private func getCells() -> [[ASListPage.Cell]] {
        return optionGroups.compactMap({ options in
            return options.map({ getCell(option: $0) })
        })
    }
    
    private func getCell(option: GameOption) -> ASListPage.Cell {
        return .iconTitleChevronCell(icon: option.icon,
                                     title: option.title,
                                     titleColor: option == .quit ? R.Color.Red : R.Color.LabelPrimary)
    }
    
    private func getListPage() -> ASListPage {
        var listPage = ASListPage.simpleList(icon: GameOption.gameShortcut.icon,
                                             title: GameOption.gameShortcut.title,
                                             detail: .smallText(R.string.localizable.gameShortcutsDesc(),
                                                                numberOfLines: 0),
                                             options: getCells())
        if var navigation = listPage.navigation {
            navigation.tools = [
                .symbolImage(R.image.refresh_iconSymbols()),
                .symbolImage(R.image.ellipsis_iconSymbols())
            ]
            listPage.navigation = navigation
        }
        listPage.top = getTop()
        listPage.pageInsets = .insets(top: R.Size.SheetGrabberTopInset)
        
        return listPage
    }
    
    private func updateTop() {
        listPageView.top = getTop()
    }
    
    private func saveShortcuts() {
        games.forEach({
            Prefference.defalut.storePrefference(kind: .gameShortcut, storeKey: .game(gameId: $0.id), storeValue: shortcutsStoreValue)
        })
    }
}

extension GameShortcutView: ShowableView {
    static func show(games: [Game], hideCompletion: (() -> Void)? = nil) {
        Self.show(parameters: games)?.hideCompletion = hideCompletion
    }
    
    func didHide() {
        NotificationCenter.default.post(name: R.NotificationName.ShortcutsChange, object: nil)
        hideCompletion?()
    }
}
