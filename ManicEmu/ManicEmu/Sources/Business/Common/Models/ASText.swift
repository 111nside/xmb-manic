//
//  swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

struct ASText {
    var attributes: Attributes? = nil
    var highlights = [Highlight]()
    var textIcons = [Icon]()
    var shadow: Shadow? = nil
    
    ///Default Title Builder
    ///Default Color: LabelPrimary, Default Font Size: 17 medium
    static func extraLargeText(_ text: String,
                               color: UIColor = R.Color.LabelPrimary,
                               numberOfLines: Int = 1) -> Self {
        Self(attributes: .head(text: text, color: color, numberOfLines: numberOfLines))
    }
    
    ///Default Title Builder
    ///Default Color: LabelPrimary, Default Font Size: 15 medium
    static func largeText(_ text: String,
                          color: UIColor = R.Color.LabelPrimary,
                          numberOfLines: Int = 1) -> Self {
        Self(attributes: .title(text: text, color: color, numberOfLines: numberOfLines))
    }
    
    ///Default Title Builder
    ///Default Color: LabelPrimary, Default Font Size: 14
    static func mediumText(_ text: String,
                           color: UIColor = R.Color.LabelPrimary,
                           numberOfLines: Int = 1) -> Self {
        Self(attributes: .body(text: text, color: color, numberOfLines: numberOfLines))
    }
    
    ///Default Detail Builder
    ///Default Color: LabelSecondary, Default Font Size: 12
    static func smallText(_ text: String,
                          color: UIColor = R.Color.LabelSecondary,
                          numberOfLines: Int = 1) -> Self {
        Self(attributes: .footnote(text: text, color: color, numberOfLines: numberOfLines))
    }
    
    ///Default Detail Builder
    ///Default Color: LabelSecondary, Default Font Size: 11
    static func extraSmallText(_ text: String,
                               color: UIColor = R.Color.LabelSecondary,
                               numberOfLines: Int = 1) -> Self {
        Self(attributes: .detail(text: text, color: color, numberOfLines: numberOfLines))
    }
    
    ///After the title, an icon follows.
    ///Default Color: LabelPrimary, Default Font Size: 15 medium Default ASIcon Size: 15 medium
    static func largeTextFolowedByIcon(icon: ASIcon,
                                       text: String,
                                       color: UIColor = R.Color.LabelPrimary,
                                       numberOfLines: Int = 1) -> Self {
        let attributes = Attributes.title(text: text, color: color, numberOfLines: numberOfLines)
        let textIcon = Icon(icon: icon.updateColorsIfNeed(colors: [color]), position: UInt(text.count > 0 ? text.count : 0))
        return Self(attributes: attributes, textIcons: [textIcon])
    }
    
    
    
    /// Detail Starting with a ASIcon
    ///Default Color: LabelSecondary, Default Font Size: 11 Default ASIcon Size: 11
    static func extraSmallTextStartingWithIcon(icon: ASIcon? = nil,
                                               text: String,
                                               color: UIColor = R.Color.LabelSecondary,
                                               numberOfLines: Int = 1) -> Self {
        let attributes = Attributes.detail(text: text, color: color, numberOfLines: numberOfLines)
        if let icon {
            let textIcon = Icon(icon: icon.updateColorsIfNeed(colors: [color]))
            return Self(attributes: attributes, textIcons: [textIcon])
        } else {
            return Self(attributes: attributes)
        }
    }
    
    ///Quickly add highlights to the detail.
    ///Default Color: LabelSecondary, Default Font Size: 11
    static func smallTextWithHighlights(_ text: String,
                                        color: UIColor = R.Color.LabelSecondary,
                                        highlights: [Highlight],
                                        numberOfLines: Int = 1) -> Self {
        let attributes = Attributes.detail(text: text, color: color, numberOfLines: numberOfLines)
        return Self(attributes: attributes, highlights: highlights)
    }
    
    struct Icon {
        var icon: ASIcon
        var position: UInt = 0
        var iconSize: CGFloat? = nil ///If not specified, it defaults to the container size or the font size in ASText Attributes.
    }
    
    struct Highlight {
        var range: Range<String.Index>
        var color: UIColor = R.Color.Yellow
        var font: UIFont? = nil ///By default, use the Label's font.
    }
    
    struct Attributes {
        var text: String
        var color = R.Color.LabelPrimary
        var font = R.Font.Body(emphasis: true)
        var alignment: NSTextAlignment = .left
        var numberOfLines: Int = 1
        var lineBreakMode: NSLineBreakMode = .byTruncatingTail
        
        ///Default font size 17 medium, color LabelPrimary
        static func head(text: String,
                         color: UIColor = R.Color.LabelPrimary,
                         numberOfLines: Int = 1) -> Attributes {
            Attributes(text: text,
                       color: color,
                       font: R.Font.Headline(emphasis: true),
                       numberOfLines: numberOfLines)
        }
        
        ///Default font size 15 medium, color LabelPrimary
        static func title(text: String,
                          color: UIColor = R.Color.LabelPrimary,
                          numberOfLines: Int = 1) -> Attributes {
            Attributes(text: text,
                       color: color,
                       numberOfLines: numberOfLines)
        }
        
        ///Default font size 14, color LabelPrimary
        static func body(text: String,
                         color: UIColor = R.Color.LabelPrimary,
                         numberOfLines: Int = 1) -> Attributes {
            Attributes(text: text,
                       color: color,
                       font: R.Font.Body2(),
                       numberOfLines: numberOfLines)
        }
        
        ///Default font size 12, color LabelSecondary
        static func footnote(text: String,
                             color: UIColor = R.Color.LabelSecondary,
                             numberOfLines: Int = 1) -> Attributes {
            Attributes(text: text, color: color,
                       font: R.Font.Footnote(),
                       numberOfLines: numberOfLines)
        }
        
        ///Default font size 11, color LabelSecondary
        static func detail(text: String,
                           color: UIColor = R.Color.LabelSecondary,
                           numberOfLines: Int = 1) -> Attributes {
            Attributes(text: text, color: color,
                       font: R.Font.Caption(),
                       numberOfLines: numberOfLines)
        }
    }
    
    struct Shadow {
        var shadowColor = UIColor.black
        var shadowOpacity: Float = 0.3
        var shadowOffset = CGSize(width: 0, height: 2)
        var shadowRadius: CGFloat = 2
    }
    
    enum TapType {
        case highlight(ASText.Highlight)
        case icon(ASText.Icon)
        case label
    }
}
