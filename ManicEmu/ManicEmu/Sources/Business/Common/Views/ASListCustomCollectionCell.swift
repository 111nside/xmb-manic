//
//  ASListCustomCollectionCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/29.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASListCustomCollectionCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(customView: UIView) {
        subviews.forEach({ $0.removeFromSuperview() })
        customView.removeFromSuperview()
        addSubview(customView)
        customView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
}
