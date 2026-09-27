//
//  MultiDiscAddCollectionCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/1/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class MultiDiscAddCollectionCell: UICollectionViewCell {
    
    var titleLabel: UILabel = {
        let view = UILabel()
        view.font = R.Font.Body(emphasis: true)
        view.textColor = R.Color.LabelPrimary
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        enablePressEffect = true
        
        layerCornerRadius = R.Size.CornerRadiusLarge
        backgroundColor = R.Color.BackgroundSecondary
        
        let containerView = UIView()
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        let icon = IconView()
        icon.image = UIImage(systemSymbol: .plusCircleFill).applySymbolConfig(size: 22, weight: .medium, color: R.Color.LabelPrimary)
        containerView.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.size.equalTo(24)
            make.centerY.leading.top.bottom.equalToSuperview()
        }
        
        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
