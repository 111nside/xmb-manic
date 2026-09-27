//
//  RetroAchievementCountView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class RetroAchievementCountView: RoundAndBorderView {
    let countLabel: UILabel = {
        let view = UILabel()
        view.font = R.Font.Caption()
        view.textColor = .white
        return view
    }()
    
    init(count: Int) {
        super.init(roundCorner: .allCorners, radius: R.Size.CornerRadiusSmall, borderColor: .white.withAlphaComponent(0.1), borderWidth: 1)
        
        enablePressEffect = true
        
        
        backgroundColor = .black.withAlphaComponent(0.1)
        let icon = UIImageView(image: R.image.settings_retro())
        icon.contentMode = .scaleAspectFill
        addSubview(icon)
        icon.snp.makeConstraints { make in
            make.size.equalTo(CGSize(width: 17, height: 12))
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceExtraSmall)
        }
        
        addSubview(countLabel)
        countLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(icon.snp.trailing).offset(2)
        }
        
        let arrowIcon = UIImageView(image: .symbolImage(.chevronRight).applySymbolConfig(size: 10))
        arrowIcon.contentMode = .scaleAspectFill
        addSubview(arrowIcon)
        arrowIcon.snp.makeConstraints { make in
            make.size.equalTo(CGSize(width: 8, height: 8))
            make.centerY.equalToSuperview()
            make.leading.equalTo(countLabel.snp.trailing).offset(2)
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceExtraSmall)
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
