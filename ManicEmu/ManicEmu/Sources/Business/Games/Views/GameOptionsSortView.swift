//
//  GameOptionsSortView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/28.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class GameOptionsSortView: BaseView {
    private var optionGroups: [[GameOption]]
    
    private var isGameOptionsSortChange = false
    
    private var hideCompletion: (() -> Void)? = nil
    
    lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            if let navigationValue = action.navigationValue {
                if let _ = navigationValue.tapToolsValue {
                    //reload
                    Prefference.defalut.deletePrefference(kind: .gameOptionsSort,
                                                          storeKey: .global())
                    if self.optionGroups != GameOption.defaultGroupAndSort {
                        self.optionGroups = GameOption.defaultGroupAndSort
                        self.listPageView.updatePage(getListPage())
                    }
                    
                } else if navigationValue.isTapClose {
                    self.hide()
                }
            }
        }
        view.enableReorder(true,
                           beginReorder: { _ in
            return true
        }, itemReorderDidUpdate: { intent in
            switch intent {
            case .moveItem(let from, let to):
                return from != to
            case .extractToNewSection:
                return true
            }
        }, itemDidReorder: { [weak self] intent in
            guard let self else { return }
            var isChangeSort = false
            switch intent {
            case .moveItem(let from, let to):
                self.applyOptionMove(from: from, to: to)
                isChangeSort = true
            case .extractToNewSection(let from, let atSection):
                self.applyOptionExtract(from: from, atSection: atSection)
                isChangeSort = true
            }
            
            if isChangeSort {
                if self.optionGroups == GameOption.defaultGroupAndSort {
                    Prefference.defalut.deletePrefference(kind: .gameOptionsSort,
                                                          storeKey: .global())
                } else {
                    let array = self.optionGroups.map({ $0.map({ $0.rawValue })})
                    if let data = try? JSONSerialization.data(withJSONObject: array),
                       let json = String(data: data, encoding: .utf8) {
                        Prefference.defalut.storePrefference(kind: .gameOptionsSort,
                                                             storeKey: .global(),
                                                             storeValue: json)
                    }
                }
            }
            
            self.isGameOptionsSortChange = isChangeSort
        })
        return view
    }()
    
    required init?(parameters: Any...) {
        self.optionGroups = GameOption.groupAndSortOptions(GameOption.allCases)
        super.init(frame: .zero)
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func applyOptionMove(from: IndexPath, to: IndexPath) {
        guard from.section < optionGroups.count,
              from.row < optionGroups[from.section].count else { return }
        
        if from.section == to.section {
            let option = optionGroups[from.section].remove(at: from.row)
            optionGroups[to.section].insert(option, at: to.row)
            return
        }
        
        let option = optionGroups[from.section].remove(at: from.row)
        let sourceSection = from.section
        var toSection = to.section
        let toRow = to.row
        
        if optionGroups[sourceSection].isEmpty {
            optionGroups.remove(at: sourceSection)
            if sourceSection < to.section {
                toSection -= 1
            }
        }
        
        guard toSection < optionGroups.count else { return }
        let row = min(toRow, optionGroups[toSection].count)
        optionGroups[toSection].insert(option, at: row)
    }
    
    private func applyOptionExtract(from: IndexPath, atSection: Int) {
        guard from.section < optionGroups.count,
              from.row < optionGroups[from.section].count else { return }
        
        let option = optionGroups[from.section].remove(at: from.row)
        let sourceSection = from.section
        var insertSection = atSection
        
        if optionGroups[sourceSection].isEmpty {
            optionGroups.remove(at: sourceSection)
            if sourceSection < atSection {
                insertSection -= 1
            }
        }
        
        insertSection = min(max(insertSection, 0), optionGroups.count)
        optionGroups.insert([option], at: insertSection)
        
    }
    
    private func getCells() -> [[ASListPage.Cell]] {
        return optionGroups.compactMap({ options in
            return options.map({ getCell(option: $0) })
        })
    }
    
    private func getCell(option: GameOption) -> ASListPage.Cell {
        return ASListPage.Cell.normal([
            .icon(option.icon),
            .title(.largeText(option.title, color: (option == .quit || option == .delete) ? R.Color.Red : R.Color.LabelPrimary)),
            .button(.iconOnly(icon: .symbol(.line3Horizontal, colors: [R.Color.LabelSecondary]),
                              iconSize: CGSize(R.Size.ButtonExtraExtraSmall)))
            
        ], enablePressEffect: false)
    }
    
    private func getListPage() -> ASListPage {
        var listPage = ASListPage.simpleList(icon: GameOption.gameOptionSort.icon,
                                             title: GameOption.gameOptionSort.title,
                                             detail: .smallText(R.string.localizable.gameOptionsSortDesc(),
                                                                numberOfLines: 0),
                                             options: getCells())
        if var navigation = listPage.navigation {
            navigation.tools = [.symbolImage(R.image.refresh_iconSymbols())]
            listPage.navigation = navigation
        }
        listPage.pageInsets = .insets(top: R.Size.SheetGrabberTopInset)
        
        return listPage
    }
}

extension GameOptionsSortView: ShowableView {
    static func show(hideCompletion: @escaping () -> Void) {
        Self.show()?.hideCompletion = hideCompletion
    }
    
    func didHide() {
        if isGameOptionsSortChange {
            NotificationCenter.default.post(name: R.NotificationName.GameOptionsSortChange, object: nil)
        }
        hideCompletion?()
    }
}
