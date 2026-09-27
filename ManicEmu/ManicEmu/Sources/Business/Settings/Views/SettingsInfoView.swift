//
//  SettingsInfoView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/25.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class SettingsInfoView: BaseView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let seperator = SparkleSeperatorView(isGradient: true)
        addSubview(seperator)
        seperator.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(24)
            make.top.equalToSuperview().offset(R.Size.ContentSpaceHuge)
        }
        
        let bottomAppNameImage = ASIconView(.image(R.image.app_title()!,
                                                   color: R.Color.LabelTertiary))
        addSubview(bottomAppNameImage)
        bottomAppNameImage.snp.makeConstraints { make in
            make.top.equalTo(seperator.snp.bottom).offset(40)
            make.centerX.equalToSuperview()
        }
        
        let versionLabel = ASLabelView(text: .extraSmallText("Version \(R.Config.AppVersion)",
                                                             color: R.Color.LabelTertiary))
        addSubview(versionLabel)
        versionLabel.snp.makeConstraints { make in
            make.top.equalTo(bottomAppNameImage.snp.bottom).offset(R.Size.ContentSpaceTiny)
            make.centerX.equalToSuperview()
        }
        
        let starView = ASIconView(.symbol(.sparkle, colors: [R.Color.BackgroundTertiary]))
        addSubview(starView)
        starView.snp.makeConstraints { make in
            make.top.equalTo(versionLabel.snp.bottom).offset(40)
            make.centerX.equalToSuperview()
        }
        
        let lilyView = UIImageView(image: R.image.lily())
        addSubview(lilyView)
        lilyView.snp.makeConstraints { make in
            make.top.equalTo(starView.snp.bottom).offset(40)
            make.centerX.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
