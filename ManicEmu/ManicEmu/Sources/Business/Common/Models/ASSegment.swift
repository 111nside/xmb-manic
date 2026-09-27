//
//  ASSegment.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

struct ASSegment {
    var items = [ASButton]()
    var index: Int = 0
    var corner: ASCornerStyle = .circle
    var background: UIColor = R.Color.BackgroundTertiary
    var indicatorCorner: ASCornerStyle = .circle
    var indicatorBackground: UIColor = R.Color.BackgroundQuaternary
    var contentInsets = UIEdgeInsets(inset: R.Size.ContentSpaceTiny)
    var itemSpacing = R.Size.ContentSpaceTiny
    
    static func iconSegment(icons: [ASIcon], index: Int = 0) -> Self {        
        Self(items: icons.map({
            ASButton.iconOnly(icon: $0,
                              iconSize: CGSize(R.Size.ButtonExtraSmall),
                              background: .clear,
                              insets: UIEdgeInsets(inset: R.Size.ContentSpaceTiny))}),
             index: index)
    }
    
    static func textSegment(titles: [String], index: Int = 0) -> Self {
        Self(items: titles.map({
            var normalText = ASText.smallText($0)
            normalText.attributes?.font = R.Font.Subheadline()
            normalText.attributes?.alignment = .center
            var highlightText = normalText
            highlightText.attributes?.color = R.Color.LabelPrimary
            highlightText.attributes?.alignment = .center
            return ASButton(normalAttributes: .init(title: normalText, background: .clear),
                            allAttributes: [.highlight: .init(title: highlightText, background: .clear)],
                            sizeStyle: .fixHeight(R.Size.ButtonSmall))
        }), index: index)
    }
}
