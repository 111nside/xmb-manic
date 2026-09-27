//
//  PlayHistoryBlankSlateView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/11.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift

class PlayHistoryBlankSlateView: BaseView {
    
    enum TapType {
        case importGame, startGame
    }
    
    init(tapAction: ((TapType)->Void)? = nil) {
        super.init(frame: .zero)
        let containerView = UIView()
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        let iconImageView = UIImageView(image: R.image.play_history_empty_icon())
        iconImageView.contentMode = .center
        containerView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(100)
        }
        
        let titleLabel = UILabel()
        titleLabel.textColor = R.Color.LabelPrimary
        titleLabel.font = R.Font.Headline(emphasis: true)
        titleLabel.text = R.string.localizable.historyEmptyTitle()
        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(iconImageView.snp.bottom).offset(R.Size.ContentSpaceHuge)
            make.leading.trailing.equalToSuperview()
        }
        
        //功能按钮
        let gameCount = Database.realm.objects(Game.self).where({ !$0.isDeleted }).count
        let buttonTitle = gameCount > 0 ? R.string.localizable.historyEmptyStartGame() : R.string.localizable.historyEmptyImportGame()
        let button = ASButton.extraExtraSmall(title: buttonTitle,
                                              titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                              titleFont: R.Font.Subheadline(),
                                              background: R.Color.Main).enableGlass(true, ignoreBackground: false)
        let actionButton = ASButtonView(button)
        actionButton.didTapButton = {
            tapAction?(gameCount > 0 ? .startGame : .importGame)
        }
        containerView.addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(R.Size.ContentSpaceHuge)
            make.height.equalTo(R.Size.ItemHeightMicro)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}
