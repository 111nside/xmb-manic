//
//  CheevosChallengeView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/9/12.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import UIKit

class CheevosChallengeView: RoundAndBorderView {
    
    private var challengeViewDict: [Int: UIImageView] = [:]
    private let containerView = UIView()
    
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
            make.leading.equalTo(containerView.snp.trailing).offset(5)
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateChallenge(_ challenge: CheevosAchievement) {
        if isHidden { isHidden = false }
        
        if let imageView = challengeViewDict[challenge._id] {
            updateLayout(view: imageView, remakeConstraints: false)
        } else {
            let view = UIImageView()
            view.layerCornerRadius = 4
            view.contentMode = .scaleAspectFill
            view.kf.setImage(with: URL(string: challenge.unlockedBadgeUrl), placeholder: UIImage.placeHolder(preferenceSize: .init(32)))
            containerView.addSubview(view)
            updateLayout(view: view)
            challengeViewDict[challenge._id] = view
        }
    }
    
    private func updateLayout(view: UIImageView?, remakeConstraints: Bool = true) {
        for (index, subView) in containerView.subviews.enumerated() {
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
    
    func removeChallenge(id: Int) {
        if let imageView = challengeViewDict[id] {
            imageView.removeFromSuperview()
            challengeViewDict.removeValue(forKey: id)
            updateLayout(view: nil)
        }
        if challengeViewDict.isEmpty {
            isHidden = true
        }
    }
    
}
