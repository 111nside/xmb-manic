//
//  CollectionFooterReusableView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class BackgroundColorDetailFooterReusableView: UICollectionReusableView {
    var titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textColor = R.Color.LabelSecondary
        view.font = R.Font.Caption()
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews([titleLabel])
        
        titleLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceLarge)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}
