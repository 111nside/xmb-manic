//
//  ServiceIconView.swift
//  ManicEmu
//
//  Created by Aoshuang on 2025/10/9.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class ServiceIconView: RoundAndBorderView {
    var imageView: UIImageView = {
        let view = UIImageView()
        return view
    }()
    
    override init(roundCorner: UIRectCorner = [],
                  radius: CGFloat = R.Size.CornerRadiusLarge,
                  borderColor: UIColor = R.Color.Border,
                  borderWidth: CGFloat = 1,
                  dashPattern: [NSNumber]? = nil) {
        super.init(roundCorner: roundCorner,
                   radius: radius,
                   borderColor: borderColor,
                   borderWidth: borderWidth)
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
