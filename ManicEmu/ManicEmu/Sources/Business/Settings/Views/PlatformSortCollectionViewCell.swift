//
//  PlatformSortCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/3.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class PlatformSortCollectionViewCell: UICollectionViewCell {
    private var titleLabel: UILabel = {
        let label = UILabel()
        label.font = R.Font.Body()
        label.textColor = R.Color.LabelPrimary
        return label
    }()
    
    private let icon = SymbolButton(image: .init(symbol: .line3Horizontal, font: R.Font.Headline(emphasis: true), color: R.Color.LabelSecondary))
    
    private lazy var visibleButton: SymbolButton = {
        let view = SymbolButton(image: .init(symbol: .eye, font: R.Font.Body(emphasis: true), color: R.Color.LabelSecondary))
        view.addTapGesture { [weak self] gesture in
            self?.didTapVisibleButton?()
        }
        return view
    }()
    
    var didTapVisibleButton: (()->Void)? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layerCornerRadius = R.Size.CornerRadiusMedium
        
        backgroundColor = R.Color.BackgroundTertiary
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
        }
        
        icon.backgroundColor = .clear
        icon.isFocusable = false
        addSubview(icon)
        icon.snp.makeConstraints { make in
            make.size.equalTo(R.Size.IconSizeMedium)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
        }
        
        visibleButton.backgroundColor = .clear
        addSubview(visibleButton)
        visibleButton.snp.makeConstraints { make in
            make.size.equalTo(R.Size.IconSizeExtraLarge)
            make.centerY.equalToSuperview()
            make.trailing.equalTo(icon.snp.leading)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(platform: String) {
        titleLabel.text = platform
        let visible = Settings.defalut.getPlatformVisible(platform: platform)
        visibleButton.imageView.image = .init(symbol: visible ? .eye : .eyeSlash, font: R.Font.Body(emphasis: true), color: visible ? R.Color.LabelSecondary : R.Color.Red)
    }
}
