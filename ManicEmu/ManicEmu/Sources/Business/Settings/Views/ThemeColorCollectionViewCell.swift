//
//  ThemeColorCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/3.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class ThemeColorCollectionViewCell: UICollectionViewCell {
    
    class ColorView: BaseView {
        var animatedGradientView: AnimatedGradientView = {
            let view = AnimatedGradientView(colors: [])
            view.layerCornerRadius = 48/2
            view.frameLimit = 24
            return view
        }()
        
        class SelectView: BaseView {
            private let outerLayer = CAShapeLayer()
            private let innerLayer = CAShapeLayer()
            private let outerColor = UIColor(.dm, light: R.Color.LabelPrimary.forceStyle(.light), dark: .white)
            private let innerColor = R.Color.BackgroundSecondary
            
            override init(frame: CGRect) {
                super.init(frame: frame)
                
                let outerWidth = 2.0
                let innerWidth = 2.0
                let totalWidth = innerWidth + outerWidth
                let radius = min(bounds.width, bounds.height) / 2
                
                // Outer border layer
                outerLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: outerWidth / 2, dy: outerWidth / 2)).cgPath
                outerLayer.strokeColor = outerColor.cgColor
                outerLayer.fillColor = UIColor.clear.cgColor
                outerLayer.lineWidth = totalWidth
                layer.addSublayer(outerLayer)
                
                // Inner border layer
                let innerInset = outerWidth
                innerLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: innerInset + innerWidth / 2, dy: innerInset + innerWidth / 2)).cgPath
                innerLayer.strokeColor = innerColor.cgColor
                innerLayer.fillColor = UIColor.clear.cgColor
                innerLayer.lineWidth = innerWidth
                layer.addSublayer(innerLayer)
                
                // Make the view itself circular
                layer.cornerRadius = radius
                clipsToBounds = true
                backgroundColor = .clear
                isHidden = true
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
                super.traitCollectionDidChange(previousTraitCollection)
                if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                    outerLayer.strokeColor = outerColor.cgColor
                    innerLayer.strokeColor = innerColor.cgColor
                }
            }
        }
        
        var selectView: SelectView = SelectView(frame: CGRect(origin: .zero, size: .init(48)))
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            enablePressEffect = true
            
            addSubview(animatedGradientView)
            animatedGradientView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            addSubview(selectView)
            selectView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private var roundContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = R.Color.BackgroundSecondary
        view.layerCornerRadius = R.Size.CornerRadiusLarge
        return view
    }()
    
    private var addButton: ASButtonView = {
        let view = ASButtonView(.iconOnly(icon: .symbol(.plus),
                                          iconSize: .init(48),
                                          background: R.Color.BackgroundTertiary,
                                          insets: .init(inset: R.Size.ContentSpaceSmall)).enableGlass(true))
        return view
    }()
    
    private var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.alwaysBounceHorizontal = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(roundContainerView)
        roundContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        roundContainerView.addSubview(addButton)
        addButton.snp.makeConstraints { make in
            make.size.equalTo(48)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
        }
        addButton.didTapButton = { [weak self] in
            guard let self = self else { return }
            //添加主题颜色
            self.showThemeColorEditor()
        }
        
        roundContainerView.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.trailing.equalTo(addButton.snp.leading)
            make.height.equalTo(100)
        }
        
        reloadColorViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateThemeColor(_ themeColor: ThemeColor) {
        let theme = Theme.defalut
        theme.updateThemeColor(themeColor)
        reloadColorViews()
    }
    
    private func reloadColorViews() {
        scrollView.subviews.forEach { $0.removeFromSuperview() }
        
        let theme = Theme.defalut
        let colors = theme.getThemeColors()
        for (index, color) in colors.enumerated() {
            let colorView = ColorView()
            colorView.animatedGradientView.setColors(color.colors.compactMap({ UIColor(hexString: $0) }))
            colorView.selectView.isHidden = !color.isSelect
            scrollView.addSubview(colorView)
            colorView.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.size.equalTo(48)
                if index == 0 {
                    make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
                } else {
                    make.leading.equalTo(scrollView.subviews[index-1].snp.trailing).offset(R.Size.ContentSpaceMedium)
                }
                if index == colors.count - 1 {
                    make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
                }
            }
            
            colorView.addTapGesture { [weak self] gesture in
                guard let self = self else { return }
                if index < self.scrollView.subviews.count, let view = self.scrollView.subviews[index] as? ColorView {
                    if !view.selectView.isHidden {
                        //当前已经选中
                        return
                    }
                }
                
                if let views = self.scrollView.subviews as? [ColorView] {
                    for (innerIndex, view) in views.enumerated() {
                        if innerIndex == index {
                            view.selectView.isHidden = false
                            var temp = colors[index]
                            temp.isSelect = true
                            Theme.defalut.updateThemeColor(temp)
                        } else {
                            view.selectView.isHidden = true
                        }
                    }
                }
            }
            
            colorView.addLongPressGesture { [weak self] gesture in
                guard let self = self else { return }
                
                switch gesture.state {
                case .began:
                    guard !color.system else {
                        UIView.makeToast(message: R.string.localizable.themeColorSystemNotAllowEdit())
                        return
                    }
                    
                    UIDevice.generateHaptic()
                    ChevronSheetView.show(stringOptions: [
                        R.string.localizable.editTitle(),
                        R.string.localizable.removeTitle()
                    ], completion: { [weak self] index in
                        guard let self, let index else { return }
                        if index == 0 {
                            //edit
                            self.showThemeColorEditor(themeColor: color)
                        } else if index == 1 {
                            //delete
                            Theme.defalut.deleteThemeColor(color)
                            self.reloadColorViews()
                        }
                    })
                    
                default:
                    break
                }
            }
        }
    }
    
    private func showThemeColorEditor(themeColor: ThemeColor? = nil) {
        ColorPickerView.show(themeColor: themeColor, didSaveAction: { [weak self] themeColor in
            self?.updateThemeColor(themeColor)
        })
    }
}
