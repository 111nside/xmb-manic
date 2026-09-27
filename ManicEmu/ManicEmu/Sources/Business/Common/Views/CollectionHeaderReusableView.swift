//
//  TitleHaderCollectionReusableView.swift
//  ManicEmu
//
//  Created by Max on 2025/1/21.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import VisualEffectView

class TitleHaderCollectionReusableView: UICollectionReusableView {
    var titleLabel: UILabel = {
        let view = UILabel()
        view.textColor = R.Color.LabelSecondary.forceStyle(UIDevice.isDarkMode ? .dark : .light)
        view.font = R.Font.Footnote(emphasis: true)
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews([titleLabel])
        
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceHuge)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }   
}

class BackgroundColorHaderReusableView: UICollectionReusableView {
    var titleLabel: UILabel = {
        let view = UILabel()
        view.textColor = R.Color.LabelSecondary.forceStyle(UIDevice.isDarkMode ? .dark : .light)
        view.font = R.Font.Footnote(emphasis: true)
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews([titleLabel])
        
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceHuge)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
