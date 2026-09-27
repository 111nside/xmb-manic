//
//  SettingsMembershipGiftView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/17.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class SettingsMembershipGiftView: BaseView {
    
    init(symbol: SFSymbol, title: String) {
        super.init(frame: .zero)
        backgroundColor = R.Color.BackgroundPrimary.forceStyle(.dark)
        
        let gift = GradientImageView(image: UIImage(symbol: symbol).applySymbolConfig(size: 16))
        addSubview(gift)
        gift.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceSmall)
            make.centerY.equalToSuperview()
        }
        
        let label = GradientLabelView()
        label.font = R.Font.Subheadline(emphasis: true)
        label.text = title
        label.textColor = R.Color.LabelPrimary
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalTo(gift.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceSmall)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layerCornerRadius = height/2
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
