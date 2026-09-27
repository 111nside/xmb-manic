//
//  TitleSortCollectionCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/4/11.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class TitleSortCollectionCell: UICollectionViewCell {
    private var titleLabel: UILabel = {
        let label = UILabel()
        label.font = R.Font.Body()
        label.textColor = R.Color.LabelPrimary
        return label
    }()
    
    private let icon = ASButtonView(.iconOnly(icon: .symbol(.line3Horizontal, colors: [R.Color.LabelSecondary]),
                                              iconSize: CGSize(R.Size.ButtonExtraExtraSmall)))
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layerCornerRadius = R.Size.CornerRadiusMedium
        
        backgroundColor = R.Color.BackgroundTertiary
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
        }
        
        icon.backgroundColor = .clear
        icon.isFocusable = false
        addSubview(icon)
        icon.snp.makeConstraints { make in
            make.size.equalTo(R.Size.IconSizeMedium)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(title: String) {
        titleLabel.text = title
    }
}
