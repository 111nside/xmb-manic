//
//  MappingInputPopupView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


class MappingInputPopupView: BaseView {
    class MappingBubbleView: RoundAndBorderView {
        var titleLabel: UILabel = {
            let view = UILabel()
            view.textColor = R.Color.LabelPrimary
            view.font = R.Font.Footnote()
            view.textAlignment = .center
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
            addShadow()
            addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(R.Size.ContentSpaceExtraSmall)
            }
        }
        
        @MainActor required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func updateTip(kind: ControllerSkin.Item.Kind, inputString: String?, position: CGPoint) {
        if let inputString {
            let bubbleView = MappingBubbleView(roundCorner: .allCorners, radius: R.Size.ItemHeightTiny/2)
            bubbleView.backgroundColor = R.Color.BackgroundSecondary
            addSubview(bubbleView)
            bubbleView.titleLabel.text = inputString
            var bubbleWidth = bubbleView.sizeThatFits(.init(100)).width + R.Size.ContentSpaceExtraSmall*2
            bubbleWidth = bubbleWidth < R.Size.ItemHeightMedium ? R.Size.ItemHeightMedium : bubbleWidth
            
            bubbleView.snp.makeConstraints { make in
                make.height.equalTo(R.Size.ItemHeightTiny)
                make.width.greaterThanOrEqualTo(R.Size.ItemHeightMedium)
                if kind == .button || kind == .switchButton {
                    var centerX = position.x - self.width/2
                    if position.x - bubbleWidth/2 < 0 {
                        //左侧超过屏幕外
                        centerX -= (position.x - bubbleWidth/2)
                    } else if position.x + bubbleWidth/2 > self.width {
                        //右侧超过屏幕外
                        centerX -= (position.x + bubbleWidth/2 - self.width)
                    }
                    make.centerX.equalToSuperview().offset(centerX)
                    make.centerY.equalToSuperview().offset(position.y - self.height/2 - R.Size.ItemHeightTiny)
                } else {
                    make.centerX.equalToSuperview().offset(position.x - self.width/2)
                    make.centerY.equalToSuperview().offset(position.y - self.height/2)
                }
            }
        }
    }
}
