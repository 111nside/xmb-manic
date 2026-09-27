//
//  BlankSlateCollectionView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/16.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import BlankSlate

class BlankSlateEmptyView: BaseView {
    let imageView = UIImageView()
    
    let label = UILabel()
    
    init(image: UIImage? = nil, title: String) {
        super.init(frame: .zero)
        
        imageView.image = image ?? R.image.empty_icon()
        imageView.contentMode = .center
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-R.Size.ItemHeightSmall)
        }
        
        label.font = R.Font.Body()
        label.textColor = R.Color.LabelSecondary
        label.text = title
        label.numberOfLines = 0
        label.textAlignment = .center
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualToSuperview().offset(R.Size.ContentSpaceLarge)
            make.trailing.lessThanOrEqualToSuperview().offset(-R.Size.ContentSpaceLarge)
            make.centerX.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom).offset(R.Size.ContentSpaceMedium)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class BlankSlateCollectionView: UICollectionView {
    
    var blankSlateView: UIView? = nil
    
    var layoutInsets: UIEdgeInsets = .zero

    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        self.bs.setDataSourceAndDelegate(self)
        isFocusable = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension BlankSlateCollectionView: BlankSlate.DataSource {
    func customView(forBlankSlate view: UIView) -> UIView? {
        return blankSlateView
    }
    
    func layout(forBlankSlate view: UIView, for element: BlankSlate.Element) -> BlankSlate.Layout {
        return .init(edgeInsets: layoutInsets)
    }
    
}

extension BlankSlateCollectionView: BlankSlate.Delegate {
    
}
