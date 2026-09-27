//
//  SettingsRateUsView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/25.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class SettingsRateUsView: BaseView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        enablePressEffect = true
        enableFocusEffects = false
        
        let containerView = UIView()
        containerView.layerCornerRadius = R.Size.CornerRadiusLarge
        containerView.addTapGesture { gesture in
            UIApplication.shared.open(R.URLs.AppReview)
        }
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let backgroundImageView = RadialGradientView()
        containerView.addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let fiveStarView = UIImageView(image: R.image.five_star())
        containerView.addSubview(fiveStarView)
        fiveStarView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(R.Size.ContentSpaceSmall)
        }
        
        var text = ASText.largeText(R.string.localizable.rateUs(),
                                    color: R.Color.Yellow,
                                    numberOfLines: 0)
        text.attributes?.alignment = .center
        let rateUsLabel = ASLabelView(text: text)
        containerView.addSubview(rateUsLabel)
        rateUsLabel.snp.makeConstraints { make in
            make.top.equalTo(fiveStarView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceSmall)
            make.centerX.equalToSuperview()
        }
        
        let detailLabel = ASLabelView(text: .extraSmallText(R.string.localizable.ratingUsDesc(),
                                                            color: R.Color.LabelPrimary))
        containerView.addSubview(detailLabel)
        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(rateUsLabel.snp.bottom).offset(R.Size.ContentSpaceMicro)
            make.centerX.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
