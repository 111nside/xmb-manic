//
//  GamesToolView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/7.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

enum SelectionChangeMode {
    case normalMode, selectionMode, selectAll, deSelectAll
}

enum SelectionType {
    case selectAll
    case selectSome(onlyOne: Bool)
    case selectNone
}

class GamesToolView: BaseView {
    ///选则状态
    var isSelectAll = false
    
    fileprivate class RightPaddingTextField: UITextField {
        override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
            return CGRectMake(bounds.size.width - 28, 0, 28, bounds.size.height);
        }
    }
    
    private lazy var searchTextField: UITextField = {
        let textField = RightPaddingTextField()
        textField.attributedPlaceholder = NSAttributedString(string: R.string.localizable.gamesSearchPlaceHolder(), attributes: [.foregroundColor: R.Color.LabelSecondary, .font: R.Font.Footnote()])
        textField.textColor = R.Color.LabelPrimary
        textField.font = R.Font.Footnote()
        textField.clearButtonMode = .never
        textField.returnKeyType = .search
        textField.modifyClearButton(with: UIImage(symbol: .xmarkCircleFill, color: R.Color.LabelSecondary), size: 28)
        textField.onReturnKeyPress { [weak textField] in
            textField?.resignFirstResponder()
        }
        textField.onEditingEnded { [weak textField, weak self] in
            self?.didSearchChange?(textField?.text)
        }
        textField.shouldClear { [weak textField, weak self] in
            self?.didSearchChange?(nil)
            return true
        }
        textField.isFocusable = true
        textField.onFocusConfirm = { [weak textField] in
            textField?.becomeFirstResponder() ?? false
        }
        return textField
    }()

    private lazy var searchIcon: GamesToolIconView = {
        let view = GamesToolIconView(toolView: searchTextField, normalSymbol: .magnifyingglass, iconSize: 16, autoLayutType: .greater(1000))//占据尽可能多的空间
        view.imageView.addTapGesture { [weak self]  gesture in
            guard let self = self else { return }
            UIDevice.generateHaptic()
            self.searchIcon.isSelected = !self.searchIcon.isSelected
            if self.searchIcon.isSelected {
                self.startSearch()
            } else {
                self.stopSearch()
            }
        }
        view.onFocusConfirm = { [weak self] in
            guard let self else { return false }
            UIDevice.generateHaptic()
            self.searchIcon.isSelected = !self.searchIcon.isSelected
            if self.searchIcon.isSelected {
                self.startSearch()
            } else {
                self.stopSearch()
            }
            return true
        }
        return view
    }()
    
    private var selectIconLabel = UILabel()
    
    lazy var selectIcon: GamesToolIconView = {
        //选择视图
        let toolView = UIView()
        //标题
        let label = selectIconLabel
        label.textAlignment = .center
        label.font = R.Font.Footnote()
        label.textColor = R.Color.LabelPrimary
        label.text = R.string.localizable.deSelectAll()
        let deSelectAllTextWidth = label.intrinsicContentSize.width
        label.text = R.string.localizable.selectAll()
        let selectAllTextWidth = label.intrinsicContentSize.width
        toolView.addSubview(label)
        label.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceTiny)
        }
        let view = GamesToolIconView(toolView: toolView, normalSymbol: .checkmarkCircle, selectedSymbol: .xmarkCircle, iconSize: 18, autoLayutType: .equal(max(deSelectAllTextWidth, selectAllTextWidth) + R.Size.ContentSpaceTiny*2))
        view.addTapGesture { [weak self, weak label] gesture in
            guard let self = self else { return }
            UIDevice.generateHaptic()
            selectIcon.isSelected = !selectIcon.isSelected
            isSelectAll = false
            if selectIcon.isSelected {
                //展开工具条
                didToolViewSelectionChange?(.selectionMode)
            } else {
                //收缩工具条
                label?.text = R.string.localizable.selectAll()
                didToolViewSelectionChange?(.normalMode)
            }
        }
        view.onFocusConfirm = { [weak self, weak label] in
            guard let self else { return false }
            UIDevice.generateHaptic()
            selectIcon.isSelected = !selectIcon.isSelected
            isSelectAll = false
            if selectIcon.isSelected {
                didToolViewSelectionChange?(.selectionMode)
            } else {
                label?.text = R.string.localizable.selectAll()
                didToolViewSelectionChange?(.normalMode)
            }
            return true
        }
        toolView.addTapGesture { [weak self, weak label] gesture in
            guard let self = self else { return }
            UIDevice.generateHaptic()
            self.isSelectAll = !self.isSelectAll
            self.updateSelectIconLabel(selectionType: self.isSelectAll ? .selectAll : .selectNone)
            didToolViewSelectionChange?(isSelectAll ? .selectAll : .deSelectAll)
        }
        toolView.isFocusable = true
        toolView.onFocusConfirm = { [weak self] in
            guard let self else { return false }
            UIDevice.generateHaptic()
            self.isSelectAll = !self.isSelectAll
            self.updateSelectIconLabel(selectionType: self.isSelectAll ? .selectAll : .selectNone)
            self.didToolViewSelectionChange?(self.isSelectAll ? .selectAll : .deSelectAll)
            return true
        }
        return view
    }()
    
    private lazy var themeIcon: GamesToolIconView = {
        let view = GamesToolIconView(toolView: nil, normalSymbol: .paintpalette, selectedSymbol: .paintpalette, iconSize: 18, autoLayutType: .equal(R.Size.ItemHeightTiny))
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            UIDevice.generateHaptic()
            ThemeSettingView.show()
        }
        view.onFocusConfirm = { [weak self] in
            guard let self else { return false }
            UIDevice.generateHaptic()
            ThemeSettingView.show()
            return true
        }
        return view
    }()
    
    lazy var manufacturerCategoryView: ManufacturerCategoryView = {
        let view = ManufacturerCategoryView()
        return view
    }()
    
    var didToolViewSelectionChange: ((SelectionChangeMode)->Void)?
    var didSearchChange: ((String?)->Void)?
    var didFilterVisibleChange: (()->Void)? = nil
    
    private var manufacturerFilterChange: Any? = nil
    
    deinit {
        if let manufacturerFilterChange {
            NotificationCenter.default.removeObserver(manufacturerFilterChange)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        searchIcon.isSelected = true
        
        let icons = [searchIcon, selectIcon, themeIcon]
        addSubviews(icons)
        for (index, icon) in icons.enumerated() {
            icon.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(R.Size.ContentSpaceExtraSmall)
                if index == 0 {
                    make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
                } else {
                    make.leading.equalTo(icons[index-1].snp.trailing).offset(R.Size.ContentSpaceSmall)
                }
                if index == icons.count - 1 {
                    make.trailing.lessThanOrEqualToSuperview().offset(-R.Size.ContentSpaceMedium)
                }
            }
        }
        
        addSubview(manufacturerCategoryView)
        manufacturerCategoryView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(R.Size.ItemHeightMicro)
            make.bottom.equalToSuperview().inset(R.Size.ContentSpaceMedium)
        }
        manufacturerCategoryView.isHidden = !Theme.defalut.enableManufacturerFilter
        
        
        manufacturerFilterChange = NotificationCenter.default.addObserver(forName: R.NotificationName.ManufacturerFilterChange, object: nil, queue: .main) { [weak self] notification in
            let enableFilter = (notification.object as? Bool) ?? false
            self?.manufacturerCategoryView.isHidden = !enableFilter
            self?.didFilterVisibleChange?()
            self?.stopFilterManufacturer()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        roundCorners([.topLeft, .topRight], radius: R.Size.CornerRadiusLarge)
    }
    
    func updateSelectIconLabel(selectionType: SelectionType) {
        switch selectionType {
        case .selectAll:
            selectIconLabel.text = R.string.localizable.deSelectAll()
        case .selectSome(_):
            selectIconLabel.text = R.string.localizable.selectAll()
        case .selectNone:
            selectIconLabel.text = R.string.localizable.selectAll()
        }
    }
    
    func startSearch() {
        searchTextField.becomeFirstResponder()
    }
    
    func stopSearch() {
        if searchTextField.isFirstResponder || !(searchTextField.text ?? "").isEmpty {
            searchTextField.text = nil
            searchTextField.resignFirstResponder()
            didSearchChange?(nil)
        }
        
    }
    
    func stopSelect() {
        if selectIcon.isSelected {
            selectIcon.isSelected = false
            isSelectAll = false
            selectIconLabel.text = R.string.localizable.selectAll()
            didToolViewSelectionChange?(.normalMode)
        }
    }
    
    func stopFilterManufacturer() {
        manufacturerCategoryView.deselectAll()
    }
    
    func foldKeyboard() {
        if searchTextField.isFirstResponder {
            searchTextField.resignFirstResponder()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class GamesToolIconView: BaseView {
    enum AutoLayutType {
        case equal(CGFloat)
        case greater(CGFloat)
    }
    
    private var normalSymbol: SFSymbol
    private var selectedSymbol: SFSymbol?
    private var iconSize: CGFloat
    
    var isSelected: Bool = false {
        willSet {
            guard isSelected != newValue else { return }
            //更新约束
            if let toolView = toolView {
                imageView.snp.remakeConstraints { make in
                    make.size.equalTo(R.Size.IconSizeExtraLarge.height)
                    make.leading.top.bottom.equalToSuperview()
                    if newValue {
                        make.trailing.equalTo(toolView.snp.leading).offset(R.Size.ContentSpaceTiny)
                    } else {
                        make.trailing.equalToSuperview()
                    }
                }
                
                //执行动画
                if newValue {
                    UIView.normalAnimate {
                        toolView.alpha = 1
                    }
                } else {
                    toolView.alpha = 0
                }
                UIView.springAnimate { [weak self] in
                    self?.superview?.layoutIfNeeded()
                }
            }
            //更新icon
            imageView.image = UIImage(symbol: newValue ? (selectedSymbol ?? normalSymbol) : normalSymbol,
                                      size: iconSize,
                                      color: newValue ? R.Color.LabelPrimary : R.Color.LabelSecondary)
        }
    }
    
    lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(symbol: normalSymbol,
                             size: iconSize ,
                             color: R.Color.LabelSecondary)
        view.contentMode = .center
        view.isUserInteractionEnabled = true
        return view
    }()
    private var toolView: UIView? = nil
    
    init(toolView: UIView? = nil, normalSymbol: SFSymbol = .wrenchAndScrewdriver, selectedSymbol: SFSymbol? = nil, iconSize: CGFloat = R.Size.SymbolSize, autoLayutType: AutoLayutType) {
        self.normalSymbol = normalSymbol
        self.iconSize = iconSize
        super.init(frame: .zero)
        self.toolView = toolView
        self.selectedSymbol = selectedSymbol
        
        enablePressEffect = true
        
        
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.size.equalTo(R.Size.IconSizeExtraLarge.height)
            make.edges.equalToSuperview()
        }
        
        if case let .equal(value) = autoLayutType, value == 0 {
           //不必添加toolView
        } else if let toolView = toolView {
            addSubview(toolView)
            toolView.snp.makeConstraints { make in
                make.top.trailing.bottom.equalToSuperview().inset(R.Size.ContentSpaceTiny)
                switch autoLayutType {
                case .equal(let value):
                    make.width.equalTo(value)
                case .greater(let value):
                    make.width.greaterThanOrEqualTo(value).priority(.medium)
                }
            }
            toolView.alpha = 0
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layerCornerRadius = height/2
        layer.borderWidth = 1
        layer.borderColor = R.Color.Border.cgColor
    }
}
