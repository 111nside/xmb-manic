//
//  CheevosProgressView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/9/7.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class CheevosProgressView: RoundAndBorderView {
    
    private var progressViewDict: [Int: (imageView: UIImageView, measuredString: String?)] = [:]
    private let containerView = UIView()
    
    private let titleLabel: UILabel = {
        let view = UILabel()
        view.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textColor = R.Color.LabelPrimary
        view.minimumScaleFactor = 0.5
        return view
    }()
    
    init() {
        super.init(roundCorner: .allCorners, radius: 16, borderColor: R.Color.Border, borderWidth: 1)
        makeBlur(blurRadius: 2.5, blurAlpha: 0.4)
        
        enablePressEffect = true
        
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceSmall)
            make.top.bottom.equalToSuperview()
        }
        
        let icon = UIImageView(image: .symbolImage(.playFill).applySymbolConfig(font: UIFont.systemFont(ofSize: 10, weight: .bold)))
        icon.contentMode = .scaleAspectFit
        addSubview(icon)
        icon.snp.makeConstraints { make in
            make.size.equalTo(12)
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceSmall)
            make.centerY.equalToSuperview()
        }
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(containerView.snp.trailing).offset(4)
            make.trailing.equalTo(icon.snp.leading).offset(-5)
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateProgress(_ progress: CheevosAchievement) {
        if isHidden { isHidden = false }
        
        titleLabel.text = progress.measuredProgress
        
        if let info = progressViewDict[progress._id] {
            updateLayout(view: info.imageView, remakeConstraints: false)
        } else {
            let view = UIImageView()
            view.layerCornerRadius = 4
            view.contentMode = .scaleAspectFill
            view.kf.setImage(with: URL(string: progress.unlockedBadgeUrl), placeholder: UIImage.placeHolder(preferenceSize: .init(32)))
            containerView.addSubview(view)
            updateLayout(view: view)
            progressViewDict[progress._id] = (view, progress.measuredProgress)
        }
    }
    
    private func updateLayout(view: UIImageView?, remakeConstraints: Bool = true, updateMeasuredString: Bool = false) {
        let hightLightView: UIImageView?
        if let view {
            hightLightView = view
        } else {
            let element = progressViewDict.randomElement()
            hightLightView = element?.value.imageView
            if updateMeasuredString {
                titleLabel.text = element?.value.measuredString
            }
        }
        
        
        for (index, subView) in containerView.subviews.enumerated() {
            subView.alpha = (subView == hightLightView ? 1 : 0.5)
            if remakeConstraints {
                subView.snp.remakeConstraints { make in
                    make.top.bottom.equalToSuperview().inset(4)
                    make.size.equalTo(24)
                    if index == 0 {
                        make.leading.equalToSuperview()
                    } else {
                        make.leading.equalTo(containerView.subviews[index-1].snp.trailing).offset(4)
                    }
                    if index == containerView.subviews.count - 1 {
                        make.trailing.equalToSuperview()
                    }
                }
            }
        }
    }
    
    func removeProgress(id: Int) {
        if let info = progressViewDict[id] {
            info.imageView.removeFromSuperview()
            progressViewDict.removeValue(forKey: id)
            updateLayout(view: nil, updateMeasuredString: info.imageView.alpha == 1 ? true : false)
        }
        if progressViewDict.isEmpty {
            isHidden = true
        }
    }
    
}
