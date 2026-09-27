//
//  ASChevron.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

struct ASChevron {
    var icon: ASIcon = .symbol(.chevronRight, colors: [R.Color.LabelTertiary])
    var title: String? = nil
    var titleColor: UIColor = R.Color.LabelSecondary
    var titleFont: UIFont = R.Font.Footnote()
    var enableInteration: Bool = false
    
    var button: ASButton {
        var temp = ASButton.chevron(icon: icon,
                                    title: title,
                                    titleColor: titleColor,
                                    titleFont: titleFont)
        temp.state = (enableInteration ? .normal : .disabled)
        return temp
    }
}
