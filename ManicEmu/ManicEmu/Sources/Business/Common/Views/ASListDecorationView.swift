//
//  ASListDecorationView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/16.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASListDecorationPrimaryView: UICollectionReusableView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layerCornerRadius = R.Size.CornerRadiusLarge
        backgroundColor = R.Color.BackgroundPrimary
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ASListDecorationSecondaryView: UICollectionReusableView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layerCornerRadius = R.Size.CornerRadiusLarge
        backgroundColor = R.Color.BackgroundSecondary
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
