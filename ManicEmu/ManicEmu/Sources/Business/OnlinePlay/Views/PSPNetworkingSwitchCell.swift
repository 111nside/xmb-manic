//
//  PSPNetworkingSwitchCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/7.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class PSPNetworkingSwitchCell: UICollectionViewCell {
    var enableSwitchButton: DisabledTapSwitch = {
        let view = DisabledTapSwitch()
        view.onTintColor = R.Color.Main
        view.tintColor = R.Color.BackgroundTertiary
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let enableContainer: UIView = {
            let view = UIView()
            view.backgroundColor = R.Color.BackgroundSecondary
            view.layerCornerRadius = R.Size.CornerRadiusMedium
            return view
        }()
        
        addSubview(enableContainer)
        enableContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        let enableIconView = UIImageView()
        enableIconView.contentMode = .center
        enableIconView.layerCornerRadius = 6
        enableIconView.image = UIImage(symbol: .person2Wave2Fill, font: R.Font.Footnote(emphasis: true), color: R.Color.LabelPrimary.forceStyle(.dark))
        enableIconView.backgroundColor = R.Color.Red
        enableContainer.addSubview(enableIconView)
        enableIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.size.equalTo(R.Size.IconSizeLarge)
            make.centerY.equalToSuperview()
        }
        
        let enableTitleLabel = UILabel()
        enableTitleLabel.text = R.string.localizable.enableNetworking()
        enableTitleLabel.textColor = R.Color.LabelPrimary
        enableTitleLabel.font = R.Font.Body(emphasis: true)
        enableContainer.addSubview(enableTitleLabel)
        enableTitleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(enableIconView)
            make.leading.equalTo(enableIconView.snp.trailing).offset(R.Size.ContentSpaceSmall)
        }
        
        enableContainer.addSubview(enableSwitchButton)
        enableSwitchButton.snp.makeConstraints { make in
            make.centerY.equalTo(enableIconView)
            make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            if #available(iOS 26.0, tvOS 26.0, *) {
                make.size.equalTo(CGSize(width: 63, height: 28))
            } else {
                make.size.equalTo(CGSize(width: 51, height: 31))
            }
        }
        if #available(iOS 26.0, tvOS 26.0, *) {} else {
            enableSwitchButton.transform = CGAffineTransformMakeScale(0.9, 0.9)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
