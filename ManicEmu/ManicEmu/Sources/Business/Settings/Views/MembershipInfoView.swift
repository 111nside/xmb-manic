//
//  MembershipInfoView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/17.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class MembershipInfoView: BaseView {
    
    private var membershipNotification: Any? = nil
    private var productUpdateNotification: Any? = nil
    
    deinit {
        if let membershipNotification = membershipNotification {
            NotificationCenter.default.removeObserver(membershipNotification)
        }
        if let productUpdateNotification = productUpdateNotification {
            NotificationCenter.default.removeObserver(productUpdateNotification)
        }
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        
        membershipNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.MembershipChange, object: nil, queue: .main) { [weak self] notification in
            self?.setupViews()
        }
        productUpdateNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.ProductsUpdate, object: nil, queue: .main) { [weak self] notification in
            self?.setupViews()
        }
        
        overrideUserInterfaceStyle = .dark
    }
    
    private func setupViews() {
        subviews.forEach { $0.removeFromSuperview() }
        let isMember = PurchaseManager.isMember
        
        let contentContainer = UIView()
        addSubview(contentContainer)
        contentContainer.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        let secondLineContent: UIView
        
        if isMember {
            let titleContainer = UIView()
            contentContainer.addSubview(titleContainer)
            titleContainer.snp.makeConstraints { make in
                make.top.equalToSuperview()
                make.centerX.equalToSuperview()
                make.height.equalTo(R.Size.IconSizeMedium.height)
            }
            
            let titleLeftView = UIImageView(image: R.image.customLaurelLeading()?.applySymbolConfig(font: UIFont.systemFont(ofSize: 16, weight: .bold), color: R.Color.LabelPrimary))
            if Locale.isRTLLanguage {
                titleLeftView.transform = CGAffineTransform(scaleX: -1, y: 1)
            }
            
            titleLeftView.contentMode = .center
            titleContainer.addSubview(titleLeftView)
            titleLeftView.snp.makeConstraints { make in
                make.leading.top.bottom.equalToSuperview()
            }
            
            let titleLabel = UILabel()
            titleLabel.adjustsFontSizeToFitWidth = true
            var text = R.string.localizable.hi() + " " + R.string.localizable.foreverMemberTitle()
            if PurchaseManager.isAnnualMember {
                text = R.string.localizable.hi() + " " + R.string.localizable.annualMemberTitle()
            } else if PurchaseManager.isMonthlyMember {
                text = R.string.localizable.hi() + " " + R.string.localizable.monthlyMemberTitle()
            }
            titleLabel.text = text
            titleLabel.font = R.Font.Headline(emphasis: true)
            titleLabel.textColor = R.Color.LabelPrimary
            titleContainer.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.leading.equalTo(titleLeftView.snp.trailing).offset(R.Size.ContentSpaceTiny)
                make.centerY.equalToSuperview()
            }
            
            let titleRightView = UIImageView(image: R.image.customLaurelLeading()?.applySymbolConfig(font: UIFont.systemFont(ofSize: 16, weight: .bold), color: R.Color.LabelPrimary))
            if !Locale.isRTLLanguage {
                titleRightView.transform = CGAffineTransform(scaleX: -1, y: 1)
            }
            titleRightView.contentMode = .center
            titleContainer.addSubview(titleRightView)
            titleRightView.snp.makeConstraints { make in
                make.trailing.centerY.equalToSuperview()
                make.leading.equalTo(titleLabel.snp.trailing).offset(R.Size.ContentSpaceTiny)
            }
            
            let thankContainer = UIView()
            secondLineContent = thankContainer
            contentContainer.addSubview(thankContainer)
            thankContainer.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(titleContainer.snp.bottom).offset(R.Size.ContentSpaceTiny)
            }
            let thankLabel = UILabel()
            thankLabel.textColor = R.Color.LabelPrimary
            thankLabel.font = R.Font.Footnote(emphasis: true)
            thankLabel.text = R.string.localizable.thanksCommingDesc()
            thankLabel.adjustsFontSizeToFitWidth = true
            thankContainer.addSubview(thankLabel)
            thankLabel.snp.makeConstraints { make in
                make.leading.top.bottom.equalToSuperview()
            }
            
            let appNameImage = UIImageView(image: R.image.app_title())
            thankContainer.addSubview(appNameImage)
            appNameImage.snp.makeConstraints { make in
                make.leading.equalTo(thankLabel.snp.trailing).offset(R.Size.ContentSpaceTiny)
                make.centerY.equalTo(thankLabel)
                make.size.equalTo(CGSize(width: 100, height: 8.2))
            }
            
            let playLabel = UILabel()
            playLabel.textColor = R.Color.LabelPrimary
            playLabel.font = R.Font.Footnote(emphasis: true)
            playLabel.text = R.string.localizable.playGameDesc()
            playLabel.adjustsFontSizeToFitWidth = true
            thankContainer.addSubview(playLabel)
            playLabel.snp.makeConstraints { make in
                make.leading.equalTo(appNameImage.snp.trailing).offset(R.Size.ContentSpaceTiny)
                make.trailing.equalToSuperview()
                make.centerY.equalTo(thankLabel)
            }
            
        } else {
            let titleContainer = UIView()
            contentContainer.addSubview(titleContainer)
            titleContainer.snp.makeConstraints { make in
                make.top.equalToSuperview()
                make.centerX.equalToSuperview()
                make.height.equalTo(R.Size.IconSizeMedium.height)
            }
            
            let becomeLabel = UILabel()
            becomeLabel.textColor = R.Color.LabelPrimary
            becomeLabel.font = R.Font.Headline(emphasis: true)
            becomeLabel.text = R.string.localizable.gameSaveGuideBecomTitle()
            becomeLabel.adjustsFontSizeToFitWidth = true
            titleContainer.addSubview(becomeLabel)
            becomeLabel.snp.makeConstraints { make in
                make.leading.centerY.top.bottom.equalToSuperview()
                
            }
            
            let appNameImage = UIImageView(image: R.image.app_title())
            titleContainer.addSubview(appNameImage)
            appNameImage.snp.makeConstraints { make in
                make.leading.equalTo(becomeLabel.snp.trailing).offset(R.Size.ContentSpaceTiny)
                make.centerY.equalToSuperview()
            }
            
            let memberLabel = UILabel()
            memberLabel.textColor = R.Color.LabelPrimary
            memberLabel.font = R.Font.Headline(emphasis: true)
            memberLabel.text = R.string.localizable.gameSaveGuideMemberTitle()
            memberLabel.adjustsFontSizeToFitWidth = true
            titleContainer.addSubview(memberLabel)
            memberLabel.snp.makeConstraints { make in
                make.leading.equalTo(appNameImage.snp.trailing).offset(R.Size.ContentSpaceTiny)
                make.centerY.equalTo(becomeLabel)
                make.trailing.lessThanOrEqualToSuperview()
            }
            
            let detalLabel = UILabel()
            secondLineContent = detalLabel
            detalLabel.textColor = R.Color.LabelPrimary
            detalLabel.font = R.Font.Footnote(emphasis: true)
            detalLabel.text = R.string.localizable.settingsNonMemberDesc()
            detalLabel.adjustsFontSizeToFitWidth = true
            contentContainer.addSubview(detalLabel)
            detalLabel.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(titleContainer.snp.bottom).offset(R.Size.ContentSpaceTiny)
            }
        }
       
        
        let symbol: SFSymbol
        var title = R.string.localizable.promptLabelForYear()
        if isMember {
            symbol = .sparkles
            title = R.string.localizable.thanksSupportDesc()
        } else {
            symbol = .appGiftFill
            if let freeTrialDay = PurchaseManager.maxFreeTrialDay {
                //有试用
                title = R.string.localizable.settingsFreeTrialDesc(freeTrialDay)
            }
        }
        let giftView = SettingsMembershipGiftView(symbol: symbol, title: title)
        contentContainer.addSubview(giftView)
        giftView.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.top.equalTo(secondLineContent.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.centerX.equalToSuperview()
            make.height.equalTo(R.Size.ButtonSmall)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
