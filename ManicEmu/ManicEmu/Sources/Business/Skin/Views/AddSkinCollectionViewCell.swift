//
//  AddSkinCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class AddSkinCollectionViewCell: UICollectionViewCell {
    var iconView: SymbolButton = {
        let view = SymbolButton(image: UIImage(symbol: .plusCircleFill, color: R.Color.LabelSecondary),
                                title: R.string.localizable.skinAddTitle(),
                                titleFont: R.Font.Caption(),
                                titleColor: R.Color.LabelSecondary,
                                edgeInsets: .zero,
                                titlePosition: .down,
                                imageAndTitlePadding: R.Size.ContentSpaceExtraSmall)
        view.layerCornerRadius = 0
        view.backgroundColor = .clear
        view.enablePressEffect = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        enablePressEffect = true
        
        layerCornerRadius = R.Size.CornerRadiusMedium
        backgroundColor = R.Color.BackgroundPrimary
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
