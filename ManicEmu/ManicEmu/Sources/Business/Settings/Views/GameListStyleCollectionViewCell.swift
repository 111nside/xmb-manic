//
//  GameListStyleCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import BetterSegmentedControl

class GameListStyleCollectionViewCell: UICollectionViewCell {
    
    private lazy var gamesPerRowSegmentView: ASSegmentView = {
        let view = ASSegmentView(.textSegment(titles: ["2", "3", "4", "5"],
                                              index: Theme.defalut.gamesPerRow-2))
        view.didSelectIndex = { [weak self] index in
            guard let self else { return }
            Theme.change { realm in
                Theme.defalut.gamesPerRow = index + 2
            }
        }
        return view
    }()
    
    private lazy var hideScrollIndicatorItemView: ASListItemView = {
        var styles = [ASListPage.Cell.Style]()
        styles.append(.icon(.symbol(.calendarDayTimelineTrailing)))
        styles.append(.title(.largeText(R.string.localizable.gamesHideScrollIndicator())))
        styles.append(.switch(.init(state: Theme.defalut.hideIndicator ? .on : .off)))
        let view = ASListItemView()
        view.styles = styles
        view.didActionOccurred = { [weak self] style, value in
            guard let self,
                    case .switch = style,
                    let value = value as? Bool else { return }
            Theme.change { realm in
                Theme.defalut.hideIndicator = value
            }
        }
        return view
    }()
    
    private lazy var groupTitleStyleSegmentView: ASSegmentView = {
        let view = ASSegmentView(.textSegment(titles: [R.string.localizable.groupTitleStyelAbbr(),
                                                       R.string.localizable.groupTitleStyelFull(),
                                                       R.string.localizable.groupTitleStyelBrand()],
                                              index: Theme.defalut.groupTitleStyle.rawValue))
        view.didSelectIndex = { [weak self] index in
            guard let self else { return }
            if let style = GroupTitleStyle(rawValue: index) {
                Theme.change { realm in
                    Theme.defalut.groupTitleStyle = style
                }
            }
        }
        return view
    }()
    
    private lazy var hideGroupTitleItemView: ASListItemView = {
        var styles = [ASListPage.Cell.Style]()
        styles.append(.icon(.symbol(.listBullet)))
        styles.append(.title(.largeText(R.string.localizable.hideGroupTitleDesc())))
        styles.append(.switch(.init(state: Theme.defalut.hideGroupTitle ? .on : .off)))
        let view = ASListItemView()
        view.styles = styles
        view.didActionOccurred = { [weak self] style, value in
            guard let self,
                    case .switch = style,
                    let value = value as? Bool else { return }
            Theme.change { realm in
                Theme.defalut.hideGroupTitle = value
            }
        }
        return view
    }()
    
    private lazy var gameSortTypeItemView: ASListItemView = {
        var styles = [ASListPage.Cell.Style]()
        styles.append(.icon(.symbol(.line3Horizontal)))
        styles.append(.title(.largeText(R.string.localizable.gameSortType())))
        let chevronTitle = (GameSortType(rawValue: Theme.defalut.getExtraInt(key: ExtraKey.gameSortType.rawValue) ?? 0) ?? .title).title
        styles.append(.chevron(.init(title: chevronTitle)))
        let view = ASListItemView()
        view.styles = styles
        view.enablePressEffect = true
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            let options = GameSortType.allCases.map { $0.title }
            let selectedTitle = (GameSortType(rawValue: Theme.defalut.getExtraInt(key: ExtraKey.gameSortType.rawValue) ?? 0) ?? .title).title
            let selectedIndex = options.firstIndex(of: selectedTitle)
            OptionsSheetView.show(icon: .symbol(.line3Horizontal),
                                  title: R.string.localizable.gameSortType(),
                                  options: options,
                                  selectedIndex: selectedIndex,
                                  completion: { [weak self] index in
                guard let self, let index else { return }
                var styles = self.gameSortTypeItemView.styles
                styles.removeAll(where: {
                    if case .chevron = $0 {
                        return true
                    }
                    return false
                })
                styles.append(.chevron(.init(title: options[index])))
                self.gameSortTypeItemView.styles = styles
                Theme.defalut.updateExtra(key: ExtraKey.gameSortType.rawValue, value: index)
                NotificationCenter.default.post(name: R.NotificationName.GameSortChange, object: nil)
            })
            
        }
        return view
    }()
    
    private lazy var gameSortOrderItemView: ASListItemView = {
        var styles = [ASListPage.Cell.Style]()
        styles.append(.icon(.symbol(.arrowUpArrowDown)))
        styles.append(.title(.largeText(R.string.localizable.gameSortOrder())))
        let chevronTitle = (GameSortOrder(rawValue: Theme.defalut.getExtraInt(key: ExtraKey.gameSortOrder.rawValue) ?? 0) ?? .ascending).title
        styles.append(.chevron(.init(title: chevronTitle)))
        let view = ASListItemView()
        view.styles = styles
        view.enablePressEffect = true
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            let options = GameSortOrder.allCases.map { $0.title }
            let selectedTitle = (GameSortOrder(rawValue: Theme.defalut.getExtraInt(key: ExtraKey.gameSortOrder.rawValue) ?? 0) ?? .ascending).title
            let selectedIndex = options.firstIndex(of: selectedTitle)
            OptionsSheetView.show(icon: .symbol(.arrowUpArrowDown),
                                  title: R.string.localizable.gameSortOrder(),
                                  options: options,
                                  selectedIndex: selectedIndex,
                                  completion: { [weak self] index in
                guard let self, let index else { return }
                var styles = self.gameSortOrderItemView.styles
                styles.removeAll(where: {
                    if case .chevron = $0 {
                        return true
                    }
                    return false
                })
                styles.append(.chevron(.init(title: options[index])))
                self.gameSortOrderItemView.styles = styles
                Theme.defalut.updateExtra(key: ExtraKey.gameSortOrder.rawValue, value: index)
                NotificationCenter.default.post(name: R.NotificationName.GameSortChange, object: nil)
            })
            
        }
        return view
    }()
    
    private lazy var filterSwitchItemView: ASListItemView = {
        var styles = [ASListPage.Cell.Style]()
        styles.append(.icon(.symbol(.line3HorizontalDecrease)))
        styles.append(.title(.largeText(R.string.localizable.enableManufacturerFilter())))
        let switchValue = Theme.defalut.enableManufacturerFilter
        let switchState: ASSwitch.State = switchValue ? .on : .off
        styles.append(.switch(.init(state: switchState)))
        let view = ASListItemView()
        view.styles = styles
        view.didActionOccurred = { [weak self] style, value in
            guard let self,
                    case .switch = style,
                    let value = value as? Bool else { return }
            Theme.defalut.updateExtra(key: ExtraKey.enableManufacturerFilter.rawValue, value: value)
            NotificationCenter.default.post(name: R.NotificationName.ManufacturerFilterChange, object: value)
        }
        return view
    }()
    
    private var mainColorChangeNotification: Any? = nil
    
    deinit {
        if let mainColorChangeNotification {
            NotificationCenter.default.removeObserver(mainColorChangeNotification)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layerCornerRadius = R.Size.CornerRadiusLarge
        backgroundColor = R.Color.BackgroundSecondary
        
        //游戏行数
        let gamesPerRowLabel = UILabel()
        gamesPerRowLabel.font = R.Font.Footnote()
        gamesPerRowLabel.textColor = R.Color.LabelSecondary
        gamesPerRowLabel.text = R.string.localizable.gamesPerRowTitle()
        addSubview(gamesPerRowLabel)
        gamesPerRowLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(R.Size.ContentSpaceMedium)
        }
        
        addSubview(gamesPerRowSegmentView)
        gamesPerRowSegmentView.snp.makeConstraints { make in
            make.top.equalTo(gamesPerRowLabel.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightExtraSmall)
        }
        
        //隐藏滚动条
        let hideScrollIndicatorContainer = UIView()
        hideScrollIndicatorContainer.backgroundColor = R.Color.BackgroundTertiary
        hideScrollIndicatorContainer.layerCornerRadius = R.Size.CornerRadiusMedium
        addSubview(hideScrollIndicatorContainer)
        hideScrollIndicatorContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(gamesPerRowSegmentView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        hideScrollIndicatorContainer.addSubview(hideScrollIndicatorItemView)
        hideScrollIndicatorItemView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
        }
        
        //分组标题样式
        let groupTitleStyleLabel = UILabel()
        groupTitleStyleLabel.font = R.Font.Footnote()
        groupTitleStyleLabel.textColor = R.Color.LabelSecondary
        groupTitleStyleLabel.text = R.string.localizable.groupTitleStyelDesc()
        addSubview(groupTitleStyleLabel)
        groupTitleStyleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.top.equalTo(hideScrollIndicatorContainer.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        
        addSubview(groupTitleStyleSegmentView)
        groupTitleStyleSegmentView.snp.makeConstraints { make in
            make.top.equalTo(groupTitleStyleLabel.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightExtraSmall)
        }
        
        //隐藏分组标题
        let hideGroupTitleContainer = UIView()
        hideGroupTitleContainer.backgroundColor = R.Color.BackgroundTertiary
        hideGroupTitleContainer.layerCornerRadius = R.Size.CornerRadiusMedium
        addSubview(hideGroupTitleContainer)
        hideGroupTitleContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(groupTitleStyleSegmentView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        hideGroupTitleContainer.addSubview(hideGroupTitleItemView)
        hideGroupTitleItemView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.bottom.equalToSuperview()
        }
        
        //排序
        let gameSortLabel = UILabel()
        gameSortLabel.font = R.Font.Footnote()
        gameSortLabel.textColor = R.Color.LabelSecondary
        gameSortLabel.text = R.string.localizable.gameSortDesc()
        addSubview(gameSortLabel)
        gameSortLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.top.equalTo(hideGroupTitleContainer.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        
        let gameSortContainer = UIView()
        gameSortContainer.backgroundColor = R.Color.BackgroundTertiary
        gameSortContainer.layerCornerRadius = R.Size.CornerRadiusMedium
        addSubview(gameSortContainer)
        gameSortContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(gameSortLabel.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.height.equalTo(R.Size.ItemHeightLarge * 2)
        }
        
        gameSortContainer.addSubview(gameSortTypeItemView)
        gameSortTypeItemView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        gameSortContainer.addSubview(gameSortOrderItemView)
        gameSortOrderItemView.snp.makeConstraints { make in
            make.top.equalTo(gameSortTypeItemView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        //使用厂商筛选
        let filterlabel = UILabel()
        filterlabel.font = R.Font.Footnote()
        filterlabel.textColor = R.Color.LabelSecondary
        filterlabel.text = R.string.localizable.filterTitle()
        addSubview(filterlabel)
        filterlabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.top.equalTo(gameSortContainer.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        
        let filterContainer = UIView()
        filterContainer.backgroundColor = R.Color.BackgroundTertiary
        filterContainer.layerCornerRadius = R.Size.CornerRadiusMedium
        addSubview(filterContainer)
        filterContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(filterlabel.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        filterContainer.addSubview(filterSwitchItemView)
        filterSwitchItemView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.bottom.equalToSuperview()
        }
        
        mainColorChangeNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.MainColorChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            self.hideScrollIndicatorItemView.switchButtons.forEach({ $0.onColor = R.Color.Main })
            self.hideGroupTitleItemView.switchButtons.forEach({ $0.onColor = R.Color.Main })
            self.gameSortTypeItemView.switchButtons.forEach({ $0.onColor = R.Color.Main })
            self.gameSortOrderItemView.switchButtons.forEach({ $0.onColor = R.Color.Main })
            self.filterSwitchItemView.switchButtons.forEach({ $0.onColor = R.Color.Main })

        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
