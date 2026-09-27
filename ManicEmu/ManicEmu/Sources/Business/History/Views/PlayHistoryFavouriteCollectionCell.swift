//
//  PlayHistoryFavouriteCollectionCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/23.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Kingfisher

class PlayHistoryFavouriteCollectionCell: UICollectionViewCell {
    private let headerTitleLabel: SymbolButton = {
        let view = SymbolButton(image: .symbolImage(.handThumbsupFill).applySymbolConfig(color: R.Color.LabelSecondary),
                                title: R.string.localizable.historyFavouriteTitle(),
                                titleFont: R.Font.Caption(),
                                titleColor: R.Color.LabelSecondary,
                                titleAlignment: .left,
                                edgeInsets: UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12),
                                titlePosition: .right,
                                imageAndTitlePadding: 4,
                                enableGlass: true)
        view.enableRoundCorner = true
        view.enablePressEffect = false
        view.backgroundColor = R.Color.SideList
        return view
    }()
    
    private let infoContainerView: UIView = {
        let view = GradientView()
        view.setupGradient(colors: [.clear, .black.withAlphaComponent(0.4)], locations: [0.0, 1.0], direction: .topToBottom)
        view.backgroundColor = R.Color.BackgroundPrimary
        view.layerCornerRadius = R.Size.CornerRadiusLarge
        view.enablePressEffect = true
        return view
    }()
    
    private let iconViewContainerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = R.Size.CornerRadiusSmall
        view.makeShadow(ofColor: R.Color.BackgroundSecondary.forceStyle(.dark), radius: 10)
        return view
    }()
    
    private let iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleToFill
        view.layerCornerRadius = R.Size.CornerRadiusSmall
        return view
    }()
    
    private let titleLabel: UILabel = {
        let view = UILabel()
        view.font = R.Font.Body()
        view.textColor = R.Color.LabelPrimary.forceStyle(.dark)
        view.numberOfLines = 2
        view.layer.shadowColor = R.Color.BackgroundPrimary.cgColor
        view.layer.shadowOpacity = 0.5
        view.layer.shadowOffset = .init(width: 0, height: 2)
        view.layer.shadowRadius = 2
        return view
    }()
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            titleLabel.layer.shadowColor = R.Color.BackgroundPrimary.cgColor
            iconViewContainerView.makeShadow(ofColor: R.Color.BackgroundSecondary.forceStyle(.dark), radius: 10)
        }
    }
    
    private let subtitleIcon: UIImageView = {
        let view = UIImageView()
        view.image = .symbolImage(.starCircleFill).applySymbolConfig(color: .white.withAlphaComponent(0.5))
        return view
    }()
    
    private let subTitleLabel: UILabel = {
        let view = UILabel()
        view.font = UIDevice.isPad ? R.Font.Caption() : R.Font.Caption()
        view.lineBreakMode = .byCharWrapping
        view.textColor = .white.withAlphaComponent(0.5)
        view.numberOfLines = 2
        return view
    }()
    
    private let retroView: RetroAchievementCountView = {
        let view = RetroAchievementCountView(count: 0)
        view.isHidden = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(headerTitleLabel)
        headerTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(R.Size.ItemHeightMicro)
        }
        
        addSubview(infoContainerView)
        infoContainerView.snp.makeConstraints { make in
            make.top.equalTo(headerTitleLabel.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.leading.trailing.equalToSuperview()
        }
        
        infoContainerView.addSubview(iconViewContainerView)
        iconViewContainerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.centerY.equalToSuperview()
            make.size.equalTo(106 * (UIDevice.isPad ? 0.8 : 1))
        }

        iconViewContainerView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
        
        let titleContainerView = UIView()
        infoContainerView.addSubview(titleContainerView)
        titleContainerView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(iconViewContainerView.snp.trailing).offset(R.Size.ContentSpaceSmall)
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceSmall)
        }
        
        titleContainerView.addSubviews([titleLabel, subtitleIcon, subTitleLabel])
        titleLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
        
        subtitleIcon.snp.makeConstraints { make in
            make.size.equalTo(R.Size.IconSizeSmall)
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(R.Size.ContentSpaceTiny)
        }
        
        subTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(subtitleIcon.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.bottom.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(R.Size.ContentSpaceTiny)
        }
        
        infoContainerView.addSubview(retroView)
        retroView.snp.makeConstraints { make in
            make.height.equalTo(24)
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceSmall)
            make.top.equalToSuperview().offset(R.Size.ContentSpaceExtraSmall)
        }
        
        let seperator = SparkleSeperatorView()
        addSubview(seperator)
        seperator.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(16)
            make.top.equalTo(infoContainerView.snp.bottom).offset(R.Size.ContentSpaceHuge)
            make.bottom.equalToSuperview().offset(-R.Size.ContentSpaceTiny)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(game: Game) {
        let estimated = iconView.size == .zero ? .init((UIDevice.isPad ? 85 : 106)) : iconView.size
        iconView.setGameCover(game: game, size: estimated) { [weak self] image in
            self?.infoContainerView.backgroundColor = image.dominantBackground
        }
        if R.Size.GameCoverRatio(gameType: game.gameType) != 1.0 {
            iconView.contentMode = .scaleAspectFill
        } else {
            iconView.contentMode = .scaleToFill
        }
        titleLabel.text = game.displayName
        if let timeAgo = game.latestPlayDate?.timeAgo() {
            subTitleLabel.text = R.string.localizable.readyGameInfoSubTitle(timeAgo, Date.timeDuration(milliseconds: Int(game.totalPlayDuration))).replacingOccurrences(of: " · ", with: "\n")
        } else {
            subTitleLabel.text = ""
        }
        if game.enableAchievements {
            retroView.isHidden = false
            retroView.countLabel.text = ""
            retroView.removeGestureRecognizers()
            retroView.addTapGesture { gesture in
                RetroAchievementsLaunchView.show(loginedAction: .jumpList(game: game))
            }
        } else {
            retroView.isHidden = true
        }
    }
}
