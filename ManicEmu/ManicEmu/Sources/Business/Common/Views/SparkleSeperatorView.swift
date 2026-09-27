//
//  SparkleSeperatorView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/23.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class SparkleSeperatorView: BaseView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    init(color: UIColor, lineColor: UIColor = R.Color.Border) {
        super.init(frame: .zero)
        setupViews(color: color, lineColor: lineColor)
    }
    
    init(isGradient: Bool) {
        super.init(frame: .zero)
        setupViews(isGradient: isGradient)
    }
    
    init(starSize: CGFloat) {
        super.init(frame: .zero)
        setupViews(starSize: starSize)
    }
    
    private func setupViews(color: UIColor = R.Color.LabelTertiary,
                            lineColor: UIColor = R.Color.Border,
                            isGradient: Bool = false,
                            starSize: CGFloat = R.Size.ButtonExtraExtraSmall) {
        let starView = isGradient ? GradientImageView(image: UIImage(symbol: .sparkle, size: starSize)) : UIImageView(image: UIImage(symbol: .sparkle, color: color))
        addSubview(starView)
        starView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        let leftLine = UIView()
        leftLine.backgroundColor = lineColor
        addSubview(leftLine)
        leftLine.snp.makeConstraints { make in
            make.height.equalTo(R.Size.Border)
            make.leading.centerY.equalToSuperview()
            make.trailing.equalTo(starView.snp.leading).offset(-R.Size.ContentSpaceSmall)
        }
        let rightLine = UIView()
        rightLine.backgroundColor = lineColor
        addSubview(rightLine)
        rightLine.snp.makeConstraints { make in
            make.height.equalTo(R.Size.Border)
            make.trailing.centerY.equalToSuperview()
            make.leading.equalTo(starView.snp.trailing).offset(R.Size.ContentSpaceSmall)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
