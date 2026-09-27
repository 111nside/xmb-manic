//
//  IconView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/11/18.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class IconView: BaseView {
    var image: UIImage? = nil {
        didSet {
            imageView.image = image
        }
    }
    
    let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        return view
    }()
    
    init(image: UIImage? = nil) {
        self.image = image
        super.init(frame: .zero)
        masksToBounds = true
        imageView.image = image
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
