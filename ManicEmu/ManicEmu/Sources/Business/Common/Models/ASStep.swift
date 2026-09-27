//
//  ASStep.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

struct ASStep {
    var decrease: ASButton
    var increase: ASButton
    var titles = [ASText]()
    var index: Int = 0
    var loopSelection: Bool = false
    var fixedWidth: Bool = false
    var spacing: CGFloat = R.Size.PaddingLarge
    
    static func quickStep(titles: [String],
                          currentIndex: Int = 0,
                          loopSelection: Bool = false,
                          fixedWidth: Bool = false) -> Self {
        
        func generateButton(_ isDecrease: Bool) -> ASButton {
            let icon = ASIcon.symbol(isDecrease ? .chevronLeft : .chevronRight, weight: .semibold)
            let sizeStyle = ASButton.Size.fixSize(R.Size.ButtonSizeExtraExtraSmall)
            let button = ASButton.quickButton(icon: icon, sizeStyle: sizeStyle)
            let disabledIcon = button.allAttributes[.normal]?.icon?.updateColorsIfNeed(colors: [R.Color.LabelTertiary], forceUpdate: true)
            let disabledButtonAttributes = ASButton.Attributes(icon: disabledIcon)
            return button.setAttributes(disabledButtonAttributes, state: .disabled)
        }
        
        let titleTexts = titles.map({
            ASText(attributes: ASText.Attributes(text: $0, font: R.Font.Footnote(), alignment: .center))
        })
        
        return Self(decrease: generateButton(true),
                    increase: generateButton(false),
                    titles: titleTexts,
                    index: currentIndex,
                    loopSelection: loopSelection,
                    fixedWidth: fixedWidth)
    }
}
