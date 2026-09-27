//
//  RadomGameCollectionReusableView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/4.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class RandomGameCollectionReusableView: UICollectionReusableView {
    
    var randomButton = ASButtonView(.extraSmall(icon: .symbol(.diceFill, colors: [R.Color.LabelPrimary]),
                                                title: R.string.localizable.randomGaming(),
                                                titleColor: R.Color.LabelPrimary,
                                                background: R.Color.BackgroundSecondary))
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(randomButton)
        randomButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}
