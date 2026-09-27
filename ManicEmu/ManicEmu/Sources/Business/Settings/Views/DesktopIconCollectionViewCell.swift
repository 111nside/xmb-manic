//
//  DesktopIconCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/3.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class DesktopIconCollectionViewCell: UICollectionViewCell {
    
    class IconView: BaseView {
        
        private var mainColorChangeNotification: Any? = nil
        
        var imageView: UIImageView = {
            let view = UIImageView()
            view.contentMode = .scaleAspectFill
            return view
        }()
        
        var selectImageView: UIImageView = {
            let view = UIImageView()
            view.contentMode = .center
            view.layerCornerRadius = R.Size.IconSizeMedium.height/2
            view.layer.shadowColor = R.Color.Shadow.cgColor
            view.layer.shadowOpacity = 0.5
            view.layer.shadowRadius = 2
            view.image = UIImage(symbol: .checkmarkCircleFill, weight: .bold, colors: [R.Color.LabelPrimary.forceStyle(.dark), R.Color.Main])
            view.isHidden = true
            return view
        }()
        
        deinit {
            if let mainColorChangeNotification {
                NotificationCenter.default.removeObserver(mainColorChangeNotification)
            }
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            enablePressEffect = true
            enableFocusEffects = false
            
            addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            addSubview(selectImageView)
            selectImageView.snp.makeConstraints { make in
                make.size.equalTo(R.Size.IconSizeMedium)
                make.trailing.equalToSuperview().offset(R.Size.ContentSpaceExtraSmall)
                make.top.equalToSuperview().offset(-R.Size.ContentSpaceExtraSmall)
            }
            
            mainColorChangeNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.MainColorChange, object: nil, queue: .main) { [weak self] notification in
                guard let self = self else { return }
                self.selectImageView.image = UIImage(symbol: .checkmarkCircleFill, weight: .bold, colors: [R.Color.LabelPrimary.forceStyle(.dark), R.Color.Main])
            }
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            imageView.image = imageView.image?.withRoundedCorners(radius: R.Size.AppleIconCornerRadius(height: height)) 
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                selectImageView.layer.shadowColor = R.Color.Shadow.cgColor
            }
        }
    }
    
    
    private var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.backgroundColor = R.Color.BackgroundSecondary
        view.layerCornerRadius = R.Size.CornerRadiusLarge
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.alwaysBounceHorizontal = true
        view.alwaysBounceVertical = false
        return view
    }()
    
    private var descLabel: UILabel = {
        let label = UILabel()
        label.font = R.Font.Caption()
        label.textColor = R.Color.LabelSecondary
        label.text = R.string.localizable.themeDesktopIconDetail()
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(100)
        }
        
        let icons = ["AppIcon",
                     "AppIcon_Lily",
                     "AppIcon_Rainbow1",
                     "AppIcon_Rainbow2",
                     "AppIcon_Rainbow3",
                     "AppIcon_Unity",
                     "AppIcon_ChineseNewYear",
                     "AppIcon_Xmas",
                     "AppIcon_Pixel32",
                     "AppIcon_Halloween",
                     "AppIcon_Dark",
                     "AppIcon_Retro",
                     "AppIcon_Color"]
        let theme = Theme.defalut
        for (index, icon) in icons.enumerated() {
            let iconView = IconView()
            iconView.imageView.image = UIImage(named: icon.lowercased())?.scaled(toSize: R.Size.IconSizeHuge)
            if theme.icon == icon {
                iconView.selectImageView.isHidden = false
            } else {
                iconView.selectImageView.isHidden = true
            }
            scrollView.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.top.bottom.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                make.height.equalTo(iconView.snp.width)
                if index == 0 {
                    make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
                } else {
                    make.leading.equalTo(scrollView.subviews[index-1].snp.trailing).offset(R.Size.ContentSpaceMedium)
                }
                if index == icons.count - 1 {
                    make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
                }
            }
            
            iconView.addTapGesture { [weak self] gesture in
                guard let self = self else { return }
                if index < self.scrollView.subviews.count, let view = self.scrollView.subviews[index] as? IconView {
                    if !view.selectImageView.isHidden {
                        //当前已经选中
                        return
                    }
                }
                
                if let views = self.scrollView.subviews as? [IconView] {
                    for (innerIndex, view) in views.enumerated() {
                        if innerIndex == index {
                            view.selectImageView.isHidden = false
                            Theme.change { realm in
                                Theme.defalut.icon = icons[index]
                            }
                        } else {
                            view.selectImageView.isHidden = true
                        }
                    }
                }
            }
        }
        
        addSubview(descLabel)
        descLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(scrollView.snp.bottom).offset(R.Size.ContentSpaceExtraSmall)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
