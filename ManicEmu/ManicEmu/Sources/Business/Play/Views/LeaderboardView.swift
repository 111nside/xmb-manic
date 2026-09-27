//
//  LeaderboardView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/9/1.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class LeaderboardDetailView: BaseView {
    private let titleLabel: UILabel = {
        let view = UILabel()
        view.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textColor = R.Color.LabelPrimary
        view.minimumScaleFactor = 0.5
        return view
    }()
    
    let seperator: UIView = {
        let view = UIView()
        view.backgroundColor = R.Color.Border
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let icon = UIImageView(image: R.image.customFlagPatternCheckered()?.applySymbolConfig(font: R.Font.Caption2(emphasis: true)))
        addSubview(icon)
        icon.snp.makeConstraints { make in
            make.size.equalTo(12)
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceExtraSmall)
            make.centerY.equalToSuperview()
        }
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-9)
        }
        
        addSubview(seperator)
        seperator.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.size.equalTo(CGSize(width: 1, height: 12))
            make.centerY.equalToSuperview()
        }
        
    }
    
    func updateTitle(string: String?) {
        titleLabel.text = string
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class LeaderboardView: RoundAndBorderView {
    private var itemsDict: [Int: LeaderboardDetailView] = [:]
    private let containerView = UIView()
    
    init() {
        super.init(roundCorner: .allCorners, radius: 12, borderColor: R.Color.Border, borderWidth: 1)
        makeBlur(blurRadius: 2.5, blurAlpha: 0.4)
        
        enablePressEffect = true
        
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.equalToSuperview().offset(-15)
        }
        
        let icon = UIImageView(image: .symbolImage(.playFill).applySymbolConfig(font: UIFont.systemFont(ofSize: 8, weight: .bold)))
        icon.contentMode = .scaleAspectFit
        addSubview(icon)
        icon.snp.makeConstraints { make in
            make.size.equalTo(10)
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceExtraSmall)
            make.centerY.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateLeaderboard(id: Int, content: String) {
        if self.isHidden {
            self.isHidden = false
        }
        if let item = itemsDict[id] {
            item.updateTitle(string: content)
        } else {
            let item = LeaderboardDetailView()
            item.updateTitle(string: content)
            containerView.addSubview(item)
            updateLayout()
            itemsDict[id] = item
        }
    }
    
    private func updateLayout() {
        for (index, subView) in containerView.subviews.enumerated() {
            if let view = subView as? LeaderboardDetailView {
                if index == containerView.subviews.count - 1 {
                    view.seperator.isHidden = true
                } else {
                    view.seperator.isHidden = false
                }
            }
            subView.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
                if index == 0 {
                    make.leading.equalToSuperview()
                } else {
                    make.leading.equalTo(containerView.subviews[index-1].snp.trailing)
                }
                if index == containerView.subviews.count - 1 {
                    make.trailing.equalToSuperview()
                }
            }
        }
    }
    
    func removeLeaderboard(id: Int) {
        if let item = itemsDict[id] {
            item.removeFromSuperview()
            itemsDict.removeValue(forKey: id)
            updateLayout()
        }
        if itemsDict.isEmpty {
            self.isHidden = true
        }
    }
}
