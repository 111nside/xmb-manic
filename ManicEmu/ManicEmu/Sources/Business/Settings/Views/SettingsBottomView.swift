//
//  SettingsBottomView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/25.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class SettingsBottomView: BaseView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
#if SIDE_LOAD
        let supportUsContainer = UIView()
        supportUsContainer.backgroundColor = R.Color.Red.withAlphaComponent(0.1)
        supportUsContainer.layerCornerRadius = R.Size.CornerRadiusLarge
        addSubview(supportUsContainer)
        supportUsContainer.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        var supportUsStyles = [ASListPage.Cell.Style]()
        supportUsStyles.append(.icon(.symbolImage(R.image.supportus_iconSymbols(),
                                                  colors: [R.Color.Red])))
        supportUsStyles.append(.title(.largeText(R.string.localizable.donateTitle(),
                                                 color: R.Color.Red)))
        supportUsStyles.append(.detail(.extraSmallText(R.string.localizable.donateDesc(),
                                                       color: R.Color.Red)))
        supportUsStyles.append(.chevron(ASChevron(icon: .symbol(.chevronRight, colors: [R.Color.Red]))))
        let supportUsView = ASListItemView()
        supportUsView.styles = supportUsStyles
        supportUsContainer.addSubview(supportUsView)
        supportUsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceSmall)
            make.top.bottom.equalToSuperview()
        }
        supportUsView.enablePressEffect = true
        supportUsView.enableFocusEffects = false
        supportUsView.addTapGesture { gesture in
            UIApplication.shared.open(R.URLs.Donate)
        }
        
#endif
        
        let rateUsView = SettingsRateUsView()
        addSubview(rateUsView)
        rateUsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(100)
#if SIDE_LOAD
            make.top.equalTo(supportUsContainer.snp.bottom).offset(R.Size.ContentSpaceMedium)
#else
            make.top.equalToSuperview()
#endif
        }
        
        let infoView = SettingsInfoView()
        addSubview(infoView)
        infoView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(rateUsView.snp.bottom).offset(R.Size.ContentSpaceMedium)
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
